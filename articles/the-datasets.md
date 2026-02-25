# Available NHANES Datasets

## Available Datasets

This package provides 339 NHANES datasets, automatically updated
annually with data from 1999-2023 (excluding the 2019-2020 cycle).

### Quick Start

``` r
library(nhanesdata)

# Load demographics data
demo <- read_nhanes('demo')

# Search for variables
term_search('blood pressure')
```

> **Easter Egg: Mortality Linkage Data**
>
> The package includes harmonized NHANES-linked mortality data
> accessible via `read_nhanes("mortality")`. This dataset links NHANES
> participants to death certificate records from the National Death
> Index (NDI), enabling survival analysis and mortality risk studies.
>
> **Key features:** - Follow-up through December 31, 2019 -
> Cause-specific mortality (ICD-10 codes) - Person-months of follow-up -
> Vital status and mortality flags
>
> **Important:** Mortality linkage requires understanding of survey
> weights, censoring, and survival analysis methods. Always consult the
> [NCHS data linkage
> documentation](https://www.cdc.gov/nchs/data-linkage/mortality-public.htm)
> and the [NHANES analytic
> guidelines](https://wwwn.cdc.gov/nchs/nhanes/analyticguidelines.aspx)
> before analyzing mortality outcomes.
>
> See the [Public-Use Linked Mortality
> Files](https://www.cdc.gov/nchs/data-linkage/mortality-public.htm) for
> methodology and variable definitions.

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
