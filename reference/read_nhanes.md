# Read NHANES Data from Cloud Storage

Downloads pre-processed NHANES data files from cloud storage. Data
includes all survey cycles (1999-2023) automatically merged and
harmonized, with quarterly updates.

## Usage

``` r
read_nhanes(dataset)
```

## Arguments

- dataset:

  Character. NHANES dataset base name (e.g., "trigly", "demo").
  **Case-insensitive** - use 'demo', 'DEMO', or 'Demo' interchangeably.
  Must be a single string (length 1). Leading/trailing whitespace is
  automatically trimmed.

## Value

A tibble containing the requested NHANES dataset across all available
survey cycles. Always includes `year` and `seqn` columns plus
dataset-specific variables.

## Details

This function downloads NHANES datasets from cloud storage (hosted at
nhanes.kylegrealis.com). All datasets combine multiple survey cycles
with automatic type harmonization. Data is updated quarterly via
automated workflows that pull fresh data from CDC servers.

**Dataset names are case-insensitive throughout this package.** Use
uppercase (matches CDC documentation) or lowercase (easier to type) -
both work identically.

**Error handling:** The function validates inputs and provides
informative error messages if the dataset fails to load (e.g., network
issues, non-existent datasets, misspelled names). Error messages include
the attempted URL and suggestions for troubleshooting.

## Examples

``` r
# \donttest{
# All case variations work identically:
trigly <- read_nhanes("trigly") # Lowercase
#> Loading: TRIGLY
#> TRIGLY complete! (27,039 rows)
demo <- read_nhanes("DEMO") # Uppercase
#> Loading: DEMO
#> DEMO complete! (113,249 rows)
acq <- read_nhanes("Acq") # Mixed case
#> Loading: ACQ
#> ACQ complete! (89,381 rows)
# }
```
