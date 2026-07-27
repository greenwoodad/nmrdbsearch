# nmrdbsearch

This program takes in an NMR peak list, either generated manually or by Topspin or MNova, and searches tables of shifts
derived from various NMR databases, currently NP-MRD (https://np-mrd.org/), NMRBank (https://doi.org/10.1039/D4SC08802F),
NMRexp (https://doi.org/10.1038/s41597-025-06245-5), and the trace impurity tables from Fulmer et al.
(DOI: [10.1021/om100106e](https://doi.org/10.1021/om100106e)). It supports 1D (1H, 13C, 31P, 19F, 11B, 29Si) and 2D (1H/X) data. It returns multiple 
output files describing possible compounds for each peak, as well as chemical structures of the top hits. 

## Prerequisites

This script requires about 7 GB disk space, a Linux environment, and sgrep (https://sgrep.sourceforge.net/). 
Currently it only supports Topspin/MNova peak lists and Bruker acqu files, but data collected on non-Bruker 
instruments can be analyzed by specifying solvent and nuclei with command-line options instead of using an acqu 
file in the data directory.

It uses Open Babel (https://openbabel.org/index.html) to draw molecule images of the top matches.

## Installing

```sh
git clone https://github.com/greenwoodad/nmrdbsearch
```
or 

```sh
git clone https://(your github username)@github.com/greenwoodad/nmrdbsearch.git
```

followed by:
```sh
chmod +x ./nmrdbsearch/install.sh
./nmrdbsearch/install.sh
```

The install script will ask where to install the program, copy nmrdbsearch to the specified location, and install dependencies (Open Babel and sgrep-1.0).

If you get an error like make: command not found you will need to install development tools.

Ubuntu, Linux Mint, Debian, Pop!_OS:
```sh
sudo apt update && sudo apt install build-essential
```

Fedora, CentOS, RHEL, Rocky Linux:
```sh
sudo dnf groupinstall "Development Tools"
```
Arch Linux, Manjaro:
```sh
sudo pacman -Syu base-devel
```
Then re-run the install script.

The script will ask if you want to alias nmrdbsearch in your .bashrc file. If you indicate yes, you can run the program by typing
nmrdbsearch in the command line, otherwise you must type "/path/to/nmrdbsearch/nmrdbsearch"

If you change your mind about this later, just add this to ~/.bashrc:

```sh
alias nmrdbsearch="/path/to/nmrdbsearch/nmrdbsearch"
```

where /path/to/ should be replaced with the location of the nmrdbsearch directory.

The install script will unpack the peak lists, expanding the total size to about 7 GB.
**This is a lengthy process and may take up to 5 minutes.**

## Getting Started

### Sorted grep (sgrep)

nmrdbsearch comes with sgrep-1.0 (https://sgrep.sourceforge.net/) in its top-level directory. It should work automatically without further action. If desired, sgrep can be aliased for general use by adding this to ~/.bashrc:

```sh
alias sgrep="/path/to/nmrdbsearch/sgrep-1.0/sgrep"
```

where /path/to/ should be replaced with the location of the nmrdbsearch directory.

### Open Babel

Running install.sh should install Open Babel. If it fails, install it following the instructions here:
https://openbabel.org/docs/Installation/install.html

## Usage

Note: The databases this program searches contain approximately 89% data collected in CDCl3, 8% in DMSO, and 3% in other solvents. Data collected in one solvent will not generally return good matches from entries in different solvents, so the best results can be expected for data collected in CDCl3. Using 13C (or 19F/31P/11B/29Si) 1D data or 1H/13C 2D data tends to provide better results than 1H 1D data, given the relatively poor dispersion of 1H shifts. Although an exact match is unlikely, observing common structural motifs in the structures_<db>.svg image file may provide insight into the identity of your compound. Searching the default ALL database will usually work well unless doing mixture analysis (see below).

### Options

| Option | Description |
|--------|-------------|
| `-h`, `-?`, `--help` | Show help message. |
| `-i`, `--input` | Set input peak list file (.txt or .xml).<br>Looks in datafolder/pdata/1/ if not given. |
| `-d`, `--database` (default ALL) | Database to search: `NP`, `NMRBank`, `NMRexp`, `IMPUR`, or `ALL`. |
| `-s`, `--solvent` (default from acqu/pdata) | Set to the most applicable solvent:<br>`acetic`, `acetone`, `C6D6`, `CD3CN`, `CD2Cl2`, `CDCl3`, `CD3OD`,<br>`D2O`, `DMF`, `DMSO`, `Pyr`, `THF`, `Tol`, `all`. |
| `-dim`, `--dimension` (default inferred from data) | Set to '1D' for 1D data, '2D' for 2D data. |
| `-n`, `--nucleus` (default from acqu/pdata) | Set to `1H`, `13C`, `31P`, `19F`, `11B`, or `29Si`. |
| `-n2`, `--nucleus2` (default from acqu/pdata) | For 2D data: set to `13C`, `31P`, `19F`, `11B`, or `29Si`. |
| `-t`, `--tolerance` | Set tolerance (± ppm) for matching peaks.<br>Defaults: 0.03 for 1H, 0.3 for 13C, 1.0 for others. |
| `-t2`, `--tolerance2` | Set tolerance (± ppm) for the indirect dimension (2D only).<br>Defaults: 0.3 for 13C, 1.0 for others. |
| `-m`, `--mixmode` (default `n`) | Mixture mode. Use `y` for complex mixtures (slower for large databases).<br>If `n`, only the top 200 matches (by number of hits) are considered. |
| `-im`, `--impureinc` (default `n`) | When using database `ALL`, include all IMPUR results in the structure image file (may increase clutter). |
| `-v`, `--verbose` | Verbose mode. More command-line output as the program runs. |
  
The defaults can be modified at the top of the script itself.

### Data Collection and Processing

#### Picking Peaks

Spectra should first be referenced to TMS. For 13C spectra collected in D2O, it may be advisable to try inputting data both directly referenced to TSP or DSS and indirectly to TMS (based on the 2H lock), as the shifts in these databases are not fully consistent one way or the other.

With 1D 1H data, peaks should be picked at the center of each multiplet. For other (decoupled) 1D spectra, automated peak picking may be sufficient, but should be checked manually. For carbons split by other nuclei such as 31P or 19F, it is advisable to pick the multiplet centers as with 1H.

With 2D data, peaks should ideally be picked with both the 13C and 1H spectra in view to achieve approximately 0.1 ppm resolution in the 13C dimension and the best possible resolution in the 1H dimension (for example, using “peak-by-peak” picking with the Shift key held down in MNova).

Peak lists will be saved in pdata/1 by default in Topspin. With MNova, click “Copy Table” in the peaks table and then paste the contents (including the header) into a text file named peak.txt (no “s”) in pdata/1. If generated manually, make sure peaks are all specified to at least one decimal place and that the filename ends in .txt. Manually-generated input files should be specified with the -i option along with -dim for dimension (1D or 2D) and -n for nucleus (and -n2 for the indirect nucleus if dim is 2D).

### Running the Program

```sh
nmrdbsearch [OPTIONS]... path/to/data (uses current directory as default)
```

When run in the directory of a Bruker dataset with a peak list of the form pdata/1/peaklist.xml or pdata/1/peak.txt, no options need to be specified, as long as the acqu file is present. The program will extract the solvent and nucleus/nuclei from the acqu file and infer the dimensionality from the peak list format.

If all you have is a peak list (in a file like file.txt), the program can be run as long as these details are provided as options. At minimum, specify the peak file with -i along with -dim for dimension (1D or 2D) and -n for nucleus (and -n2 for the indirect nucleus if dim is 2D). It is advisable to also supply the solvent with -s; otherwise it will be set to all.

By default, the program runs on all databases (ALL), which can take about a minute to complete. Smaller databases (NP, NMRBank, and IMPUR) will be faster. Under normal operation, matches that have high match ratios (peak hits / total signals for a compound) can be dropped from the results files if the number of hits is still low compared to the number of input peaks, depending on the quality of the other matches. This may be undesirable if your peak list represents a complex mixture. Set mixture mode to y with the -m flag to retain these results as well, but be aware that this will slow down the program significantly for large databases (ALL and NMRexp).

When running with the ALL database, hits from the IMPUR database will be retained even if they are considered weak (only a few peak hits), because the compounds in this database are more likely to be present as impurities. By default they are excluded from the structures_ALL.svg image file, but can be included by specifying the -im flag.

## Notes about 2D Data

Currently, database entries are identified as matches for 2D data if they contain 1H and X shifts that are both within their respective tolerances for a peak in the input table. This means that the search identifies possible HMBC peaks as well as HSQC peaks. On the other hand, it produces more false positives than if only entries’ HSQC peaks were considered. 

Match ratios for 2D data are calculated based on 1H shifts filtered by the X nucleus.

## Results Files

This program produces multiple results files in $datadirectory/nmrdbsearch, but the most important files to check are **best_hits_summary_<db>** and **structures_<db>.svg**. The best_hits_summary_<db> file shows the top 20 hits (plus some IMPUR hits if dbstring=ALL) sorted by the match ratio given by Hopcroft–Karp bipartite matching. This is defined as the number of one-to-one matches (a queried peak cannot match multiple DB peaks and vice versa) divided by the total number of peaks in the database for that compound. Note that this is distinct from the match ratio given in the full_summary_<db>, hitssorted_full_summary_<db>, and shiftordered_results_<db> files. A value of 1.0 is a good sign of an exact match (except for compounds with only a small number of signals), and a value above 0.8 is likely to indicate strong structural similarity. Also reported are the number of peaks that the given accession uniquely matched (usually 0 unless the shift is highly unusual, more common for nuclei like 11B and 29Si), the accession, and the compound name (if available).

The full_summary_<db>, hitssorted_full_summary_<db>, and shiftordered_results_<db> files give the top 200 (maxaccessions in the script) results, formatted in different ways. In full_summary_<db>, they are sorted by the “many-to-one” match ratio defined as hits / compound peaks, where a single queried peak or peak pair can match multiple database peaks (but not vice versa). In hitssorted_full_summary_<db>, they are sorted by the total number of hits, and in shiftordered_results_<db>, results are clustered by the queried peaks (or pairs of peaks). There are also individual files corresponding to each of the best accessions (from best_hits_summary_<db>) where the database peaks for that accession can be compared to the queried peaks. This can be useful to check if the last few unmatched queried peaks are actually just outside the tolerance window for a given accession.

Finally, structures_<db>.svg shows a grid of the structures of the best accessions, with the accession name and Hopcroft–Karp match ratio displayed under each. Common structural motifs can often be observed by studying the matches.

## Note about Database Processing:

The provided peak lists have been adapted from their source databases. In the case of NP-MRD, only experimental shifts have been included. In all cases (except for the impurity tables), some shifts have been excluded because they were identified as likely typos or otherwise inappropriate. These include values that appear to be from a different nucleus, mis-read IR stretches, J-couplings, or other non-chemical-shift text. Nonetheless, some typos have undoubtedly gone undetected. No attempt has been made to insert corrected versions of typos into the lists; they have simply been omitted. Properly-reported very large values were checked manually, so genuinely anomalously large shifts (for example from paramagnetic effects) have been preserved. Peak ranges (reported as shift1–shift2) are represented here as the average of the two reported values.

## Contributing

Pull requests are welcome.

## Authors

Alex Greenwood – author and maintainer –
https://github.com/greenwoodad

## License

MIT
