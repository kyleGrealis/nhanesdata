# COVID-19 and the 2019-2020 NHANES Cycle

## Overview

The 2019-2020 NHANES survey cycle (suffix K) is **not included** in the
datasets provided by this package. This vignette explains why and what
it means for your analyses.

## What Happened

NHANES data collection operates on a continuous two-year cycle. The
2019-2020 cycle began on schedule but was suspended in March 2020 due to
the COVID-19 pandemic. Only partial data were collected before fieldwork
stopped.

The CDC determined that the incomplete 2019-2020 data could not be
treated as a standard NHANES cycle. Instead, the agency released it
separately as a “pre-pandemic” dataset and combined some components with
the subsequent 2021-2023 cycle.

## How This Affects Dataset Naming

NHANES cycles use alphabetical suffixes: `DEMO` (1999-2000), `DEMO_B`
(2001-2002), `DEMO_C` (2003-2004), and so on through `DEMO_J`
(2017-2018). The 2019-2020 cycle would have been suffix K.

Because this cycle is excluded, datasets skip from suffix J directly to
suffix L (2021-2023):

| Suffix | Cycle     | Status       |
|--------|-----------|--------------|
| J      | 2017-2018 | Included     |
| K      | 2019-2020 | **Excluded** |
| L      | 2021-2023 | Included     |

When you load any dataset with
[`read_nhanes()`](https://www.kylegrealis.com/nhanesdata/reference/read_nhanes.md),
the `year` column will show values from 1999 through 2017, then jump to
2021. There is no `year == 2019` in any dataset.

## Why We Exclude It

1.  **Incomplete data collection.** The CDC suspended fieldwork partway
    through the cycle, so the sample is not representative of the U.S.
    population in the way that complete NHANES cycles are.
2.  **Non-standard release format.** The CDC published these data with
    different naming conventions and file structures than standard
    NHANES cycles, which complicates automated processing.
3.  **Analytical validity.** The CDC explicitly advises against
    combining the partial 2019-2020 data with standard two-year cycles
    for most analyses.

## CDC Documentation

For full details on the 2019-2020 data release and the CDC’s guidance on
its use, see:

- [NHANES 2019-2020
  Overview](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2019)
- [NCHS Data Brief on the pandemic’s impact on
  NHANES](https://www.cdc.gov/nchs/nhanes/)

## Future Plans

We plan to incorporate the 2019-2020 pre-pandemic data in a future
release. This requires careful handling of the non-standard naming
conventions and clear documentation so users understand the limitations
of that cycle. When available, these data will be clearly flagged so
they are not inadvertently mixed with standard cycles.

## What to Do in the Meantime

If your analysis requires 2019-2020 data, you can access the
pre-pandemic files directly from the CDC using the
[**nhanesA**](https://cran.r-project.org/package=nhanesA) package:

``` r
library(nhanesA)

# Access 2019-2020 pre-pandemic demographics
demo_k <- nhanesA::nhanes("P_DEMO")
```

Note that the CDC uses a `P_` prefix (rather than the `_K` suffix) for
some of these pre-pandemic tables. Consult the CDC documentation linked
above for the correct table names.
