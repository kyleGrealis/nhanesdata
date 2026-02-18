# Search NHANES Variables by Term or Phrase

A convenience wrapper around
[`nhanesA::nhanesSearch`](https://rdrr.io/pkg/nhanesA/man/nhanesSearch.html)
that returns a simplified, concise output focused on variable names,
descriptions, and survey years. Results are sorted by year (most recent
first) and then by variable name.

## Usage

``` r
term_search(var)
```

## Arguments

- var:

  Character. Search term or phrase to find in variable names or
  descriptions. Case-insensitive. Special regex characters are
  automatically escaped for literal matching.

## Value

A data.frame with 4 columns:

- `Variable.Name`: NHANES variable code

- `Variable.Description`: Description of the variable

- `Data.File.Name`: Name of the data file containing the variable

- `Begin.Year`: Starting year of the survey cycle (numeric)

Results are sorted by `Begin.Year` (descending) then `Variable.Name`.
Returns an empty data.frame with correct structure if no matches found.

## See also

[`var_search`](https://www.kylegrealis.com/nhanesdata/reference/var_search.md)
for searching by exact variable name,
[`get_url`](https://www.kylegrealis.com/nhanesdata/reference/get_url.md)
for getting documentation URLs,
[`nhanesSearch`](https://rdrr.io/pkg/nhanesA/man/nhanesSearch.html) for
the underlying search function

Other search and lookup functions:
[`get_url()`](https://www.kylegrealis.com/nhanesdata/reference/get_url.md),
[`var_search()`](https://www.kylegrealis.com/nhanesdata/reference/var_search.md)

## Examples

``` r
# \donttest{
# Search for diabetes-related variables (showing first 5 results)
term_search("diabetes") |> head(5)
#>   Variable.Name
#> 1        DID040
#> 2        DIQ010
#> 3        DIQ160
#> 4        DIQ180
#> 5        DID040
#>                                                                                                               Variable.Description
#> 1 How old {was SP/were you} when a doctor or other health professional first told {you/him/her} that {you/he/she} had diabetes or 
#> 2 The next questions are about specific medical conditions. {Other than during pregnancy, {have you/has SP}/{Have you/Has SP}} eve
#> 3 {Have you/Has SP} ever been told by a doctor or other health professional that {you have/SP has} any of the following:  prediabe
#> 4                                 {Have you/Has SP} had a blood test for high blood sugar or diabetes within the past three years?
#> 5 How old {was SP/were you} when a doctor or other health professional first told {you/him/her} that {you/he/she} had diabetes or 
#>   Data.File.Name Begin.Year
#> 1          DIQ_L       2021
#> 2          DIQ_L       2021
#> 3          DIQ_L       2021
#> 4          DIQ_L       2021
#> 5          DIQ_J       2017

# Search for blood pressure measurements (showing first 5 results)
term_search("blood pressure") |> head(5)
#>   Variable.Name
#> 1        BPQ020
#> 2        BPQ030
#> 3        BPQ150
#> 4      BPAOMNTS
#> 5        BPD035
#>                                                                                                               Variable.Description
#> 1 {Have you/Has SP} ever been told by a doctor or other health professional that {you/s/he} had hypertension, also called high blo
#> 2          {Were you/Was SP} told on 2 or more different visits that {you/s/he} had hypertension, also called high blood pressure?
#> 3                    {Are you/Is SP} now taking any medication prescribed by a doctor for {your/his/her/SP's} high blood pressure?
#> 4 Difference in minutes between blood pressure obtained by a physician with a mercury sphygmomanometer (legacy) and blood pressure
#> 5       How old {were you/was SP} when {you were/he/she was} first told that {you/he/she} had hypertension or high blood pressure?
#>   Data.File.Name Begin.Year
#> 1          BPQ_L       2021
#> 2          BPQ_L       2021
#> 3          BPQ_L       2021
#> 4         BPXO_J       2017
#> 5          BPQ_J       2017
# }
```
