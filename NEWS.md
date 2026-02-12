# nhanesdata 0.2.0

Released: Feb. 2026

## Breaking Changes

* Type harmonization now converts all factor/categorical columns to character
  instead of numeric. Previously, `as.double(factor)` returned internal level
  indices (1, 2, 3, ...) instead of the actual CDC codes (e.g., 1, 3, 4),
  silently corrupting data across survey cycles.
* 95 variables across 22 datasets that were previously stored as raw CDC
  numeric codes are now translated to human-readable labels (e.g., BMX
  `bmdbmic`: `2, 3, 4, 1` is now `"Normal weight"`, `"Overweight"`,
  `"Obese"`, `"Underweight"`). Affected datasets include DEMO, BMX, MCQ, OSQ,
  SMQ, and others. See `data/raw/comparison_report.md` for the full list.

## Bug Fixes

### Critical: Factor-to-numeric data corruption

* Fixed `pull_nhanes()` type harmonization where `as.double(factor(...))` was
  returning factor level indices instead of original CDC code values. For
  example, BMIWT codes `1, 3, 4` were being converted to `1, 2, 3`. All
  factor-vs-numeric conflicts now resolve to character with human-readable
  labels preserved.

### Critical: Continuous variable corruption via cross-cycle translation

* Fixed `.translate_numeric_columns()` corrupting continuous variables
  (e.g., `ridageyr`, `indfmpir`, `dmdhhsiz`) by applying categorical label
  mappings to them. The function now detects "Range of Values" entries in CDC
  codebooks and skips those columns entirely, preserving numeric data.

### All-NA column type clashes

* Fixed `bind_rows()` failures when a column exists in some NHANES cycles but
  not others. The missing column was filled with typed NAs (e.g., logical NA)
  that clashed with the column's actual type (e.g., double) in other cycles.
  Added `.coerce_na_column()` helper to convert all-NA columns to match the
  target type before binding.

## New Features

### Cross-cycle label translation

* Added `.translate_numeric_columns()` to apply CDC codebook labels from
  sibling cycles when `nhanesA::nhanes()` returns a column as plain numeric
  (because the codebook was unavailable for that cycle). This ensures
  consistent human-readable labels across all survey waves.

### Type harmonization improvements

* Added `.coerce_na_column()` internal helper for type-safe NA column
  conversion supporting numeric, double, integer, character, logical, factor,
  and ordered types.
* `.harmonize_column_types()` now proactively resolves type conflicts before
  every `bind_rows()` call, with informative `[harmonize]` messages logging
  each conversion.
* Factor-vs-factor conflicts convert both sides to character (avoids
  incompatible factor levels across cycles).
* Integer-vs-double conflicts (no factors) convert both sides to double.

## Contributors

* Added Amrit Baral, Natalie Neugaard, Johannes Thrul, and Janardan Devkota
  as contributors in DESCRIPTION.
* Created `inst/CITATION` for proper citation support via `citation("nhanesdata")`.

## Pipeline Comparison Results

Full comparison of all 71 datasets against existing baselines:

* **59 datasets changed** — type conversions from the harmonization fix.
* **6 datasets identical** — cbc, ghb, glu, hdl, tchol, trigly (pure numeric
  lab data with no categorical columns).
* **5 new datasets** — dxxag, l10, l10am, lab10, lab10am (no prior baseline).
* **1 failed** — rxq_rx (baseline parquet unreadable; new pull succeeded).
* **3 row count changes** — dr2tot (+9,762), ecq (-3,093), fsq (+11,933).
* **2 new columns** — fsq gained `fsd162`, biopro gained `wtph2yr`.

## Internal Changes

* Added 5 missing datasets to `datasets.yml` and pipeline scripts: `dxxag`,
  `l10`, `l10am`, `lab10`, `lab10am` (total: 71 datasets).
* Created `inst/scripts/compare_pipeline.R` for comparing new pipeline output
  against existing parquet baselines with detailed markdown reporting.
* Expanded test suite for type harmonization (71 tests covering all-NA
  coercion, factor conflicts, continuous variable protection, and cross-cycle
  translation).
* Applied `styler::style_pkg()` for consistent code formatting.
* Fixed `lintr` warnings across package source files.

---

# nhanesdata 0.1.1 (development version)

Released: Jan. 25, 2026

## Major Changes

### Automated R2 Upload Workflow

* Implemented GitHub Actions workflow for quarterly automated NHANES data updates
* Workflow pulls fresh data from CDC servers, detects changes via MD5 checksums, and uploads only changed datasets to Cloudflare R2
* Added `.checksums.json` for version tracking across workflow runs
* Configured cron schedule for quarterly runs (January, April, July, October)
* Manual workflow dispatch available with optional dataset filtering and dry-run mode

### Infrastructure Improvements

* Replaced `pins` package with direct `paws.storage::s3$put_object()` for R2 uploads (#XX)
  - Creates flat files at bucket root (`demo.parquet`) instead of nested versioned folders
  - Maintains correct URL structure for `read_nhanes()` function
* Created `nhanes_r2_upload()` internal function for direct R2 uploads
* Added namespace access via `:::` operator for internal functions in workflow scripts
* Fixed JSON serialization bug (`auto_unbox = FALSE`) preventing workflow completion

### Documentation

* Added dataset catalog vignette with searchable, filterable table using `reactable`
* Improved workflow documentation with inline comments

## Dependencies

* Added `paws.storage` to GitHub Actions workflow dependencies
* Added `reactable` to Suggests for interactive dataset catalog

## Bug Fixes

* Fixed environment variable validation to check for non-empty values
* Improved error handling in R2 upload with informative messages
* Fixed workflow summary generation for single-dataset updates

---

# nhanesdata 0.1.0

* Improved vignettes and README with clearer examples and better documentation.

## Breaking changes

* `read_r2()` renamed to `read_nhanes()` to better reflect the function's purpose.
* `pull_nhanes()` no longer exported; end users should use `read_nhanes()` to load data.

## Improvements

* Reduced required dependencies—moved 7 packages to Suggests (janitor, fs, pins, jsonlite, yaml, tools, cli).
* Dataset names are now case-insensitive; use 'demo', 'DEMO', or 'Demo' interchangeably.
* Improved error messages for clearer debugging and better user experience.
* `get_url()` rewritten for better reliability and performance.

## Bug fixes

* Fixed critical bug in `pull_nhanes()` where `save()` was failing with "object not found" error.
* Fixed NULL handling in `term_search()` and `var_search()` to prevent crashes on unexpected API responses.
* Fixed type coercion where Begin.Year column was not being properly converted to numeric format.

# nhanesdata 0.0.0.9000 (2025-11-17)

## New features

* Added automated quarterly data update workflow via GitHub Actions with manual
  trigger capability.

## Initial release

* Initial development version of nhanesdata with core functionality for
  accessing and managing NHANES data.
