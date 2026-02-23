## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

+ local: Arch Linux, R 4.5.2
+ GitHub Actions: ubuntu-latest, R release
+ win-builder: R devel

## Resubmission

This is a resubmission addressing reviewer feedback from February 23, 2026.

### Changes made to address CRAN feedback:

1. **Moved data processing functions out of R/**:
   - Relocated `pull_nhanes()` and its helper functions from `R/data.R` and
     `R/utils.R` to `inst/scripts/pull_nhanes.R`
   - These are internal maintenance functions used only by package maintainers
     in automated workflows, not part of the user-facing API
   - Eliminates CRAN policy concern about default file writing in R/ functions
   - Workflow script (`inst/scripts/workflow_update.R`) now sources these
     functions directly instead of using `:::`

### Previous resubmission changes (February 18, 2026):

1. **DESCRIPTION file**:
   - Removed "An R Package" from title
   - Added NHANES URL (<https://www.cdc.gov/nchs/nhanes/>) to Description field
   - Added `srvyr` to Imports for new `create_design()` function

2. **Documentation**:
   - Changed `term_search()` examples from `\dontrun{}` to `\donttest{}` with
     limited output to comply with CRAN example policy while avoiding excessive
     console output
   - Removed examples from internal `pull_nhanes()` function (no user-facing
     file writing in examples)

3. **Function improvements**:
   - Added explicit `@importFrom` statements to `create_design()`
   - Added comprehensive test suite (`tests/testthat/test-create-design.R`)
     covering weight calculations, input validation, and edge cases
   - Added package-level documentation (`R/nhanesdata-package.R`)

4. **Additional improvements**:
   - Added survey design vignette (`vignettes/survey-design.Rmd`) explaining
     CDC weighting guidelines and proper usage of `create_design()`
   - Updated pkgdown configuration for improved documentation site

All changes maintain backward compatibility with version 0.2.0.

## Notes

The package provides access to pre-processed NHANES data hosted on
Cloudflare R2 cloud storage. All datasets are publicly accessible
and require no authentication.
