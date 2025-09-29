# Terraform State Synchronization Issue

## Current Situation

The Form.io Community Edition service is successfully deployed and running, but there's a mismatch between Terraform state and actual infrastructure.

### What's Deployed

1. **Form.io Community Service** (`formio-community-dev`)
   - Status: ✅ **READY** and healthy
   - URL: https://formio-community-dev-kx62qbq7iq-ts.a.run.app
   - Port: 3001 (Community default)
   - Health Checks: TCP socket on startup, HTTP to `/spec.json` for liveness
   - Deployed via: Direct `gcloud` commands (due to Terraform state lock)

2. **Configuration Matches Terraform Code**
   - Port 3001 ✅
   - TCP socket probes ✅
   - Image: formio/formio:rc ✅
   - All environment variables correct ✅

### The Problem

1. **Terraform State Doesn't Know About the Service**
   - The service was deployed manually via `gcloud` when Terraform was locked
   - Terraform wants to create a new service instead of managing the existing one

2. **State File Permission Issue**
   ```
   oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com does not have
   storage.objects.get access to the Google Cloud Storage object
   ```
   - The service account used by Terraform can't access the state file
   - This prevents both importing the existing service and applying changes

### Solution Options

#### Option 1: Fix Permissions (Recommended)
Grant the service account access to the state bucket:
```bash
gsutil iam ch serviceAccount:oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com:objectAdmin \
  gs://dss-org-tf-state
```

Then import the existing service:
```bash
terraform import 'module.formio-community[0].google_cloud_run_v2_service.formio_community_service' \
  'projects/erlich-dev/locations/australia-southeast1/services/formio-community-dev'
```

#### Option 2: Delete and Recreate
1. Delete the manually created service:
   ```bash
   gcloud run services delete formio-community-dev --project=erlich-dev --region=australia-southeast1
   ```
2. Apply Terraform to recreate it properly

#### Option 3: Leave As-Is (Current State)
- Service is running correctly ✅
- Configuration matches what Terraform would deploy ✅
- Only issue is state tracking

### Current Infrastructure Code Status

The Terraform code in `terraform/environments/dev/main.tf` correctly includes:

```hcl
module "formio-community" {
  count  = var.deploy_community ? 1 : 0
  source = "../../modules/formio-community-service"
  # ... full configuration
}
```

And in `terraform.tfvars`:
```hcl
deploy_community = true  # Community is enabled
deploy_enterprise = true # Enterprise also running
```

### What Works Now

Despite the state mismatch:
- ✅ Community service is running and healthy
- ✅ TCP health checks are passing
- ✅ Port 3001 is correctly configured
- ✅ MongoDB connectivity is working
- ✅ Service is accessible at its URL

### Recommended Action

Since the service is running correctly with the right configuration, the immediate priority should be:

1. **Fix the permission issue** for the service account to access the state bucket
2. **Import the existing service** into Terraform state
3. **Run `terraform apply`** to ensure everything is in sync

Until then, the service will continue to run correctly, but any future Terraform operations will show it wanting to create a duplicate service.