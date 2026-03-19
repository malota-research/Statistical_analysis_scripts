# Data Requirements

## `statistical_analysis.m`

Expected input:

- File type: `.xlsx`, `.xls`, or `.csv`
- Required column: `SampleID`
- Other columns: numeric parameters to analyze

Behavior:

- User selects groups and parameters interactively
- Script decision workflow per parameter:
  - Anderson-Darling test for normality in each group
  - Levene's test for homogeneity when applicable
  - Two groups: Student's t-test (normal) or Mann-Whitney U test (non-normal)
  - More than two groups: one-way ANOVA + Tukey post hoc (normal + homogeneous) or Kruskal-Wallis + Dunn-type pairwise comparisons
- Script exports:
  - Text report with selected test path and p-values
  - Boxplot, bar plot, binary significance heatmap, significance-stars heatmap

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
- Fits mixed model `w ~ s + (1|p)`
- Uses Bonferroni-adjusted pairwise contrasts after mixed-model fitting
- Script exports:
  - Text report with model coefficients, ANOVA, and adjusted post hoc p-values
  - Boxplot, heatmap, bar plot, residual diagnostics

## `muse_file_cleaner_advanced.m`

Expected input:

- File type: `.xlsx`, `.xls`, or `.csv`
- First row should contain column headers

Behavior:

- Cleans invalid/duplicate headers
- Optionally converts `%` columns to decimal fractions
- Exports `*_processed.xlsx` to source directory

## Data availability

Raw experimental data used in the manuscript are available from the corresponding author on reasonable request.
