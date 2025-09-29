# Terraform Permission Resolution Guide

## Problem Summary

The Form.io Community Edition service cannot be fully managed by Terraform due to multiple permission issues:

1. **State File Access**: The service account `oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com` lacks access to the Terraform state bucket (`gs://dss-org-tf-state`)
2. **Secret Manager Access**: Terraform cannot read/write secrets without proper IAM roles
3. **Service Account Permissions**: The deployment service account needs specific role bindings

## Current Status

### What's Working
- Community service can be deployed via `gcloud` commands
- Service account has been granted access to specific secrets
- Port 3001 and TCP health checks are correctly configured in the Terraform module

### What's Broken
- Terraform cannot import existing resources due to state file permission errors
- Terraform apply fails due to missing Secret Manager permissions
- The service account used by Terraform (`oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com`) lacks necessary IAM roles

## Resolution Steps

### Option 1: Fix IAM Permissions (Recommended)

#### Step 1: Grant State Bucket Access
```bash
# As an admin user with bucket owner permissions:
gsutil iam ch serviceAccount:oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com:objectAdmin \
  gs://dss-org-tf-state
```

#### Step 2: Grant Secret Manager Access
```bash
# Grant project-level Secret Manager Admin role
gcloud projects add-iam-policy-binding erlich-dev \
  --member='serviceAccount:oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com' \
  --role='roles/secretmanager.admin'
```

#### Step 3: Grant Storage Admin Access
```bash
# For managing GCS buckets
gcloud projects add-iam-policy-binding erlich-dev \
  --member='serviceAccount:oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com' \
  --role='roles/storage.admin'
```

#### Step 4: Import Existing Resources
Once permissions are fixed:
```bash
cd terraform/environments/dev

# Import the Cloud Run service
terraform import 'module.formio-community[0].google_cloud_run_v2_service.formio_community_service' \
  'projects/erlich-dev/locations/australia-southeast1/services/formio-community-dev'

# Apply Terraform to create missing resources (backend service)
terraform apply -target='module.formio-community[0]'
```

### Option 2: Use Different Authentication

#### Use Personal Account with Admin Permissions
```bash
# Switch to admin account
gcloud config set account admin@dsselectrical.com.au

# Set application default credentials
gcloud auth application-default login

# Run Terraform
terraform apply
```

#### Use Service Account Impersonation
```bash
# Set impersonation
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="terraform@erlich-dev.iam.gserviceaccount.com"

# Run Terraform
terraform apply
```

### Option 3: Manual Deployment (Current Workaround)

Until permissions are fixed, deploy using `gcloud` directly:

```bash
# Deploy Community service
gcloud run deploy formio-community-dev \
  --project=erlich-dev \
  --region=australia-southeast1 \
  --image=formio/formio:rc \
  --port=3001 \
  --memory=2Gi \
  --cpu=1000m \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --service-account=oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com \
  --allow-unauthenticated \
  --set-env-vars="HOST=0.0.0.0,PROTOCOL=https,PRIMARY=true" \
  --set-secrets="MONGO_URI=dss-formio-api-mongodb-community-connection-string-dev:latest,JWT_SECRET=dss-formio-api-jwt-secret-dev:latest,DB_SECRET=dss-formio-api-db-secret-dev:latest"

# Update health checks
gcloud run services update formio-community-dev \
  --project=erlich-dev \
  --region=australia-southeast1 \
  --command='/bin/sh' \
  --args='-c,NODE_CONFIG=$(jq -n --arg m "$MONGO_URI" --arg j "$JWT_SECRET" --arg d "$DB_SECRET" "{mongo:\$m,jwt:{secret:\$j},db:{secret:\$d},port:3001,host:\"0.0.0.0\",protocol:\"https\",primary:true}") exec node main.js'
```

## NODE_CONFIG Challenge

The Form.io Community Edition requires a `NODE_CONFIG` environment variable with a specific JSON structure. This is challenging because:

1. Cloud Run doesn't support complex JSON in environment variables easily
2. The wrapper script approach requires careful escaping
3. Form.io Community defaults to `mongodb://localhost:27017/formio-ce` if NODE_CONFIG is not properly set

### Working Solution
Use a wrapper script that assembles NODE_CONFIG at runtime from individual environment variables:

```bash
#!/bin/sh
NODE_CONFIG=$(echo {} | jq \
  --arg mongo "$MONGO_URI" \
  --arg jwt "$JWT_SECRET" \
  --arg db "$DB_SECRET" \
  --argjson port 3001 \
  --arg host "0.0.0.0" \
  --arg protocol "https" \
  --arg domain "$DOMAIN" \
  --argjson primary true \
  '. | .mongo = $mongo | .jwt.secret = $jwt | .db.secret = $db | .port = $port | .host = $host | .protocol = $protocol | .domain = $domain | .primary = $primary')
export NODE_CONFIG
exec node main.js
```

## Required IAM Roles Summary

For the service account `oauth-cloudrun-dev@erlich-dev.iam.gserviceaccount.com`:

| Resource | Required Role | Purpose |
|----------|--------------|---------|
| State Bucket | `storage.objectAdmin` | Read/write Terraform state |
| Secrets | `secretmanager.admin` | Manage secrets |
| Cloud Run | `run.admin` | Deploy services |
| Storage Buckets | `storage.admin` | Create/manage GCS buckets |
| Backend Services | `compute.admin` | Create backend services |

## Error Messages Reference

### State File Access Error
```
Error: error loading state: Failed to open state file at gs://dss-org-tf-state/formio-service/environments/dev/default.tfstate
Permission 'storage.objects.get' denied on resource
```

### Secret Manager Error
```
Error: Error when reading or editing SecretManagerSecret
Permission 'secretmanager.secrets.get' denied for resource
```

### MongoDB Connection Error
```
Error: Could not connect to the given Database for server updates: mongodb://localhost:27017/formio-ce
```
This indicates NODE_CONFIG is not being read properly.

## Next Steps

1. **Immediate**: Get admin access to grant necessary permissions
2. **Short-term**: Import existing resources into Terraform state
3. **Long-term**: Ensure all deployments go through Terraform

## Contact

For permission grants, contact the infrastructure admin who has:
- Owner access to the `dss-org-tf-state` bucket
- Project Owner role on `erlich-dev` project