# Naming Conventions

This document defines the naming conventions used throughout the DSS Form.io Service infrastructure, following Qrius GCP methodology standards.

## General Principles

1. **Consistency**: All resources follow the same naming patterns
2. **Readability**: Names are descriptive and human-readable
3. **Uniqueness**: Names include environment and randomization where needed
4. **Length Limits**: Respect GCP resource name length limitations
5. **Case Sensitivity**: Use appropriate case for each resource type

## Primary Naming Pattern

The core pattern used across all resources:

```
{project}-{service}-{component}-{environment}
```

Where:
- `project`: `dss-formio` (project identifier)
- `service`: Service component (e.g., `api`, `storage`, `db`)
- `component`: Specific component (e.g., `bucket`, `secret`, `sa`)
- `environment`: `dev`, `staging`, `prod`

## Resource-Specific Conventions

### Google Cloud Run Services
**Pattern**: `{project}-{service}-{environment}`
**Examples**:
- `dss-formio-api-dev`
- `dss-formio-api-staging`
- `dss-formio-api-prod`

### Service Accounts
**Pattern**: `{project}-{service}-sa-{environment}`
**Examples**:
- `dss-formio-api-sa-dev`
- `dss-formio-api-sa-staging`
- `dss-formio-api-sa-prod`

### Secret Manager Secrets
**Pattern**: `{project}-{service}-{secret-type}-{environment}`
**Examples**:
- `dss-formio-api-jwt-secret-dev`
- `dss-formio-api-license-key-prod`
- `dss-formio-api-db-secret-staging`

### Storage Buckets
**Pattern**: `{project}-{service}-{environment}-{random-suffix}`
**Examples**:
- `dss-formio-storage-dev-a1b2c3`
- `dss-formio-storage-prod-x9y8z7`

**Note**: Buckets include random suffix for global uniqueness

### PostgreSQL Instances
**Pattern**: `{project}-{service}-{environment}`
**Examples**:
- `dss-formio-postgres-dev`
- `dss-formio-postgres-prod`

### VPC Connectors
**Pattern**: `{project}-vpc-connector-{environment}`
**Examples**:
- `dss-formio-vpc-connector-dev`
- `dss-formio-vpc-connector-prod`

### Pub/Sub Topics
**Pattern**: `{project}-{event-type}-{environment}`
**Examples**:
- `dss-formio-form-events-dev`
- `dss-formio-submissions-prod`
- `dss-formio-webhooks-staging`

### Pub/Sub Subscriptions
**Pattern**: `{project}-{event-type}-sub-{environment}`
**Examples**:
- `dss-formio-form-events-sub-dev`
- `dss-formio-submissions-sub-prod`

## Terraform Resource Names

### Variables
**Convention**: `snake_case`
**Examples**:
- `formio_license_key`
- `mongodb_connection_string`
- `service_account_email`

### Outputs
**Convention**: `snake_case`
**Examples**:
- `formio_service_url`
- `storage_bucket_name`
- `vpc_connector_id`

### Terraform Resources
**Convention**: `snake_case` with descriptive names
**Examples**:
```hcl
resource "google_cloud_run_v2_service" "formio_service" {}
resource "google_service_account" "formio_service_account" {}
resource "google_secret_manager_secret" "formio_jwt_secret" {}
```

### Module Names
**Convention**: `kebab-case`
**Examples**:
- `cloud-run`
- `secret-manager`
- `vpc-networking`

## Environment-Specific Variations

### Development Environment
- **Focus**: Cost optimization and development ease
- **Naming**: Standard pattern with `dev` suffix
- **Examples**: Lower-tier resources, relaxed security

### Staging Environment  
- **Focus**: Production-like testing
- **Naming**: Standard pattern with `staging` suffix
- **Examples**: Mid-tier resources, production security

### Production Environment
- **Focus**: High availability and security
- **Naming**: Standard pattern with `prod` suffix
- **Examples**: High-tier resources, strict security

## Labels and Tags

All resources include consistent labels:

```hcl
labels = {
  environment = "dev|staging|prod"
  project     = "dss-formio"
  managed_by  = "terraform"
  cost_center = "engineering"
  tier        = "development|staging|production"
}
```

## Validation Rules

Naming conventions are enforced through:

1. **TFLint Configuration**: `.tflint.hcl` validates naming patterns
2. **Variable Validation**: Terraform variable validation blocks
3. **Pre-commit Hooks**: Automated validation before commits
4. **CI/CD Pipeline**: Validation in deployment pipeline

## Special Cases

### Shared Infrastructure Integration
When using shared infrastructure from `gcp-dss-erlich-infra-terraform`:
- Reference shared resources by their established names
- Maintain consistency with shared naming patterns
- Document shared resource dependencies

### MongoDB Atlas Resources
Follow Atlas naming conventions while maintaining consistency:
- **Project**: `dss-formio-{environment}`
- **Cluster**: `dss-formio-{environment}-cluster`

### Custom Domains
When using custom domains:
- **Development**: `forms-dev.qrius.global`
- **Staging**: `forms-staging.qrius.global`  
- **Production**: `forms.qrius.global`

## Common Mistakes to Avoid

1. **Inconsistent Casing**: Don't mix `snake_case` and `kebab-case`
2. **Missing Environment**: Always include environment suffix
3. **Generic Names**: Avoid generic names like `bucket1` or `service`
4. **Length Violations**: Check GCP length limits before naming
5. **Special Characters**: Avoid unsupported characters in resource names

## Migration Strategy

When updating existing resources to follow these conventions:

1. **Plan Changes**: Use `terraform plan` to review name changes
2. **Import Resources**: Use `terraform import` to avoid recreation
3. **Update Dependencies**: Update all references to renamed resources
4. **Test Thoroughly**: Validate all functionality after renaming

## Tools and Automation

### TFLint Rules
```hcl
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}
```

### Pre-commit Validation
Automated validation runs on every commit to ensure naming compliance.

### Documentation Generation
Resource names are automatically documented in module README files.

## References

- [GCP Resource Naming Best Practices](https://cloud.google.com/resource-manager/docs/creating-managing-projects#before_you_begin)
- [Terraform Naming Conventions](https://www.terraform.io/docs/extend/best-practices/naming.html)
- [Qrius GCP Methodology](/.claude/qrius-terraform-gcp-preferences.md)