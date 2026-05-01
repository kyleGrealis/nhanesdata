# Bug Report: `create_design()` Temporal Expansion Issues

**Target Package**: `nhanesdata`
**Priority**: High (Blocks 1999+ longitudinal analysis)
**Report Date**: May 1, 2026

## Executive Summary
The current implementation of `nhanesdata::create_design()` (v0.2.1) fails to support NHANES cycles prior to 2003. Specifically, it does not account for the 4-year weight variables used in the 1999-2000 and 2001-2002 cycles, nor does it handle the unique fasting weight naming conventions for those years.

## Critical Issues

### 1. Hard-coded 2-year Weight Mapping
The function currently maps weight types to fixed 2-year variable names:
- `interview` -> `wtint2yr`
- `mec` -> `wtmec2yr`
- `fasting` -> `wtsaf2yr`

**The Problem**: NHANES demographic files for 1999–2002 **do not contain** `wtint2yr` or `wtmec2yr`. They use `wtint4yr` and `wtmec4yr`. The current function will either error out or return an empty design for these years.

### 2. Fasting Weight Gap (1999–2002)
For the 1999–2002 lab subsamples, the fasting weight is stored as `WTSAF4YR`. The current package version only looks for `wtsaf2yr`, making fasting-based trend analysis since 1999 impossible without manual pre-processing.

## Recommended Fix
Port the more robust logic from the local `nephro/R/create_design_fxn.R` script into the package.

**Proposed Logic Change**:
```r
# Mirror this logic from the local dev script:
design_weight = case_when(
  year %in% c(1999, 2001) ~ wtmec4yr * 2/length(cycles),  # Use 4-yr weight for early cycles
  .default = wtmec2yr * 1/length(cycles)                 # Use 2-yr weight for 2003+
)
```

## Next Steps for `dev` Branch
1. Update `create_design` to detect if years 1999/2001 are present.
2. Implement conditional weight variable selection (4-yr vs 2-yr).
3. Ensure 2/n scaling is applied to 4-year weights and 1/n to 2-year weights as per CDC guidelines.

---
*Created by Gemini CLI for the nhanesdata development workflow.*

## Resolution (Applied May 1, 2026)
The issues identified in this report have been fully addressed in the development branch.

### Changes Implemented:
1. **Independent Weight Detection**: Added `needs_4yr` and `needs_2yr` boolean flags derived from the unique years present in the filtered dataset.
2. **Dynamic Variable Validation**: Updated the `weight_vars` switch logic to only require 4-year or 2-year variables if the corresponding cycles are actually present in the data. This prevents the "missing column" crash when analyzing only early (1999-2002) or only late (2003+) cycles.
3. **Full Fasting Weight Support**: Added `wtsaf4yr` to the `weight_vars` selection for fasting subsamples. 
4. **Robust Branching Logic**: Replaced strict `if_else()` (which evaluates all branches and causes crashes on missing columns) with conditional control flow.
    - If data contains both early and late cycles, `if_else()` is used only after ensuring both columns exist.
    - If data is exclusive to one era, the function now bypasses the irrelevant weight calculations entirely.
5. **Correct Scaling**: Enforced CDC scaling rules:
    - 4-year weights: `weight * 2/n`
    - 2-year weights: `weight * 1/n`
    *(Where n is the total number of cycles combined).*

### Verification:
- **Case 1 (Early Only)**: Verified that 1999-2001 analysis no longer requires `wtint2yr`.
- **Case 2 (Mixed)**: Verified that combining 1999 and 2003 properly scales 4-year weights by 2/2 and 2-year weights by 1/2.
- **Case 3 (Fasting)**: Verified `wtsaf4yr` is correctly recognized and used for 1999/2001 lab data.

---
*Resolution applied and verified by Gemini CLI.*
