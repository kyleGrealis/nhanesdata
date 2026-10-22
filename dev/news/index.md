# Changelog

## nhanesdata (development version)

### Data Fixes

- The `dxx` dataset (Dual-Energy X-ray Absorptiometry, Whole Body) was
  missing the 2017-2018 cycle (DXX_J). `read_nhanes("dxx")` returned
  51,970 rows covering 2005, 2011, 2013, and 2015 only. It now returns
  57,084 rows including 2017, with 3,658 non-missing `DXDTOPF` records
  for that cycle, matching CDC’s published file.

  Any analysis using whole-body DXA variables (`DXDTOPF`, `DXDTOFAT`,
  `DXDTOLE`, `DXDTOBMC`, `DXDTOTOT`, and the limb lean measures) over
  the 2011-2018 window was silently restricted to 2011-2016. Results
  were correct for the cycles present, but cohorts were smaller than
  expected and pooled survey weights assumed four cycles rather than
  three. Re-running affected analyses is recommended. The sibling
  `dxxag` dataset was unaffected.

  No action is needed to pick up the fix: data is served independently
  of the installed package version.

- The `telo` and `tfa` datasets were missing their 1999-2000 cycle. CDC
  publishes those two files as `TELO_A` and `TFA_A`, and the data pull
  only ever tried the bare 1999 name, so the cycle was never fetched.
  `read_nhanes("telo")` returned 4,269 rows (2001 only) and now returns
  7,839 across 1999 and 2001; `read_nhanes("tfa")` returned 5,423 rows
  (2009 only) and now returns 9,682 across 1999 and 2009. Both datasets
  have been rebuilt and republished
  ([\#25](https://github.com/kyleGrealis/nhanesdata/issues/25)). No
  other dataset is affected: the remaining 24 `_A` files for 1999-2000
  are `SS*` surplus-specimen tables that this package does not publish.

  No action is needed to pick up the fix: data is served independently
  of the installed package version.

### Internal

- `pull_nhanes()` now tries a second file name for the 1999-2000 cycle.
  Most 1999-2000 tables are published bare (`DEMO`, `BMX`) but a few
  carry an `_A` suffix, so the cycle enumeration gained an `alt_code`
  column holding `<NAME>_A` on the 1999 row only. The bare name is tried
  first and the first candidate returning data wins, so a table with
  both spellings uses the bare file and a cycle can never be bound
  twice. Cycle-to-year alignment is unchanged, and tables with a real
  bare 1999 file cost no extra request
  ([\#25](https://github.com/kyleGrealis/nhanesdata/issues/25)).

- The data update workflow now records per-dataset coverage (row count,
  survey cycles, and column names) alongside the existing hash, and
  blocks any upload that loses rows, cycles, or columns relative to the
  previous build. This closes the gap that allowed a failed cycle fetch
  to be published as a complete dataset
  ([\#24](https://github.com/kyleGrealis/nhanesdata/issues/24)).

- Added `inst/scripts/audit_parquet_cycles.R` to report survey cycle
  coverage across all published datasets.

## nhanesdata 0.2.2

CRAN release: 2026-05-04

### Bug Fixes

- Fixed
  [`create_design()`](https://www.kylegrealis.com/nhanesdata/dev/reference/create_design.md)
  crash for any analysis including 1999 or 2001 NHANES cycles. The
  `needs_2yr` flag was referenced but never defined, causing
  `object 'needs_2yr' not found` at runtime.
- Fixed
  [`create_design()`](https://www.kylegrealis.com/nhanesdata/dev/reference/create_design.md)
  requiring 2-year weight columns (`wtint2yr`, `wtmec2yr`) for datasets
  containing only 1999/2001 cycles, where those columns do not exist in
  NHANES demographic files.
- Fixed fasting weight validation to check for `wtsaf4yr` when 1999/2001
  cycles are present, matching the calculation logic that already used
  it.
- Added `wtsaf4yr` to
  [`globalVariables()`](https://rdrr.io/r/utils/globalVariables.html) to
  resolve R CMD check NOTEs.
- Corrected roxygen documentation that incorrectly stated 4-year fasting
  weights were not supported.

## nhanesdata 0.2.1

CRAN release: 2026-02-28

### Bug Fixes

- Converted vignettes from Quarto (.qmd) to R Markdown (.Rmd) to fix
  vignette build failures on Windows CI.

### New Features

- Adding
  [`create_design()`](https://www.kylegrealis.com/nhanesdata/dev/reference/create_design.md)
  function to return survey-weighted design data for use in downstream
  analyses. Combines cycles and properly accounts for weight type
  (interview, MEC, fasting) and adheres to CDC guidelines for use with
  earlier cycles. See [CDC Weighting
  Guidelines](https://wwwn.cdc.gov/nchs/nhanes/tutorials/Weighting.aspx)
  for more information.

## nhanesdata 0.2.0

Released: Feb. 2026

### Breaking Changes

- Categorical columns across all datasets are now stored as character
  with human-readable labels instead of raw numeric codes. For example,
  BMX `bmdbmic` values like `2, 3, 4, 1` are now `"Normal weight"`,
  `"Overweight"`, `"Obese"`, `"Underweight"`. This affects 95 variables
  across 22 datasets.

### Bug Fixes

- Fixed data corruption where factor-to-numeric conversion returned
  internal level indices instead of actual CDC codes (e.g., codes
  `1, 3, 4` were silently stored as `1, 2, 3`).
- Fixed continuous variables like `ridageyr` and `indfmpir` being
  corrupted when categorical label mappings were incorrectly applied to
  them.
- Fixed column type clashes when binding survey cycles where a column
  existed in some cycles but not others.

### New Features

- Cross-cycle label translation: when the CDC codebook is unavailable
  for a particular cycle, labels are now carried over from a sibling
  cycle so all waves have consistent human-readable values.
- Added 5 new datasets: `dxxag`, `l10`, `l10am`, `lab10`, `lab10am` (71
  datasets total).
- Added `inst/CITATION` for `citation("nhanesdata")` support.

### Contributors

- Added Amrit Baral, Natalie Neugaard, Johannes Thrul, and Janardan
  Devkota as contributors.

------------------------------------------------------------------------

## nhanesdata 0.1.1

Released: Jan. 2026

### Changes

- Automated annual data updates via GitHub Actions with checksum-based
  change detection and Cloudflare R2 uploads.
- Replaced `pins` with direct R2 uploads for simpler URL structure.
- Added dataset catalog vignette with searchable table.

------------------------------------------------------------------------

## nhanesdata 0.1.0

### Breaking Changes

- `read_r2()` renamed to
  [`read_nhanes()`](https://www.kylegrealis.com/nhanesdata/dev/reference/read_nhanes.md).
- `pull_nhanes()` no longer exported; use
  [`read_nhanes()`](https://www.kylegrealis.com/nhanesdata/dev/reference/read_nhanes.md)
  to load data.

### Improvements

- Reduced required dependencies (moved 7 packages to Suggests).
- Dataset names are now case-insensitive.
- Improved error messages and
  [`get_url()`](https://www.kylegrealis.com/nhanesdata/dev/reference/get_url.md)
  reliability.

### Bug Fixes

- Fixed `pull_nhanes()` where
  [`save()`](https://rdrr.io/r/base/save.html) failed with “object not
  found” error.
- Fixed NULL handling in
  [`term_search()`](https://www.kylegrealis.com/nhanesdata/dev/reference/term_search.md)
  and
  [`var_search()`](https://www.kylegrealis.com/nhanesdata/dev/reference/var_search.md).
- Fixed `Begin.Year` column not converting to numeric.

------------------------------------------------------------------------

## nhanesdata 0.0.0.9000 (2025-11-17)

- Initial development version with core functionality for accessing and
  managing NHANES data.
