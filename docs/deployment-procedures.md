# Deployment Procedures - Form.io Dual Edition Setup

## Overview
This document provides step-by-step procedures for deploying both Form.io Community and Enterprise editions simultaneously with a shared MongoDB instance.

## Prerequisites

### Required Software
- Terraform >= 1.0
- Google Cloud SDK
- Access to GCP project with appropriate permissions

### Required Permissions
- Compute Engine Admin
- Cloud Run Admin  
- Secret Manager Admin
- Storage Admin
- IAM Admin
- VPC Network Admin

## Dual Deployment Architecture

The system deploys two Form.io services:
- **Community Edition**: `formio-api-community-dev` (uses `formio/formio:v4.6.0-rc.3`)
- **Enterprise Edition**: `formio-api-enterprise-dev` (uses `formio/formio-enterprise:9.5.0`)

Both editions share:
- Single MongoDB instance with separate databases (`formio_community`, `formio_enterprise`)
- Shared Google Cloud Storage bucket with different paths
- Same Secret Manager secrets for authentication

## Environment Variable Setup

### Required Environment Variables

```bash
# Form.io Authentication Secrets
export TF_VAR_formio_root_password="SecureDevPassword123!"
export TF_VAR_formio_jwt_secret="dev-jwt-secret-64-chars-for-strong-encryption-and-security-test"
export TF_VAR_formio_db_secret="dev-db-secret-64-chars-for-strong-database-encryption-security"

# MongoDB Authentication
export TF_VAR_mongodb_admin_password="SecureMongoAdminDev123!"
export TF_VAR_mongodb_formio_password="SecureMongoFormioUser123!"
```

### Security Requirements

**Password Complexity:**
- `formio_root_password`: Minimum 8 characters
- `formio_jwt_secret`: Minimum 64 characters (no special characters)
- `formio_db_secret`: Minimum 64 characters
- MongoDB passwords: Minimum 8 characters with complexity

**Production Recommendations:**
- Use secrets stored in external secret management systems
- Rotate passwords regularly
- Use unique passwords per environment

## Deployment Steps

### 1. Environment Configuration

Update deployment flags in `terraform/environments/dev/terraform.tfvars`:

```hcl
# Enable both editions
deploy_community  = true
deploy_enterprise = true

# Version configuration
formio_version     = "9.5.0"           # Enterprise
community_version  = "v4.6.0-rc.3"     # Community

# Service naming (must be short for SA names)
service_name = "formio-api"
```

### 2. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 3. Set Environment Variables

```bash
# Set all required secrets
export TF_VAR_formio_root_password="your-secure-root-password"
export TF_VAR_formio_jwt_secret="your-64-character-jwt-secret-for-token-validation-and-signing"
export TF_VAR_formio_db_secret="your-64-character-database-encryption-secret-for-field-security"
export TF_VAR_mongodb_admin_password="your-secure-mongodb-admin-password"
export TF_VAR_mongodb_formio_password="your-secure-mongodb-formio-password"
```

### 4. Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars" -compact-warnings
```

### 5. Deploy Infrastructure

```bash
terraform apply -var-file="terraform.tfvars"
```

## Expected Infrastructure

### Cloud Run Services
- `dss-formio-api-com-dev` - Community edition service
- `dss-formio-api-ent-dev` - Enterprise edition service

### MongoDB Setup
- Single Compute Engine instance running MongoDB 7.0
- Two databases: `formio_com`, `formio_ent`
- Separate connection strings in Secret Manager

### Service Accounts
- `dss-formio-api-com-sa-dev` (25 chars) - Community service account
- `dss-formio-api-ent-sa-dev` (25 chars) - Enterprise service account

### Secret Manager Secrets
- `dss-formio-api-root-password-dev`
- `dss-formio-api-jwt-secret-dev`
- `dss-formio-api-db-secret-dev`
- `dss-formio-api-mongodb-admin-password-dev`
- `dss-formio-api-mongodb-formio-password-dev`
- `dss-formio-api-mongodb-community-connection-string-dev`
- `dss-formio-api-mongodb-enterprise-connection-string-dev`

## Configuration Differences

### Community Edition
- Image: `formio/formio:v4.6.0-rc.3`
- Database: `formio_com`
- Storage path: `com/dev/uploads`
- No license key required

### Enterprise Edition
- Image: `formio/formio-enterprise:9.5.0`
- Database: `formio_ent`
- Storage path: `ent/dev/uploads`
- License key required (from NOTES.md)

## Validation Steps

### 1. Check Service Status
```bash
# List Cloud Run services
gcloud run services list --region=australia-southeast1

# Check service health
curl https://dss-formio-api-com-dev-<hash>-as.a.run.app/health
curl https://dss-formio-api-ent-dev-<hash>-as.a.run.app/health
```

### 2. Verify MongoDB Connection
```bash
# SSH to MongoDB instance
gcloud compute ssh formio-mongodb-dev --zone=australia-southeast1-a

# Check databases exist
mongo -u mongoAdmin -p
> show databases
```

### 3. Test Form Creation
- Access Community: `https://dss-formio-api-com-dev-<hash>-as.a.run.app`
- Access Enterprise: `https://dss-formio-api-ent-dev-<hash>-as.a.run.app`
- Login with root credentials
- Create test forms in each edition

## Troubleshooting

### Common Issues

**Service Account Name Too Long**
- Service names use abbreviated editions: `ent` (enterprise), `com` (community)  
- Format: `{service_name}-{edition_abbrev}-sa-{env}` must be ≤30 chars
- Example: `dss-formio-api-ent-sa-dev` (25 chars) ✅

**Secret Not Found Errors**
- Verify all environment variables are set
- Check secret naming matches service_name pattern
- Ensure secrets exist in Secret Manager

**MongoDB Connection Issues**
- Verify VPC connectivity
- Check firewall rules allow port 27017
- Confirm MongoDB service is running

**Existing Resource Conflicts**
- Previous deployments may conflict with naming
- Consider destroying and recreating for clean state
- Or update naming conventions to avoid conflicts

## Security Considerations

1. **Enhanced Secret Management**: 
   - Write-only secrets using `secret_data_wo` prevent secrets from being stored in Terraform state
   - Cryptographically secure password generation using `random_password`
   - All sensitive data stored in Google Secret Manager with automatic encryption
2. **Network Isolation**: MongoDB in private subnet, accessed via VPC connector
3. **IAM Least Privilege**: 
   - Module-level IAM bindings for specific secrets only
   - Each service has access only to the secrets it needs
   - No project-wide secret accessor roles
4. **Encryption**: All data encrypted at rest and in transit
5. **Audit Logging**: All secret access logged for compliance

## Cost Optimization

- MongoDB runs on e2-small (cost-effective for dev)
- Cloud Run scales to zero when not in use
- Shared storage and networking resources
- Estimated monthly cost: <$100 for dev environment

## Environment-Specific Notes

### Development
- Reduced instance sizes for cost savings
- No load balancer or custom domains
- Basic monitoring and alerting
- 7-day backup retention

### Production Recommendations
- Increase MongoDB instance size (e2-medium or higher)
- Add custom domains and SSL certificates
- Enhanced monitoring and alerting
- 30-day backup retention
- Multi-zone deployment for high availability