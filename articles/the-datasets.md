# Available NHANES Datasets

## Available Datasets

This package provides 342 NHANES datasets, automatically updated
quarterly with data from 1999-2023 (excluding the 2019-2020 cycle).

### Quick Start

``` r
library(nhanesdata)

# Load demographics data
demo <- read_nhanes('demo')

# Search for variables
term_search('blood pressure')
```

### Categories

**Questionnaire/Interview Tables** - Self-reported data from participant
interviews

**Examination Tables** - Physical measurements and laboratory results

### Notes

- All datasets span multiple survey cycles (1999-2023)
- Each includes `year` and `seqn` columns for merging
- Data types are harmonized across cycles
- Variable names match CDC documentation

For detailed variable information, use
[`term_search()`](https://www.kylegrealis.com/nhanesdata/reference/term_search.md)
or visit the [CDC NHANES website](https://wwwn.cdc.gov/nchs/nhanes/).

> **Warning:** CDC may change data periodically. The data was aggregated
> as best as possible to reconcile variable types that changed across
> cycles. **ALWAYS** reference the CDC documentation with
> `nhanesdata::get_url(dataset)`!
>
> See
> [`get_url()`](https://www.kylegrealis.com/nhanesdata/reference/get_url.md)
> documentation.
