# Form.io Custom Service - Development Environment

This Terraform configuration deploys the Form.io Custom service to the
`erlich-dev` GCP project for development purposes.

## Overview

- **Environment**: Development (dev)
- **GCP Project**: erlich-dev
- **Region**: us-central1
- **Service Name**: formio-custom-dev
- **Docker Image**: gcr.io/erlich-dev/formio-custom:7

## Prerequisites

1. **GCP Authentication**: Ensure you're authenticated with GCP

   ```bash
   gcloud auth application-default login
   gcloud config set project erlich-dev
   ```

2. **Terraform**: Install Terraform >= 1.5

   ```bash
   brew install terraform
   ```

3. **Secret Manager Secrets**: Ensure these secrets exist in GCP Secret Manager:
   - `dss-formio-api-mongodb-custom-connection-string-dev`
   - `dss-formio-api-jwt-secret-dev`
   - `dss-formio-api-token-private-key-v1-dev`
   - `dss-formio-api-token-public-key-v1-dev`

4. **GCS Bucket**: Create the uploads bucket if it doesn't exist:
   ```bash
   gsutil mb -p erlich-dev -l us-central1 gs://erlich-dev-formio-uploads
   ```

## Configuration

### Variables

The configuration uses the following default values:

```hcl
project_id  = "erlich-dev"
region      = "us-central1"
environment = "dev"
```

### Module Configuration

The deployment uses the `formio-custom-service` module with:

- **Scaling**: Min 0, Max 10 instances
- **Resources**: 1 CPU, 512Mi memory
- **Timeout**: 300 seconds
- **Access**: Unauthenticated (for development)
- **Logging**: Debug level enabled

### Environment Variables

The service is configured with:

- `NODE_ENV=development`
- `LOG_LEVEL=debug`
- `FORMIO_FILES_SERVER=gcs`
- `GCS_BUCKET_NAME=erlich-dev-formio-uploads`

## Deployment

### Initialize Terraform

```bash
cd terraform/environments/dev-formio-custom
terraform init
```

### Plan Changes

```bash
terraform plan
```

### Apply Configuration

```bash
terraform apply
```

### View Outputs

```bash
terraform output
# Example output:
# service_name = "formio-custom-dev"
# service_url = "https://formio-custom-dev-abc123-uc.a.run.app"
```

## Post-Deployment

### Access the Service

The service URL will be output after deployment. Access it via:

```bash
SERVICE_URL=$(terraform output -raw service_url)
curl -I $SERVICE_URL/health
```

### View Logs

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=formio-custom-dev" --limit 50 --format json
```

### Test the Service

```bash
# Health check
curl $SERVICE_URL/health

# Test form endpoint (requires authentication)
curl -H "Content-Type: application/json" $SERVICE_URL/form
```

## Maintenance

### Update Docker Image

1. Update the `docker_image` variable in `main.tf`
2. Run `terraform apply`

### Update Secrets

Secrets are managed in GCP Secret Manager. To update:

```bash
# Example: Update JWT secret
echo -n "new-jwt-secret" | gcloud secrets versions add dss-formio-api-jwt-secret-dev --data-file=-
```

### Destroy Resources

To tear down the environment:

```bash
terraform destroy
```

**Warning**: This will delete the Cloud Run service. Secrets and GCS buckets are
not automatically deleted.

## Troubleshooting

### Service Not Starting

Check Cloud Run logs:

```bash
gcloud run services logs read formio-custom-dev --region=us-central1 --limit=100
```

### Secret Access Issues

Verify the Cloud Run service account has Secret Manager access:

```bash
gcloud projects get-iam-policy erlich-dev \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:*" \
  --format="table(bindings.role)"
```

### Permission Issues

Ensure the Terraform service account has these roles:

- `roles/run.admin`
- `roles/iam.serviceAccountUser`
- `roles/secretmanager.secretAccessor`

## Related Documentation

- [Form.io Custom Service Module](../../modules/formio-custom-service/README.md)
- [Terraform Best Practices](../../../docs/TERRAFORM_BEST_PRACTICES.md)
- [GCP Secret Manager Guide](https://cloud.google.com/secret-manager/docs)
