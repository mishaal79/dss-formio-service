# Local Development Workflow

## Overview

This guide provides the **recommended workflow for local development** of the Form.io Custom service using Make commands.

**Key Principle**: Simplicity over complexity for local development.

---

## Quick Start

```bash
# From repository root
make build-deploy
```

That's it! This builds the Docker image and deploys it to Cloud Run.

---

## Architecture

### Image Tagging Strategy for Local Development

**For Local Development**: Use `dev-latest` tag
- ✅ Simple workflow
- ✅ No config changes needed
- ✅ Fast iteration
- ✅ Terraform detects changes automatically

**Why Not Git SHA for Local Dev?**
- ❌ Requires manual config updates
- ❌ Adds friction to rapid iteration
- ❌ Overkill for local development

**Git SHA tagging** is great for CI/CD and production, but for local development, simplicity wins.

---

## Available Commands

### Essential Commands

```bash
# Build and deploy (recommended for local dev)
make build-deploy

# Build only (without deploying)
make build

# Deploy only (assumes image exists in GCR)
make deploy

# Preview changes before deploying
make plan
```

### Monitoring Commands

```bash
# Check service status
make status

# View recent logs
make logs

# Get service URL
cd dss-formio-service/terraform/environments/dev-formio-custom
terraform output service_url
```

### Cleanup Commands

```bash
# Destroy Cloud Run infrastructure
make destroy

# Clean local Docker images
make clean
```

---

## Typical Development Workflow

### 1. Make Code Changes

Edit files in:
- `formio/` - Backend server code
- `packages/formio-file-upload/` - File upload module
- `formio/Dockerfile` - Docker configuration

### 2. Build and Deploy

```bash
# Single command builds and deploys
make build-deploy
```

**What happens**:
1. Builds Docker image with `dev-latest` tag
2. Pushes to Google Container Registry
3. Deploys to Cloud Run using Terraform
4. Outputs service URL

### 3. Verify Deployment

```bash
# Check status
make status

# View logs
make logs

# Test health endpoint
curl https://formio-custom-dev-XXXXXXXXX.run.app/health
```

### 4. Iterate

Repeat steps 1-3 as needed. The `dev-latest` tag ensures Terraform always deploys the newest image.

---

## How It Works

### Image Tagging

**Local Development** uses a static `dev-latest` tag:
```bash
gcr.io/erlich-dev/formio-custom:dev-latest
```

Every build overwrites this tag with the new image. Terraform detects the change because it tracks the **image digest** (`sha256:...`), not the tag.

### Terraform Configuration

The environment configuration (`terraform/environments/dev-formio-custom/main.tf`) is set to:

```hcl
custom_image_tag = "dev-latest"
```

No changes needed between deployments!

---

## Troubleshooting

### Build Fails

**Error**: `docker: command not found`
**Solution**: Install Docker Desktop and ensure it's running

**Error**: `Error response from daemon: Get "https://gcr.io/v2/": denied`
**Solution**: Authenticate with GCR:
```bash
gcloud auth configure-docker gcr.io
```

### Deploy Fails

**Error**: `Error 403: Permission denied`
**Solution**: Check service account credentials:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/keys/dev-mish-key.json"
```

**Error**: `Image not found in GCR`
**Solution**: Ensure image was pushed:
```bash
make push
```

### Service Not Updating

**Problem**: Deployed but old code is running

**Solution 1**: Check image digest changed:
```bash
gcloud container images describe gcr.io/erlich-dev/formio-custom:dev-latest
```

**Solution 2**: Force new revision:
```bash
cd dss-formio-service/terraform/environments/dev-formio-custom
terraform taint module.formio_custom_service.google_cloud_run_v2_service.formio_custom
terraform apply
```

---

## Best Practices

### For Local Development

✅ **DO**:
- Use `make build-deploy` for rapid iteration
- Use `dev-latest` tag
- Keep Terraform config unchanged
- Test locally with `make logs`

❌ **DON'T**:
- Don't use Git SHA tags for local dev
- Don't manually update Terraform config
- Don't skip the push step (images must be in GCR)
- Don't use `latest` in production

### For Production Deployments

Use Git SHA or semantic versioning:
```bash
# Build with Git SHA (for prod)
./dss-formio-service/scripts/tag-and-push.sh git-sha

# Update prod Terraform config
custom_image_tag = "git-3b95aa5"
```

---

## Environment Configuration

### Required Environment Variables

The Makefile automatically sets:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/keys/dev-mish-key.json"
```

### Customizing Configuration

Edit `.env` files in:
- `formio/.env` - Form.io server config
- `dss-formio-service/terraform/environments/dev-formio-custom/terraform.tfvars` - Infrastructure config

---

## Performance Tips

### Faster Builds

**Use BuildKit caching**:
```bash
# Enable BuildKit (faster builds)
export DOCKER_BUILDKIT=1
make build
```

**Multi-stage builds** are already optimized in `formio/Dockerfile`.

### Parallel Builds

```bash
# Build multiple services in parallel
make -j2 build
```

---

## Comparison: Local Dev vs CI/CD

| Aspect | Local Development | CI/CD / Production |
|--------|------------------|-------------------|
| **Tag** | `dev-latest` | `git-abc1234` or `v1.2.3` |
| **Workflow** | `make build-deploy` | Automated pipeline |
| **Config Changes** | None required | Update Terraform variable |
| **Iteration Speed** | Fast (2-3 minutes) | Slower (5-10 minutes) |
| **Traceability** | Low (overwritten tag) | High (immutable tags) |
| **Best For** | Rapid iteration | Stable releases |

---

## Related Documentation

- [Image Tagging Strategy](IMAGE_TAGGING_STRATEGY.md) - Complete guide to tagging strategies
- [Cloud Run Deployment](CLOUD_RUN_DEPLOYMENT.md) - Terraform module documentation
- [Build Script](../scripts/tag-and-push.sh) - Advanced tagging script

---

## Support

**Issues?** Check the troubleshooting section or contact the team.

**Last Updated**: 2025-11-13
