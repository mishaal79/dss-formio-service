# Deployment Procedures Runbook

This runbook provides step-by-step procedures for deploying and managing the DSS Form.io Service infrastructure.

## Prerequisites

### Required Tools
- Terraform >= 1.6.0
- Google Cloud SDK
- TFLint (for quality checks)
- Pre-commit (optional, for automated quality gates)

### Authentication
```bash
# Authenticate with Google Cloud
gcloud auth application-default login

# Set project context
gcloud config set project YOUR_PROJECT_ID

# Verify authentication
gcloud auth list
```

### Environment Variables
```bash
# Set required secrets (store securely, never commit)
export TF_VAR_formio_root_password="your-secure-password"
export TF_VAR_formio_jwt_secret="your-jwt-secret-64-chars-minimum"
export TF_VAR_formio_db_secret="your-db-secret-64-chars-minimum"
```

## Development Environment Deployment

### 1. Initialize Development Environment
```bash
cd terraform/environments/dev
terraform init
```

### 2. Review Configuration
```bash
# Review variables
cat terraform.tfvars

# Update project ID and other environment-specific values
vi terraform.tfvars
```

### 3. Quality Checks
```bash
# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Run TFLint (optional)
tflint --config=../../../.tflint.hcl
```

### 4. Plan Deployment
```bash
# Generate execution plan
terraform plan -var-file=terraform.tfvars -out=dev.tfplan

# Review the plan carefully
# Look for expected resources and no unexpected deletions
```

### 5. Deploy Infrastructure
```bash
# Apply the plan
terraform apply dev.tfplan

# Verify deployment
terraform show
```

### 6. Validate Deployment
```bash
# Check outputs
terraform output

# Test Form.io service
curl -f $(terraform output -raw formio_service_url)/health
```

## Staging Environment Deployment

### 1. Prerequisites
- Development environment successfully deployed
- Staging-specific configurations reviewed
- Staging secrets configured

### 2. Deploy Staging
```bash
cd terraform/environments/staging
terraform init
terraform plan -var-file=terraform.tfvars -out=staging.tfplan
terraform apply staging.tfplan
```

### 3. Integration Testing
```bash
# Run integration tests
cd ../../../
terraform test tests/integration/staging_environment.tftest.hcl
```

## Production Environment Deployment

### 1. Pre-Production Checklist
- [ ] Development and staging environments stable
- [ ] All tests passing
- [ ] Security review completed
- [ ] Change management approval obtained
- [ ] Backup procedures validated
- [ ] Rollback plan prepared

### 2. Production Deployment
```bash
cd terraform/environments/prod
terraform init

# Extra validation for production
terraform plan -var-file=terraform.tfvars -detailed-exitcode
if [ $? -eq 2 ]; then
  echo "Changes detected, proceeding with deployment"
  terraform apply -var-file=terraform.tfvars
else
  echo "No changes to apply"
fi
```

### 3. Post-Deployment Validation
```bash
# Verify all services are healthy
curl -f $(terraform output -raw formio_service_url)/health

# Check monitoring and alerting
# Verify logs are flowing correctly
# Test key functionality
```

## Environment Updates

### Standard Update Process
```bash
# 1. Review changes
git diff HEAD~1

# 2. Run quality checks
terraform fmt -recursive
terraform validate
tflint --config=../../.tflint.hcl

# 3. Test changes
terraform test

# 4. Plan and apply
terraform plan -var-file=terraform.tfvars -out=update.tfplan
terraform apply update.tfplan

# 5. Validate
terraform output
```

### Emergency Updates
For critical security or operational issues:

```bash
# 1. Skip non-critical quality checks if needed
terraform validate  # Always validate

# 2. Plan with lock timeout for urgent changes
terraform plan -var-file=terraform.tfvars -lock-timeout=5m

# 3. Apply with shorter timeout
terraform apply -lock-timeout=10m

# 4. Immediate validation
curl -f $(terraform output -raw formio_service_url)/health
```

## Rollback Procedures

### Infrastructure Rollback
```bash
# 1. Identify the last good state
terraform state list

# 2. Plan rollback to previous configuration
git checkout PREVIOUS_GOOD_COMMIT
terraform plan -var-file=terraform.tfvars -out=rollback.tfplan

# 3. Execute rollback
terraform apply rollback.tfplan

# 4. Validate rollback
terraform output
curl -f $(terraform output -raw formio_service_url)/health
```

### Application Rollback
```bash
# If only application needs rollback (not infrastructure)
# Update image version in terraform.tfvars
formio_version = "9.4.0"  # Previous version

# Apply the change
terraform plan -var-file=terraform.tfvars -target=module.formio_service.module.cloud_run
terraform apply -target=module.formio_service.module.cloud_run
```

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock
```bash
# Check for stale locks
terraform force-unlock LOCK_ID

# Prevention: Always use lock-timeout
terraform plan -lock-timeout=10m
```

#### 2. Authentication Issues
```bash
# Re-authenticate
gcloud auth application-default login

# Check project configuration
gcloud config list

# Verify permissions
gcloud projects get-iam-policy PROJECT_ID
```

#### 3. Resource Already Exists
```bash
# Import existing resource
terraform import google_cloud_run_v2_service.formio_service \
  projects/PROJECT_ID/locations/REGION/services/SERVICE_NAME

# Or use random suffix for uniqueness
```

#### 4. License Issues
```bash
# Verify license in Secret Manager
gcloud secrets versions access latest --secret="formio-license-key-ENV"

# Check Cloud Run logs for license errors
gcloud logs read "resource.type=cloud_run_revision" --limit=50
```

### Emergency Contacts
- **Infrastructure Team**: infrastructure@qrius.global
- **Form.io Support**: Enterprise support channel
- **GCP Support**: Enterprise support case system

## Monitoring and Alerts

### Health Checks
```bash
# Form.io service health
curl -f $(terraform output -raw formio_service_url)/health

# Database connectivity
curl -f $(terraform output -raw formio_service_url)/api/health/db

# License status
curl -f $(terraform output -raw formio_service_url)/api/health/license
```

### Log Monitoring
```bash
# View recent logs
gcloud logs read "resource.type=cloud_run_revision" --limit=100

# Follow logs in real-time
gcloud logs tail "resource.type=cloud_run_revision"

# Search for errors
gcloud logs read "resource.type=cloud_run_revision AND severity>=ERROR"
```

### Performance Monitoring
- Monitor Cloud Run metrics in GCP Console
- Check Form.io admin dashboard for application metrics
- Review cost reports for unexpected charges

## Maintenance Procedures

### Regular Maintenance
- **Weekly**: Review logs and performance metrics
- **Monthly**: Update Terraform and provider versions
- **Quarterly**: Review and renew certificates
- **Annually**: Review license and cost optimization

### Security Updates
```bash
# Update base images
formio_version = "9.5.1"  # New version

# Update Terraform providers
terraform init -upgrade

# Apply security updates
terraform plan -var-file=terraform.tfvars
terraform apply
```

## Backup and Recovery

### Configuration Backup
```bash
# Backup Terraform state
gsutil cp gs://terraform-state-bucket/environments/prod/default.tfstate \
  backup/prod-state-$(date +%Y%m%d).tfstate

# Backup configuration
git tag -a prod-v1.0 -m "Production deployment v1.0"
git push origin prod-v1.0
```

### Data Recovery
- Form.io data is stored in MongoDB Atlas with automated backups
- Application configurations are in Secret Manager with versioning
- Infrastructure state is in versioned GCS bucket

## Documentation Updates

After any significant changes:
1. Update this runbook with new procedures
2. Update architecture documentation
3. Create/update ADRs for significant decisions
4. Update README with new requirements or procedures

## References
- [Form.io Enterprise Documentation](https://help.form.io/deployments/form.io-enterprise-server)
- [Terraform Best Practices](https://www.terraform.io/docs/extend/best-practices/index.html)
- [GCP Operations Documentation](https://cloud.google.com/docs/operations)