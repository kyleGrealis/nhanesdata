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

[`var_search`](https://www.kyleGrealis.com/nhanesdata/reference/var_search.md)
for searching by exact variable name,
[`get_url`](https://www.kyleGrealis.com/nhanesdata/reference/get_url.md)
for getting documentation URLs,
[`nhanesSearch`](https://rdrr.io/pkg/nhanesA/man/nhanesSearch.html) for
the underlying search function

Other search and lookup functions:
[`get_url()`](https://www.kyleGrealis.com/nhanesdata/reference/get_url.md),
[`var_search()`](https://www.kyleGrealis.com/nhanesdata/reference/var_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Search for diabetes-related variables
term_search("diabetes")

# Search for blood pressure measurements
term_search("blood pressure")

# Handles special characters safely
term_search("weight (kg)")
} # }
```
