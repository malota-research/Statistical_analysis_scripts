# Data Requirements

## `statistical_analysis.m`

Expected input:

- File type: `.xlsx`, `.xls`, or `.csv`
- Required column: `SampleID`
- Other columns: numeric parameters to analyze

Behavior:

- User selects groups and parameters interactively
- Script performs tests and exports text + figures

## `larvae_hatching_analysis.m`

Expected input:

- File type: `.xlsx` or `.xls`
- Exactly 3 columns, interpreted as:
  - `w`: hatching success
  - `s`: substance/group
  - `p`: repetition or block

Behavior:

- Script cleans category labels
- Requires reference category `k` in group column
- Fits mixed model and exports report + figures

## `muse_file_cleaner_advanced.m`

Expected input:

- File type: `.xlsx`, `.xls`, or `.csv`
- First row should contain column headers

Behavior:

- Cleans invalid/duplicate headers
- Optionally converts `%` columns to decimal fractions
- Exports `*_processed.xlsx` to source directory
