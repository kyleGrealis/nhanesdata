# Available NHANES Datasets

## Available Datasets

This package provides 342 NHANES datasets, automatically updated
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
> **Key features:**  
> \* Follow-up through December 31, 2019  
> \* Cause-specific mortality (ICD-10 codes)  
> \* Person-months of follow-up  
> \* Vital status and mortality flags
>
> **Important:** Mortality linkage requires understanding of survey
> weights, censoring, and survival analysis methods. Always consult the
> [NCHS data linkage
> documentation](https://www.cdc.gov/nchs/linked-data/mortality-files/?CDC_AAref_Val=https://www.cdc.gov/nchs/data-linkage/mortality-public.htm)
> and the [NHANES analytic
> guidelines](https://wwwn.cdc.gov/nchs/nhanes/analyticguidelines.aspx)
> before analyzing mortality outcomes.
>
> See the [Public-Use Linked Mortality
> Files](https://www.cdc.gov/nchs/linked-data/mortality-files/) for
> methodology and variable definitions.

### Categories

**Questionnaire/Interview Tables** - Self-reported data from participant
interviews

**Examination Tables** - Physical measurements and laboratory results

### Codebook Validation Status

The **CB** column indicates whether each dataset’s categorical variable
labels have been cross-validated against CDC codebooks across all survey
cycles (1999–2023).

| Symbol | Meaning |
|:--:|----|
| ✓ | **Verified** – Per-cycle CDC codebooks were compared and all labels confirmed correct across cycles. |
| 🔍 | **Unverified** – No CDC codebook was available for automated cross-validation. These are predominantly continuous laboratory values where label drift does not apply. The data is correct; only the independent label audit could not be performed. |
| 🛠️ | **Fix applied** – A label discrepancy was found and corrected. See below. |
| ⚠️ | **Caution** – Known label text changes across survey cycles. See below. |

#### 🛠️ Fix Applied: CDQ (Cardiovascular Health)

The 2001–2002 cycle codebook (`CDQ_B`) listed raw numeric values (“1”,
“2”, …, “8”) as labels for variables `CDQ009A`–`CDQ009H` instead of the
descriptive pain-location text used in all other cycles. This was a CDC
codebook deficiency, not a change in questionnaire meaning. The
corrected labels (e.g., “Pain in right arm”, “Pain in left chest”) now
match the descriptive text from the 2003+ codebooks.

#### ⚠️ Caution: OHXDEN (Oral Health - Dentition)

CDC updated descriptive labels for 111 dental coding variables across
survey cycles. The underlying numeric codes retain their original
meaning — for example, tooth condition code `2` consistently means
“permanent tooth” whether the label reads “Permanent tooth
(succedaneous)” (2001) or “Permanent tooth present” (2009+). Similarly,
code `3` means “implant” regardless of whether the label is “Implant” or
“Dental Implant.” These are cosmetic label refinements by CDC, not
changes in clinical coding. Researchers performing cross-cycle analyses
should be aware that label text may differ by era.

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
