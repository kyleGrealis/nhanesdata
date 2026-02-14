# Search for NHANES Variable by Exact Name

A convenience wrapper around
[`nhanesA::nhanesSearchVarName`](https://rdrr.io/pkg/nhanesA/man/nhanesSearchVarName.html)
that searches for variables by exact variable name match. The function
automatically converts input to uppercase to match NHANES naming
conventions. Use this when you know the variable code; use
[`term_search()`](https://www.kyleGrealis.com/nhanesdata/reference/term_search.md)
for text-based searches.

## Usage

``` r
var_search(var)
```

## Arguments

- var:

  Character. Variable name to search for. Will be automatically
  converted to uppercase. Not case-sensitive.

## Value

A character vector of CDC table names containing the variable (e.g.,
`"DEMO"`, `"DEMO_B"`, `"DEMO_C"`). Returns `character(0)` if the
variable is not found.

## See also

[`term_search`](https://www.kyleGrealis.com/nhanesdata/reference/term_search.md)
for text-based searches,
[`get_url`](https://www.kyleGrealis.com/nhanesdata/reference/get_url.md)
for documentation URLs,
[`nhanesSearchVarName`](https://rdrr.io/pkg/nhanesA/man/nhanesSearchVarName.html)
for the underlying function

Other search and lookup functions:
[`get_url()`](https://www.kyleGrealis.com/nhanesdata/reference/get_url.md),
[`term_search()`](https://www.kyleGrealis.com/nhanesdata/reference/term_search.md)

## Examples

``` r
# \donttest{
# Search for specific variable (case-insensitive)
var_search("RIDAGEYR") # Age variable across all DEMO cycles
#>  [1] "DEMO"   "DEMO_B" "DEMO_C" "DEMO_D" "DEMO_E" "DEMO_F" "DEMO_G" "DEMO_H"
#>  [9] "DEMO_I" "DEMO_J" "DEMO_L" "P_DEMO"
var_search("BPXSY1") # Systolic blood pressure
#>  [1] "BPX"   "BPX_B" "BPX_C" "BPX_D" "BPX_E" "BPX_F" "BPX_G" "BPX_H" "BPX_I"
#> [10] "BPX_J"
# }
```
