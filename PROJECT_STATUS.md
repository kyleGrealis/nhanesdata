# Project Status: nhanesdata

**Current Version:** 0.0.0.9000 (development)
**Last Updated:** 2025-11-19

## Quick Status

✅ **Package is functional and ready for use**

### User-Facing API (4 functions)
- `read_nhanes(dataset)` - Load NHANES data from cloud storage
- `term_search(var)` - Search variables by keyword
- `var_search(var)` - Search variables by exact name
- `get_url(table)` - Get CDC documentation URL

**All functions are case-insensitive!**

### Automated Data Pipeline
- Quarterly updates via GitHub Actions
- 66 NHANES datasets tracked
- Change detection via MD5 checksums
- Cloudflare R2 cloud storage

## Recent Major Changes

**v0.0.0.9000 (development):**
- ✅ Renamed `read_r2()` → `read_nhanes()` for better clarity
- ✅ Made `pull_nhanes()` internal-only (maintainer use)
- ✅ Optimized dependencies (7 packages moved to Suggests)
- ✅ Added comprehensive documentation with case-insensitivity examples
- ✅ Added COVID-19 cycle documentation
- ✅ Acknowledged nhanesA package developers

## Outstanding Tasks

### High Priority
- [ ] Create test files for `get_url()` and `.get_year_from_suffix()`
- [ ] Rename `test-read_r2.R` → `test-read-nhanes.R`

### Future Improvements
- [ ] Consider inlining workflow helper functions (detect_data_changes, update_checksum, load_dataset_config) directly into workflow_update.R
- [ ] Add pkgdown website
- [ ] Submit to CRAN when stable

## Testing Status

**Current Coverage:** ~70% (pragmatic approach)
- ✅ Excellent coverage for checksums and config loading
- ✅ Mock tests for read_nhanes
- ⚠️ Missing tests for get_url (pure logic, should have tests)
- ⚠️ Skipping tests for thin wrappers (term_search, var_search)

## Installation

```r
remotes::install_github("kyleGrealis/nhanesdata")
```

## Quick Start

```r
library(nhanesdata)

# Load data (case-insensitive!)
demo <- read_nhanes('demo')
bpx <- read_nhanes('BPX')

# Search for variables
term_search('diabetes')
```

For detailed information, see `README.md` and package vignettes.
