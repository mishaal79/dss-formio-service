# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Deployment Pattern

**Infrastructure (Terraform)**: VPC, databases, secrets, service definitions
**Applications (gcloud)**: Container deployments, traffic management, scaling

## Essential Commands

### Infrastructure Management
- **Setup**: `make dev-setup` → `make infra-apply`
- **Plan**: `make infra-plan`
- **Apply**: `make infra-apply` 
- **Test**: `make test` (mock validation)
- **Format**: `make format`

### Application Deployment  
- **Deploy Community**: `make deploy-com IMG=formio/formio:v4.6.0`
- **Deploy Enterprise**: `make deploy-ent IMG=formio/formio-enterprise:9.5.1`
- **Deploy Both**: `make deploy-all`
- **Route Traffic**: `make traffic-com-100` or `make traffic-ent-100`

### Monitoring
- **Status**: `make status`
- **Logs**: `make logs-com` or `make logs-ent`

## Architecture

**Form.io Enterprise on GCP:**
- **App**: Cloud Run services (2 editions: community + enterprise)
- **DB**: Self-hosted MongoDB on Compute Engine
- **Storage**: GCS buckets for file uploads
- **Secrets**: Auto-generated passwords in Secret Manager
- **Network**: Shared VPC from `gcp-dss-erlich-infra-terraform`
- **Region**: australia-southeast1

## Environment Setup

**Required variables** (set in `.env`):
```bash
export TF_VAR_formio_license_key="license-key-here"
export TF_VAR_formio_root_email="admin@domain.com"
```

## Key Files

- **`Makefile`**: Deployment automation with separation of concerns
- **`terraform/secrets.tf`**: Auto-generates secure passwords
- **`terraform/environments/dev/`**: Dev environment configuration
- **`.tflint.hcl`**: Terraform linting and naming rules
- **`scripts/run-tests.sh`**: Terraform testing framework

## Deployment Workflow

1. **Infrastructure**: `make infra-plan` → `make infra-apply` (one-time)
2. **Applications**: `make deploy-all IMG=new-version` (frequent)
3. **Testing**: `make test` before changes
4. **Monitoring**: `make status` and `make logs-*` for troubleshooting

**License expires**: 08/29/2025