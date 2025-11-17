# nhanesdata (development version)

## Bug fixes

* Fixed critical bug in `pull_nhanes()` where the `save()` function was failing
  with "object not found" error. Added `assign()` to properly create the named
  object before saving to .rda format.

* Fixed JSON serialization error in `inst/scripts/workflow_update.R` by
  converting `difftime` objects to numeric and `POSIXct` timestamps to character
  strings.

## Configuration improvements

* Updated `.Rbuildignore` to properly exclude non-package files (`SECURITY.md`,
  `logos/`, `workflow_summary.json`) and fixed regex patterns to use proper
  escaping.

* Removed `^inst$` from `.Rbuildignore` to ensure `inst/` directory contents
  are included in the package.

# nhanesdata 0.0.0.9000 (2025-11-17)

## New features

* New function `detect_data_changes()` for MD5 checksum-based change detection
  of datasets.

* New function `update_checksum()` to update and maintain checksums in JSON
  format.

* New function `load_dataset_config()` for YAML configuration loading of
  dataset metadata.

* New function `drop_label_kyle()` to remove attributes from dataframe columns
  using tidyselect syntax (handles join conflicts from labeled data).

* Added automated quarterly data update workflow via GitHub Actions with manual
  trigger capability.

## Initial release

* Initial development version of nhanesdata with core functionality for
  accessing and managing NHANES data.
