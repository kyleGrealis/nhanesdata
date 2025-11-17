# nhanesdata

[![Update NHANES Data](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml/badge.svg)](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml)

An R package for accessing NHANES (National Health and Nutrition Examination Survey) data with automated quarterly updates from CDC servers.

## What This Package Does

This package provides:

1. **Automated Data Updates**: GitHub Actions workflow pulls fresh NHANES data quarterly from CDC servers  
2. **Public Data Access**: Pre-processed datasets hosted on Cloudflare R2 for fast, reliable downloads  
3. **Data Harmonization**: Seamlessly combines survey cycles (1999-2021) with automatic type reconciliation  
4. **Dual Storage Formats**: Saves data as both `.rda` (R native) and `.parquet` (cross-platform)  
5. **Change Detection**: MD5 checksums ensure only updated datasets are uploaded to cloud storage  

All processed datasets are publicly available at `https://nhanes.kylegrealis.com/` with no authentication required.

## Installation

Install from GitHub:

```r
# install.packages("remotes")
remotes::install_github("kyleGrealis/nhanesdata")
```

## Quick Start

```r
library(nhanesdata)

# Load pre-processed datasets from public R2 storage
demo <- read_r2('demo')        # Demographics
bpx <- read_r2('bpx')          # Blood pressure
trigly <- read_r2('trigly')    # Triglycerides

# Or download fresh data directly from CDC servers
demo_fresh <- pull_nhanes('demo')
```

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

### Data Acquisition

**`pull_nhanes(nhanes_table, selected_variables = NULL, save = TRUE)`**  

Pulls all available cycles for a given NHANES table name and harmonizes them into a single dataset.

- **Handles type mismatches**: Automatically coerces conflicting variable types across cycles  
- **Adds survey year**: Prepends `year` variable to track survey cycle  
- **Saves dual formats**: Outputs both `.rda` (for R) and `.parquet` (for cross-platform use)  
- **Case-insensitive**: Accepts lowercase table names (`'demo'` or `'DEMO'`)  

Example:
```r
# Download all cycles of demographics data
demo <- pull_nhanes('demo')

# Download only specific variables from alcohol questionnaire
alq <- pull_nhanes('alq', selected_variables = c('SEQN', 'ALQ101', 'ALQ130'))
```

### Data Loading

**`read_r2(dataset, type = 'parquet')`**  

Loads pre-processed NHANES data from public Cloudflare R2 storage.

- **No re-downloading required**: Access already-processed data  
- **Faster than CDC servers**: Hosted on Cloudflare for reliability  
- **Public access**: No authentication needed  

Example:
```r
# Load triglyceride data from public storage
trigly <- read_r2('trigly')

# Load acculturation questionnaire data
acq <- read_r2('acq')
```

### Helper Functions

- **`get_url(table)`**: Returns the CDC codebook URL for a given table  
- **`term_search(var)`**: Wrapper around `nhanesA::nhanesSearch()` with cleaner output  
- **`var_search(var)`**: Wrapper around `nhanesA::nhanesSearchVarName()` with cleaner output  
- **`find_variable(var_name)`**: Searches all loaded data frames for a specific variable  
- **`drop_label_kyle(df, ...)`**: Removes variable labels that cause join conflicts  

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
demo <- read_r2('demo')

# You get: All 11 cycles merged together
# - 1999-2000 data (from DEMO)
# - 2001-2002 data (from DEMO_B)
# - 2003-2004 data (from DEMO_C)
# - ... through 2021-2022 (from DEMO_L)
# - Each row has a 'year' column showing its cycle
```

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

# Load multiple datasets at once
datasets <- c('demo', 'bpx', 'bmx', 'trigly') |>
  purrr::map(read_r2) |>
  purrr::set_names(c('demo', 'bpx', 'bmx', 'trigly'))

# Access individual datasets
demographics <- datasets$demo
blood_pressure <- datasets$bpx
body_measures <- datasets$bmx
```

### Basic Single Dataset Loading

```r
library(nhanesdata)

# Load demographics from public R2 storage
demo <- read_r2('demo')

# Check the year distribution
demo |>
  dplyr::count(year) |>
  dplyr::arrange(year)
```

### Joining Datasets Across Survey Components

```r
library(nhanesdata)
library(tidyverse)

# Load related datasets
c('demo', 'bpx', 'bmx') |>
  purrr::map(read_r2) |>
  purrr::set_names(c('demo', 'bpx', 'bmx')) |>
  list2env(envir = .GlobalEnv)

# Join by participant ID (seqn) and year
analysis_data <- demo |>
  dplyr::inner_join(bpx, by = c('seqn', 'year')) |>
  dplyr::inner_join(bmx, by = c('seqn', 'year')) |>
  dplyr::select(year, seqn, ridageyr, riagendr, bpxsy1, bmxbmi)
```

### Download Fresh Data from CDC Servers

If you need to pull data directly from CDC (instead of using pre-processed R2 files):

```r
library(nhanesdata)

# Pull fresh demographics data from CDC
# This merges all cycles automatically
demo_fresh <- pull_nhanes('demo')

# Pull only specific variables (faster download)
demo_subset <- pull_nhanes(
  'demo',
  selected_variables = c('SEQN', 'RIDAGEYR', 'RIAGENDR', 'RIDRETH3')
)
```

### Working with Survey Years

Since the `year` column tracks survey cycles, you can filter and analyze by time period:

```r
library(nhanesdata)
library(tidyverse)

demo <- read_r2('demo')

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

# Find which loaded datasets contain a variable
# (after loading multiple datasets into your environment)
find_variable('bpxsy1')  # Systolic blood pressure
```

## Data Storage Formats

Both formats are saved automatically during the automated pipeline:

- **`.parquet`** (default): Cross-platform, faster I/O, columnar storage, works with Python/Julia/Arrow  
- **`.rda`**: Native R format, preserves object names, slightly smaller file size  

The `read_r2()` function defaults to `.parquet` for better performance and interoperability.

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

This is useful for:
- Sharing data with collaborators who don't need the full package  
- Accessing data from Python, Julia, or other Arrow-compatible languages  
- Quick data exploration without installing dependencies  

## Setup for Package Maintainers

### Local Installation

```r
# Install from GitHub
pak::pak("kyleGrealis/nhanesdata")

# Or using remotes
# remotes::install_github("kyleGrealis/nhanesdata")
```

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

## Contributing

This is a personal data project, but feel free to fork it if you find it useful.

## License

NHANES data is public domain (U.S. government). This processing code is provided as-is.
