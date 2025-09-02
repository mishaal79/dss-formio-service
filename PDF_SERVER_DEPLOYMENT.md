# Form.io PDF Plus Server Deployment

## Overview
The Form.io PDF Plus server has been successfully deployed as a Cloud Run service to enable advanced PDF generation capabilities for Form.io Enterprise. This server provides pixel-perfect PDF generation with overlays and dynamic content support.

## Deployment Details

### Services Deployed
- **PDF Server**: `dss-formio-api-pdf-dev` - https://dss-formio-api-pdf-dev-kx62qbq7iq-ts.a.run.app
- **Enterprise Server**: `dss-formio-api-ent-dev` - Configured with PDF_SERVER environment variable

### Docker Images
- **PDF Server**: `formio/pdf-server:5.11.0-rc.34`
- **PDF Libs**: `formio/pdf-libs:2.2.4` (configured but not deployed as sidecar due to Cloud Run limitations)

### Configuration
- **Storage**: Google Cloud Storage (GCS) with S3-compatible API
- **Database**: MongoDB Atlas connection (shared with Enterprise)
- **License**: Form.io Enterprise license key (shared)
- **Network**: Direct VPC egress through central infrastructure

## Architecture

### Module Structure
```
terraform/modules/pdf-server/
├── main.tf       # Cloud Run service, IAM, backend service
├── variables.tf  # Input variables
└── outputs.tf    # Service URL and backend service ID
```

### Integration Points
1. **Form.io Enterprise**: Configured with `PDF_SERVER` environment variable pointing to PDF server URL
2. **MongoDB Atlas**: Shared connection with Enterprise for form data access
3. **GCS Storage**: Shared bucket for PDF storage and retrieval
4. **Load Balancer**: Backend service created for future centralized load balancer integration

## Cloud Run Limitations Discovered

### Single Container Restriction
Cloud Run v2 only supports one container with exposed ports per service. The `formio/pdf-libs:2.2.4` container was initially configured as a sidecar but had to be removed due to this limitation.

**Error**: "Revision template should contain exactly one container with an exposed port"

### No TCP Socket Probes
Cloud Run doesn't support TCP socket probes for health checks. HTTP GET probes are used instead.

**Error**: "Cloud Run currently does not support TCP socket in liveness probe"

### Backend Service Configuration
Serverless NEGs don't support `timeout_sec` in backend service configuration.

**Error**: "Timeout sec is not supported for a backend service with Serverless network endpoint groups"

## Resource Configuration

### PDF Server Resources
- **Min Instances**: 0 (scales to zero when idle)
- **Max Instances**: 3
- **CPU**: 1000m (1 vCPU)
- **Memory**: 2Gi
- **Concurrency**: 50 requests per instance
- **Timeout**: 300 seconds

### CDN Configuration
The backend service is configured with Cloud CDN for caching static PDF assets:
- **Cache Mode**: CACHE_ALL_STATIC
- **Default TTL**: 1 hour
- **Max TTL**: 24 hours
- **Negative Caching**: 404s cached for 2 minutes

## Security Configuration

### Service Account
A dedicated service account `dss-formio-api-pdf-sa-dev` is created with:
- Secret Manager access for license key and MongoDB connection
- Storage Object Admin for GCS bucket access

### Access Control
- **Public Access**: Disabled
- **Authorized Members**:
  - Form.io Enterprise service account
  - Admin users (configured in terraform.tfvars)

## Usage

### Form.io Configuration
The PDF server is automatically configured in Form.io Enterprise through the `PDF_SERVER` environment variable. No additional configuration is needed in the Form.io UI.

### Testing PDF Generation
1. Create a form with PDF export capability in Form.io
2. Submit a form entry
3. Use the PDF export option to generate a PDF
4. The PDF will be generated using the PDF Plus server

## Monitoring

### Health Checks
- **Startup Probe**: HTTP GET on port 4005, path "/"
- **Liveness Probe**: HTTP GET on port 4005, path "/"

### Logs
View PDF server logs:
```bash
gcloud run services logs read dss-formio-api-pdf-dev --region=australia-southeast1
```

## Future Enhancements

### PDF Libs Sidecar
The `formio/pdf-libs:2.2.4` container provides additional rendering capabilities but requires:
1. Separate deployment as its own Cloud Run service
2. Inter-service communication setup
3. Alternative deployment method (e.g., GKE) that supports multi-container pods

### Load Balancer Integration
The backend service `dss-formio-api-pdf-backend-dev` has been created for future integration with the centralized load balancer. To enable:
1. Add the backend service ID to central infrastructure configuration
2. Configure path-based routing for PDF endpoints

## Terraform Commands

### Deploy PDF Server
```bash
# Plan changes
make plan

# Apply changes
make apply

# Check status
gcloud run services describe dss-formio-api-pdf-dev --region=australia-southeast1
```

### Update Configuration
```bash
# Modify terraform/environments/dev/terraform.tfvars
# Then apply changes
make apply
```

## Troubleshooting

### PDF Generation Not Working
1. Check PDF server is running:
   ```bash
   curl https://dss-formio-api-pdf-dev-kx62qbq7iq-ts.a.run.app
   ```

2. Verify Enterprise has PDF_SERVER env var:
   ```bash
   gcloud run services describe dss-formio-api-ent-dev --region=australia-southeast1 --format="json" | jq '.spec.template.spec.containers[0].env[] | select(.name=="PDF_SERVER")'
   ```

3. Check logs for errors:
   ```bash
   gcloud run services logs read dss-formio-api-pdf-dev --region=australia-southeast1 --limit=50
   ```

### Connection Issues
- Ensure both services are in the same VPC network
- Verify service account permissions
- Check MongoDB Atlas network access list

## License Expiry
Form.io Enterprise license expires: **08/29/2025**