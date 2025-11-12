# Form.io Custom Image Tagging Strategy

## Problem Statement

**Original Issue**: Manual sequential numbering (`custom_image_tag = "7"`) doesn't work well for CI/CD:
- Requires Terraform config changes for every deployment
- No correlation with code changes
- Hard to track what code is in each image
- Forces Terraform apply even when only container changed

## Solution: Git SHA-Based Tagging

### Recommended Strategy: `git-<short-sha>`

**Format**: `git-3b95aa5` (7-character commit SHA)

**Benefits**:
- ✅ Automatic correlation with code changes
- ✅ Immutable and traceable
- ✅ CI/CD friendly
- ✅ No Terraform config changes needed for container updates
- ✅ Easy rollbacks to specific commits

**Drawbacks**:
- ⚠️ Not human-readable for version progression
- ⚠️ Requires Git SHA lookup for version identification

---

## Implementation

### 1. Build Script (`scripts/tag-and-push.sh`)

Automated Docker image building with multiple tagging strategies:

```bash
# Default: Git SHA tagging
./scripts/tag-and-push.sh

# Explicit strategies
./scripts/tag-and-push.sh git-sha
./scripts/tag-and-push.sh semver v1.2.3
./scripts/tag-and-push.sh timestamp
./scripts/tag-and-push.sh latest
```

**Features**:
- Multi-platform support (`linux/amd64` for Cloud Run)
- Automatic `latest` aliasing
- Terraform variable output
- Color-coded logging

### 2. Terraform Integration

**Module Variable** (`modules/formio-custom-service/variables.tf`):

```hcl
variable "custom_image_tag" {
  description = <<-EOT
    Custom Docker image tag for Form.io enhanced edition.
    Recommended formats for CI/CD:
    - Git SHA: "git-abc1234" (automatic correlation with code)
    - Semantic version: "v1.2.3" (for releases)
    - Timestamp: "20251113-abc1234" (for frequent deployments)
    - "latest" (for dev environments, not recommended for prod)
  EOT
  type        = string
  default     = "latest"
}
```

**Environment Configuration** (`environments/dev-formio-custom/main.tf`):

```hcl
module "formio_custom_service" {
  source = "../../modules/formio-custom-service"

  # Use Git SHA for dev deployments
  custom_image_tag = "git-3b95aa5"  # Updated automatically by CI/CD

  # Other configuration...
}
```

### 3. CI/CD Integration

**GitHub Actions Example**:

```yaml
name: Deploy Form.io Custom Service

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get Git SHA
        id: sha
        run: echo "sha=git-$(git rev-parse --short=7 HEAD)" >> $GITHUB_OUTPUT

      - name: Build and Push Image
        run: |
          ./dss-formio-service/scripts/tag-and-push.sh git-sha

      - name: Deploy to Cloud Run
        run: |
          cd dss-formio-service/terraform/environments/dev-formio-custom
          export TF_VAR_custom_image_tag="${{ steps.sha.outputs.sha }}"
          terraform apply -auto-approve
```

---

## Tagging Strategy Comparison

| Strategy | Format | Use Case | Pros | Cons |
|----------|--------|----------|------|------|
| **Git SHA** | `git-3b95aa5` | CI/CD, Dev | Automatic correlation, immutable | Not human-readable |
| **Semantic** | `v1.2.3` | Production releases | Clear progression, human-readable | Manual version bumps |
| **Timestamp** | `20251113-3b95aa5` | Frequent dev deploys | Sortable, traceable | Longer tags |
| **Latest** | `latest` | Local dev only | No config changes | Not immutable, hard to rollback |

---

## Workflow Examples

### Local Development

```bash
# Build with Git SHA (recommended)
cd /Users/mishal/code/worktrees/phase3-integration
./dss-formio-service/scripts/tag-and-push.sh git-sha

# Update Terraform
cd dss-formio-service/terraform/environments/dev-formio-custom
export TF_VAR_custom_image_tag="git-3b95aa5"
make deploy
```

### Production Release

```bash
# Build with semantic version
./dss-formio-service/scripts/tag-and-push.sh semver v1.2.3

# Update Terraform
cd dss-formio-service/terraform/environments/prod
export TF_VAR_custom_image_tag="v1.2.3"
terraform apply -auto-approve
```

### Quick Dev Iteration

```bash
# Build with timestamp + SHA
./dss-formio-service/scripts/tag-and-push.sh timestamp

# Deploy immediately
cd dss-formio-service/terraform/environments/dev-formio-custom
export TF_VAR_custom_image_tag="$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short=7 HEAD)"
terraform apply -auto-approve
```

---

## Rollback Strategy

### Rollback to Specific Commit

```bash
# Find previous Git SHA
git log --oneline -10
# Output: 3b95aa5 fix(ci): resolve Cloud Run deployment issues
#         79ae87a docs(docs): document unlock() defensive fix

# Rollback to previous version
cd dss-formio-service/terraform/environments/dev-formio-custom
export TF_VAR_custom_image_tag="git-79ae87a"
terraform apply -auto-approve
```

### Rollback to Latest Stable

```bash
# Use 'latest' tag (points to most recent push)
export TF_VAR_custom_image_tag="latest"
terraform apply -auto-approve
```

---

## Image Management

### List Available Images

```bash
# List all Form.io custom images
gcloud container images list-tags gcr.io/erlich-dev/formio-custom \
  --format="table(tags,digest.slice(7:19),timestamp.date())" \
  --limit=20
```

### Delete Old Images

```bash
# Delete images older than 30 days
gcloud container images list-tags gcr.io/erlich-dev/formio-custom \
  --filter="timestamp.datetime < $(date -d '30 days ago' --iso-8601=seconds)" \
  --format="get(digest)" \
  --limit=unlimited | \
  xargs -I {} gcloud container images delete "gcr.io/erlich-dev/formio-custom@{}" --quiet
```

### Promote Image to Production

```bash
# Tag dev image for production
docker pull gcr.io/erlich-dev/formio-custom:git-3b95aa5
docker tag gcr.io/erlich-dev/formio-custom:git-3b95aa5 gcr.io/erlich-prod/formio-custom:v1.2.3
docker push gcr.io/erlich-prod/formio-custom:v1.2.3
```

---

## Best Practices

### For Development Environments
✅ Use Git SHA strategy: `git-<sha>`
✅ Rebuild and redeploy on every commit
✅ Keep `latest` tag updated
✅ Clean up old images regularly

### For Staging Environments
✅ Use semantic versioning: `v1.2.3-rc.1`
✅ Pin specific versions in Terraform
✅ Test rollback procedures
✅ Document release notes

### For Production Environments
✅ Use semantic versioning: `v1.2.3`
✅ Never use `latest` tag
✅ Require manual approval for deployments
✅ Keep last 3 versions for rollback
✅ Tag images with environment: `v1.2.3-prod`

---

## Troubleshooting

### Image Tag Validation Errors

**Error**: `Invalid repository labels: value "git-3b95aa5" contains invalid character '.' at index 3`

**Cause**: GCP labels don't allow certain characters (dots, colons)

**Solution**: Module already sanitizes version for labels:
```hcl
version_sanitized = replace(replace(var.custom_image_tag, ".", "-"), ":", "-")
```

### Image Not Found

**Error**: `The requested image 'gcr.io/erlich-dev/formio-custom:git-3b95aa5' does not exist`

**Solution**:
```bash
# Verify image exists
gcloud container images list-tags gcr.io/erlich-dev/formio-custom

# If missing, rebuild
./dss-formio-service/scripts/tag-and-push.sh git-sha
```

### Terraform Doesn't Detect Changes

**Issue**: Changing `custom_image_tag` doesn't trigger Cloud Run update

**Cause**: Terraform uses image digest for change detection

**Solution**: Force new revision:
```bash
terraform taint module.formio_custom_service.google_cloud_run_v2_service.formio_custom
terraform apply
```

---

## Migration Guide

### Migrating from Sequential Numbering

**Before** (`custom_image_tag = "7"`):
- Required Terraform config changes for every deploy
- No correlation with code changes
- Hard to track versions

**After** (`custom_image_tag = "git-3b95aa5"`):
- Automatic version from Git
- Clear correlation with commits
- Easy rollbacks

**Migration Steps**:

1. **Build new image with Git SHA**:
   ```bash
   ./dss-formio-service/scripts/tag-and-push.sh git-sha
   ```

2. **Update Terraform configuration**:
   ```hcl
   # Before
   custom_image_tag = "7"

   # After
   custom_image_tag = "git-3b95aa5"
   ```

3. **Deploy**:
   ```bash
   cd dss-formio-service/terraform/environments/dev-formio-custom
   terraform apply
   ```

4. **Verify**:
   ```bash
   gcloud run services describe formio-custom-dev \
     --region=us-central1 \
     --format="value(spec.template.spec.containers[0].image)"
   ```

---

## Related Documentation

- [Terraform Module Variables](../terraform/modules/formio-custom-service/variables.tf)
- [Build Script](../scripts/tag-and-push.sh)
- [Environment Configuration Template](../terraform/environments/dev-formio-custom/terraform.tfvars.template)
- [Cloud Run Deployment Guide](./CLOUD_RUN_DEPLOYMENT.md)
