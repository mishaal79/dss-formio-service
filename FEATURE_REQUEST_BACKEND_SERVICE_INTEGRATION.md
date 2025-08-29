# Feature Request: Automated Backend Service Integration for Centralized Load Balancer

**Date**: 2025-08-29  
**Requested By**: Platform Team  
**Priority**: High  
**Impact**: Infrastructure-wide improvement affecting all services

## Executive Summary

Currently, integrating services with the centralized load balancer requires manual configuration updates in the central infrastructure repository. This feature request proposes an automated backend service discovery and integration mechanism that would eliminate manual steps, reduce errors, and improve deployment velocity.

## Problem Statement

### Current Situation
When deploying a new service (like Form.io) that needs to be accessible through the centralized load balancer:

1. **Service Team** deploys their infrastructure using Terraform
2. **Service Team** manually extracts backend service ID from outputs
3. **Service Team** creates a PR to update `gcp-dss-erlich-infra-terraform/environments/*/terraform.tfvars`
4. **Infrastructure Team** reviews and approves the PR
5. **Infrastructure Team** applies the central infrastructure changes
6. **Service** becomes accessible through the load balancer

### Pain Points
- **Manual Process**: Requires coordination between multiple teams
- **Error-Prone**: Copy-paste errors in backend service IDs
- **Slow**: Multiple PRs and approvals needed for simple integrations
- **Scaling Issues**: Process becomes unwieldy with many services
- **Drift Risk**: Services can be deleted without updating central config

### Example of Current Manual Process
```hcl
# Current: Manual update required in central infrastructure
# File: gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars

lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/erlich-dev/global/backendServices/formio-backend-dev"
  }
  # Each new service requires manual addition here
}
```

## Proposed Solution

### Automated Backend Service Discovery
Implement a service registration pattern where services can self-register with the centralized load balancer through one of these approaches:

#### Option 1: Service Catalog with Labels (Recommended)
Services tag their backend services with standardized labels that the central infrastructure can discover:

```hcl
# In service repository (e.g., dss-formio-service)
resource "google_compute_backend_service" "formio_backend" {
  name = "formio-backend-${var.environment}"
  
  labels = {
    "load-balancer-integration" = "enabled"
    "hostname"                   = "forms.${var.environment}.cloud.dsselectrical.com.au"
    "managed-by"                 = "terraform"
    "service"                    = "formio"
  }
}
```

```hcl
# In central infrastructure
data "google_compute_backend_service" "registered_services" {
  for_each = toset(var.registered_domains)
  
  filter = "labels.load-balancer-integration=enabled AND labels.hostname=${each.key}"
}

# Automatically configure load balancer with discovered services
resource "google_compute_url_map" "main" {
  dynamic "host_rule" {
    for_each = data.google_compute_backend_service.registered_services
    
    content {
      hosts        = [host_rule.value.labels.hostname]
      path_matcher = host_rule.key
    }
  }
}
```

#### Option 2: Shared State with Service Registry
Create a service registry module that both service and central infrastructure can use:

```hcl
# Shared module: terraform/modules/service-registry
variable "service_registrations" {
  type = map(object({
    hostname           = string
    backend_service_id = string
    health_check_path  = string
  }))
}

output "registered_services" {
  value = var.service_registrations
}
```

#### Option 3: GCS-Based Configuration Store
Services write their configuration to a GCS bucket that central infrastructure reads:

```hcl
# Service writes configuration
resource "google_storage_bucket_object" "service_config" {
  name   = "${var.service_name}-${var.environment}.json"
  bucket = "org-service-registry"
  
  content = jsonencode({
    hostname           = "forms.${var.environment}.cloud.dsselectrical.com.au"
    backend_service_id = google_compute_backend_service.formio_backend.id
    health_check_path  = "/health"
    created_at         = timestamp()
  })
}

# Central infrastructure reads configurations
data "google_storage_bucket_objects" "service_configs" {
  bucket = "org-service-registry"
  prefix = "${var.environment}/"
}
```

## Technical Implementation Details

### Prerequisites
- Standardized naming conventions for backend services
- Consistent labeling strategy across all services
- Service account permissions for cross-project resource discovery

### Implementation Steps

1. **Phase 1: Foundation** (Week 1-2)
   - Define standardized label schema
   - Create service discovery module
   - Set up permissions for cross-project access

2. **Phase 2: Pilot** (Week 3-4)
   - Implement with Form.io service as pilot
   - Test automated discovery and routing
   - Document patterns and best practices

3. **Phase 3: Rollout** (Week 5-8)
   - Migrate existing services to new pattern
   - Update CI/CD pipelines
   - Deprecate manual tfvars updates

### Backwards Compatibility
- Support both manual and automated patterns during transition
- Automated discovery takes precedence over manual configuration
- Provide migration script for existing services

## Benefits

### Immediate Benefits
- **Faster Deployments**: No waiting for central infrastructure updates
- **Fewer Errors**: Eliminate manual copy-paste mistakes
- **Better Autonomy**: Service teams can fully manage their deployments
- **Improved Visibility**: Centralized view of all registered services

### Long-term Benefits
- **Scalability**: Easy to add new services without bottlenecks
- **Consistency**: Enforced patterns through automation
- **Auditability**: Clear tracking of service registrations
- **Cost Optimization**: Automatic cleanup of unused backend services

## Success Metrics

- **Deployment Time**: Reduce from 2-3 days to < 1 hour
- **Manual Interventions**: Reduce from 2-3 per service to 0
- **Configuration Errors**: Reduce from ~10% to < 1%
- **Service Onboarding**: Increase from 2-3/month to 10+/month

## Security Considerations

- **Access Control**: Services can only register their own backend services
- **Validation**: Hostname ownership verification before registration
- **Audit Logging**: Track all service registration changes
- **Rate Limiting**: Prevent abuse of registration system

## Migration Plan

### For New Services
Immediately use the automated pattern with no manual tfvars updates required.

### For Existing Services
1. Add required labels to existing backend services
2. Verify automated discovery works correctly
3. Remove manual configuration from tfvars
4. Monitor for 24 hours before confirming success

### Rollback Strategy
If issues occur, manual tfvars configuration takes precedence, allowing immediate rollback.

## Example Integration

### Before (Manual Process)
```bash
# 1. Service team deploys
terraform apply

# 2. Service team gets backend service ID
terraform output backend_service_configuration

# 3. Service team creates PR to central repo
# 4. Wait for review and approval
# 5. Infrastructure team applies changes
```

### After (Automated Process)
```bash
# 1. Service team deploys with labels
terraform apply

# Done! Service automatically integrated with load balancer
```

## Cost Analysis

### Implementation Cost
- **Development**: 2 engineer-weeks
- **Testing**: 1 engineer-week
- **Documentation**: 0.5 engineer-week
- **Total**: ~3.5 engineer-weeks

### Savings
- **Manual Work Eliminated**: 2-4 hours per service deployment
- **Reduced Errors**: Avoid 1-2 incident per quarter from misconfigurations
- **Faster Time-to-Market**: Services available 2-3 days sooner
- **ROI**: Positive after 5-10 service deployments

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Service misconfiguration | Medium | Validation rules and automated testing |
| Permission issues | Low | Clear IAM role templates |
| Discovery performance | Low | Caching and rate limiting |
| Breaking changes | High | Backwards compatibility layer |

## Alternative Solutions Considered

1. **GitHub Actions Integration**: Rejected due to complexity and GitOps preferences
2. **Manual API Calls**: Rejected due to lack of declarative configuration
3. **Consul/Istio Service Mesh**: Rejected due to operational overhead

## Recommendation

Implement **Option 1 (Service Catalog with Labels)** as it:
- Requires minimal changes to existing infrastructure
- Leverages native GCP functionality
- Provides good visibility and debugging capabilities
- Scales well with the organization's growth

## Next Steps

1. **Approval**: Get stakeholder buy-in on the approach
2. **Design Review**: Detailed technical design with infrastructure team
3. **POC**: Implement proof-of-concept with Form.io service
4. **Production Rollout**: Gradual migration of all services

## Appendix: Current Manual Configuration Example

Current configuration that would be automated:

```hcl
# File: gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/erlich-dev/global/backendServices/formio-backend-dev"
  }
}
```

## References

- [Google Cloud Load Balancing Documentation](https://cloud.google.com/load-balancing/docs)
- [Terraform Google Provider - Backend Services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service)
- [Current Manual Process Documentation](./docs/central-infrastructure-integration.md)

---

**Contact**: Platform Team - platform-team@dss.com  
**Slack Channel**: #infrastructure-automation  
**Related Tickets**: INFRA-2024-001, FORMIO-2024-015