# DSS Form.io Service

Enterprise form management service deployed on Google Cloud Platform using Form.io, MongoDB Atlas, and central infrastructure resources.

## Quick Start

```bash
# Set up environment
cp .env.example .env
# Edit .env with your credentials

# Deploy infrastructure
make init           # Initialize Terraform
make plan           # Review changes
make apply          # Apply infrastructure

# Deploy applications
make deploy-ent     # Deploy Enterprise (uses Terraform's configured version)
make show-versions  # Compare configured vs deployed versions
```

## Architecture Overview

- **Form.io Editions**: Both Community (open-source) and Enterprise (licensed)
- **Database**: MongoDB Atlas Flex Cluster (managed, cost-effective)
- **Storage**: Google Cloud Storage for file uploads
- **Infrastructure**: Central VPC from `gcp-dss-erlich-infra-terraform`
- **Load Balancer**: Centralized architecture in central infrastructure project
- **Region**: australia-southeast1
- **Configuration**: Terraform as single source of truth (all values flow from Terraform → Makefile)

## Prerequisites

### Required Software
- **Terraform** >= 1.6.0
- **Google Cloud SDK** (gcloud authenticated)
- **Make** (for automation commands)
- **MongoDB Shell** (mongosh) for database operations

### Required Access
- GCP Project with enabled APIs (Cloud Run, Secret Manager, Storage)
- Form.io Enterprise License (expires: 08/29/2025)
- MongoDB Atlas account with API keys
- Access to central infrastructure repository (`gcp-dss-erlich-infra-terraform`)

### Required Permissions
- Cloud Run Admin
- Secret Manager Admin
- Storage Admin
- VPC Network User (for central infrastructure VPC)

## Environment Configuration

### 1. Create Environment File

```bash
cp .env.example .env
```

### 2. Configure Required Variables

```bash
# Form.io Configuration
export TF_VAR_formio_license_key="your-license-key"
export TF_VAR_formio_root_email="admin@domain.com"

# MongoDB Atlas Configuration
export MONGODB_ATLAS_PUBLIC_KEY="your-atlas-public-key"
export MONGODB_ATLAS_PRIVATE_KEY="your-atlas-private-key"
export TF_VAR_mongodb_atlas_org_id="your-atlas-org-id"

# GCP Project
export TF_VAR_project_id="your-gcp-project-id"
```

### 3. MongoDB Atlas Setup

1. Sign up at [cloud.mongodb.com](https://cloud.mongodb.com)
2. Create Organization and generate API keys
3. Set Role: "Organization Project Creator"
4. Add credentials to `.env` file

## Deployment Commands

### Infrastructure Management

```bash
make init          # Initialize Terraform
make plan          # Preview infrastructure changes
make apply         # Deploy infrastructure (MongoDB, storage, secrets)
make destroy       # Tear down infrastructure (with confirmation)
make check         # Run quality checks (format + lint)
make security      # Run security scans
```

### Application Deployment

```bash
# Deploy using Terraform's configured versions
make deploy-ent               # Deploy Enterprise with configured version
make deploy-com               # Deploy Community with configured version
make deploy-configured        # Deploy all enabled editions

# Deploy specific versions (override Terraform)
make deploy-ent IMG=formio/formio-enterprise:9.5.1
make deploy-com IMG=formio/formio:v4.6.0

# Version management
make show-versions           # Compare configured vs deployed versions

# Environment variable updates
make update-ent              # Update Enterprise env vars from Terraform
make update-com              # Update Community env vars from Terraform

# Traffic management
make traffic-ent-100         # Route 100% traffic to Enterprise latest
make traffic-com-100         # Route 100% traffic to Community latest
```

### Target Different Environments

```bash
# All commands support ENV variable
ENV=prod make plan           # Plan production changes
ENV=prod make apply          # Apply to production
ENV=prod make deploy-ent     # Deploy to production
ENV=prod make show-versions  # Show production versions
```

### Monitoring & Maintenance

```bash
make status              # Check deployment status
make show-versions       # Compare configured vs deployed versions
make logs-ent           # View Enterprise edition logs
make logs-com           # View Community edition logs
make atlas-status       # Show MongoDB Atlas status
make health-check       # Run comprehensive health check
make restart-services   # Restart services to pick up changes
```

## Project Structure

```
dss-formio-service/
├── Makefile                 # Deployment automation (reads from Terraform)
├── README.md               # This file
├── ARCHITECTURE.md         # Design decisions and rationale
├── CLAUDE.md              # AI assistant configuration
├── terraform/
│   ├── environments/       # Environment configurations
│   │   ├── dev/           # Development environment
│   │   │   ├── main.tf    # Dev infrastructure
│   │   │   ├── variables.tf # Configuration values (source of truth)
│   │   │   └── outputs.tf   # Exposes config for Makefile
│   │   └── prod/          # Production environment
│   └── modules/           # Reusable Terraform modules
│       ├── formio-service/    # Form.io Cloud Run deployment
│       ├── mongodb-atlas/     # MongoDB Atlas configuration
│       ├── secrets/           # Secret Manager setup
│       └── storage/           # GCS bucket configuration
├── scripts/               # Automation scripts
│   ├── health-check.sh   # Service health checks
│   ├── init-atlas-databases.sh  # MongoDB initialization
│   └── run-tests.sh      # Terraform test runner
└── local-testing/        # Local development setup
```

## Service Access

After deployment, access services at:

- **Community Edition**: `https://dss-formio-com-dev-*.run.app`
- **Enterprise Edition**: `https://dss-formio-ent-dev-*.run.app`

Default credentials:
- Email: Configured via `TF_VAR_formio_root_email`
- Password: Auto-generated in Secret Manager

## Database Architecture

### MongoDB Atlas Configuration
- **Provider**: GCP (australia-southeast2)
- **Cluster Type**: Flex (M0 equivalent, cost-effective)
- **Databases**:
  - `formio_community` - Community edition data
  - `formio_enterprise` - Enterprise edition data
- **Backup**: Daily automated backups
- **Security**: TLS encryption + credential authentication

### Connection Security
- Connection strings stored in Secret Manager
- Automatic password rotation support
- Network access: Open (0.0.0.0/0) with TLS + auth

## Central Infrastructure Integration

This service integrates with the central infrastructure project (`gcp-dss-erlich-infra-terraform`) which provides:
- VPC networking and subnets
- Centralized load balancer
- DNS zones
- Cloud NAT for egress

### Integration Steps

1. **Deploy this service** to create backend services:
   ```bash
   make init
   make plan
   make apply
   ```

2. **Note the backend service ID** from outputs:
   ```bash
   cd terraform/environments/dev
   terraform output backend_service_configuration
   ```

3. **Update central infrastructure** `terraform.tfvars`:
   ```hcl
   lb_host_rules = {
     "forms.dev.cloud.dsselectrical.com.au" = {
       backend_service_id = "projects/PROJECT_ID/global/backendServices/formio-backend-dev"
     }
   }
   ```

4. **Apply central infrastructure** to activate routing:
   ```bash
   cd ../gcp-dss-erlich-infra-terraform/environments/dev
   terraform apply
   ```

### Why Manual Configuration?

This architecture uses deliberate tfvars configuration rather than automatic remote state consumption to:
- Avoid circular dependencies between projects
- Maintain explicit configuration control
- Enable stable production deployments
- Support automation via CI/CD pipelines

## Security Features

- **Secret Management**: All sensitive data in GCP Secret Manager
- **TLS Encryption**: Enforced for all connections
- **Authentication**: Form.io built-in auth with JWT tokens
- **Network Security**: Private VPC with controlled egress
- **Compliance**: PCI-DSS scope considerations

## Form.io Portal File Storage Configuration

### S3-Compatible Storage (GCS)

Form.io file uploads are configured to use Google Cloud Storage via S3-compatible API. The infrastructure is automatically provisioned by Terraform, but the Form.io portal requires manual configuration.

#### Critical Configuration Requirement

⚠️ **IMPORTANT**: You MUST enable "Use MinIO Server" in the Form.io portal for GCS S3-compatible storage to work correctly. This is a PORTAL configuration, NOT a server environment variable configuration.

#### Portal Configuration Steps

1. **Navigate to Form.io Portal**
   - Go to your project settings
   - Select "Settings" → "Integrations" → "File Storage"
   - Select the "S3" tab

2. **Enable MinIO Mode (CRITICAL)**
   - ✅ **CHECK "Use MinIO Server"** - This enables S3-compatible storage for non-AWS providers
   - This changes URL generation from AWS virtual-hosted-style to path-style URLs

3. **Retrieve Credentials from Secret Manager**
   ```bash
   # Get Access Key ID
   gcloud secrets versions access latest \
     --secret="dss-formio-api-ent-gcs-s3-key-dev" \
     --project=erlich-dev

   # Get Secret Access Key
   gcloud secrets versions access latest \
     --secret="dss-formio-api-ent-gcs-s3-secret-dev" \
     --project=erlich-dev
   ```

4. **Enter Configuration Values**
   - **MinIO Server URL**: `https://storage.googleapis.com`
   - **Access Key ID**: (Retrieved from Secret Manager)
   - **Secret Access Key**: (Retrieved from Secret Manager)
   - **Bucket Name**: `erlich-dev-formio-storage-dev-g004azjs`
   - **Bucket Region**: Leave empty or use `auto`
   - **Starts With (Folder)**: `ent/dev/uploads/` (for Enterprise) or `pdf/dev/uploads/` (for PDF server)

5. **Optional Settings**
   - **Access Control List**: `private` (recommended) or `public-read`
   - **Max File Size**: `104857600` (100MB in bytes)
   - **Policy Expiration**: `3600` (1 hour in seconds)
   - **Enable S3 Multipart**: Yes (for large file uploads)

#### How It Works

When "Use MinIO Server" is enabled:
- Server responds with `"minio":true` in storage requests
- Generates path-style URLs: `https://storage.googleapis.com/bucket/path`
- Compatible with GCS S3-compatible API

When NOT enabled (default):
- Server responds with `"minio":false`
- Generates AWS virtual-hosted-style URLs: `bucket.s3.region.amazonaws.com`
- Does NOT work with GCS

#### Common Mistakes to Avoid

❌ **DO NOT add these environment variables** (they are incorrect and not in documentation):
- `FORMIO_S3_ENDPOINT` - This is NOT a valid Form.io environment variable
- `FORMIO_S3_FORCE_PATH_STYLE` - This is NOT a valid Form.io environment variable

❌ **DO NOT change** `FORMIO_S3_REGION` from `auto` to actual GCS region like `australia-southeast1`
- Google Cloud documentation specifies using `auto` for S3-compatible API

❌ **DO NOT forget** to check "Use MinIO Server" in portal
- Without this, Form.io will generate AWS-style URLs that don't work with GCS

#### Troubleshooting

1. **Verify MinIO Mode is Enabled**
   ```bash
   # Test the storage endpoint
   curl 'https://your-formio-service.run.app/project/YOUR_PROJECT_ID/form/YOUR_FORM_ID/storage/s3' \
     -H 'x-jwt-token: YOUR_JWT_TOKEN' \
     --data-raw '{"name":"test.txt","size":100,"type":"text/plain"}'
   ```
   
   Look for `"minio":true` in the response. If it shows `"minio":false`, the MinIO mode is not enabled in portal.

2. **Check Presigned URL Format**
   - ✅ Correct (MinIO mode): `https://storage.googleapis.com/bucket-name/path/to/file?...`
   - ❌ Wrong (AWS mode): `https://bucket-name.s3.auto.amazonaws.com/path/to/file?...`

3. **Server Environment Variables** (already configured by Terraform)
   - `FORMIO_S3_SERVER=https://storage.googleapis.com`
   - `FORMIO_S3_BUCKET=bucket-name`
   - `FORMIO_S3_REGION=auto`
   - `FORMIO_S3_KEY` and `FORMIO_S3_SECRET` from Secret Manager

#### Important Notes

- The solution is primarily in the PORTAL configuration, not server environment variables
- Credentials are stored in Google Secret Manager and should never be committed to code
- Region must be `auto` as documented in [Google Cloud S3 migration guide](https://cloud.google.com/storage/docs/aws-simple-migration)

## Configuration Management

### Single Source of Truth

This project follows the DRY (Don't Repeat Yourself) principle with Terraform as the single source of truth:

1. **All configuration originates in Terraform** (`terraform/environments/*/variables.tf`)
2. **Terraform outputs expose configuration** (`terraform/environments/*/outputs.tf`)
3. **Makefile dynamically reads from Terraform** (no hardcoded values)
4. **gcloud commands use Terraform-provided values**

Example flow:
```
Terraform variables → Terraform outputs → Makefile reads → gcloud uses
```

This ensures:
- No configuration duplication
- Consistent values across all tools
- Single place to update configuration
- Environment-specific overrides work correctly

## Testing

```bash
make test          # Run Terraform tests
make check         # Run quality checks (format + lint)
make security      # Run security scans
```

Test coverage includes:
- Module validation
- License key verification
- Environment configuration
- Service health checks

## Troubleshooting

### Common Issues

1. **MongoDB Connection Failed**
   ```bash
   # Check Atlas cluster status
   make logs-com | grep mongo
   # Verify connection string in Secret Manager
   ```

2. **License Validation Error**
   ```bash
   # Ensure internet egress for license.form.io
   # Check Cloud NAT configuration
   ```

3. **Service Unhealthy**
   ```bash
   make status
   make logs-ent | grep error
   ```

### Debug Commands

```bash
# Check service details
gcloud run services describe dss-formio-com-dev --region=australia-southeast1

# View secret values (carefully)
gcloud secrets versions access latest --secret=formio-root-password

# MongoDB connection test
mongosh "mongodb+srv://cluster-url" --username admin
```

## Maintenance

### Regular Tasks

- **License Renewal**: Enterprise license expires 08/29/2025
- **Security Updates**: Update Form.io images monthly
- **Backup Verification**: Test MongoDB restore quarterly
- **Cost Review**: Monitor Atlas and Cloud Run usage

### Upgrade Procedure

1. Test new version in dev environment
2. Update image tag in deployment command
3. Run health checks
4. Monitor logs for errors
5. Roll back if issues detected

## Cost Optimization

- **MongoDB Atlas Flex**: ~$9/month (vs $57 for M10)
- **Cloud Run**: Scales to zero when idle
- **Storage**: Lifecycle policies for old files
- **Networking**: Shared infrastructure reduces costs

## Support

- **Form.io Documentation**: [docs.form.io](https://docs.form.io)
- **MongoDB Atlas**: [docs.atlas.mongodb.com](https://docs.atlas.mongodb.com)
- **GCP Cloud Run**: [cloud.google.com/run/docs](https://cloud.google.com/run/docs)
- **Internal**: Contact platform-team@dss.com

## License

Form.io Enterprise License: `pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt`
- Expires: August 29, 2025
- Tier: Developer (25 users)
- Projects: Unlimited

---
Last Updated: 2025