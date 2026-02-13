# nhanesdata

<!-- badges: start -->
[![Update NHANES Data](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml/badge.svg)](https://github.com/kyleGrealis/nhanesdata/actions/workflows/update-nhanes-data.yml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

The National Health and Nutrition Examination Survey (NHANES) is one of the most comprehensive public health datasets available, spanning over two decades of U.S. health data. But working with it has been frustrating. If you've tried using NHANES before, you've likely hit two major problems: (1) CDC server reliability issues that break reproducible research, and (2) cycle suffix confusion, where finding `DEMO`, `DEMO_B`, `DEMO_C`, all the way through `DEMO_L` makes data discovery a scavenger hunt.

**nhanesdata** solves both problems. All datasets are hosted on reliable cloud storage with fast access, and all survey cycles are already merged. Just use `read_nhanes("demo")` and you get demographics data from 1999-2023 with a `year` column tracking which cycle each observation belongs to. No CDC server timeouts, no suffix confusion.

> All processed datasets are publicly available at `https://nhanes.kylegrealis.com/` with no authentication required.

## Acknowledgments

This package builds on the [**nhanesA**](https://cran.r-project.org/package=nhanesA) package, which provides the foundation for accessing NHANES data through R.

## Installation

```r
# install.packages("pak")
pak::pak("kyleGrealis/nhanesdata")
```

## Quick Start

```r
library(nhanesdata)

# Load any dataset (case-insensitive)
demo   <- read_nhanes("demo")    # Demographics
bpx    <- read_nhanes("BPX")     # Blood pressure
trigly <- read_nhanes("TRIGLY")   # Triglycerides

# Search for variables
term_search("diabetes") # By keyword
var_search("RIDAGEYR")  # By variable name

# Get CDC documentation
get_url("DEMO_J")
```

All datasets include a `year` column (survey cycle start year) and `seqn` (participant ID). Join datasets on both columns:

```r
library(dplyr)

analysis <- read_nhanes("demo") |>
  inner_join(read_nhanes("bpx"), by = c("seqn", "year"))
```

## Functions

| Function | Purpose |
|----------|---------|
| `read_nhanes(dataset)` | Load a pre-merged NHANES dataset from cloud storage |
| `term_search(var)` | Search variables by keyword or phrase |
| `var_search(var)` | Search variables by exact name |
| `get_url(table)` | Get CDC codebook URL for a specific table |

All functions are case-insensitive.

## Available Datasets

71 datasets across two categories, with more planned:

- **Questionnaire/Interview (50):** `demo`, `bpq`, `diq`, `smq`, `alq`, and 45 more
- **Examination (16):** `bmx`, `bpx`, `cbc`, `trigly`, and 12 more
- **Laboratory (5):** `dxxag`, `l10`, `l10am`, `lab10`, `lab10am`

See the [dataset catalog](https://www.kyleGrealis.com/nhanesdata/articles/the-datasets.html) for the full list, or browse `inst/extdata/datasets.yml` in the source.

## Important Notes

- The **2019-2020 survey cycle** (suffix K) is excluded due to COVID-19 data collection disruptions. See `vignette("covid-data-exclusion")` for details.
- Variable names match CDC documentation. Always verify definitions with `get_url()` since variable usage may differ across cycles.
- Data types are automatically harmonized across cycles (integer vs. double, factor vs. character).

## Direct Access (Without the Package)

```r
library(arrow)
demo <- arrow::read_parquet("https://nhanes.kylegrealis.com/demo.parquet")
```

This works from any language with Arrow support (Python, Julia, etc.). Dataset names in URLs are lowercase.

## Getting Help

- **Documentation:** `?read_nhanes`, `browseVignettes("nhanesdata")`
- **Bug reports:** [GitHub Issues](https://github.com/kyleGrealis/nhanesdata/issues)
- **CDC NHANES:** [nhanes.cdc.gov](https://www.cdc.gov/nchs/nhanes/)

## Related Packages

- [**nhanesA**](https://cran.r-project.org/package=nhanesA): Direct interface to the NHANES API
- [**survey**](https://cran.r-project.org/package=survey): Complex survey analysis with proper weighting
- [**srvyr**](https://cran.r-project.org/package=srvyr): Tidy survey analysis using **dplyr** syntax
- [**gtsummary**](https://cran.r-project.org/package=gtsummary): Publication-ready summary tables
- [**sumExtras**](https://www.kylegrealis.com/sumExtras): Extended summary statistics and helpers

## License

NHANES data is public domain (U.S. government). This processing code is MIT licensed.
