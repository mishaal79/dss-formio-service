# Form Web BFF Terraform Module

Cloud Run Backend-for-Frontend (BFF) service module with VPC integration, load
balancer support, and service-to-service authentication.

## Features

- ✅ **Configurable Port**: Container port configurable via Dockerfile ARG, ENV,
  and Terraform variable
- ✅ **VPC Integration**: Private networking with `PRIVATE_RANGES_ONLY` egress
- ✅ **Service-to-Service Auth**: IAM-based authentication to Form.io custom
  service
- ✅ **Load Balancer Ready**: NEG + Backend Service + Health Check
  pre-configured
- ✅ **Security Hardening**: Least-privilege service account, VPC egress control
- ✅ **Observability**: Cloud Logging, Monitoring, Tracing enabled
- ✅ **Production Ready**: Auto-scaling, health checks, connection draining

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Cloud Load Balancer                       │
│                      (Future)                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  Backend Service     │
          │  + Health Check      │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  Network Endpoint    │
          │  Group (Serverless)  │
          └──────────┬───────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│               Cloud Run Service                            │
│               (form-web-bff)                               │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Container (Node.js 24 Alpine)                        │ │
│  │ - Fastify Server                                     │ │
│  │ - tRPC API Endpoints                                 │ │
│  │ - Port: var.container_port (default: 3002)          │ │
│  │ - Health: /health/ready                              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  Service Account: form-web-bff-sa-{env}                   │
│  - roles/logging.logWriter                                │
│  - roles/monitoring.metricWriter                          │
│  - roles/cloudtrace.agent                                 │
│  - roles/run.invoker (on formio-custom)                   │
└────────────────────┬───────────────────────────────────────┘
                     │
                     │ VPC Connector
                     │ (PRIVATE_RANGES_ONLY)
                     │
         ┌───────────┼───────────────────┐
         ▼           ▼                   ▼
    ┌────────┐  ┌────────┐      ┌──────────────┐
    │ MongoDB│  │ Redis  │      │ Form.io      │
    │        │  │        │      │ Custom       │
    └────────┘  └────────┘      └──────────────┘
```

## Port Configuration Architecture

**Three-Layer Configuration System**:

1. **Dockerfile ARG**: `ARG PORT=3002` (build-time default)
2. **Container ENV**: `ENV PORT=${PORT}` (runtime environment variable)
3. **Terraform Variable**: `var.container_port` (default: 3002, validates
   1024-65535)

**Flow**:

```
Terraform → Cloud Run → Container ENV → Fastify Server
var.container_port → ENV PORT → process.env.PORT → server.listen()
```

**Why This Design?**:

- No hardcoded ports in any layer
- Consistent configuration across Dockerfile, Cloud Run, Health Checks
- Easy to change for different environments or services
- Validates port range at Terraform level

## Usage

### Basic Example

```hcl
module "form_web_bff" {
  source = "../../modules/form-web-bff"

  # Project configuration
  project_id  = "my-gcp-project"
  region      = "australia-southeast1"
  environment = "dev"

  # Docker image
  image_url = "gcr.io/my-project/form-web-bff:latest"

  # VPC networking (from central infrastructure)
  vpc_connector_id   = data.terraform_remote_state.central_infra.outputs.vpc_connector_id
  vpc_egress_setting = "PRIVATE_RANGES_ONLY"

  # Service-to-service authentication
  formio_custom_service_name = module.formio_custom.service_name
  formio_custom_service_url  = module.formio_custom.service_url

  # Port configuration (optional - defaults to 3002)
  container_port = 3002

  # Resource limits
  min_instance_count    = 0
  max_instance_count    = 10
  container_concurrency = 80
  memory_limit          = "512Mi"
  cpu_limit             = "1000m"

  # Application configuration
  node_env  = "production"
  log_level = "info"
  cors_origin = "https://app.example.com"

  # Rate limiting
  rate_limit_max       = 100
  rate_limit_window_ms = 60000

  # Observability
  otel_endpoint = "http://otel-collector:4318"

  # Labels
  labels = {
    managed-by = "terraform"
    project    = "dss-formio"
  }
}
```

### Custom Port Example

```hcl
module "form_web_bff" {
  source = "../../modules/form-web-bff"

  # ... other configuration ...

  # Use custom port
  container_port = 8080

  # Note: Dockerfile must be built with matching ARG PORT value:
  # docker build --build-arg PORT=8080 -t form-web-bff:custom .
}
```

### Production Example

```hcl
module "form_web_bff" {
  source = "../../modules/form-web-bff"

  project_id  = "prod-gcp-project"
  region      = "australia-southeast1"
  environment = "prod"

  image_url = "gcr.io/prod-project/form-web-bff:v1.0.0"

  # Production VPC
  vpc_connector_id   = data.terraform_remote_state.central_infra.outputs.vpc_connector_id
  vpc_egress_setting = "PRIVATE_RANGES_ONLY"

  # Service-to-service auth
  formio_custom_service_name = module.formio_custom.service_name
  formio_custom_service_url  = module.formio_custom.service_url

  # Production scaling
  min_instance_count    = 2  # Always-on instances
  max_instance_count    = 50
  container_concurrency = 100
  memory_limit          = "1Gi"
  cpu_limit             = "2000m"

  # Security
  allow_unauthenticated = false  # Require authentication
  node_env              = "production"
  log_level             = "warn"

  # Production CORS
  cors_origin = "https://app.qrius.com.au"

  # Higher rate limits
  rate_limit_max       = 1000
  rate_limit_window_ms = 60000

  labels = {
    environment = "production"
    criticality = "high"
  }
}
```

### Load Balancer Integration

```hcl
# 1. Create form-web-bff module
module "form_web_bff" {
  source = "../../modules/form-web-bff"
  # ... configuration ...
}

# 2. Use outputs for load balancer URL map
resource "google_compute_url_map" "main" {
  name            = "main-lb"
  default_service = google_compute_backend_service.default.id

  host_rule {
    hosts        = ["api.example.com"]
    path_matcher = "api"
  }

  path_matcher {
    name            = "api"
    default_service = google_compute_backend_service.default.id

    path_rule {
      paths   = ["/bff/*"]
      service = module.form_web_bff.backend_service_id
    }
  }
}
```

## Port Configuration Testing

**Test different port values**:

```bash
# 1. Test default port (3002)
terraform plan -var="container_port=3002"

# 2. Test custom port (8080)
terraform plan -var="container_port=8080"

# 3. Test invalid port (should fail validation)
terraform plan -var="container_port=80"
# Expected error: Container port must be between 1024 and 65535

# 4. Verify health check uses same port
terraform plan | grep "container_port"
```

## Requirements

| Name        | Version  |
| ----------- | -------- |
| terraform   | >= 1.5.0 |
| google      | >= 5.0.0 |
| google-beta | >= 5.0.0 |
| random      | >= 3.5.0 |

## Providers

| Name        | Version  |
| ----------- | -------- |
| google      | >= 5.0.0 |
| google-beta | >= 5.0.0 |

## Resources

| Name                                                      | Type     |
| --------------------------------------------------------- | -------- |
| google_cloud_run_v2_service.form_web_bff                  | resource |
| google_cloud_run_v2_service_iam_member.public_access      | resource |
| google_cloud_run_service_iam_member.formio_custom_invoker | resource |
| google_compute_backend_service.form_web_bff               | resource |
| google_compute_health_check.form_web_bff                  | resource |
| google_compute_region_network_endpoint_group.form_web_bff | resource |
| google_project_iam_member.form_web_bff_logging            | resource |
| google_project_iam_member.form_web_bff_monitoring         | resource |
| google_project_iam_member.form_web_bff_trace              | resource |
| google_service_account.form_web_bff                       | resource |

## Inputs

| Name                       | Description                                                              | Type          | Default                                             | Required |
| -------------------------- | ------------------------------------------------------------------------ | ------------- | --------------------------------------------------- | :------: |
| allow_unauthenticated      | Allow public access without authentication (dev/staging only)            | `bool`        | `false`                                             |    no    |
| container_concurrency      | Maximum number of concurrent requests per container                      | `number`      | `80`                                                |    no    |
| container_port             | Container port for Fastify server (matches Dockerfile ARG PORT)          | `number`      | `3002`                                              |    no    |
| cors_origin                | CORS allowed origins (comma-separated or \*)                             | `string`      | `"*"`                                               |    no    |
| cpu_limit                  | CPU limit per instance                                                   | `string`      | `"1000m"`                                           |    no    |
| environment                | Environment name (dev, staging, prod)                                    | `string`      | n/a                                                 |   yes    |
| formio_custom_service_name | Form.io custom service name for IAM binding (service-to-service auth)    | `string`      | n/a                                                 |   yes    |
| formio_custom_service_url  | Form.io custom service URL for backend requests                          | `string`      | n/a                                                 |   yes    |
| image_url                  | Full Docker image URL including tag (gcr.io/PROJECT_ID/form-web-bff:TAG) | `string`      | n/a                                                 |   yes    |
| labels                     | Resource labels                                                          | `map(string)` | `{"managed-by":"terraform","project":"dss-formio"}` |    no    |
| log_level                  | Logging level (debug, info, warn, error)                                 | `string`      | `"info"`                                            |    no    |
| max_instance_count         | Maximum number of Cloud Run instances                                    | `number`      | `10`                                                |    no    |
| memory_limit               | Memory limit per instance                                                | `string`      | `"512Mi"`                                           |    no    |
| min_instance_count         | Minimum number of Cloud Run instances                                    | `number`      | `0`                                                 |    no    |
| node_env                   | Node.js environment (development, production)                            | `string`      | `"production"`                                      |    no    |
| otel_endpoint              | OpenTelemetry collector endpoint (empty to disable)                      | `string`      | `""`                                                |    no    |
| project_id                 | Google Cloud project ID                                                  | `string`      | n/a                                                 |   yes    |
| rate_limit_max             | Maximum requests per time window                                         | `number`      | `100`                                               |    no    |
| rate_limit_window_ms       | Rate limiting time window in milliseconds                                | `number`      | `60000`                                             |    no    |
| region                     | Google Cloud region for deployment                                       | `string`      | `"australia-southeast1"`                            |    no    |
| request_timeout            | Request timeout in seconds                                               | `number`      | `60`                                                |    no    |
| vpc_connector_id           | VPC connector ID for private networking (from central infrastructure)    | `string`      | n/a                                                 |   yes    |
| vpc_egress_setting         | VPC egress setting (PRIVATE_RANGES_ONLY recommended)                     | `string`      | `"PRIVATE_RANGES_ONLY"`                             |    no    |

## Outputs

| Name                        | Description                                      |
| --------------------------- | ------------------------------------------------ |
| backend_service_id          | Backend service ID for load balancer integration |
| backend_service_name        | Backend service name                             |
| backend_service_self_link   | Backend service self link                        |
| configuration               | Service configuration summary                    |
| container_port              | Container port                                   |
| health_check_id             | Health check ID                                  |
| health_check_url            | Health check endpoint URL                        |
| integration                 | Configuration for external integrations          |
| latest_revision             | Latest deployed revision                         |
| network_endpoint_group_id   | Network Endpoint Group ID                        |
| network_endpoint_group_name | Network Endpoint Group name                      |
| service_account_email       | Service account email                            |
| service_account_id          | Service account ID                               |
| service_name                | Cloud Run service name                           |
| service_url                 | Form Web BFF service URL                         |

## Validation

This module includes comprehensive input validation:

- **Container Port**: Must be between 1024 and 65535 (non-privileged ports)
- **Environment**: Must be one of: dev, staging, prod
- **Node Environment**: Must be development or production
- **Log Level**: Must be one of: debug, info, warn, error
- **Rate Limit Max**: Must be between 1 and 10000
- **Rate Limit Window**: Must be between 1000ms and 3600000ms
- **Memory Limit**: Must match format: `<number><unit>` (Ki, Mi, Gi)
- **CPU Limit**: Must match format: `<number>m` or `<number>`
- **VPC Egress**: Must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY

## Security

### Service Account Permissions

The module creates a service account with **least-privilege** permissions:

- `roles/logging.logWriter` - Write application logs
- `roles/monitoring.metricWriter` - Write custom metrics
- `roles/cloudtrace.agent` - Export traces
- `roles/run.invoker` (on formio-custom) - Service-to-service authentication

### VPC Egress Control

Recommended configuration:

```hcl
vpc_egress_setting = "PRIVATE_RANGES_ONLY"
```

This restricts outbound traffic to:

- Private VPC resources (MongoDB, Redis, Form.io custom service)
- Google APIs (via Private Google Access)

**Never use `ALL_TRAFFIC` in production** - it allows unrestricted internet
access.

### Public Access

```hcl
allow_unauthenticated = false  # Production default
```

Only enable `allow_unauthenticated = true` for development/staging environments.

Production should use:

- Cloud IAP (Identity-Aware Proxy)
- API Gateway with authentication
- Load Balancer with Cloud Armor

## Troubleshooting

### Port Configuration Issues

**Problem**: Health check fails with "Connection refused"

**Solution**: Verify port consistency across all layers:

```bash
# 1. Check Terraform variable
terraform plan | grep container_port

# 2. Check Dockerfile ARG
grep "ARG PORT" apps/form-web-bff-server/Dockerfile

# 3. Check Container ENV
grep "ENV PORT" apps/form-web-bff-server/Dockerfile

# 4. Check server.ts
grep "env.PORT" apps/form-web-bff-server/src/server.ts

# All should match (default: 3002)
```

### VPC Connectivity Issues

**Problem**: BFF cannot reach Form.io custom service

**Solution**:

1. Verify VPC connector is attached:
   `gcloud run services describe form-web-bff-dev`
2. Check egress setting: Should be `PRIVATE_RANGES_ONLY`
3. Verify IAM binding: BFF service account should have `roles/run.invoker` on
   formio-custom
4. Check Cloud Run logs:
   `gcloud logging read "resource.type=cloud_run_revision"`

### Service-to-Service Authentication Fails

**Problem**: 403 Forbidden when calling Form.io custom service

**Solution**:

```bash
# 1. Verify IAM binding exists
gcloud run services get-iam-policy formio-custom-dev \
  --region=australia-southeast1 \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/run.invoker"

# 2. Expected output should include:
# serviceAccount:form-web-bff-sa-dev@PROJECT_ID.iam.gserviceaccount.com

# 3. If missing, reapply Terraform
terraform apply -target=google_cloud_run_service_iam_member.formio_custom_invoker
```

### Load Balancer Health Check Fails

**Problem**: Backend service shows unhealthy backends

**Solution**:

1. Verify health check path: `/health/ready`
2. Check health check port matches container port
3. Test endpoint directly:
   ```bash
   curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
        https://form-web-bff-dev-xxxxx.run.app/health/ready
   ```
4. Check Cloud Run logs for startup errors

## Migration from Standalone Terraform

This module replaces the standalone Terraform configuration at
`apps/form-web-bff-server/terraform/`.

**Key Differences**:

| Aspect                  | Standalone     | Module                               |
| ----------------------- | -------------- | ------------------------------------ |
| Port Configuration      | Hardcoded 3002 | Variable-based (default: 3002)       |
| VPC Integration         | None           | Required (VPC connector)             |
| Load Balancer           | None           | NEG + Backend Service + Health Check |
| Service-to-Service Auth | Manual         | Automated IAM binding                |
| Monitoring              | Basic          | Logging + Monitoring + Tracing       |

**Migration Steps**:

1. Build Docker image with ARG PORT support
2. Deploy module to dev environment
3. Test all endpoints
4. Verify health checks pass
5. Delete standalone terraform configuration

See [ANALYSIS_SUMMARY.md](../../docs/ANALYSIS_SUMMARY.md) for complete migration
plan.

## Contributing

When modifying this module:

1. **Follow formio-custom-service pattern** - Maintain consistency
2. **Validate changes** - Run `terraform fmt`, `terraform validate`, `tflint`,
   `tfsec`
3. **Update documentation** - Regenerate with `terraform-docs`
4. **Test thoroughly** - Deploy to dev environment first
5. **Update CHANGELOG** - Document all changes

## References

- **PRD**:
  [docs/PRD_FORM_WEB_BFF_MODULE.md](../../docs/PRD_FORM_WEB_BFF_MODULE.md)
- **Analysis**: [docs/ANALYSIS_SUMMARY.md](../../docs/ANALYSIS_SUMMARY.md)
- **Cloud Run Docs**: https://cloud.google.com/run/docs
- **VPC Connector**:
  https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
- **Service-to-Service Auth**:
  https://cloud.google.com/run/docs/authenticating/service-to-service

## License

Proprietary - Qrius Global Pty Ltd

---

**Module Version**: 1.0.0 **Last Updated**: 2025-11-06 **Maintainer**: Platform
Team
