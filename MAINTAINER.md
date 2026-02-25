# Maintainer Notes

## Cloudflare R2 Credentials

### Local Setup
```r
# Add to .Renviron (NEVER commit this file)
R2_ACCOUNT_ID="your_account_id"
R2_ACCESS_KEY_ID="your_access_key_id"
R2_SECRET_ACCESS_KEY="your_secret_access_key"
```

### GitHub Secrets
Settings → Secrets and variables → Actions → Add:
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

### Token Rotation (Annually)
1. Cloudflare Dashboard → R2 → Manage R2 API Tokens
2. Create new token (Object Read & Write, bucket: `nhanes-data`)
3. Update `.Renviron` and GitHub Secrets
4. Delete old token

## Workflow Update Commands

### Test with Sample (20 datasets)
```bash
# Generate random sample
Rscript inst/scripts/create_random_sample.R

# Test with sample (live upload + verification)
Rscript inst/scripts/workflow_update.R --sample
```

### Full Update (339 datasets, 18 batches)
```bash
# Dry run (no upload, checks for changes)
Rscript inst/scripts/workflow_update.R --dry-run

# Live run (uploads + verification)
Rscript inst/scripts/workflow_update.R
```

### Process Specific Batch
```bash
# Dry run batch 5
Rscript inst/scripts/workflow_update.R --dry-run --batch=5

# Live run batch 5
Rscript inst/scripts/workflow_update.R --batch=5
```

### Process Specific Datasets
```bash
Rscript inst/scripts/workflow_update.R --datasets=demo,bpx,bmx
```

## Workflow Features

### Batch Processing
- Organizes 339 datasets into 18 category-based batches (max 20 per batch)
- 4-minute delays between batches to respect CDC rate limiting
- Categories: dietary → examination → questionnaire → laboratory
- Aggressive memory cleanup after each dataset (prevents connection exhaustion)

### Upload Verification
- After each live upload, verifies data integrity by downloading from R2
- Checks: row count, column count, column names, required columns, data presence, seqn uniqueness
- **Workflow stops immediately if verification fails**
- Only runs during live uploads (skipped in dry-run mode)

### Hash Tracking
- `.checksums.json` stores MD5 hashes of uploaded datasets
- Workflow only uploads datasets that changed (UNCHANGED datasets are skipped)
- Dry runs check hashes but never write to file
- Clear checksums to force re-upload: `echo '{"_comment": "..."}' > .checksums.json`

### Empty Dataset Handling
- Gracefully skips datasets with no available data across any cycle
- Prevents crashes when CDC returns 404 for all cycles

## Adding New Datasets

1. Edit `inst/extdata/datasets.yml` (alphabetically within category):
```yaml
datasets:
  newdataset:
    name: newdataset
    description: Brief description
    category: questionnaire  # dietary, examination, questionnaire, laboratory
```

2. Test with sample mode first:
```bash
Rscript inst/scripts/create_random_sample.R
Rscript inst/scripts/workflow_update.R --sample
```

3. Run full workflow:
```bash
Rscript inst/scripts/workflow_update.R
```

## Data Pipeline

1. **Pull**: `pull_nhanes(dataset)` downloads from CDC, merges cycles (1999-2023), harmonizes types
2. **Check**: Compare MD5 hash against `.checksums.json` (skip if unchanged)
3. **Upload**: `nhanes_r2_upload(data, name, bucket)` writes Parquet to R2 via paws.storage
4. **Verify**: `verify_r2_upload(dataset, original_data)` downloads and validates integrity
5. **Track**: Update `.checksums.json` with new hash

## GitHub Actions

Workflow runs quarterly (January, April, July, October) to refresh all datasets. Already configured with R2 credentials as repository secrets.
