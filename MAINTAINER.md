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

## Triggering Updates

### Local Full Update
```r
source("inst/scripts/workflow_update.R")
# Runs all 71 datasets, uploads to R2, updates .checksums.json
```

### GitHub Actions
Already configured - you know how to do this.

## Adding New Datasets

Edit `inst/extdata/datasets.yml`:

```yaml
questionnaire:
  - name: newdataset
    description: Brief description
```

The workflow picks up all datasets listed there. That's it.

## Data Workflow

1. `pull_nhanes(dataset)` - Downloads from CDC, merges cycles, returns data
2. `nhanes_r2_upload(data, name, bucket)` - Uploads to R2 via paws.storage
3. `detect_data_changes(dataset)` - Checks if data changed via MD5
4. `update_checksum(dataset, hash)` - Updates `.checksums.json`

That's it.
