# NHANES Data Collection & Processing

A data pipeline for downloading, harmonizing, and storing data from the National Health and Nutrition Examination Survey (NHANES) across multiple survey cycles (1999-2021).

## What This Project Does

This project systematically downloads NHANES data from CDC servers, harmonizes variables across survey cycles, handles type mismatches between cycles, and stores the cleaned data in both `.rda` and `.parquet` formats. The processed datasets are publicly hosted at `https://nhanes.kylegrealis.com/` for easy retrieval without re-running the entire acquisition pipeline.

**This is NOT an R package.** It's a data processing workflow built around Quarto documents for checkpointing and reproducibility.

## Why Quarto (.qmd) Files?

The CDC's NHANES servers are unreliable. They go down. Connections timeout. Downloads fail halfway through.

Quarto documents provide crucial **checkpointing capabilities** during data acquisition:
- **Chunk-by-chunk execution**: Download one table, save it, move to the next
- **Session persistence**: Keep downloaded data in memory between chunks when servers are unstable
- **Logging**: Track which tables succeeded/failed during acquisition runs
- **Selective re-execution**: Re-run only failed chunks without restarting from scratch

The `.qmd` format isn't academic posturing—it saves hours of re-downloading when government infrastructure decides to shit the bed mid-process.

## Project Structure

```
nhanes-data/
├── R/                           # Utility functions and setup
│   ├── _libraries.R            # Package loading and setup
│   └── custom_functions.R      # Data acquisition and processing functions
├── data/
│   └── raw/
│       ├── R/                  # Downloaded data as .rda files
│       └── parquet/            # Downloaded data as .parquet files
├── gather_nhanes_data.qmd      # Main data acquisition script (executed chunk-by-chunk)
├── nhanes-data.qmd             # Project entry point
├── nhanes-pins.R               # Testing script for R2/Cloudflare storage
├── pins_2.R                    # Additional storage configuration examples
├── _quarto.yml                 # Quarto project configuration
├── _brand.yml                  # Styling configuration
└── _variables.yml              # Author/metadata variables
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

## Setup

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd nhanes-data
   ```

2. **Install R dependencies** (see above)

3. **(Optional) Configure Cloudflare R2 for data storage**
   If you want to push processed data to your own R2 bucket, set these environment variables:
   ```r
   Sys.setenv(R2_ACCOUNT_ID = "your_account_id")
   Sys.setenv(R2_ACCESS_KEY_ID = "your_access_key")
   Sys.setenv(R2_SECRET_ACCESS_KEY = "your_secret_key")
   ```
   See `pins_2.R` for an example configuration using the `pins` package.

## Usage

### Option 1: Use Pre-Processed Data (Recommended)

Load data directly from public storage without re-downloading:

```r
source('R/_libraries.R')
source('R/custom_functions.R')

# Load pre-processed datasets
demo <- read_r2('demo')
bpx <- read_r2('bpx')
trigly <- read_r2('trigly')
```

### Option 2: Download Data from CDC Servers

Open `gather_nhanes_data.qmd` in RStudio and execute chunks sequentially.

**Important**:
- Execute one chunk at a time, especially when downloading large tables
- If a download fails, wait for CDC servers to come back online
- Re-run failed chunks without restarting the entire process
- Check `data/raw/parquet/` to see which tables have already been saved

Example workflow in the `.qmd` file:
```r
# Load libraries and functions
source('R/_libraries.R')

# Download individual tables
demo <- pull_nhanes('demo')
bpx <- pull_nhanes('bpx')
alq <- pull_nhanes('alq')
```

## Data Storage Formats

- **`.rda`**: Native R format, preserves object names, smaller file size
- **`.parquet`**: Cross-platform, works with Python/Julia/etc., faster I/O, columnar storage

Both formats are saved automatically. Use `.parquet` for interoperability or when working with large datasets.

## Notes on NHANES Data

- **Survey cycles**: NHANES data is released in 2-year cycles (1999-2000, 2001-2002, etc.)
- **2019-2020 cycle**: Was interrupted by COVID-19 and not released
- **Variable naming**: Table names have cycle suffixes (e.g., `DEMO_B` = 2001-2002 demographics)
- **Type mismatches**: Older cycles sometimes use different variable types (factor vs. character). The `pull_nhanes()` function handles this automatically.
- **`DXX` tables**: Body composition scans with repeated measures in 2005 cycle—do NOT blindly merge without reading the documentation

## Public Data Access

Pre-processed datasets are publicly available at:
```
https://nhanes.kylegrealis.com/{dataset_name}.parquet
```

Example:
```r
arrow::read_parquet('https://nhanes.kylegrealis.com/demo.parquet')
```

## Contributing

This is a personal data project, but feel free to fork it if you find it useful.

## License

NHANES data is public domain (U.S. government). This processing code is provided as-is.
