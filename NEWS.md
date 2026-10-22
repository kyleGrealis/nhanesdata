# nhanesdata (development version)

## Data Fixes

* The `dxx` dataset (Dual-Energy X-ray Absorptiometry, Whole Body) was
  missing the 2017-2018 cycle (DXX_J). `read_nhanes("dxx")` returned
  51,970 rows covering 2005, 2011, 2013, and 2015 only. It now returns
  57,084 rows including 2017, with 3,658 non-missing `DXDTOPF` records
  for that cycle, matching CDC's published file.

  Any analysis using whole-body DXA variables (`DXDTOPF`, `DXDTOFAT`,
  `DXDTOLE`, `DXDTOBMC`, `DXDTOTOT`, and the limb lean measures) over
  the 2011-2018 window was silently restricted to 2011-2016. Results
  were correct for the cycles present, but cohorts were smaller than
  expected and pooled survey weights assumed four cycles rather than
  three. Re-running affected analyses is recommended. The sibling
  `dxxag` dataset was unaffected.

  No action is needed to pick up the fix: data is served independently
  of the installed package version.

## Internal

* The data update workflow now records per-dataset coverage (row count,
  survey cycles, and column names) alongside the existing hash, and
  blocks any upload that loses rows, cycles, or columns relative to the
  previous build. This closes the gap that allowed a failed cycle fetch
  to be published as a complete dataset (#24).

* Added `inst/scripts/audit_parquet_cycles.R` to report survey cycle
  coverage across all published datasets.


# nhanesdata 0.2.2

## Bug Fixes

* Fixed `create_design()` crash for any analysis including 1999 or 2001
  NHANES cycles. The `needs_2yr` flag was referenced but never defined,
  causing `object 'needs_2yr' not found` at runtime.
* Fixed `create_design()` requiring 2-year weight columns (`wtint2yr`,
  `wtmec2yr`) for datasets containing only 1999/2001 cycles, where those
  columns do not exist in NHANES demographic files.
* Fixed fasting weight validation to check for `wtsaf4yr` when 1999/2001
  cycles are present, matching the calculation logic that already used it.
* Added `wtsaf4yr` to `globalVariables()` to resolve R CMD check NOTEs.
* Corrected roxygen documentation that incorrectly stated 4-year fasting
  weights were not supported.

# nhanesdata 0.2.1

## Bug Fixes

* Converted vignettes from Quarto (.qmd) to R Markdown (.Rmd) to fix
  vignette build failures on Windows CI.

## New Features

* Adding `create_design()` function to return survey-weighted design data
  for use in downstream analyses. Combines cycles and properly accounts
  for weight type (interview, MEC, fasting) and adheres to CDC guidelines
  for use with earlier cycles. See [CDC Weighting Guidelines](https://wwwn.cdc.gov/nchs/nhanes/tutorials/Weighting.aspx)
  for more information.

# nhanesdata 0.2.0

Released: Feb. 2026

## Breaking Changes

* Categorical columns across all datasets are now stored as character with
  human-readable labels instead of raw numeric codes. For example, BMX
  `bmdbmic` values like `2, 3, 4, 1` are now `"Normal weight"`,
  `"Overweight"`, `"Obese"`, `"Underweight"`. This affects 95 variables
  across 22 datasets.

## Bug Fixes

* Fixed data corruption where factor-to-numeric conversion returned internal
  level indices instead of actual CDC codes (e.g., codes `1, 3, 4` were
  silently stored as `1, 2, 3`).
* Fixed continuous variables like `ridageyr` and `indfmpir` being corrupted
  when categorical label mappings were incorrectly applied to them.
* Fixed column type clashes when binding survey cycles where a column existed
  in some cycles but not others.

## New Features

* Cross-cycle label translation: when the CDC codebook is unavailable for a
  particular cycle, labels are now carried over from a sibling cycle so all
  waves have consistent human-readable values.
* Added 5 new datasets: `dxxag`, `l10`, `l10am`, `lab10`, `lab10am`
  (71 datasets total).
* Added `inst/CITATION` for `citation("nhanesdata")` support.

## Contributors

* Added Amrit Baral, Natalie Neugaard, Johannes Thrul, and Janardan Devkota
  as contributors.

---

# nhanesdata 0.1.1

Released: Jan. 2026

## Changes

* Automated annual data updates via GitHub Actions with checksum-based
  change detection and Cloudflare R2 uploads.
* Replaced `pins` with direct R2 uploads for simpler URL structure.
* Added dataset catalog vignette with searchable table.

---

# nhanesdata 0.1.0

## Breaking Changes

* `read_r2()` renamed to `read_nhanes()`.
* `pull_nhanes()` no longer exported; use `read_nhanes()` to load data.

## Improvements

* Reduced required dependencies (moved 7 packages to Suggests).
* Dataset names are now case-insensitive.
* Improved error messages and `get_url()` reliability.

## Bug Fixes

* Fixed `pull_nhanes()` where `save()` failed with "object not found" error.
* Fixed NULL handling in `term_search()` and `var_search()`.
* Fixed `Begin.Year` column not converting to numeric.

---

# nhanesdata 0.0.0.9000 (2025-11-17)

* Initial development version with core functionality for accessing and
  managing NHANES data.
