#!/bin/bash

# Exit immediately if any command fails
set -e

echo ""
echo "=== Installation Setup ==="

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DIR="$PWD"

echo "Source directory: $SOURCE_DIR"
echo

# Ask whether to install in-place
while true; do
    read -r -p "Install in-place in $SOURCE_DIR? [Y/n]: " ans
    case "$ans" in
        [Yy]|"" )
            TARGET_DIR="$SOURCE_DIR"
            in_place="y"
            break
            ;;
        [Nn] )
            in_place="n"
            read -r -p "Enter installation target directory (will be created if needed): " TARGET_DIR
            # If user just hits Enter, fall back to PWD
            TARGET_DIR="${TARGET_DIR:-$DEFAULT_DIR}"
            TARGET_DIR="$(mkdir -p "$TARGET_DIR" && cd "$TARGET_DIR" && pwd)"
            break
            ;;
        * )
            echo "Please answer y or n."
            ;;
    esac
done

# Offer to add nmrdbsearch alias to ~/.bashrc
echo
echo "You can add an alias so 'nmrdbsearch' runs $TARGET_DIR/nmrdbsearch"
while true; do
    read -r -p "Add alias to $HOME/.bashrc? [Y/n]: " answer
    case "$answer" in
        [Yy]|"" )
            # Check if alias already exists to avoid duplicates
            if grep -q 'alias nmrdbsearch=' "$HOME/.bashrc" 2>/dev/null; then
                echo "An alias for nmrdbsearch already exists in $HOME/.bashrc; not adding another."
            else
                echo "alias nmrdbsearch=\"$TARGET_DIR/nmrdbsearch\"" >> "$HOME/.bashrc"
                echo "Alias added. Restart your shell or run:"
                echo "  source \"$HOME/.bashrc\""
            fi
            break
            ;;
        [Nn] )
            echo "Skipping alias creation."
            break
            ;;
        * )
            echo "Please answer y or n."
            ;;
    esac
done
echo "Installing to: $TARGET_DIR"

echo "Copying contents..."
if [ "$in_place" = "y" ]; then
    echo "Installing in-place; no copy needed."
else
    # Copy all contents (including hidden files) to the target directory
    cp -r "$SOURCE_DIR"/. "$TARGET_DIR"/
fi

if [ "$in_place" = "n" ]; then
    echo
    echo "Note: You now have two copies of nmrdbsearch:"
    echo "  Source (for git pull / updates): $SOURCE_DIR"
    echo "  Installed (used at runtime):     $TARGET_DIR"
    echo "Future 'git pull' should be run in the source directory."
    echo "The alias (if added) points to:    $TARGET_DIR/nmrdbsearch"
    echo
fi

echo "Compiling subdirectories..."
# Find any subdirectory containing a Makefile and run 'make' inside it
find "$TARGET_DIR" -type f -name "Makefile" | while read -r makefile; do
    SUB_DIR="$(dirname "$makefile")"
    echo "Running make in: $SUB_DIR"
    # Run make inside a subshell to avoid breaking the script's directory state
    (cd "$SUB_DIR" && make)
done

DB_LIST=( 'NMRBank' 'NMRexp' 'NP' 'IMPUR' 'ALL' )
NUM_DBS=${#DB_LIST[@]}

for db in "${DB_LIST[@]}"; do
    mkdir -p "$TARGET_DIR/$db"
done

#extracting the .tar.gz files into their directories
echo "Extracting compressed files..."

tar -xf "$TARGET_DIR/IMPUR.tar.gz" -C "$TARGET_DIR/IMPUR"
tar -xf "$TARGET_DIR/NP.tar.gz" -C "$TARGET_DIR/NP"
tar -xf "$TARGET_DIR/NMRBank.tar.gz" -C "$TARGET_DIR/NMRBank"
tar -xf "$TARGET_DIR/NMRexp.tar.gz" -C "$TARGET_DIR/NMRexp"
tar -xf "$TARGET_DIR/NMRexp_dbsum.tar.gz" -C "$TARGET_DIR/NMRexp"
tar -xf "$TARGET_DIR/ALL_dbsum.tar.gz" -C "$TARGET_DIR/ALL"

#cleaning up .tar.gz files
rm "$TARGET_DIR"/*.tar.gz

echo "Configuring nmrdbsearch script..."

# Search and replace 'folder_goes_here' in nmrdb
nmrdbsearchfile="$TARGET_DIR/nmrdbsearch"
# Use a safe delimiter (|) in sed in case the folder name contains slashes
sed -i "s|folder_goes_here|$TARGET_DIR|g" "$nmrdbsearchfile"

# Make nmrdbsearch executable
chmod +x "$nmrdbsearchfile"

echo "=== Dependency Check: Open Babel ==="
# Install Open Babel if it is not already installed
if ! command -v obabel &> /dev/null; then
    echo "Open Babel not found. Installing dependency..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y openbabel libopenbabel-dev
    elif command -v yum &> /dev/null; then
        sudo yum install -y openbabel openbabel-devel
    elif command -v brew &> /dev/null; then
        brew install open-babel
    else
        echo "Error: Package manager not recognized. Please install Open Babel manually."
        exit 1
    fi
else
    echo "Open Babel is already installed."
fi


#do some copying and sorting of database files to make the ultimate all-databases db and 
#all-solvents lists

# Nuclei and solvents
NUC_LIST=( '1H' '13C' '31P' '19F' '11B' '29Si' )
SOLVENT_LIST=( \
  'DMSO' 'C2D2Cl4' 'acetic' 'CD2Cl2' 'CD3CN' 'acetone' \
  'CF3CO2D' 'DMF' 'mixed' 'D2O' 'DMF' 'MeOD' 'pyridine' \
  'not_known' 'THF' 'PhMe' 'C6D6' 'DMSO' 'CDCl3'  \
)

NUM_SOLVENTS=${#SOLVENT_LIST[@]}
NUM_NUCLEI=${#NUC_LIST[@]}

# Databases for sections 1 & 2
DB_LIST=( 'NMRBank' 'NMRexp' 'NP' 'IMPUR' )
NUM_DBS=${#DB_LIST[@]}

###############################################################################
# Progress bar
###############################################################################

draw_progress() {
    local current=$1 total=$2
    local bar_width=50
    local percent=$(( 100 * current / total ))
    local filled=$(( bar_width * current / total ))
    printf -v fill  "%${filled}s"
    printf -v empty "%$((bar_width - filled))s"
    printf "\rProgress: [${fill// /#}${empty// /-}] %d%% (%d/%d)" \
           "$percent" "$current" "$total"
}

###############################################################################
# Step counts (for progress bar)
###############################################################################

# Section 1: per-DB "all solvent" peaklists (approximate: one step per nuc×DB)
TOTAL_STEPS_1=$(( NUM_NUCLEI * NUM_DBS ))

# Section 2: ALL peaklists (only 1H and 13C)
TOTAL_STEPS_2=$(( 2 * NUM_SOLVENTS + 2 ))

# Section 3: unpacking peak lists (depends on nuclei per DB)
TOTAL_STEPS_3=0
for ((db_idx=0; db_idx<NUM_DBS; db_idx++)); do
    db=${DB_LIST[db_idx]}
    if [ "$db" = "NMRexp" ]; then
        local_nucs=( '1H' '13C' '31P' '19F' '11B' '29Si' )
    else
        local_nucs=( '1H' '13C' )
    fi
    num_local_nucs=${#local_nucs[@]}
    TOTAL_STEPS_3=$(( TOTAL_STEPS_3 + num_local_nucs * NUM_SOLVENTS + num_local_nucs ))
done

TOTAL_STEPS_3=$(( TOTAL_STEPS_3 + 2 * NUM_SOLVENTS + 2 )) # adding in steps for ALL


###############################################################################
# Section 1: per-DB "all solvent" peaklists
###############################################################################

echo "Section 1: generating per-DB 'all solvent' peaklists."
current_step=0

for ((db_idx=0; db_idx<NUM_DBS; db_idx++)); do
    db=${DB_LIST[db_idx]}
    db_dir="$TARGET_DIR/$db"

    for ((nuc_idx=0; nuc_idx<NUM_NUCLEI; nuc_idx++)); do
        nuc=${NUC_LIST[nuc_idx]}
        all_solvents_file="$TARGET_DIR/$db/accessions_${nuc}_all"

        # Only if this nucleus is actually used for this DB
        if [ -f "$db_dir/accessions_${nuc}_CDCl3" ]; then
            >"$all_solvents_file"

            for ((sol_idx=0; sol_idx<NUM_SOLVENTS; sol_idx++)); do
                solvent=${SOLVENT_LIST[sol_idx]}
                src_file="$db_dir/accessions_${nuc}_${solvent}"

                # Append if file exists
                if [ -f "$src_file" ]; then
                    cat "$src_file" >> "$all_solvents_file"
                fi
            done
			
            LC_ALL=C sort -u -o "$all_solvents_file" "$all_solvents_file"
            LC_ALL=C sort -n -o "$all_solvents_file" "$all_solvents_file"
        fi

        current_step=$((current_step + 1))
        draw_progress "$current_step" "$TOTAL_STEPS_1"
    done
done
echo

###############################################################################
# Section 2: ALL DB (1H and 13C)
###############################################################################

echo -e "\nSection 2: generating ALL peaklists for 1H and 13C."
current_step=0

SOLVENT_LIST+=( 'all' )
NUM_SOLVENTS=${#SOLVENT_LIST[@]}

for ((nuc_idx=0; nuc_idx<2; nuc_idx++)); do
    nuc=${NUC_LIST[nuc_idx]}

    for ((sol_idx=0; sol_idx<NUM_SOLVENTS; sol_idx++)); do
        solvent=${SOLVENT_LIST[sol_idx]}
        combined_file="$TARGET_DIR/ALL/accessions_${nuc}_${solvent}"
        >"$combined_file"

        for ((db_idx=0; db_idx<NUM_DBS; db_idx++)); do
            db=${DB_LIST[db_idx]}
            db_dir="$TARGET_DIR/$db"
            src_file="$db_dir/accessions_${nuc}_${solvent}"

            if [ -f "$src_file" ]; then
                cat "$src_file" >> "$combined_file"
            fi
        done

        LC_ALL=C sort -o "$combined_file" "$combined_file"

        current_step=$((current_step + 1))
        draw_progress "$current_step" "$TOTAL_STEPS_2"
    done
done
echo
echo -e "\nALL lists generated."

###############################################################################
# Section 3: unpack accessions into per-peak files
###############################################################################

# DB list for unpacking (includes ALL)
DB_LIST=( 'NMRBank' 'NMRexp' 'NP' 'ALL' 'IMPUR' )
NUM_DBS=${#DB_LIST[@]}

echo -e "\nSection 3: Unpacking peak lists. This may take as long as 5 minutes! Please be patient!"
current_step=0

for ((db_idx=0; db_idx<NUM_DBS; db_idx++)); do
    db=${DB_LIST[db_idx]}

    for ((sol_idx=0; sol_idx<NUM_SOLVENTS; sol_idx++)); do
        solvent=${SOLVENT_LIST[sol_idx]}

        for ((nuc_idx=0; nuc_idx<NUM_NUCLEI; nuc_idx++)); do
            nuc=${NUC_LIST[nuc_idx]}

            # Source: per-DB except ALL, which lives in TARGET_DIR
            src_file="$TARGET_DIR/$db/accessions_${nuc}_${solvent}"
            if [[ "$db" == "ALL" ]]; then
                src_file="$TARGET_DIR/$db/accessions_${nuc}_${solvent}"
            fi

            # Only track progress if DB actually uses this nucleus (CDCl3 marker)
            if [ -f "$TARGET_DIR/$db/accessions_${nuc}_CDCl3" ]; then
                current_step=$((current_step + 1))
                draw_progress "$current_step" "$TOTAL_STEPS_3"
            fi

            [ ! -f "$src_file" ] && continue

            out_file="$TARGET_DIR/$db/peaks_${nuc}_${solvent}"
            >"$out_file"

            # Expand CSV accession->peaks into one line per peak
            gawk -F',' -v OFS=',' '
                {
                    accession  = $1
                    shifts_raw = substr($0, index($0, FS) + 1)
                    n = split(shifts_raw, a, ",")
                    for (k = 1; k <= n; k++) {
                        print a[k], accession
                    }
                }
            ' "$src_file" >> "$out_file"

            LC_ALL=C sort -n -o "$out_file" "$out_file"
        done
    done
done
echo


cd "$TARGET_DIR"

echo ""
echo "=== Installation Completed Successfully! ==="
