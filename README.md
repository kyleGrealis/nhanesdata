# nhanesdata

<!-- badges: start -->
[![Update NHANES Data](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml/badge.svg)](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

An R package for accessing NHANES (National Health and Nutrition Examination Survey) data with automated quarterly updates from CDC servers. Automatically harmonizes multi-cycle data, handles type inconsistencies across survey years, and provides pre-processed datasets for fast access.

## What This Package Does

This package provides:

1. **Automated Data Updates**: GitHub Actions workflow pulls fresh NHANES data quarterly from CDC servers
2. **Public Data Access**: Pre-processed datasets hosted on Cloudflare R2 for fast, reliable downloads
3. **Data Harmonization**: Seamlessly combines survey cycles (1999-2021) with automatic type reconciliation
4. **Dual Storage Formats**: Saves data as both `.rda` (R native) and `.parquet` (cross-platform)
5. **Change Detection**: MD5 checksums ensure only updated datasets are uploaded to cloud storage  

All processed datasets are publicly available at `https://nhanes.kylegrealis.com/` with no authentication required.

## Acknowledgments

This package builds on the excellent work of the [nhanesA](https://cran.r-project.org/package=nhanesA) package developers. We're grateful for their efforts in making NHANES data accessible through R.

The nhanesdata package extends nhanesA by:
- Automatically harmonizing data across survey cycles
- Providing pre-processed datasets for faster access
- Handling type inconsistencies between cycles
- Offering convenient search and discovery functions

## Installation

Install from GitHub:

```r
# Using pak (recommended)
# install.packages("pak")
pak::pak("kyleGrealis/nhanesdata")

# Or using remotes
# install.packages("remotes")
remotes::install_github("kyleGrealis/nhanesdata")
```

## Quick Start

```r
library(nhanesdata)

# Load NHANES data (all survey cycles pre-merged)
# Dataset names are case-insensitive!
demo <- read_nhanes('demo')        # Demographics - lowercase
bpx <- read_nhanes('BPX')          # Blood pressure - uppercase
trigly <- read_nhanes('TRIGLY')    # Triglycerides - uppercase

# Search for variables
term_search('diabetes')            # Search by keyword
var_search('LBXGLU')              # Search by variable name
get_url('DEMO_J')                 # Get CDC documentation
```

## User Functions

**All functions are case-insensitive** - use 'demo', 'DEMO', or 'Demo' interchangeably!

| Function | Purpose |
|----------|---------|
| `read_nhanes(dataset)` | Load NHANES data (all cycles pre-merged) |
| `term_search(var)` | Search variables by keyword or phrase |
| `var_search(var)` | Search variables by exact name |
| `get_url(table)` | Get CDC documentation URL for a dataset |

Data is updated quarterly via automated workflows. See the workflow badge at the top for latest update status.

## Automated Data Pipeline

This package includes a **fully automated GitHub Actions workflow** that:

1. **Runs quarterly** (Jan 1, Apr 1, Jul 1, Oct 1 at 2 AM UTC)
2. **Pulls fresh data** from CDC servers for all 66 NHANES datasets
3. **Detects changes** using MD5 checksums (only uploads modified data)
4. **Uploads to R2** (Cloudflare object storage) for public access
5. **Commits checksums** to track data versions over time  

### Manual Workflow Triggers

You can also trigger data updates manually:

**Via GitHub UI:**
1. Go to **Actions** → **Update NHANES Data**
2. Click **Run workflow**
3. Optional: Specify datasets (comma-separated) or enable dry-run mode

**Via GitHub CLI:**  
```bash
# Update all datasets
gh workflow run update-nhanes-data.yml

# Update specific datasets only
gh workflow run update-nhanes-data.yml -f datasets="demo,bpx,trigly"

# Dry run (skip R2 upload)
gh workflow run update-nhanes-data.yml -f dry_run=true
```

### Available Datasets

The automation processes **66 NHANES datasets** across two categories:

**Questionnaire/Interview Tables (50):**
- `demo` - Demographics
- `bpq` - Blood Pressure & Cholesterol Questionnaire
- `diq` - Diabetes
- `smq` - Smoking
- `alq` - Alcohol
- ... and 45 more (see `inst/extdata/datasets.yml` for full list)

**Examination Tables (16):**
- `bmx` - Body Measures
- `bpx` - Blood Pressure (Examination)
- `cbc` - Blood Counts
- `trigly` - Triglycerides
- ... and 12 more  

## Package Structure

```
nhanesdata/
├── R/                              # Package functions
│   ├── data.R                      # CDC data fetching & change detection
│   ├── pins.R                      # Cloudflare R2 integration
│   └── custom_functions.R          # Helper utilities
├── inst/
│   ├── extdata/
│   │   ├── datasets.yml            # Dataset configuration (66 datasets)
│   │   └── original_data_pull_script.qmd  # Legacy reference
│   └── scripts/
│       └── workflow_update.R       # Workflow orchestration script
├── .github/workflows/
│   └── update-nhanes-data.yml      # Automated data update workflow
├── man/                            # Documentation
├── tests/testthat/                 # Unit tests
├── vignettes/                      # User guides
├── .checksums.json                 # MD5 hashes for change detection
└── SECURITY.md                     # R2 setup & security guide
```

## Key Functions

### Data Loading

**`read_nhanes(dataset)`**

Loads pre-processed NHANES data from cloud storage. All dataset names are **case-insensitive**.

- **Fast access**: Hosted on cloud storage for worldwide reliability
- **All cycles pre-merged**: 1999-2023 data automatically combined
- **No authentication needed**: Public access to all datasets
- **Case-insensitive**: Use 'demo', 'DEMO', or 'Demo' - all work!
- **Graceful error handling**: Helpful messages if the API is unavailable

Example:
```r
# All case variations work identically:
trigly <- read_nhanes('trigly')    # Lowercase
demo <- read_nhanes('DEMO')        # Uppercase
acq <- read_nhanes('Acq')          # Mixed case
```

### Helper Functions

All helper functions are **case-insensitive**:

- **`get_url(table)`**: Returns the CDC codebook URL for a given table
- **`term_search(var)`**: Search for variables by keyword or phrase (wraps `nhanesA::nhanesSearch()`)
- **`var_search(var)`**: Search for variables by exact name (wraps `nhanesA::nhanesSearchVarName()`)

## Dependencies

### Core packages:
- **tidyverse**: Data manipulation and pipelines
- **nhanesA**: Interface to NHANES data API
- **arrow**: Fast parquet file I/O
- **janitor**: Variable name cleaning
- **haven** / **foreign**: Reading CDC data formats

### Optional packages:
- **pins**: For pushing data to cloud storage (S3-compatible)
- **survey** / **srvyr**: Complex survey analysis (not used in data acquisition)
- **gtsummary** / **gt**: Table formatting (for downstream analysis)
- **tidymodels**: Modeling framework (for downstream analysis)  

Install dependencies:
```r
install.packages(c(
  "tidyverse", "nhanesA", "arrow", "janitor", "haven",
  "foreign", "broom", "glue", "readxl", "fs"
))
```

## Understanding NHANES Dataset Names

This is **critical** to understand before using the package:

### How CDC Names Datasets

The CDC releases NHANES data in 2-year cycles, with each cycle getting a **letter suffix**:

| CDC Table Name | Survey Cycle | Years |
|----------------|--------------|-------|
| `DEMO` | 1999-2000 | No suffix (first cycle) |
| `DEMO_B` | 2001-2002 | B |
| `DEMO_C` | 2003-2004 | C |
| `DEMO_D` | 2005-2006 | D |
| ... | ... | ... |
| `DEMO_J` | 2017-2018 | J |
| `DEMO_L` | 2021-2022 | L (skips K) |

This pattern applies to **all 66 datasets**: `BPX`, `BPX_B`, `BPX_C`, ..., `BPX_L` for blood pressure examination data, and so on.

### How This Package Names Datasets

We **combine all cycles** and store them by **base name only** (no suffixes):

- CDC has: `DEMO`, `DEMO_B`, `DEMO_C`, ..., `DEMO_L` (11 separate files)  
- We store: `demo` (1 merged file with all cycles)  
- A `year` column automatically tracks which cycle each row came from  

This means:

```r
# You call this:
demo <- read_nhanes('demo')

# You get: All 11 cycles merged together
# - 1999-2000 data (from DEMO)
# - 2001-2002 data (from DEMO_B)
# - 2003-2004 data (from DEMO_C)
# - ... through 2021-2022 (from DEMO_L)
# - Each row has a 'year' column showing its cycle
```

### Important: 2019-2020 Cycle (COVID-19)

The 2019-2020 survey cycle (suffix K) is **NOT included** in this package's datasets.

**Why?** The COVID-19 pandemic disrupted data collection, and the CDC determined the data quality was insufficient for standard NHANES analysis. The CDC combined partial 2019-2020 data with 2021-2023 data and released it as a special pre-pandemic dataset.

**Reference:** [CDC NHANES 2019-2020 Data Documentation](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2019)

**Impact:** Datasets jump from suffix J (2017-2018) to suffix L (2021-2023), skipping K entirely.

### Why This Matters

When searching CDC documentation, you'll see table names with suffixes (e.g., `DEMO_J` for 2017-2018 demographics). But when using this package, you use the **base name** (`demo`) and get **all cycles automatically merged**.

This design:
- Simplifies data access (one name instead of tracking 11 suffix codes)
- Enables longitudinal analysis (all years in one dataset)
- Handles type mismatches between cycles automatically
- Adds temporal context via the `year` column

## Usage Examples

### Load Multiple Datasets with Tidyverse Style

The recommended approach uses `purrr::map()` for clean, functional workflows:

```r
library(nhanesdata)
library(tidyverse)

# Load multiple datasets - mix uppercase/lowercase as you like!
datasets <- c('demo', 'BPX', 'bmx', 'TRIGLY') |>
  purrr::map(read_nhanes) |>
  purrr::set_names(c('demo', 'bpx', 'bmx', 'trigly'))

# Access individual datasets
demographics <- datasets$demo
blood_pressure <- datasets$bpx
body_measures <- datasets$bmx
```

### Basic Single Dataset Loading

```r
library(nhanesdata)

# Load demographics (case-insensitive)
demo <- read_nhanes('demo')        # Lowercase
# demo <- read_nhanes('DEMO')      # Uppercase - same result!

# Check the year distribution
demo |>
  dplyr::count(year) |>
  dplyr::arrange(year)
```

### Joining Datasets Across Survey Components

```r
library(nhanesdata)
library(tidyverse)

# Load related datasets (demonstrating case flexibility)
c('demo', 'BPX', 'Bmx') |>
  purrr::map(read_nhanes) |>
  purrr::set_names(c('demo', 'bpx', 'bmx')) |>
  list2env(envir = .GlobalEnv)

# Join by participant ID (seqn) and year
analysis_data <- demo |>
  dplyr::inner_join(bpx, by = c('seqn', 'year')) |>
  dplyr::inner_join(bmx, by = c('seqn', 'year')) |>
  dplyr::select(year, seqn, ridageyr, riagendr, bpxsy1, bmxbmi)
```


### Working with Survey Years

Since the `year` column tracks survey cycles, you can filter and analyze by time period:

```r
library(nhanesdata)
library(tidyverse)

demo <- read_nhanes('DEMO')  # Uppercase works too!

# Filter to recent cycles only
recent_data <- demo |>
  dplyr::filter(year >= 2015)

# Compare across time periods
demo |>
  dplyr::mutate(
    period = dplyr::case_when(
      year < 2010 ~ '1999-2009',
      year < 2020 ~ '2010-2019',
      TRUE ~ '2020+'
    )
  ) |>
  dplyr::group_by(period) |>
  dplyr::summarise(n_participants = dplyr::n())
```

### Using Helper Functions

```r
library(nhanesdata)

# Find the CDC codebook for a dataset
get_url('DEMO_J')  # Get docs for 2017-2018 demographics

# Search for variables by term
term_search('diabetes')

# Search by exact variable name
var_search('LBXTC')  # Total cholesterol
```

## Data Storage Formats

The package uses **parquet format** for optimal performance and cross-platform compatibility:

- **`.parquet`** (primary): Cross-platform, fast I/O, columnar storage, works with Python/Julia/Arrow
- **`.rda`**: Native R format also available (generated during data updates)

The `read_nhanes()` function uses `.parquet` files for better performance and interoperability.

## Notes on NHANES Data Quality

### Survey Cycle Details

- **2-year cycles**: Data released biannually (1999-2000, 2001-2002, etc.)
- **2019-2020 cycle**: Interrupted by COVID-19 pandemic and not released
- **Suffix pattern**: Letters B through L, skipping K (so J → L between 2017-2018 and 2021-2022)  

### Type Harmonization

Older cycles sometimes use different variable types (e.g., factor vs. character, integer vs. double). The `pull_nhanes()` function detects and resolves these conflicts automatically:

```r
# This handles type mismatches transparently
demo <- pull_nhanes('demo')
# Type mismatch in riagendr: integer vs double... converting types now...
# Type mismatch in ridreth1: factor vs character... converting types now...
```

### Special Cases

**DXX Tables (Body Composition)**: The 2005-2006 cycle contains repeated measures that shouldn't be merged blindly with other cycles. Read the CDC documentation carefully before using these datasets.

## Public Data Access

All pre-processed datasets are hosted publicly at:

```
https://nhanes.kylegrealis.com/{dataset_name}.parquet
```

You can access them directly without the package:

```r
# Direct download (without nhanesdata package)
library(arrow)

demo <- arrow::read_parquet('https://nhanes.kylegrealis.com/demo.parquet')
trigly <- arrow::read_parquet('https://nhanes.kylegrealis.com/trigly.parquet')
```

**Note:** Dataset names in URLs are lowercase. The `read_nhanes()` function handles case conversion automatically.

This direct access is useful for:
- Sharing data with collaborators who don't need the full package
- Accessing data from Python, Julia, or other Arrow-compatible languages
- Quick data exploration without installing dependencies

## Setup for Package Maintainers

### Cloudflare R2 Configuration

To push processed data to your own R2 bucket, configure these environment variables:

```r
# Set in .Renviron or configure via system environment
Sys.setenv(
  R2_ACCOUNT_ID = "your_account_id",
  R2_ACCESS_KEY_ID = "your_access_key",
  R2_SECRET_ACCESS_KEY = "your_secret_key"
)
```

See `SECURITY.md` for detailed setup instructions and security best practices.

### GitHub Actions Secrets

For automated workflows, add these secrets to your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add new repository secrets:
   - `R2_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`  

The workflow at `.github/workflows/update-nhanes-data.yml` will use these automatically.

## Getting Help

- **Bug reports & feature requests**: [GitHub Issues](https://github.com/kyleGrealis/nhanesdata/issues)
- **Function documentation**: `?function_name` (e.g., `?read_nhanes`, `?term_search`)
- **Package vignettes**: `browseVignettes("nhanesdata")` for detailed guides
- **CDC NHANES resources**: [NHANES Website](https://www.cdc.gov/nchs/nhanes/)
- **nhanesA package**: For direct CDC API access, see [nhanesA on CRAN](https://cran.r-project.org/package=nhanesA)

## Related Packages

- **[nhanesA](https://cran.r-project.org/package=nhanesA)**: Direct interface to NHANES API (this package wraps it for multi-cycle harmonization)
- **[survey](https://cran.r-project.org/package=survey)**: Complex survey analysis with proper weighting
- **[srvyr](https://cran.r-project.org/package=srvyr)**: Tidy survey analysis using dplyr syntax
- **[gtsummary](https://cran.r-project.org/package=gtsummary)**: Publication-ready summary tables

## Contributing

This is a personal data project, but feel free to fork it if you find it useful.

## License

NHANES data is public domain (U.S. government). This processing code is provided as-is.
