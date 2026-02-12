# Changelog

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

- Automated quarterly data updates via GitHub Actions with
  checksum-based change detection and Cloudflare R2 uploads.
- Replaced `pins` with direct R2 uploads for simpler URL structure.
- Added dataset catalog vignette with searchable table.

------------------------------------------------------------------------

## nhanesdata 0.1.0

### Breaking Changes

- `read_r2()` renamed to
  [`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md).
- `pull_nhanes()` no longer exported; use
  [`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
  to load data.

### Improvements

- Reduced required dependencies (moved 7 packages to Suggests).
- Dataset names are now case-insensitive.
- Improved error messages and
  [`get_url()`](https://kyleGrealis.com/nhanesdata/reference/get_url.md)
  reliability.

### Bug Fixes

- Fixed `pull_nhanes()` where
  [`save()`](https://rdrr.io/r/base/save.html) failed with “object not
  found” error.
- Fixed NULL handling in
  [`term_search()`](https://kyleGrealis.com/nhanesdata/reference/term_search.md)
  and
  [`var_search()`](https://kyleGrealis.com/nhanesdata/reference/var_search.md).
- Fixed `Begin.Year` column not converting to numeric.

------------------------------------------------------------------------

## nhanesdata 0.0.0.9000 (2025-11-17)

- Initial development version with core functionality for accessing and
  managing NHANES data.
