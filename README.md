# DSS Form.io Service - Infrastructure as Code

Terraform modules for deploying Form.io services to Google Cloud Platform.

## Overview

This repository contains production-ready Terraform modules for deploying
Form.io services and related infrastructure on GCP Cloud Run.

## Git-Subrepo Management

This directory is managed as a git-subrepo linked to
`mishaal79/dss-formio-service`.

### Quick Reference

**Push local changes to fork**:

```bash
HUSKY=0 git subrepo push dss-formio-service -b main
```

**Pull changes from fork**:

```bash
HUSKY=0 git subrepo pull dss-formio-service
```

**Check status**:

```bash
git subrepo status dss-formio-service
```

> **Note**: Use `HUSKY=0` prefix to bypass commit-msg hooks that conflict with
> git-subrepo's commit message format.

### Development Workflow

1. **Make changes** in monorepo: `dss-formio-service/`
2. **Test changes**:
   ```bash
   cd dss-formio-service/terraform/environments/dev
   terraform init
   terraform plan
   ```
3. **Commit in monorepo**:
   ```bash
   git add dss-formio-service/
   git commit -m "feat(monorepo): add new Cloud Run service"
   ```
4. **Push to fork**:
   ```bash
   HUSKY=0 git subrepo push dss-formio-service -b main
   ```

### Fork Repository

- **Remote**: `git@github.com:mishaal79/dss-formio-service.git`
- **Branch**: `main`
- **Visibility**: Private

## Directory Structure

```
dss-formio-service/
├── terraform/
│   ├── environments/
│   │   ├── dev/                    # Development environment
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── terraform.tf
│   │   │   └── terraform.tfvars.example
│   │   ├── prod/                   # Production environment
│   │   └── production/             # Alternative production config
│   │
│   └── modules/
│       ├── formio-service/         # Main Form.io server deployment
│       ├── form-web-bff/           # Backend-for-Frontend service
│       ├── cloud-run/              # Reusable Cloud Run module
│       ├── formio-community-service/  # Community edition
│       ├── formio-custom-service/  # Enterprise edition
│       ├── mongodb-atlas/          # MongoDB Atlas integration
│       ├── pdf-server/             # PDF generation service
│       └── storage/                # GCS bucket management
│
├── tests/
│   ├── unit/                       # Terraform unit tests
│   └── integration/                # Integration tests
│
├── docs/
│   ├── PRD_FORM_WEB_BFF_MODULE.md # Module requirements
│   └── ANALYSIS_SUMMARY.md         # Technical analysis
│
├── .gitignore                      # Terraform artifacts exclusion
├── .tflint.hcl                     # Linting configuration
├── .pre-commit-config.yaml         # Pre-commit hooks
└── Makefile                        # Operational commands
```

## Quick Start

### Prerequisites

- Terraform >= 1.5.0
- GCP account with billing enabled
- gcloud CLI configured
- Service account with appropriate permissions

### Local Development

1. **Initialize Terraform**:

   ```bash
   cd terraform/environments/dev
   terraform init
   ```

2. **Create tfvars file**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GCP project details
   ```

3. **Plan deployment**:

   ```bash
   terraform plan
   ```

4. **Apply changes**:
   ```bash
   terraform apply
   ```

### Environment Variables

Required for deployment:

- `GCP_PROJECT_ID` - Google Cloud project ID
- `GCP_REGION` - Deployment region (e.g., `us-central1`)
- `MONGODB_URI` - MongoDB connection string
- `JWT_SECRET` - Form.io JWT secret
- `DB_SECRET` - Form.io database encryption secret

See `terraform/environments/dev/terraform.tfvars.example` for complete list.

## Modules

### formio-service

Main Form.io server deployment on Cloud Run.

**Features**:

- Autoscaling (1-10 instances)
- VPC connector integration
- Secret Manager integration
- Cloud SQL (PostgreSQL) support

### form-web-bff

Backend-for-Frontend service for SPA applications.

**Features**:

- Configurable ports (default: 3001)
- CORS handling
- API gateway patterns
- Load balancing

### cloud-run

Reusable Cloud Run service module.

**Features**:

- Container deployment
- Environment variable management
- IAM role binding
- Health checks
- Traffic splitting

## Testing

### Unit Tests

```bash
cd tests/unit
terraform test
```

### Integration Tests

```bash
cd tests/integration
terraform test
```

### Manual Validation

```bash
make plan ENV=dev
make validate ENV=dev
```

## Deployment

### Development Environment

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

### Production Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Maintenance

### Updating Modules

1. Make changes in `terraform/modules/`
2. Update version tags if using registry
3. Test in dev environment
4. Deploy to production

### Terraform State

State is stored in GCS bucket (configured in `terraform.tf`).

**State locking**: Enabled via GCS backend

**State backup**: Automatic via GCS versioning

## Troubleshooting

### Common Issues

**Issue**: Terraform provider download fails **Solution**: Run
`terraform providers lock` to regenerate lock file

**Issue**: Permission denied on GCS bucket **Solution**: Check service account
has `roles/storage.objectAdmin`

**Issue**: Cloud Run deployment timeout **Solution**: Increase `timeout_seconds`
in module configuration

### Debugging

Enable detailed logging:

```bash
export TF_LOG=DEBUG
terraform plan
```

Check Cloud Run logs:

```bash
gcloud logging read "resource.type=cloud_run_revision" --limit 50
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in monorepo root.

## License

See [LICENSE](../LICENSE) in monorepo root.

---

**Maintained By**: Qrius Global **Pattern**: Git-subrepo managed infrastructure
**Last Updated**: 2025-11-07
