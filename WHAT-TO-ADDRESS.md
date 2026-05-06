# What To Address (Post-RMed)

Issues identified via code review of `inst/scripts/pull_nhanes.R`, `R/create_design.R`,
and `inst/scripts/workflow_update.R`. Ordered roughly by impact.

---

## 1. Semantic harmonization: reference_translations applies newest codebook backward

**File:** `inst/scripts/pull_nhanes.R` - `pull_nhanes()` and `.translate_numeric_columns()`

**Problem:** The pipeline caches translation tables from the newest available cycle
(tries L, then J, then I, ...) and applies those labels to all older cycles where
nhanesA returned raw numeric codes. For demographic variables this is mostly safe.
For clinical questionnaire variables (e.g., DIQ, MCQ, CDQ) response codes and
gating structures changed meaningfully across cycles - silently applying 2017-2018
labels to 1999-2000 numeric codes produces plausible-looking but wrong data. No
warning fires.

**Fix:** Try each cycle's own codebook first; fall back to the reference only when
the cycle genuinely has no parseable codebook. If no codebook exists and the
reference cycle is more than 2-3 cycles away, leave values as numeric and flag the
column in an attribute rather than silently applying a potentially-wrong mapping.

---

## 2. No crosswalk system for variables with changed meanings across cycles

**File:** `inst/scripts/pull_nhanes.R`

**Problem:** Variables that kept the same name but changed response codes, question
wording, or reference population across cycles are merged as-is. The pipeline has
no mechanism to reconcile these. This is the core limitation of calling the output
"harmonized" - it is structurally merged and type-reconciled, but not semantically
harmonized for variables with cross-cycle drift.

**Fix:** Add a `inst/crosswalks/` directory with per-variable mapping files (CSV or
YAML), keyed by `variable_name` + `cycle`. Apply these as a post-processing step
after the structural merge in `pull_nhanes()`. Each file should document the source
(CDC codebook, data user's guide, etc.) for reproducibility. Variables without a
crosswalk entry should be tagged in an output attribute so downstream users know
what has and hasn't been reconciled.

Priority variables to crosswalk first: DIQ (diabetes questionnaire), MCQ (medical
conditions), ALQ (alcohol use) - these changed most across cycles.

---

## 3. Performance: O(n * m) translation loop

**File:** `inst/scripts/pull_nhanes.R` - `.translate_numeric_columns()`

**Problem:** The inner loop iterates over every code for every row:

```r
for (j in seq_along(codes)) {
  mask <- !is.na(col_vec) & col_vec == codes[j]
  translated[mask] <- labels[j]
}
```

For large tables (DEMO, DIQ, BPX) this is slow. On a 100k-row dataset with 20
codes this is 2 million comparisons per column.

**Fix:** Vectorize with `match()`:

```r
idx <- match(col_vec, codes)
translated <- ifelse(is.na(idx), as.character(col_vec), labels[idx])
```

No behavior change, significant speedup on large tables.

---

## 4. table_suffixes in pull_nhanes() futures through P, but .get_year_from_suffix() only maps through L

**Files:** `inst/scripts/pull_nhanes.R`, `R/utils.R`

**Problem:** `pull_nhanes()` builds suffix list through P (2029), but
`.get_year_from_suffix()` in `utils.R` only maps A through L. Any new cycle
beyond L would cause `get_url()` to warn "Unrecognized table suffix" and default
to 1999 - silently wrong.

**Fix:** Keep both in sync. Either cap `table_suffixes` at what's mapped in
`.get_year_from_suffix()`, or extend the mapping as new cycles are confirmed by CDC.

---

## 5. options(survey.lonely.psu) is a session-wide side effect

**File:** `R/create_design.R`

**Problem:** `create_design()` sets `options(survey.lonely.psu = "adjust")` globally,
affecting any other survey analysis in the user's session. This is unexpected behavior
from a function that otherwise has no side effects.

**Fix:** Save and restore the prior option value using `on.exit()`:

```r
old_opt <- getOption("survey.lonely.psu")
on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
options(survey.lonely.psu = "adjust")
```

Or document this explicitly in the function's Details section so users aren't
surprised when their own survey objects change behavior.

---

## 6. verify_r2_upload() halts the entire workflow on first failure

**File:** `inst/scripts/workflow_update.R`

**Problem:** A verification failure calls `stop()` which kills the whole workflow
mid-run, leaving subsequent datasets unprocessed and the log/summary incomplete.
For an annual batch job processing hundreds of datasets, one bad upload shouldn't
abort everything.

**Fix:** Catch the stop, log it as a failure, and continue to the next dataset.
Aggregate verification failures in the summary report and exit with status 1 at
the end, same as other failure types.

---

## Notes

- archMitters SSH was unreachable when this file was created; pushed via GitHub API.
- This file can be deleted once issues are tracked in GitHub Issues or a project board.
