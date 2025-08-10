# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Workflow

**Standard Change Process:**
1. **Format** → `terraform fmt -recursive .`
2. **Lint** → `tflint --config=.tflint.hcl --recursive` 
3. **Test** → `./scripts/run-tests.sh mock` (cost-free validation)
4. **Plan** → `cd terraform/environments/dev && terraform plan`
5. **Apply** → `terraform apply`

## Essential Commands

### Testing
- **All tests**: `./scripts/run-tests.sh` 
- **Mock only**: `./scripts/run-tests.sh mock` (fmt, validate, lint, security)
- **Unit tests**: `terraform test tests/unit/*.tftest.hcl`
- **Single test**: `terraform test path/to/test.tftest.hcl`

### Development
- **Environment setup**: `cp .env.example .env` → edit license key + email → `source .env`
- **Init**: `cd terraform/environments/dev && terraform init`
- **Validate**: `terraform validate` 
- **Format**: `terraform fmt -recursive .`
- **Lint**: `tflint --config=.tflint.hcl --recursive`

## Architecture

**Form.io Enterprise on GCP:**
- **App**: Cloud Run (formio/formio-enterprise:9.5.1-rc.10, formio/formio:rc)
- **DB**: Self-hosted MongoDB on Compute Engine
- **Storage**: GCS for file uploads
- **Secrets**: Auto-generated via Terraform → Secret Manager (NO manual passwords)
- **Network**: Shared VPC from gcp-dss-erlich-infra-terraform
- **Region**: australia-southeast1

## Key Patterns

### Security
- **Auto-generated secrets**: All passwords created by `terraform/secrets.tf`
- **Secret Manager integration**: Never hardcode credentials
- **Only 2 env vars required**: license key + root email

### Environment Variables (.env)
```bash
export TF_VAR_formio_license_key="license-here"
export TF_VAR_formio_root_email="admin@domain.com" 
# Project defaults to "erlich-dev" (override with TF_VAR_project_id if needed)
```

### Naming Conventions
- **Terraform resources**: snake_case (enforced by TFLint)
- **Modules**: kebab-case 
- **GCP resources**: `{project}-{service}-{component}-{env}` pattern
- **Validation**: `.tflint.hcl` enforces naming rules

### Testing
- **Use Terraform native testing**: `.tftest.hcl` files in `tests/`
- **Plan-only tests**: No real resources created
- **3 test levels**: mock (free) → unit → integration

## Critical Files

- **`.tflint.hcl`**: Naming convention enforcement + security rules
- **`terraform/secrets.tf`**: Auto-generates all passwords securely  
- **`terraform/environments/dev/`**: Dev environment config with erlich-dev defaults
- **`scripts/run-tests.sh`**: Comprehensive test runner
- **`.env.example`**: Template for required environment variables

## Shared Infrastructure

**Dependencies**: Requires `gcp-dss-erlich-infra-terraform` for:
- VPC network + egress subnet (for Form.io license validation)
- VPC connector for Cloud Run → MongoDB connectivity

**Remote state**: `dss-org-tf-state` GCS bucket, `erlich/dev` prefix

## Form.io License

**Enterprise license expires**: 08/29/2025
**License validation**: Requires internet access via shared egress subnet