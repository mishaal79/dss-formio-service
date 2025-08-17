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

### MongoDB Atlas Management
- **Atlas Console**: `https://cloud.mongodb.com`
- **Connect via Shell**: `mongosh "mongodb+srv://cluster-url" --username <username>`
- **Database Initialize**: `./scripts/init-atlas-databases.sh`
- **Connection Test**: Check Form.io service logs for connectivity
- **Metrics**: View performance metrics in MongoDB Atlas dashboard

## Architecture

**Form.io Enterprise on GCP:**
- **App**: Cloud Run services (2 editions: community + enterprise)
- **DB**: MongoDB Atlas Flex Cluster (managed, cost-effective)
- **Storage**: GCS buckets for file uploads
- **Secrets**: Auto-generated passwords in Secret Manager
- **Network**: Shared VPC from `gcp-dss-erlich-infra-terraform`
- **Region**: australia-southeast1

## Environment Setup

**Required variables** (set in `.env`):
```bash
# Form.io Configuration
export TF_VAR_formio_license_key="license-key-here"
export TF_VAR_formio_root_email="admin@domain.com"

# MongoDB Atlas Configuration
export MONGODB_ATLAS_PUBLIC_KEY="your-atlas-public-key"
export MONGODB_ATLAS_PRIVATE_KEY="your-atlas-private-key"
export TF_VAR_mongodb_atlas_org_id="your-atlas-org-id"
```

## MongoDB Atlas Setup

**First-time setup**:
1. **Create Atlas Account**: Sign up at https://cloud.mongodb.com
2. **Create Organization**: Name it "qrius-global" or similar
3. **Generate API Keys**: Organization → Access Manager → API Keys
   - Role: "Organization Project Creator"
   - Note the Public and Private keys
4. **Set Environment Variables**: Add Atlas credentials to `.env`
5. **Deploy Infrastructure**: `make infra-apply`
6. **Initialize Databases**: `./scripts/init-atlas-databases.sh`

**Atlas Configuration**:
- **Cluster Type**: Flex (cost-effective development)
- **Provider**: GCP australia-southeast1
- **Backup**: Automatic daily backups enabled
- **Network Access**: VPC connector subnet (10.8.0.0/28)

## Key Files

- **`Makefile`**: Deployment automation with separation of concerns
- **`terraform/modules/mongodb-atlas/`**: MongoDB Atlas Terraform module
- **`terraform/secrets.tf`**: Auto-generates secure passwords
- **`terraform/environments/dev/`**: Dev environment configuration
- **`.tflint.hcl`**: Terraform linting and naming rules
- **`scripts/run-tests.sh`**: Terraform testing framework
- **`scripts/init-atlas-databases.sh`**: Database initialization script

## Deployment Workflow

1. **Infrastructure**: `make infra-plan` → `make infra-apply` (one-time)
2. **Applications**: `make deploy-all IMG=new-version` (frequent)
3. **Testing**: `make test` before changes
4. **Monitoring**: `make status` and `make logs-*` for troubleshooting

**License expires**: 08/29/2025