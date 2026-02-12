# nhanesdata

The National Health and Nutrition Examination Survey (NHANES) is one of
the most comprehensive public health datasets available, spanning over
two decades of U.S. health data. But working with it has been
frustrating. If you’ve tried using NHANES before, you’ve likely hit two
major problems: (1) CDC server reliability issues that break
reproducible research, and (2) cycle suffix confusion—finding `DEMO`,
`DEMO_B`, `DEMO_C`, all the way through `DEMO_L` makes data discovery a
scavenger hunt.

**nhanesdata** solves both problems. All datasets are hosted on reliable
cloud storage with fast access, and we’ve already merged all survey
cycles for you. Just use `read_nhanes('demo')` and you get demographics
data from 1999-2023 with a `year` column tracking which cycle each
observation belongs to—no CDC server timeouts, no suffix confusion.

> All processed datasets are publicly available at
> `https://nhanes.kylegrealis.com/` with no authentication required.

## Acknowledgments

This package builds on the excellent work of the
[**nhanesA**](https://cran.r-project.org/package=nhanesA) package
developers. We’re grateful for their efforts in making NHANES data
accessible through R.

**nhanesdata** extends **nhanesA** by:

- Automatically harmonizing data across survey cycles  
- Providing pre-processed datasets for faster access  
- Handling type inconsistencies between cycles  
- Offering convenient search and discovery functions

## Quick Navigation

- [Installation](#installation) - Get the package  
- [Finding Variables](#finding-variables) - Search for data you need  
- [Working with Multiple Datasets](#working-with-multiple-datasets) -
  Join datasets together  
- [Understanding Dataset Names](#understanding-nhanes-dataset-names) -
  Learn CDC naming conventions  
- [Getting Help](#getting-help) - Resources and support

## Installation

Install from GitHub using **pak** (recommended):

``` r
# install.packages("pak")
pak::pak("kyleGrealis/nhanesdata")
```

Or using **remotes**:

``` r
# install.packages("remotes")
remotes::install_github("kyleGrealis/nhanesdata")
```

## Quick Start

``` r
library(nhanesdata)

# Load NHANES data (all survey cycles pre-merged)
# Dataset names are case-insensitive!
demo <- read_nhanes('demo')        # Demographics - lowercase
bpx <- read_nhanes('BPX')          # Blood pressure - uppercase
trigly <- read_nhanes('TRIGLY')    # Triglycerides - uppercase

# Search for variables
term_search('diabetes')            # Search by keyword
var_search('LBXGLU')               # Search by variable name
get_url('DEMO_J')                  # Get CDC documentation
```

## User Functions

**All functions are case-insensitive** - use `'demo'`, `'DEMO'`, or
`'Demo'` interchangeably!

| Function               | Purpose                                  |
|------------------------|------------------------------------------|
| `read_nhanes(dataset)` | Load NHANES data (all cycles pre-merged) |
| `term_search(var)`     | Search variables by keyword or phrase    |
| `var_search(var)`      | Search variables by exact name           |
| `get_url(table)`       | Get CDC documentation URL for a dataset  |

Quarterly checks ensure the package always has the most recently
available NHANES data. If you notice an update before we do, we would
love the feedback!

> **Note on Data Harmonization:** This package reconciles data types
> (integers and floats are now consistent) across NHANES cycles, but
> variable names remain unchanged from the original CDC data. Users
> should verify the CDC/NHANES documentation to understand how variable
> names and usage may have changed from cycle to cycle.

## Available Datasets

This package currently includes 71 datasets (with more coming) across
two categories:

**Questionnaire/Interview Tables (50):**

- `demo` - Demographics  
- `bpq` - Blood Pressure & Cholesterol Questionnaire  
- `diq` - Diabetes  
- `smq` - Smoking  
- `alq` - Alcohol  
- … and 45 more (see `inst/extdata/datasets.yml` for full list)

**Examination Tables (16):**

- `bmx` - Body Measures  
- `bpx` - Blood Pressure (Examination)  
- `cbc` - Blood Counts  
- `trigly` - Triglycerides  
- … and 12 more

## Key Functions

### Data Loading

**`read_nhanes(dataset)`**

Loads pre-processed NHANES data from cloud storage. All dataset names
are **case-insensitive**.

- **Fast access**: Hosted on cloud storage for worldwide reliability  
- **All cycles pre-merged**: 1999-2023 data automatically combined  
- **No authentication needed**: Public access to all datasets  
- **Case-insensitive**: Use ‘demo’, ‘DEMO’, or ‘Demo’ - all work!  
- **Graceful error handling**: Helpful messages if the API is
  unavailable

Example:

``` r
# All case variations work identically:
trigly <- read_nhanes('trigly')    # Lowercase
demo <- read_nhanes('DEMO')        # Uppercase
acq <- read_nhanes('Acq')          # Mixed case
```

------------------------------------------------------------------------

### Helper Functions

All helper functions are **case-insensitive**:

- **`get_url(table)`**: Returns the CDC codebook URL for a given table  
- **`term_search(var)`**: Search for variables by keyword or phrase
  (wraps
  [`nhanesA::nhanesSearch()`](https://rdrr.io/pkg/nhanesA/man/nhanesSearch.html))  
- **`var_search(var)`**: Search for variables by exact name (wraps
  [`nhanesA::nhanesSearchVarName()`](https://rdrr.io/pkg/nhanesA/man/nhanesSearchVarName.html))

## Understanding NHANES Dataset Names

This is **critical** to understand before using the package:

### How CDC Names Datasets

The CDC releases NHANES data in 2-year cycles, with each cycle getting a
**letter suffix**:

| CDC Table Name | Survey Cycle | Years                   |
|----------------|--------------|-------------------------|
| `DEMO`         | 1999-2000    | No suffix (first cycle) |
| `DEMO_B`       | 2001-2002    | B                       |
| `DEMO_C`       | 2003-2004    | C                       |
| `DEMO_D`       | 2005-2006    | D                       |
| …              | …            | …                       |
| `DEMO_J`       | 2017-2018    | J                       |
| `DEMO_L`       | 2021-2023    | L (skips K)             |

This pattern applies to **all NHANES datasets**: `BPX`, `BPX_B`,
`BPX_C`, …, `BPX_L` for blood pressure examination data, and so on.

> Do note that there are mild inconsistencies in the suffix naming
> convention, particularly with COVID-era data.

### How This Package Names Datasets

We **combine all cycles** and store them by **base name only** (no
suffixes):

- CDC has: `DEMO`, `DEMO_B`, `DEMO_C`, …, `DEMO_L` (11 separate files)  
- We store: `demo` (1 merged file with all cycles)  
- A `year` column automatically tracks which cycle each row came from

This means:

``` r
# You call this:
demo <- read_nhanes('demo')

# You get: All 11 cycles merged together
# - 1999-2000 data (from DEMO)
# - 2001-2002 data (from DEMO_B)
# - 2003-2004 data (from DEMO_C)
# - ... through 2021-2023 (from DEMO_L)
# - Each row has a 'year' column showing its cycle
```

**Important Note on the `year` Variable:** The `year` column represents
the **start year** of each 2-year survey cycle. For example,
`year = 1999` indicates the 1999-2000 cycle, and `year = 2017` indicates
the 2017-2018 cycle. Refer to the [NHANES
documentation](https://www.cdc.gov/nchs/nhanes/) for more details on
survey cycles and year representation.

### Important: 2019-2020 Cycle (COVID-19)

The 2019-2020 survey cycle (suffix K) is **NOT included** in this
package’s datasets.

**Why?** The COVID-19 pandemic disrupted data collection, and the CDC
determined the data quality was insufficient for standard NHANES
analysis. The CDC combined partial 2019-2020 data with 2021-2023 data
and released it as a special pre-pandemic dataset.

**Reference:** [CDC NHANES 2019-2020 Data
Documentation](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2019)

**Impact:** Datasets jump from suffix J (2017-2018) to suffix L
(2021-2023), skipping K entirely.

### Why This Matters

When searching CDC documentation, you’ll see table names with suffixes
(e.g., `DEMO_J` for 2017-2018 demographics). But when using this
package, you use the **base name** (`demo`) and get **all cycles
automatically merged**.

This design: - Simplifies data access (one name instead of tracking 11
suffix codes)  
- Enables longitudinal analysis (all years in one dataset)  
- Handles type mismatches between cycles automatically  
- Adds temporal context via the `year` column

## Finding Variables

Let’s say you want to study hypertension but don’t know which dataset
contains blood pressure variables. **nhanesdata** provides search
functions to help you discover variables.

### Method 1: Search by Term

Use
[`term_search()`](https://kyleGrealis.com/nhanesdata/reference/term_search.md)
to find variables by keyword:

``` r
library(nhanesdata)

# Find variables related to blood pressure
term_search("blood pressure")
```

This returns a data frame showing variable names, which datasets they
appear in, and descriptions. For example, you’ll see that `BPXSY1`
(systolic blood pressure) is in the `BPX` tables, so you’d use
`read_nhanes('bpx')`.

### Method 2: Search by Variable Name

If you know the exact variable name, use
[`var_search()`](https://kyleGrealis.com/nhanesdata/reference/var_search.md):

``` r
# Find all occurrences of BPXSY1 across cycles
var_search("BPXSY1")
```

This shows which survey cycles contain that variable, which is helpful
for understanding data availability over time.

### Method 3: Verify Variables in Loaded Data

After loading a dataset, check if it contains the variables you need:

``` r
# Load body measures data
bmx <- read_nhanes('bmx')

# Check for the height variable
'bmxht' %in% names(bmx)  # Returns TRUE or FALSE

# View all available columns
names(bmx)
```

All search functions are **case-insensitive**, so
[`term_search()`](https://kyleGrealis.com/nhanesdata/reference/term_search.md),
[`var_search()`](https://kyleGrealis.com/nhanesdata/reference/var_search.md),
and other functions work with any capitalization.

## Working with Multiple Datasets

The real power of NHANES comes from linking datasets together. You can
join data from different examinations and questionnaires using the
`seqn` (participant ID) and `year` (survey cycle) columns.

### Basic Single Dataset Loading

``` r
library(nhanesdata)

# Load demographics
demo <- read_nhanes('demo')

# Check the year distribution
demo |>
  dplyr::count(year)
```

### Joining Multiple Datasets

``` r
library(nhanesdata)
library(dplyr)

# Load related datasets
demo <- read_nhanes('demo')        # Demographics
bpx <- read_nhanes('BPX')          # Blood pressure measurements
bmx <- read_nhanes('Bmx')          # Body measurements

# Combine datasets using inner_join()
# Always join on BOTH seqn AND year
analysis_data <- demo |>
  inner_join(bpx, by = c('seqn', 'year')) |>
  inner_join(bmx, by = c('seqn', 'year')) |>
  select(year, seqn, ridageyr, riagendr, bpxsy1, bmxbmi)
```

**Key joining principle:** Always join on both `seqn` (participant ID)
AND `year` (survey cycle). The same participant can appear in multiple
survey cycles, and the same sequence number can be reused across cycles.

## Data Storage Format

All datasets are stored remotely as `.parquet` files for optimal
performance and cross-platform compatibility. **Note:** The storage
format does not affect how you read the data - simply use
[`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
and the function handles everything. You are not writing `.parquet`
files to your local environment unless you explicitly choose to save
them locally.

## Notes on NHANES Data Quality

### Survey Cycle Details

- **2-year cycles**: Data released biannually (1999-2000, 2001-2002,
  etc.)  
- **2019-2020 cycle**: Interrupted by COVID-19 pandemic and not
  released  
- **Suffix pattern**: Letters B through L, skipping K (so J → L between
  2017-2018 and 2021-2023)

### Type Harmonization

Older cycles sometimes use different variable types (e.g., factor
vs. character, integer vs. double). The `pull_nhanes()` function detects
and resolves these conflicts automatically:

``` r
# This handles type mismatches transparently
demo <- pull_nhanes('demo')
# Type mismatch in riagendr: integer vs double... converting types now...
# Type mismatch in ridreth1: factor vs character... converting types now...
```

### Special Cases

**DXX Tables (Body Composition)**: The 2005-2006 cycle contains repeated
measures that shouldn’t be merged blindly with other cycles. Read the
CDC documentation carefully before using these datasets.

## Public Data Access

All pre-processed datasets are hosted publicly at:

    https://nhanes.kylegrealis.com/{dataset_name}.parquet

You can access them directly without the package using **arrow**:

``` r
# Direct download (without nhanesdata package)
library(arrow)

demo <- arrow::read_parquet('https://nhanes.kylegrealis.com/demo.parquet')
trigly <- arrow::read_parquet('https://nhanes.kylegrealis.com/trigly.parquet')
```

**Note:** Dataset names in URLs are lowercase. The
[`read_nhanes()`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md)
function handles case conversion automatically.

This direct access is useful for:

- Sharing data with collaborators who don’t need the full package  
- Accessing data from Python, Julia, or other **arrow**-compatible
  languages  
- Quick data exploration without installing dependencies

## Getting Help

- **Bug reports & feature requests**: [GitHub
  Issues](https://github.com/kyleGrealis/nhanesdata/issues)  
- **Function documentation**: `?function_name` (e.g.,
  [`?read_nhanes`](https://kyleGrealis.com/nhanesdata/reference/read_nhanes.md),
  [`?term_search`](https://kyleGrealis.com/nhanesdata/reference/term_search.md))  
- **Package vignettes**: `browseVignettes("nhanesdata")` for detailed
  guides  
- **CDC NHANES resources**: [NHANES
  Website](https://www.cdc.gov/nchs/nhanes/)  
- **nhanesA package**: For direct CDC API access, see [**nhanesA** on
  CRAN](https://cran.r-project.org/package=nhanesA)

## Related Packages

- **[nhanesA](https://cran.r-project.org/package=nhanesA)**: Direct
  interface to NHANES API  
- **[survey](https://cran.r-project.org/package=survey)**: Complex
  survey analysis with proper weighting  
- **[srvyr](https://cran.r-project.org/package=srvyr)**: Tidy survey
  analysis using **dplyr** syntax  
- **[gtsummary](https://cran.r-project.org/package=gtsummary)**:
  Publication-ready summary tables

## Contributing

This is a personal data project, but feel free to fork it if you find it
useful.

## License

NHANES data is public domain (U.S. government). This processing code is
provided as-is.
