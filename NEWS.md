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
