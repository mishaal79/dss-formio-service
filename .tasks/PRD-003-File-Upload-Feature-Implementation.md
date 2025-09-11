# PRD-003: Form.io File Upload Feature Implementation

**Date**: 2025-01-11  
**Priority**: HIGH  
**Status**: 🟡 PHASE 1 COMPLETE - Infrastructure Deployed  
**Author**: Mishal (via Claude)  
**Assignee**: Claude Code  
**Last Updated**: 2025-09-11  

## Executive Summary

Form.io forms require file upload functionality to support document attachments, images, and other file types. While the infrastructure partially supports file uploads (GCS bucket exists with CORS), the authentication mechanism is missing, preventing actual file uploads from working. This PRD outlines the implementation of S3-compatible GCS access for file uploads, following the same pattern successfully used by the PDF server.

## Problem Statement

### Current State
- **Storage**: GCS bucket configured with proper CORS settings
- **Environment Variables**: Basic configuration present (FORMIO_FILES_SERVER=gcs, FORMIO_GCS_BUCKET, FORMIO_GCS_PATH)
- **Permissions**: Service account has storage.admin role
- **Status**: File uploads fail due to missing authentication credentials
- **PDF Server**: Successfully uses S3-compatible HMAC keys for GCS access

### Business Impact
- Users cannot attach documents to forms
- No support for image uploads in form submissions
- Limited form functionality for document-heavy workflows
- Blocks deployment of forms requiring file attachments

### Root Cause
The Form.io service is configured to use GCS but lacks the authentication mechanism (HMAC keys) to actually access the storage bucket. The PDF server already solves this problem using S3-compatible credentials.

## Solution Approach

### Recommended: S3-Compatible GCS Access
**Rationale:**
- Already proven to work with PDF server
- Best documented in Form.io ecosystem
- No additional infrastructure required
- Supports multipart uploads up to 5TB
- Compatible with Form.io file component out-of-the-box

### Alternatives Considered

#### 1. Google Drive Integration
- **Pros**: Native Google integration, user-friendly interface
- **Cons**: Manual OAuth setup required, cannot be automated via Terraform, complex token management
- **Decision**: Not recommended due to manual configuration overhead

#### 2. Native GCS with Application Default Credentials
- **Pros**: Simplest from GCP perspective
- **Cons**: Requires custom Form.io provider plugin, less documented
- **Decision**: Not recommended due to lack of Form.io support

#### 3. MinIO Self-Hosted S3
- **Pros**: Full S3 compatibility, complete control
- **Cons**: Additional infrastructure to manage, extra operational overhead
- **Decision**: Not recommended - adds unnecessary complexity when GCS already provides S3-compatible API

## Technical Requirements

### Infrastructure Components

#### 1. HMAC Key Generation
```terraform
# Generate HMAC keys for Form.io service account
resource "google_storage_hmac_key" "formio_gcs_key" {
  service_account_email = google_service_account.formio_service_account.email
  project              = var.project_id
}
```

#### 2. Secret Storage
```terraform
# Store HMAC keys in Secret Manager
resource "google_secret_manager_secret" "formio_s3_key" {
  secret_id = "formio-gcs-s3-key-${var.environment}"
  project   = var.project_id
}

resource "google_secret_manager_secret" "formio_s3_secret" {
  secret_id = "formio-gcs-s3-secret-${var.environment}"
  project   = var.project_id
}
```

#### 3. Environment Variables
```yaml
FORMIO_S3_SERVER: "storage.googleapis.com"
FORMIO_S3_KEY: <from-secret-manager>
FORMIO_S3_SECRET: <from-secret-manager>
FORMIO_S3_BUCKET: <existing-bucket-name>
FORMIO_S3_REGION: "auto"
FORMIO_S3_PATH: "uploads/${environment}"
```

### Form.io Configuration

#### File Component Settings
```json
{
  "type": "file",
  "key": "documents",
  "label": "Upload Documents",
  "storage": "s3",
  "url": "",
  "options": {
    "indexFiles": false
  },
  "uploadOnly": false,
  "image": false,
  "privateDownload": true,
  "filePattern": "*",
  "fileMinSize": "0KB",
  "fileMaxSize": "10MB",
  "fileTypes": [
    {
      "label": "",
      "value": ""
    }
  ]
}
```

## Implementation Status

### ✅ Phase 1: Infrastructure Setup (COMPLETED - 2025-09-11)
1. ✅ **Generated HMAC keys** for Form.io Enterprise service account
2. ✅ **Stored keys** in Google Secret Manager:
   - `dss-formio-api-ent-gcs-s3-key-dev`
   - `dss-formio-api-ent-gcs-s3-secret-dev`
3. ✅ **Updated Terraform** modules with S3-compatible environment variables
4. ✅ **Added IAM bindings** for secret access
5. ✅ **Applied infrastructure** changes to development environment

**Commits:**
- `9100d9b`: feat: add S3-compatible GCS file upload infrastructure

**Resources Created:**
- HMAC keys for service account `dss-formio-api-ent-sa-dev@erlich-dev.iam.gserviceaccount.com`
- Secret Manager secrets with appropriate IAM bindings
- Updated Cloud Run service with S3 environment variables

## Implementation Plan

### Phase 1: Infrastructure Setup (COMPLETED)
1. ✅ **Generate HMAC keys** for existing Form.io service account
2. ✅ **Store keys** in Google Secret Manager
3. ✅ **Update Terraform** modules to include S3-compatible environment variables
4. ✅ **Add IAM bindings** for secret access

### Phase 2: Service Configuration (Day 2)
1. **Update formio-service module** with S3 environment variables
2. **Deploy changes** to development environment
3. **Verify** environment variables are correctly injected

### Phase 3: Testing & Validation (Day 3-4)
1. **Create test form** with file upload component
2. **Test small files** (<10MB)
3. **Test large files** (>100MB)
4. **Verify multipart upload** for very large files
5. **Test file retrieval** and display
6. **Confirm PDF server** continues to work

### Phase 4: Production Rollout (Day 5)
1. **Deploy to staging** environment
2. **Run regression tests**
3. **Deploy to production** with monitoring
4. **Document configuration** for future reference

## Testing Strategy

### PDF Server Validation (Pre-Implementation)
```bash
# Test current PDF server functionality
curl -X POST https://forms.dev.cloud.dsselectrical.com.au/pdf-proxy/pdf \
  -H "Content-Type: application/json" \
  -d '{"html": "<h1>Test PDF</h1>"}'

# Verify S3-compatible access to GCS
gsutil ls gs://${BUCKET_NAME}/pdf/dev/uploads/

# Check PDF server logs for storage operations
gcloud run services logs read dss-formio-api-pdf-dev \
  --limit 50 \
  --project erlich-dev
```

### File Upload Testing
```javascript
// Test file upload via Form.io API
const formio = new Formio('https://forms.dev.cloud.dsselectrical.com.au');
const file = new File(['test content'], 'test.txt', { type: 'text/plain' });

formio.uploadFile('s3', file, 'test.txt', '/uploads/test/', (evt) => {
  console.log('Upload progress:', evt);
}).then(response => {
  console.log('Upload complete:', response);
}).catch(error => {
  console.error('Upload failed:', error);
});
```

### Edge Cases to Test
1. **Large Files** (>100MB) - Verify multipart upload
2. **Concurrent Uploads** - Multiple users uploading simultaneously
3. **Network Interruption** - Resume capability for large files
4. **File Type Validation** - Blocked file types are rejected
5. **Storage Quota** - Behavior when approaching storage limits
6. **CORS Errors** - Different domains accessing the service
7. **Permission Errors** - Invalid or expired credentials
8. **File Overwrite** - Same filename uploaded multiple times
9. **Special Characters** - Filenames with unicode/special characters
10. **Zero-byte Files** - Empty file handling

## Security Considerations

### Access Control
- HMAC keys stored in Secret Manager with restricted access
- Service account with minimal required permissions (storage.objectAdmin)
- No public access to storage bucket
- CORS configured for specific domains only

### Data Protection
- Files encrypted at rest in GCS
- HTTPS-only access to files
- Signed URLs for temporary file access
- Audit logging for all file operations

### Compliance
- GDPR compliance for file deletion
- Data residency in australia-southeast1 region
- Backup and retention policies applied

## Monitoring & Observability

### Key Metrics
- File upload success rate
- Average upload time by file size
- Storage usage trends
- Failed upload reasons
- API latency for file operations

### Alerts
- Upload failure rate > 5%
- Storage usage > 80% of quota
- HMAC key approaching expiration
- Unusual spike in upload volume

### Logging
```yaml
Log Entries to Monitor:
- File upload initiated: user, filename, size
- Upload completed: duration, storage path
- Upload failed: error reason, retry count
- File retrieved: user, filename
- File deleted: user, filename, reason
```

## Success Criteria

### Functional Requirements
- [ ] Users can upload files up to 100MB through forms
- [ ] Files are successfully stored in GCS bucket
- [ ] Files can be retrieved and displayed in forms
- [ ] PDF server continues to function correctly
- [ ] Multipart upload works for large files

### Performance Requirements
- [ ] Files <10MB upload in <5 seconds
- [ ] Files <100MB upload in <30 seconds
- [ ] 99.9% upload success rate
- [ ] <100ms latency for file metadata operations

### Security Requirements
- [ ] All uploads over HTTPS
- [ ] No public access to uploaded files
- [ ] Audit trail for all file operations
- [ ] Credentials stored securely in Secret Manager

## Risk Assessment

### High Risk
- **HMAC Key Compromise**: Mitigated by Secret Manager storage and rotation policy
- **Storage Costs**: Mitigated by lifecycle policies and monitoring

### Medium Risk
- **CORS Misconfiguration**: Mitigated by thorough testing across domains
- **Large File Abuse**: Mitigated by file size limits and rate limiting

### Low Risk
- **S3 API Compatibility**: Well-established pattern, minimal risk
- **Service Interruption**: Graceful degradation if storage unavailable

## Cost Analysis

### One-Time Costs
- Development effort: 5 days
- Testing effort: 2 days
- Documentation: 1 day

### Ongoing Costs
- GCS Storage: ~$0.020 per GB/month
- GCS Operations: ~$0.005 per 10,000 operations
- Secret Manager: ~$0.06 per secret/month
- Estimated monthly cost: $50-100 (based on usage)

## Documentation Requirements

### Technical Documentation
- Terraform module documentation
- Environment variable reference
- Troubleshooting guide
- Runbook for common issues

### User Documentation
- Form builder guide for file upload component
- File size and type restrictions
- Best practices for file uploads

## Rollback Plan

If issues arise after deployment:
1. **Remove S3 environment variables** from Cloud Run service
2. **Revert to previous** Cloud Run revision
3. **Investigate issues** in non-production environment
4. **Re-deploy** after fixes

## Appendix

### A. Current PDF Server Configuration (Working Reference)
```yaml
Environment Variables:
  FORMIO_S3_SERVER: "storage.googleapis.com"
  FORMIO_S3_BUCKET: <bucket-name>
  FORMIO_S3_PATH: "pdf/dev/uploads"
  FORMIO_S3_KEY: <from-secret>
  FORMIO_S3_SECRET: <from-secret>
```

### B. Form.io File Storage Providers
1. **S3/S3-Compatible** (Recommended)
   - AWS S3
   - GCS with S3 compatibility
   - MinIO
2. **Azure Blob Storage**
3. **Google Drive** (Manual setup)
4. **Custom URL**

### C. Useful Commands
```bash
# Generate HMAC key for service account
gsutil hmac create serviceaccount@project.iam.gserviceaccount.com

# Test S3-compatible access
aws s3 ls s3://bucket-name/ \
  --endpoint-url https://storage.googleapis.com \
  --aws-access-key-id=GOOG1... \
  --aws-secret-access-key=...

# Monitor upload operations
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=dss-formio-api-ent-dev \
  AND textPayload:upload" \
  --limit 50 \
  --format json
```

### D. References
- [Form.io File Storage Documentation](https://help.form.io/developers/integrations/file-storage)
- [GCS S3 Compatibility](https://cloud.google.com/storage/docs/interoperability)
- [GCS HMAC Keys](https://cloud.google.com/storage/docs/authentication/hmackeys)
- [Form.io File Component](https://help.form.io/userguide/forms/form-components#file)

## Sign-off

- [ ] Product Owner
- [ ] Technical Lead
- [ ] Security Team
- [ ] DevOps Team

---

**Next Steps**: Review and approve this PRD, then proceed with Phase 1 implementation.