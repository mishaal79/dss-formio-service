# DSS Form.io Enterprise Service

A simple Form.io Enterprise deployment on Google Cloud Platform using Cloud Run, MongoDB, and shared infrastructure.

## Quick Start

Deploy Form.io Enterprise in the dev environment:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## Architecture

- **Form.io Enterprise**: Cloud Run service with enterprise license
- **Database**: Self-hosted MongoDB on Compute Engine  
- **Storage**: Google Cloud Storage for file uploads
- **Networking**: Shared VPC with internet egress for license validation

## Prerequisites

1. **GCP Project** with enabled APIs (Compute, Cloud Run, Secret Manager, Storage)
2. **Form.io Enterprise License** (expires 08/29/2025)
3. **Terraform** >= 1.6.0
4. **Access** to shared infrastructure (`gcp-dss-erlich-infra-terraform`)

## Environment Variables

Set required secrets before deployment:

```bash
export TF_VAR_formio_root_password="SecurePassword123!"
export TF_VAR_formio_jwt_secret="your-64-character-jwt-secret-string-for-token-validation"
export TF_VAR_formio_db_secret="your-64-character-database-encryption-secret-string"
export TF_VAR_formio_license_key="pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
export TF_VAR_mongodb_admin_password="SecureMongoAdmin123!"
export TF_VAR_mongodb_formio_password="SecureMongoFormio123!"
```

## Configuration

Key configuration files:
- `terraform/environments/dev/terraform.tfvars` - Environment settings
- `terraform/variables.tf` - Variable definitions
- `.tflint.hcl` - Terraform linting rules

## Access

After deployment, access Form.io at the Cloud Run service URL provided in Terraform outputs.

## Documentation

- [Architecture Overview](docs/architecture.md) - System design and components
- [Deployment Guide](docs/deployment-procedures.md) - Detailed deployment steps
- [Enterprise License](docs/enterprise-configuration.md) - License management

## License

Form.io Enterprise license expires **08/29/2025**. See [NOTES.md](NOTES.md) for license details.