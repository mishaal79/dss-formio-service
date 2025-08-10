# Form.io Enterprise Deployment Guide

Simple deployment guide for Form.io Enterprise in the development environment.

## Prerequisites

### Required Software
- **Terraform** >= 1.6.0
- **Google Cloud SDK** (gcloud)
- **Git** access to both repositories:
  - `dss-formio-service` (this repository)
  - `gcp-dss-erlich-infra-terraform` (shared infrastructure)

### Required GCP Permissions
- Compute Engine Admin
- Cloud Run Admin  
- Secret Manager Admin
- Storage Admin
- IAM Admin
- VPC Network User (for shared infrastructure)

### Shared Infrastructure
Ensure the shared infrastructure is deployed first:

```bash
# In gcp-dss-erlich-infra-terraform repository
cd environments/dev
terraform init
terraform apply
```

This provides the VPC, subnets, and egress connectivity needed for Form.io licensing.

## Environment Configuration

### 1. Set Required Environment Variables

```bash
# Form.io Authentication Secrets
export TF_VAR_formio_root_password="SecureDevPassword123!"
export TF_VAR_formio_jwt_secret="dev-jwt-secret-64-chars-for-strong-encryption-and-security-test"
export TF_VAR_formio_db_secret="dev-db-secret-64-chars-for-strong-database-encryption-security"

# Form.io Enterprise License
export TF_VAR_formio_license_key="pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
export TF_VAR_formio_root_email="admin@example.com"

# MongoDB Authentication
export TF_VAR_mongodb_admin_password="SecureMongoAdminDev123!"
export TF_VAR_mongodb_formio_password="SecureMongoFormioUser123!"

# GCP Project Configuration
export TF_VAR_project_id="your-gcp-project-id"
```

### 2. Password Requirements

- **formio_root_password**: Minimum 8 characters
- **formio_jwt_secret**: Exactly 64 characters (alphanumeric only)
- **formio_db_secret**: Exactly 64 characters (alphanumeric only)
- **MongoDB passwords**: Minimum 8 characters with complexity

## Deployment Steps

### 1. Navigate to Dev Environment

```bash
cd terraform/environments/dev
```

### 2. Initialize Terraform

```bash
terraform init
```

This downloads required providers and initializes the backend.

### 3. Plan Deployment

```bash
terraform plan
```

Review the planned changes to ensure everything looks correct.

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

## Deployment Verification

### 1. Check Cloud Run Service

```bash
# Get the service URL from Terraform outputs
terraform output formio_enterprise_service_url
```

### 2. Verify MongoDB Connection

The MongoDB instance should be accessible from Cloud Run via private networking.

### 3. Test Form.io Access

1. Open the Cloud Run service URL in your browser
2. Log in using the root credentials:
   - Email: Value of `TF_VAR_formio_root_email`
   - Password: Value of `TF_VAR_formio_root_password`

### 4. Verify License

Check that the enterprise license is active by accessing enterprise features.

## Configuration Files

### terraform.tfvars (Optional)

Create `terraform.tfvars` for persistent configuration:

```hcl
# Project Configuration
project_id = "your-gcp-project-id"
region     = "us-central1"

# Form.io Configuration  
service_name      = "formio-api"
formio_version    = "9.5.0"
formio_root_email = "admin@example.com"

# MongoDB Configuration
mongodb_version       = "7.0"
mongodb_machine_type  = "e2-small"
mongodb_data_disk_size = 30

# Resource Configuration
max_instances  = 5
min_instances  = 0
cpu_request    = "1000m"
memory_request = "2Gi"
```

## Troubleshooting

### Common Issues

#### License Validation Fails
- **Symptom**: Form.io cannot validate enterprise license
- **Cause**: No internet access from Cloud Run
- **Fix**: Ensure shared infrastructure provides egress-enabled subnet

#### MongoDB Connection Fails
- **Symptom**: Form.io cannot connect to database
- **Cause**: Network connectivity or authentication issues
- **Fix**: Check VPC networking and Secret Manager secrets

#### Secrets Not Found
- **Symptom**: Terraform cannot find environment variables
- **Cause**: Environment variables not set correctly
- **Fix**: Re-export all required `TF_VAR_*` variables

### Logs and Monitoring

#### Cloud Run Logs
```bash
gcloud run services logs read formio-api-ent --region=us-central1
```

#### MongoDB Logs
```bash
gcloud compute ssh mongodb-dev --zone=us-central1-a
sudo journalctl -u mongod -f
```

## Cleanup

### Destroy Infrastructure

```bash
terraform destroy
```

**Warning**: This will delete all resources including the MongoDB instance and data.

### Selective Cleanup

To keep data but stop services:
```bash
# Stop Cloud Run service
gcloud run services update formio-api-ent --cpu=0 --region=us-central1

# Stop MongoDB instance  
gcloud compute instances stop mongodb-dev --zone=us-central1-a
```

## Security Considerations

### Secret Management
- All secrets stored in Google Secret Manager
- Environment variables only used during Terraform execution
- No secrets stored in Terraform state or version control

### Network Security
- MongoDB only accessible via private VPC
- Cloud Run uses shared VPC with controlled egress
- Firewall rules restrict traffic to required services

### Access Control
- Service accounts use minimal required permissions
- IAM policies follow principle of least privilege
- Regular audit of access permissions recommended

## Next Steps

After successful deployment:

1. **Configure Forms**: Create your first forms in the Form.io interface
2. **User Management**: Set up additional users and permissions
3. **Integration**: Connect forms to your applications
4. **Monitoring**: Set up alerts for service health
5. **Backup**: Implement regular MongoDB backups for production use