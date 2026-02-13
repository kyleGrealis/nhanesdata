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

A data.frame showing all occurrences of the variable across survey
cycles, including variable descriptions, data file names, and years
available. Returns an empty data.frame with appropriate structure if the
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
var_search("RIAGENDR") # Gender variable
#>  [1] "BFRPOL_D" "BFRPOL_E" "BFRPOL_F" "BFRPOL_G" "BFRPOL_H" "BFRPOL_I"
#>  [7] "DEMO"     "DEMO_B"   "DEMO_C"   "DEMO_D"   "DEMO_E"   "DEMO_F"  
#> [13] "DEMO_G"   "DEMO_H"   "DEMO_I"   "DEMO_J"   "DEMO_L"   "DOXPOL_D"
#> [19] "DOXPOL_E" "DOXPOL_F" "DOXPOL_G" "DOXPOL_H" "DOXPOL_I" "PCBPOL_D"
#> [25] "PCBPOL_E" "PCBPOL_F" "PCBPOL_G" "PCBPOL_H" "PCBPOL_I" "PSTPOL_D"
#> [31] "PSTPOL_E" "PSTPOL_F" "PSTPOL_G" "PSTPOL_H" "PSTPOL_I" "P_DEMO"  
#> [37] "SSBFR_B"  "SSPCB_B"  "SSPST_B" 
var_search("ridageyr") # Age variable (auto-converted to uppercase)
#>  [1] "DEMO"   "DEMO_B" "DEMO_C" "DEMO_D" "DEMO_E" "DEMO_F" "DEMO_G" "DEMO_H"
#>  [9] "DEMO_I" "DEMO_J" "DEMO_L" "P_DEMO"

# See where glucose variables appear
var_search("LBXGLU")
#>  [1] "GLU_D"   "GLU_E"   "GLU_F"   "GLU_G"   "GLU_H"   "GLU_I"   "GLU_J"  
#>  [8] "GLU_L"   "L10AM_B" "L10AM_C" "LAB10AM" "P_GLU"  
# }
```
