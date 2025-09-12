# Form.io Google Cloud Storage (GCS) S3-Compatible Configuration Guide

## Problem

Form.io file uploads to Google Cloud Storage fail when the system generates AWS-style virtual-hosted URLs (`bucket.s3.region.amazonaws.com`). GCS requires path-style URLs (`storage.googleapis.com/bucket/path`).

## Solution

Enable "Use MinIO Server" in Form.io portal to switch from AWS URL generation to path-style URL generation.

## 1. Google Cloud Storage Setup

### 1.1 Create GCS Bucket
```bash
gsutil mb -p PROJECT_ID -c STANDARD -l REGION gs://BUCKET_NAME/
```

### 1.2 Configure CORS
```bash
cat > cors.json << EOF
[{
  "origin": ["*"],
  "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
  "responseHeader": ["*"],
  "maxAgeSeconds": 3600
}]
EOF

gsutil cors set cors.json gs://BUCKET_NAME
```

### 1.3 Create Service Account
```bash
gcloud iam service-accounts create formio-storage \
  --display-name="Form.io Storage Service Account"

gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
  --member="serviceAccount:formio-storage@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

### 1.4 Generate HMAC Keys
```bash
gsutil hmac create formio-storage@PROJECT_ID.iam.gserviceaccount.com
```
Output:
- Access Key: `GOOG1E...` (save this)
- Secret: `...` (save this)

## 2. Form.io API Server Configuration

### 2.1 Required Environment Variables

```bash
# File storage type
FORMIO_FILES_SERVER=s3

# GCS S3-compatible endpoint
FORMIO_S3_SERVER=https://storage.googleapis.com

# Your GCS bucket name
FORMIO_S3_BUCKET=your-bucket-name

# Must be "auto" for GCS (not actual region like us-central1)
FORMIO_S3_REGION=auto

# Path prefix for uploaded files
FORMIO_S3_PATH=uploads/

# HMAC credentials (store in secrets manager)
FORMIO_S3_KEY=GOOG1E...your-access-key
FORMIO_S3_SECRET=your-secret-key

# Optional: For PDF server specifically
FORMIO_S3_PORT=443  # Only if FORMIO_S3_SERVER doesn't include https://
```

### 2.2 Docker Deployment Example

```yaml
version: '3'
services:
  formio-enterprise:
    image: formio/formio-enterprise:9.6.0
    environment:
      - FORMIO_FILES_SERVER=s3
      - FORMIO_S3_SERVER=https://storage.googleapis.com
      - FORMIO_S3_BUCKET=my-formio-storage
      - FORMIO_S3_REGION=auto
      - FORMIO_S3_PATH=enterprise/uploads/
      - FORMIO_S3_KEY=${GCS_ACCESS_KEY}
      - FORMIO_S3_SECRET=${GCS_SECRET_KEY}
```

### 2.3 Cloud Run Deployment (Terraform)

```hcl
resource "google_cloud_run_v2_service" "formio" {
  template {
    containers {
      env {
        name  = "FORMIO_FILES_SERVER"
        value = "s3"
      }
      env {
        name  = "FORMIO_S3_SERVER"
        value = "https://storage.googleapis.com"
      }
      env {
        name  = "FORMIO_S3_BUCKET"
        value = var.storage_bucket_name
      }
      env {
        name  = "FORMIO_S3_REGION"
        value = "auto"
      }
      env {
        name  = "FORMIO_S3_PATH"
        value = "uploads/"
      }
      env {
        name = "FORMIO_S3_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gcs_access_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "FORMIO_S3_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gcs_secret_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }
}

```

## 3. Form.io Portal Configuration (CRITICAL)

### 3.1 Navigate to Storage Settings
1. Log into Form.io Portal at https://portal.form.io
2. Select your project
3. Go to: **Settings** (left sidebar)
4. Select: **Integrations**
5. Click: **File Storage**
6. Choose: **S3** tab

### 3.2 Enable MinIO Mode
✅ **CHECK "Use MinIO Server"** checkbox

This checkbox controls URL generation:
- When checked: `minio: true` → Path-style URLs → Works with GCS
- When unchecked: `minio: false` → AWS virtual-hosted-style URLs → Fails with GCS

### 3.3 Configure Storage Settings

| Field | Required Value | Description |
|-------|----------------|-------------|
| **Use MinIO Server** | ✅ Checked | Enables path-style URL generation for GCS |
| **MinIO Server URL** | `https://storage.googleapis.com` | GCS S3-compatible endpoint |
| **Access Key ID** | `GOOG1E...` | HMAC access key from step 1.4 |
| **Secret Access Key** | Your HMAC secret | HMAC secret from step 1.4 |
| **Bucket Name** | Your bucket name | GCS bucket created in step 1.1 |
| **Bucket Region** | `auto` or empty | Must be "auto", not actual GCS region |
| **Starts With** | `uploads/` | Folder prefix for files |
| **Access Control List** | `private` | File access control |
| **S3 Encryption** | None | GCS handles encryption |
| **Max Size** | `104857600` | 100MB limit (optional) |
| **Policy Expiration** | `3600` | 1 hour presigned URL validity |
| **Enable S3 Multipart** | ✅ Checked | For files >5MB |

### 3.4 Save Configuration
Click **Save** button at bottom of form.

## 4. Form Component Configuration

### 4.1 Add File Component to Form
1. Edit your form in Form.io
2. Drag "File" component to form
3. Open component settings

### 4.2 Configure File Component

| Tab | Setting | Value |
|-----|---------|-------|
| **Display** | Label | Your field label |
| **Data** | Storage | **S3** |
| **Data** | Url | Leave empty (uses project default) |
| **Data** | Options | Leave empty |
| **File** | Display as Image(s) | Optional |
| **File** | Image Size | 200 (if displaying images) |
| **File** | Enable Web Camera | Optional |
| **File** | File Types | e.g., `jpg,jpeg,png,pdf` |
| **Validation** | Required | As needed |
| **Validation** | Minimum File Size | Optional |
| **Validation** | Maximum File Size | e.g., `10MB` |

### 4.3 Save Component
Click **Save** to add component to form.

## 5. Technical Details

### 5.1 API Request/Response Flow

#### Storage Request (POST /storage/s3)
```javascript
// Request from Form.io client
POST /project/PROJECT_ID/form/FORM_ID/storage/s3
{
  "name": "example.pdf",
  "size": 1048576,
  "type": "application/pdf",
  "multipart": false
}
```

#### Response with MinIO Mode ENABLED
```javascript
{
  "minio": true,  // Critical: Indicates MinIO mode is active
  "signed": "https://storage.googleapis.com/my-bucket/uploads/example.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&...",
  "url": "https://storage.googleapis.com",
  "bucket": "my-bucket",
  "key": "uploads/example.pdf",
  "data": {
    "key": "uploads/",
    "acl": "private",
    "policy": "eyJleHBpcmF0aW9uIj...",  // Base64 encoded policy
    "Content-Type": "application/pdf",
    "filename": "example.pdf",
    "signature": "XcyOXsa4dE2RO+mzis6t8Cq64Go=",
    "AWSAccessKeyId": "GOOG1E..."
  }
}
```

#### Response with MinIO Mode DISABLED (Wrong)
```javascript
{
  "minio": false,  // Problem: AWS mode active
  "signed": "https://my-bucket.s3.auto.amazonaws.com/uploads/example.pdf?...",  // Wrong URL format
  "url": "https://storage.googleapis.com",
  // ... rest of response
}
```

### 5.2 URL Format Differences

| Mode | Generated URL | Result |
|------|---------------|--------|
| **MinIO Mode (Correct)** | `https://storage.googleapis.com/bucket/path/file` | ✅ Works with GCS |
| **AWS Mode (Wrong)** | `https://bucket.s3.region.amazonaws.com/path/file` | ❌ DNS resolution fails |

### 5.3 Backend Detection Logic

Form.io server determines MinIO mode based on:
1. Portal configuration sent with each request
2. If portal has "Use MinIO Server" checked → `minio: true`
3. If unchecked → `minio: false` → AWS SDK default behavior

## 6. Verification and Testing

### 6.1 Test Storage Configuration
```bash
# Get JWT token from browser DevTools (Network tab, look for x-jwt-token header)
JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test storage endpoint
curl 'https://your-formio-service.com/project/PROJECT_ID/form/FORM_ID/storage/s3' \
  -H "x-jwt-token: $JWT" \
  -H 'Content-Type: application/json' \
  --data-raw '{"name":"test.txt","size":100,"type":"text/plain"}' | jq .
```

### 6.2 Verify Response
```bash
# Check for minio: true
{
  "minio": true,  # ✅ Correct
  "signed": "https://storage.googleapis.com/..."  # ✅ Path-style URL
}
```

### 6.3 Test File Upload
```bash
# Using the signed URL from above response
SIGNED_URL="https://storage.googleapis.com/bucket/path/file?..."

# Upload file
curl -X PUT "$SIGNED_URL" \
  -H "Content-Type: text/plain" \
  --data-binary "@test.txt"
```

## 7. Troubleshooting

### 7.1 Upload Fails with Status 0
**Symptom**: Browser shows failed request with status 0
**Cause**: DNS cannot resolve `bucket.s3.auto.amazonaws.com`
**Fix**: Enable "Use MinIO Server" in portal

### 7.2 CORS Errors
**Symptom**: Browser console shows CORS policy errors
**Fix**: Verify CORS configuration on GCS bucket

### 7.3 403 Forbidden Errors
**Symptom**: Upload returns 403
**Causes**:
- Wrong HMAC keys
- Service account lacks Storage Object Admin role
- Bucket name mismatch

### 7.4 Region Issues
**Symptom**: Presigned URLs have wrong region
**Fix**: Ensure `FORMIO_S3_REGION=auto` (not `us-central1` or other GCS regions)

## 8. Common Mistakes

### 8.1 Environment Variable Mistakes
```bash
# WRONG - These don't exist in Form.io
FORMIO_S3_ENDPOINT=https://storage.googleapis.com  # ❌ Not a valid env var
FORMIO_S3_FORCE_PATH_STYLE=true  # ❌ Not a valid env var

# WRONG - Using actual GCS region
FORMIO_S3_REGION=us-central1  # ❌ Must be "auto"

# CORRECT
FORMIO_S3_SERVER=https://storage.googleapis.com  # ✅
FORMIO_S3_REGION=auto  # ✅
```

### 8.2 Portal Configuration Mistakes
- Forgetting to check "Use MinIO Server" checkbox
- Using AWS S3 URL instead of GCS endpoint
- Setting actual GCS region instead of "auto"

## 9. Implementation Checklist

- [ ] GCS bucket created with CORS enabled
- [ ] Service account created with Storage Object Admin role
- [ ] HMAC keys generated and saved
- [ ] Server environment variables configured:
  - [ ] `FORMIO_FILES_SERVER=s3`
  - [ ] `FORMIO_S3_SERVER=https://storage.googleapis.com`
  - [ ] `FORMIO_S3_BUCKET` set
  - [ ] `FORMIO_S3_REGION=auto`
  - [ ] `FORMIO_S3_KEY` and `FORMIO_S3_SECRET` in secrets
- [ ] Portal configuration completed:
  - [ ] "Use MinIO Server" checkbox ✅ CHECKED
  - [ ] MinIO Server URL set to `https://storage.googleapis.com`
  - [ ] HMAC credentials entered
  - [ ] Bucket name and region configured
- [ ] Tested with curl to verify `minio: true` in response
- [ ] File upload component added to form with S3 storage selected
- [ ] Test file upload successful

## 10. Support Information

When contacting Form.io support about GCS S3-compatible storage:

1. **Confirm server responds with `minio: true`** when portal has "Use MinIO Server" checked
2. **Provide example** of presigned URL being generated
3. **State that** GCS requires path-style URLs, not virtual-hosted-style
4. **Mention** that `FORMIO_S3_REGION=auto` is required per Google documentation
5. **Include** this full configuration guide