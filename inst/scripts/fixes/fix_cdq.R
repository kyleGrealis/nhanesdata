################################################################################
# Title: Fix CDQ009A-H labels for 2001-2002 cycle
# Date: 2026-05-07
# Issue: CDQ_B codebook has raw numeric labels (1-8) instead of descriptive
#        pain location labels used in CDQ_C+ (2003 onward).
# Source: CDC codebook comparison — CDQ_B vs CDQ_C
################################################################################

fix_cdq <- function(df) {
  # CDQ009A-H mapping: numeric label -> descriptive label
  # Confirmed from CDC codebooks: CDQ_C (2003+) has the descriptive labels
  cdq009_map <- list(
    cdq009a = c("1" = "Pain in right arm"),
    cdq009b = c("2" = "Pain in right chest"),
    cdq009c = c("3" = "Pain in neck"),
    cdq009d = c("4" = "Pain in upper sternum"),
    cdq009e = c("5" = "Pain in lower sternum"),
    cdq009f = c("6" = "Pain in left chest"),
    cdq009g = c("7" = "Pain in left arm"),
    cdq009h = c("8" = "Pain in epigastric area")
  )

  for (var in names(cdq009_map)) {
    if (var %in% names(df)) {
      old_val <- names(cdq009_map[[var]])
      new_val <- unname(cdq009_map[[var]])
      df[[var]][df[[var]] == old_val] <- new_val
    }
  }

  df
}

#### Apply & Upload ####

library(nhanesdata)

cdq <- nhanesdata::read_nhanes("cdq")

# Show before
cat("Before fix — CDQ009A in 2001:\n")
print(table(cdq$cdq009a[cdq$year == 2001], useNA = "ifany"))

cdq <- fix_cdq(cdq)

# Show after
cat("\nAfter fix — CDQ009A in 2001:\n")
print(table(cdq$cdq009a[cdq$year == 2001], useNA = "ifany"))

# Verify no raw numbers remain
raw_nums <- c("1", "2", "3", "4", "5", "6", "7", "8")
for (var in paste0("cdq009", letters[1:8])) {
  if (var %in% names(cdq)) {
    remaining <- sum(cdq[[var]] %in% raw_nums, na.rm = TRUE)
    if (remaining > 0) {
      stop(sprintf("Fix incomplete: %s still has %d raw numeric values", var, remaining))
    }
  }
}
cat("\nAll CDQ009A-H raw numeric labels replaced. Uploading...\n")

nhanesdata:::nhanes_r2_upload(
  x = cdq,
  name = "cdq",
  bucket = "nhanes-data"
)
