# Reproducibility Checklist

Use this checklist before publishing the repository link in the manuscript.

## Environment

- MATLAB version recorded
- Required toolbox availability confirmed
- Script runtime tested on at least one clean machine/session

## Data

- Input dataset format is documented
- Sensitive or identifying data removed
- Example data (if shared) is anonymized

## Outputs

- Reports are generated without manual code edits
- Figure files are generated and readable
- Output folder naming and timestamps behave as expected

## Reporting policy

- Record which statistical path was selected for each parameter (parametric vs non-parametric)
- Distinguish raw p-values from adjusted p-values in manuscript text and captions
- For hatching mixed-model pairwise contrasts, report Bonferroni-adjusted p-values
- Use significance thresholds consistently: p < 0.05, p < 0.01, p < 0.001

## Data availability

- State in manuscript and repository that raw data are available on reasonable request
- Keep an internal copy of original data files and generated reports for auditability

## Repository

- README updated with final manuscript title/context
- Repository is public (or journal reviewers have access)
- Final commit/tag created for publication snapshot
