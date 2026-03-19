# Statystical Analysis Scripts

Supplementary material repository containing MATLAB scripts used for data processing and statistical analysis in a scientific workflow.

## Methods summary

This repository contains MATLAB workflows used to analyze cytometry endpoints and larvae hatching outcomes.

- `scripts/statistical_analysis.m` uses an assumption-driven path per parameter: normality check first, then parametric or non-parametric group comparisons depending on data structure (two-group vs multi-group) and variance behavior.
- `scripts/larvae_hatching_analysis.m` fits a linear mixed-effects model with replicate/plate as a random effect and reports Bonferroni-adjusted pairwise contrasts.
- Reports include test path, p-values, and generated figures (boxplots, bar plots, and heatmaps) to support transparent, reproducible interpretation.

## Scope

This repository intentionally contains only three scripts:

1. `scripts/statistical_analysis.m`
2. `scripts/larvae_hatching_analysis.m`
3. `scripts/muse_file_cleaner_advanced.m`

## Repository structure

- `scripts/` - MATLAB source scripts used in the study workflow
- `docs/` - reproducibility notes and expected input data format
- `examples/` - optional place for anonymized demo inputs or screenshots

## Requirements

- MATLAB R2021a or newer (recommended)
- Statistics and Machine Learning Toolbox (required by statistical scripts)
- Input files in `.xlsx`, `.xls`, or `.csv` format (depending on script)

## Quick start

1. Open MATLAB.
2. Set current folder to this repository root.
3. Run one of the scripts from `scripts/`.
4. Follow interactive prompts for file selection, group selection, and output folder.

## Script summary

### `statistical_analysis.m`

General multi-group statistical analysis for cytometry-style tabular data.

- Interactive selection of groups and parameters
- Automatic normality checks
- Parametric vs non-parametric branch selection
- Pairwise post hoc comparisons
- Text report and plots export

### `larvae_hatching_analysis.m`

Linear mixed-effects analysis of larvae hatching success by substance group.

- Expects three columns (renamed internally to `w`, `s`, `p`)
- Fits mixed model `w ~ s + (1|p)`
- Computes Bonferroni-adjusted post hoc contrasts
- Exports report, boxplot, heatmap, bar plot, and residual diagnostics

### `muse_file_cleaner_advanced.m`

Preprocessing utility for Muse cytometer export files.

- Loads Excel/CSV data
- Cleans headers and duplicate variable names
- Optional conversion of percentage columns to decimal fractions
- Saves processed output as `*_processed.xlsx`

## Reproducibility notes

See:

- `docs/REPRODUCIBILITY.md`
- `docs/DATA_REQUIREMENTS.md`

## Data availability

Raw experimental data are available from the corresponding author on reasonable request.

## Citation in manuscript (example)

"MATLAB analysis scripts are available as supplementary material at: https://github.com/Warlord1986pl/Statystical_analysis_scripts."

Citation metadata for software citation tools is provided in `CITATION.cff`.

## License

No open-source license has been applied yet. If needed for journal policy, add a dedicated license file before public release.
