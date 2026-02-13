# Get CDC Documentation URL for NHANES Table

Constructs and returns the full CDC documentation URL for a given NHANES
table. The function handles table names with or without cycle suffixes
(e.g., "DEMO_J" for 2017-2018 or "DEMO" for 1999-2000) and automatically
maps the suffix to the appropriate survey cycle year.

## Usage

``` r
get_url(table)
```

## Arguments

- table:

  Character. The table where variable information is needed. Can include
  cycle suffix (e.g., "DEMO_J") or not (e.g., "DEMO"). Not
  case-sensitive.

## Value

Character string (invisibly). Full URL to CDC data documentation,
codebook, and frequencies is returned invisibly and also printed to the
console via message() for interactive use.

## See also

[`term_search`](https://www.kyleGrealis.com/nhanesdata/reference/term_search.md),
[`var_search`](https://www.kyleGrealis.com/nhanesdata/reference/var_search.md)

Other search and lookup functions:
[`term_search()`](https://www.kyleGrealis.com/nhanesdata/reference/term_search.md),
[`var_search()`](https://www.kyleGrealis.com/nhanesdata/reference/var_search.md)

## Examples

``` r
# These examples will run and display URLs
get_url("DEMO_J") # Demographics 2017-2018
#> https://wwwn.cdc.gov/nchs/data/nhanes/public/2017/datafiles/DEMO_J.htm
get_url("diq_j") # Case-insensitive: Diabetes 2017-2018
#> https://wwwn.cdc.gov/nchs/data/nhanes/public/2017/datafiles/DIQ_J.htm
get_url("DIQ") # No suffix = 1999-2000 cycle
#> https://wwwn.cdc.gov/nchs/data/nhanes/public/1999/datafiles/DIQ.htm

# Capture the URL for programmatic use
url <- get_url("BMX_J")
#> https://wwwn.cdc.gov/nchs/data/nhanes/public/2017/datafiles/BMX_J.htm
```
