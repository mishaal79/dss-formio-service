# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Core Principle: Terraform as Single Source of Truth

**All configuration originates from Terraform**. The Makefile dynamically reads values from Terraform outputs, eliminating duplication and ensuring consistency. Never hardcode values that Terraform already knows.

## Deployment Pattern

**Infrastructure (Terraform)**: VPC, databases, secrets, service definitions, all configuration
**Applications (gcloud)**: Container deployments using Terraform-provided configuration

## Essential Commands

### Infrastructure Management
- **Initialize**: `make init`
- **Plan Changes**: `make plan`
- **Apply Changes**: `make apply`
- **Quality Checks**: `make check` (format + lint)
- **Security Scan**: `make security`
- **Test**: `make test` (mock validation)
- **Environment**: `ENV=prod make plan` (target specific environment)

### Application Deployment  
- **Deploy Enterprise**: `make deploy-ent` (uses Terraform's configured version)
- **Deploy with Version**: `make deploy-ent IMG=formio/formio-enterprise:9.5.1`
- **Deploy Community**: `make deploy-com` (if enabled in Terraform)
- **Deploy Configured**: `make deploy-configured` (uses Terraform versions)
- **Update Env Vars**: `make update-ent` (sync from Terraform)
- **Route Traffic**: `make traffic-ent-100` (100% to latest)

### Monitoring
- **Status**: `make status`
- **Show Versions**: `make show-versions` (configured vs deployed)
- **Logs**: `make logs-ent` or `make logs-com`
- **Health Check**: `make health-check`

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
- **Network**: Central VPC from `gcp-dss-erlich-infra-terraform`
- **Region**: australia-southeast1

## Single Source of Truth Pattern

**Configuration Flow:**
1. **Terraform Variables** → Define all configuration
2. **Terraform Outputs** → Expose configuration for consumption
3. **Makefile** → Reads from Terraform outputs dynamically
4. **gcloud Commands** → Use Terraform-provided values

**Values managed by Terraform:**
- Project ID, Region, Environment
- Service names (fully qualified)
- Image versions (configured and deployed)
- Database names
- Environment variables
- All infrastructure configuration

**Example Pattern:**
```makefile
# Helper to read Terraform outputs
define tf_output
$(shell cd $(TF_DIR) && terraform output -raw $(1) 2>/dev/null || echo $(2))
endef

# Dynamic configuration from Terraform
PROJECT_ID := $(call tf_output,project_id,erlich-dev)
```

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

- **`Makefile`**: Deployment automation that reads from Terraform outputs
- **`terraform/environments/dev/outputs.tf`**: Exposes all configuration for Makefile
- **`terraform/modules/mongodb-atlas/`**: MongoDB Atlas Terraform module
- **`terraform/secrets.tf`**: Auto-generates secure passwords
- **`terraform/environments/dev/`**: Dev environment configuration
- **`.tflint.hcl`**: Terraform linting and naming rules
- **`scripts/run-tests.sh`**: Terraform testing framework
- **`scripts/init-atlas-databases.sh`**: Database initialization script

## Central Infrastructure Integration

**Important**: This service requires manual configuration in the central infrastructure project.

### Integration Steps

1. **Deploy this service** to create backend services:
   ```bash
   make infra-apply
   ```

2. **Get backend service configuration**:
   ```bash
   cd terraform/environments/dev
   terraform output backend_service_configuration
   ```

3. **Update central infrastructure** (`gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars`):
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
- Avoids circular dependencies between Terraform projects
- Provides explicit configuration control
- Enables stable production deployments
- Can be automated via CI/CD pipelines

## Deployment Workflow

### First-Time Setup
1. **Initialize**: `make init`
2. **Plan Infrastructure**: `make plan`
3. **Apply Infrastructure**: `make apply`
4. **Update Central LB**: Add backend service ID to central infrastructure tfvars
5. **Deploy Application**: `make deploy-ent` (uses Terraform's configured version)

### Ongoing Deployments
1. **Deploy New Version**: `make deploy-ent IMG=formio/formio-enterprise:9.5.1`
2. **Update Env Vars**: `make update-ent` (sync from Terraform)
3. **Check Status**: `make status` and `make show-versions`
4. **View Logs**: `make logs-ent`

### Version Management
- **Check Versions**: `make show-versions` shows configured vs deployed
- **Deploy Configured**: `make deploy-configured` uses Terraform versions
- **Override Version**: Provide explicit IMG parameter when needed

**License expires**: 08/29/2025

## Performance Optimizations

### CDN & Cold Start Elimination (Implemented Sept 1, 2025)

**Infrastructure Optimizations Applied:**
- **Cloud CDN**: Enabled on backend service (`dss-formio-api-ent-backend-dev`)
  - Cache mode: `CACHE_ALL_STATIC`
  - Default TTL: 1 hour, Max TTL: 24 hours, Client TTL: 30 minutes
  - Negative caching: 404s for 5 minutes
  - Query string whitelist: version, locale
- **Cold Start Elimination**: Min instances set to 1 (always warm)
- **Performance Targets**: <300ms first load, <100ms cached responses, >80% CDN hit rate

**Configuration Files:**
- `terraform/modules/formio-service/main.tf`: Backend service CDN policy
- `terraform/environments/dev/terraform.tfvars`: min_instances = 1

**Testing CDN Performance:**
```bash
# Test cache headers
curl -I https://forms.dev.cloud.dsselectrical.com.au
# Look for: X-Cache-Status, Cache-Control headers

# Monitor CDN hit rates
gcloud monitoring metrics list --filter="metric.type:loadbalancing.googleapis.com/https/backend_request_count"
```

**Branch**: `feature/issue-30-automated-backend-discovery`

**Load Balancer Integration Required:**
The backend service with CDN has been created but requires central infrastructure update:
```bash
# Add to gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars:
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev"
  }
}
# Then run: terraform apply in central infrastructure project
```