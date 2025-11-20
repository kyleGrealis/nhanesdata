# nhanesdata 0.1.0

## Breaking changes

* **RENAMED** `read_r2()` to `read_nhanes()`. The new name better reflects the
  function's purpose (reading NHANES data) rather than the implementation detail
  (R2 cloud storage). Update your code:
  ```r
  # Old (no longer works):
  demo <- read_r2('demo')

  # New:
  demo <- read_nhanes('demo')
  ```

* **REMOVED** `pull_nhanes()` from exported functions. This function is now
  internal-only for package maintainers running data update workflows. End users
  should use `read_nhanes()` to load pre-processed data from cloud storage.

* **REMOVED** internal workflow helper functions (`detect_data_changes()`,
  `update_checksum()`, `load_dataset_config()`). These functions had exactly
  one call site each in the workflow script and have been inlined directly into
  `inst/scripts/workflow_update.R` for simplicity. This change is transparent to
  end users and only affects package maintainers.

* **REMOVED** dependency on `nhanesA::nhanesManifest()` in `get_url()`. The
  function now constructs URLs directly using internal suffix-to-year mapping.
  This change should be transparent to users but may affect behavior for edge
  cases with unusual table suffixes.

## Improvements

* **Lighter dependency footprint**: Moved 7 packages from Imports to Suggests
  (janitor, fs, pins, jsonlite, yaml, tools, cli). These are only needed for
  internal maintainer functions. End users installing the package get fewer
  required dependencies.

* **Enhanced documentation**: All user-facing functions now explicitly document
  that dataset names are **case-insensitive**. Use 'demo', 'DEMO', or 'Demo'
  interchangeably.

* **Added acknowledgments**: README and vignettes now acknowledge the excellent
  [nhanesA](https://cran.r-project.org/package=nhanesA) package developers,
  whose work provides the foundation for CDC data access.

* **COVID-19 cycle documentation**: Added clear explanation in README and
  vignettes about why the 2019-2020 survey cycle (suffix K) is excluded, with
  reference to CDC documentation.

* **Simplified workflow architecture**: Inlined three single-use helper functions
  directly into the workflow script, reducing code from 225 lines of abstraction
  (functions + docs + tests) to ~40 lines of direct inline logic. This makes the
  workflow easier to understand and maintain.

* Complete rewrite of `get_url()` for better reliability and performance:
  - Uses internal suffix-to-year mapping instead of external manifest lookup
  - Adds comprehensive documentation with usage examples
  - Now returns URL invisibly for programmatic use while still printing
  - Better error handling for unrecognized table suffixes
  - Supports case-insensitive input and tables with or without suffixes

* New internal utility functions in `R/utils.R`:
  - `.get_year_from_suffix()` maps NHANES table suffixes to survey cycle years
  - `globalVariables()` declaration eliminates R CMD check NOTEs

* Added dependency guards to all internal functions that use Suggests packages,
  with clear error messages and installation instructions

* **Comprehensive error handling**: `read_nhanes()` now validates all inputs
  and provides clear, helpful error messages. Search functions (`term_search()`
  and `var_search()`) gracefully handle API failures instead of crashing.

* **Test suite expansion**: Added 200+ comprehensive tests covering core package
  functionality with proper test infrastructure and setup files. Tests focus on
  package logic rather than external API behavior.

* **Documentation cleanup**: Fixed roxygen2 documentation for all functions,
  cleaned NAMESPACE of orphaned imports, fixed markdown formatting in README
  and vignettes, and added pkgdown configuration for improved documentation site.

* **API simplification**: Removed unnecessary `type` parameter from `read_nhanes()`
  since only parquet format is supported, resulting in simpler function signatures.

## Bug fixes

* Fixed critical bug in `pull_nhanes()` where the `save()` function was failing
  with "object not found" error. Added `assign()` to properly create the named
  object before saving to .rda format.

* Fixed NULL handling in `term_search()` and `var_search()` to prevent crashes
  when API responses contain unexpected null values.

* Fixed type coercion issue where Begin.Year column was not being properly
  converted to numeric format in `read_nhanes()`.

* Fixed case-insensitive behavior to work consistently across all functions
  when handling dataset and table names.


# nhanesdata 0.0.0.9000 (2025-11-17)

## New features

* Added automated quarterly data update workflow via GitHub Actions with manual
  trigger capability.

## Initial release

* Initial development version of nhanesdata with core functionality for
  accessing and managing NHANES data.
