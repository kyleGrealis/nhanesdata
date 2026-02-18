# Calculate survey design weight within a NHANES dataset

Input an NHANES dataset and apply the proper weight calculation. There
are 3 categories of weights:

1.  Interview weight

2.  Mobile Exam Center (MEC) weight

3.  Fasting weight

The probability of being sampled for each type of NHANES category
decreases from interview to fasting samples. Therefore, when selecting
the proper weight, the practitioner should use the weight with the
lowest probability when combining variables across categories. For
example, when performing an analysis using demographics (interview),
diabetes information (interview), and DEXA scanning (MEC), the
associated MEC weight is the proper weight variable to use.

It is also important to select the proper year grouping for the cycle.
NHANES cycles for 1999 and 2001 use 4-year sample weights, while all
subsequent cycles use 2-year sample weights. This type of combination
requires careful attention to:

1.  The variables used, to determine weight category (interview, MEC,
    fasting).

2.  The cycles (years) used, to select proper year grouping variable.

This function will allow the user to input a dataset, select analysis
start & end years, and specify the type of weight category. The
resulting survey design will calculate the proper weight and apply that
when creating the design object.

NOTE: It is **not** required to specify variables for this function and
it is **highly recommended** to perform preprocessing of variables
*before* creating a complex design object.

See also
[`as_survey_design`](http://gdfe.co/srvyr/reference/as_survey_design.md)

## Usage

``` r
create_design(
  dsn,
  start_yr,
  end_yr,
  wt_type = c("interview", "mec", "fasting")
)
```

## Arguments

- dsn:

  Tibble or data-frame.

- start_yr:

  Numeric. Lower bound for year filtering (inclusive). Must be an odd
  year representing a valid NHANES cycle start: 1999, 2001, 2003, ...,
  2019, 2021. For example, use 2007 for the 2007-2008 cycle. Data will
  be filtered to include years between start_yr and end_yr.

- end_yr:

  Numeric. Upper bound for year filtering (inclusive). Must be an odd
  year \>= start_yr. Weight calculations are based on the number of
  cycles actually present in the filtered data, so it is valid to have
  gaps (e.g., start_yr=1999, end_yr=2017 with 2007-2010 missing).

- wt_type:

  Character. Category of weight to be used. Use the weight category with
  the lowest probability of selection, but only if at least one variable
  from that category is to be used. Accepts full names (`"interview"`,
  `"mec"`, `"fasting"`) or abbreviations (`"int"`, `"mec"`, `"fast"`).

## Value

A survey design object of class `tbl_svy` (from srvyr package)
containing the calculated design weights and survey design metadata
(PSUs, strata). Participants without valid weights for the specified
weight type are automatically filtered out before design object
creation. Participants with zero weights are retained in the design
object but will be automatically excluded from most survey analyses.

## Details

**Weight Calculation for Combined Cycles**

NHANES provides 4-year weights for the 1999-2000 and 2001-2002 cycles,
while all subsequent cycles provide only 2-year weights. When combining
multiple cycles:

- If 1999 or 2001 cycles are included: Use the 4-year weight variable
  multiplied by `2/n` where `n` is the total number of cycles. The
  numerator is 2 because the 4-year weight represents two 2-year cycles.

- For cycles 2003 and beyond: Use the 2-year weight variable multiplied
  by `1/n`.

- The denominator `n` is always the total number of cycles in the
  analysis.

Example: Combining 4 cycles (1999, 2001, 2003, 2005):

- 1999 & 2001: `wtmec4yr * 2/4`

- 2003 & 2005: `wtmec2yr * 1/4`

Fasting weights (`wtsaf2yr`) are used with `1/n` multiplication.

NOTE: 4-year fasting weights (`wtsaf4yr`) exist in NHANES laboratory
files for 1999-2002 but are not currently supported by this function.

**Fasting Subsample Weights**

For fasting subsample analyses combining 1999-2002 cycles, the 4-year
fasting weight (WTSAF4YR) exists in laboratory files (e.g., LAB10AM,
LAB13AM) but is typically NOT in demographic files obtained via nhanesA.
If your dataset includes merged laboratory fasting data from 1999-2002,
ensure WTSAF4YR is present. Otherwise, this function assumes only 2-year
fasting weights (WTSAF2YR) are available.

## Examples

``` r
# \donttest{
# Load demographics data
demo <- read_nhanes("demo")
#> Loading: DEMO
#> DEMO complete! (113,249 rows)

# Create design object with interview weights
design <- create_design(
  dsn = demo,
  start_yr = 1999,
  end_yr = 2011,
  wt_type = "interview"
)

# Combine with examination data and use MEC weights
bmx <- read_nhanes("bmx")
#> Loading: BMX
#> BMX complete! (96,288 rows)
combined <- demo |>
  dplyr::left_join(bmx, by = c("seqn", "year"))

design_mec <- create_design(
  dsn = combined,
  start_yr = 2007,
  end_yr = 2017,
  wt_type = "mec"
)
#> 
#> Note: 2428 participants have zero mec weights and will be retained in the
#> design object.
#> These participants were not in the subsample for this weight category
#> and will be automatically excluded from analyses by the {survey} package.
# }
```
