# Changelog

## nhanesdata 0.1.1 (development version)

Released: Jan. 25, 2026

### Major Changes

#### Automated R2 Upload Workflow

- Implemented GitHub Actions workflow for quarterly automated NHANES
  data updates
- Workflow pulls fresh data from CDC servers, detects changes via MD5
  checksums, and uploads only changed datasets to Cloudflare R2
- Added `.checksums.json` for version tracking across workflow runs
- Configured cron schedule for quarterly runs (January, April, July,
  October)
- Manual workflow dispatch available with optional dataset filtering and
  dry-run mode

#### Infrastructure Improvements

- Replaced `pins` package with direct `paws.storage::s3$put_object()`
  for R2 uploads (#XX)
  - Creates flat files at bucket root (`demo.parquet`) instead of nested
    versioned folders
  - Maintains correct URL structure for
    [`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
    function
- Created `nhanes_r2_upload()` internal function for direct R2 uploads
- Added namespace access via `:::` operator for internal functions in
  workflow scripts
- Fixed JSON serialization bug (`auto_unbox = FALSE`) preventing
  workflow completion

#### Documentation

- Added dataset catalog vignette with searchable, filterable table using
  `reactable`
- Improved workflow documentation with inline comments

### Dependencies

- Added `paws.storage` to GitHub Actions workflow dependencies
- Added `reactable` to Suggests for interactive dataset catalog

### Bug Fixes

- Fixed environment variable validation to check for non-empty values
- Improved error handling in R2 upload with informative messages
- Fixed workflow summary generation for single-dataset updates

------------------------------------------------------------------------

## nhanesdata 0.1.0

- Improved vignettes and README with clearer examples and better
  documentation.

### Breaking changes

- `read_r2()` renamed to
  [`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
  to better reflect the function’s purpose.
- `pull_nhanes()` no longer exported; end users should use
  [`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
  to load data.

### Improvements

- Reduced required dependencies—moved 7 packages to Suggests (janitor,
  fs, pins, jsonlite, yaml, tools, cli).
- Dataset names are now case-insensitive; use ‘demo’, ‘DEMO’, or ‘Demo’
  interchangeably.
- Improved error messages for clearer debugging and better user
  experience.
- [`get_url()`](https://kyleGrealis.com/nhanesdata/reference/get_url.md)
  rewritten for better reliability and performance.

### Bug fixes

- Fixed critical bug in `pull_nhanes()` where
  [`save()`](https://rdrr.io/r/base/save.html) was failing with “object
  not found” error.
- Fixed NULL handling in
  [`term_search()`](https://kyleGrealis.com/nhanesdata/reference/term_search.md)
  and
  [`var_search()`](https://kyleGrealis.com/nhanesdata/reference/var_search.md)
  to prevent crashes on unexpected API responses.
- Fixed type coercion where Begin.Year column was not being properly
  converted to numeric format.

## nhanesdata 0.0.0.9000 (2025-11-17)

### New features

- Added automated quarterly data update workflow via GitHub Actions with
  manual trigger capability.

### Initial release

- Initial development version of nhanesdata with core functionality for
  accessing and managing NHANES data.
