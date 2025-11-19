# Storage Module

This module manages Google Cloud Storage buckets for Form.io file uploads with
enhanced security and compliance features.

## Features

### Security (STOR-003)

- ✅ **Uniform bucket-level access** - Enforced for consistent access control
- ✅ **Public access prevention** - Enforced to prevent accidental data exposure
- ✅ **Least privilege service accounts** - Separate accounts for Form.io and
  TUS servers
- ✅ **Server-side encryption** - Google-managed keys (CMEK support available)
- ✅ **Conditional IAM policies** - TUS server can only delete chunks in
  specific prefixes

### Compliance (STOR-002)

- ✅ **7-year retention policy** - Configurable retention for regulatory
  compliance
- ✅ **Lifecycle management** - Automatic cleanup and storage class transitions
- ✅ **Versioning** - Enabled for file recovery and audit trails

### Performance (STOR-004)

- ✅ **CORS configuration** - Optimized for TUS resumable uploads
- ✅ **Regional bucket** - Low latency for Australia Southeast region
- ✅ **Storage class transitions** - Cost optimization via lifecycle rules

## Bucket Structure

```
gs://PROJECT-formio-storage-ENV-SUFFIX/
├── uploads/              # Production uploads (7-year retention)
├── uploads-temp/         # Temporary uploads (90-day cleanup)
├── uploads-failed/       # Failed uploads (1-day cleanup)
├── tus-chunks/          # TUS resumable chunks (7-day cleanup)
└── temp/                # Legacy temporary files (90-day cleanup)
```

## Lifecycle Rules

| Rule                        | Prefix                   | Age      | Action   |
| --------------------------- | ------------------------ | -------- | -------- |
| Clean TUS chunks            | `tus-chunks/`            | 7 days   | Delete   |
| Clean failed uploads        | `uploads-failed/`        | 1 day    | Delete   |
| Clean temp uploads          | `uploads-temp/`, `temp/` | 90 days  | Delete   |
| Archive temp to Nearline    | `uploads-temp/`, `temp/` | 30 days  | Nearline |
| Archive uploads to Nearline | `uploads/`               | 90 days  | Nearline |
| Archive uploads to Coldline | `uploads/`               | 365 days | Coldline |
| Archive uploads to Archive  | `uploads/`               | 3 years  | Archive  |
| Delete old versions         | All (archived)           | 30 days  | Delete   |
| Abort incomplete uploads    | All                      | 7 days   | Abort    |

## Service Accounts

### Form.io Server (`formio-server-sa-{ENV}`)

- **Purpose**: Application server file operations
- **Permissions**:
  - `roles/storage.objectCreator` - Upload files
  - `roles/storage.objectViewer` - Read files

### TUS Server (`tus-server-sa-{ENV}`)

- **Purpose**: Resumable upload management
- **Permissions**:
  - `roles/storage.objectCreator` - Create chunks
  - `roles/storage.objectViewer` - Read chunks
  - `roles/storage.objectUser` - Delete chunks (conditional on `tus-chunks/`
    prefix)

## Outputs

| Output                                | Description                          |
| ------------------------------------- | ------------------------------------ |
| `bucket_name`                         | Name of the primary GCS bucket       |
| `bucket_url`                          | GS URL for gsutil access             |
| `bucket_https_url`                    | HTTPS URL for web access             |
| `bucket_location`                     | Regional location                    |
| `bucket_storage_class`                | Storage class (STANDARD)             |
| `formio_server_service_account_email` | Form.io server SA email              |
| `tus_server_service_account_email`    | TUS server SA email                  |
| `formio_server_sa_key_secret_id`      | Secret Manager ID for Form.io SA key |
| `tus_server_sa_key_secret_id`         | Secret Manager ID for TUS SA key     |
| `retention_period_days`               | Compliance retention period          |
| `cors_origins`                        | Allowed CORS origins                 |

## Usage Example

```hcl
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  formio_bucket_name     = var.formio_bucket_name
  enable_versioning      = true
  enable_lifecycle_rules = true
  cors_origins          = ["https://formio.example.com"]
  kms_key_name          = null  # Use Google-managed keys
}
```

## Security Best Practices

1. **Never disable uniform bucket-level access** - Required for consistent
   security
2. **Never allow public access** - Use service accounts with least privilege
3. **Monitor service account keys** - Rotate regularly via Secret Manager
4. **Lock retention policy in production** - Prevents accidental data deletion
5. **Use CMEK for sensitive data** - Configure `kms_key_name` for
   customer-managed encryption

## Cost Optimization

- Files automatically transition to cheaper storage classes based on age
- Old versions are deleted after 30 days
- Failed uploads are cleaned up after 1 day
- TUS chunks are cleaned up after 7 days
- Incomplete multipart uploads are aborted after 7 days

## Compliance Notes

- **7-year retention** is configured but not locked by default
- Lock retention in production after testing: `is_locked = true`
- All operations are audited via Cloud Audit Logs
- Versioning provides file recovery capabilities

## Migration Notes

### STOR-001 Implementation

A dedicated uploads bucket `formio-uploads-dev-erlich` was created with:

- Storage class: STANDARD
- Location: australia-southeast1
- Uniform bucket-level access: Enabled
- Public access prevention: Enforced
- Server-side encryption: Google-managed keys

The main storage bucket has been enhanced with comprehensive security features
including:

- Service accounts with least privilege
- 7-year retention policy
- Advanced lifecycle management
- CORS configuration for TUS uploads
