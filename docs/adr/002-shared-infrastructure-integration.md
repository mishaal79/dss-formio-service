# ADR-002: Shared Infrastructure Integration

## Status
Accepted

## Date
2025-01-09

## Context
The DSS Form.io Service needs to integrate with existing shared infrastructure from the `gcp-dss-erlich-infra-terraform` project to optimize costs, maintain consistency, and leverage existing security and networking configurations.

## Decision
We have decided to **integrate with shared infrastructure** from `gcp-dss-erlich-infra-terraform` while maintaining the ability to deploy standalone infrastructure when shared resources are not available.

## Rationale

### Cost Optimization
- **Shared VPC**: Leverage existing VPC infrastructure instead of creating duplicate networking
- **Shared VPC Connectors**: Reuse existing VPC connectors for Cloud Run networking
- **Shared Security Groups**: Utilize existing firewall rules and security policies
- **Reduced Overhead**: Lower operational overhead by leveraging shared monitoring and logging

### Consistency and Governance
- **Standardized Networking**: Consistent networking patterns across organization
- **Centralized Security**: Unified security policies and compliance frameworks
- **Shared Monitoring**: Consistent observability across all services
- **Governance Alignment**: Follows organizational infrastructure governance

### Flexibility and Resilience
- **Conditional Integration**: Can deploy with or without shared infrastructure
- **Fallback Capability**: Ability to create local infrastructure when shared is unavailable
- **Environment Flexibility**: Different environments can use different integration levels

## Implementation Details

### Remote State Integration
```hcl
data "terraform_remote_state" "shared_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-erlich-terraform-state"
    prefix = "shared-infra/{environment}"
  }
}
```

### Conditional Resource Creation
```hcl
module "networking" {
  count  = var.shared_vpc_id == null ? 1 : 0
  source = "./modules/networking"
  # ... configuration
}
```

### Shared Resource Variables
```hcl
variable "shared_vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
  default     = null
}

variable "shared_vpc_connector_id" {
  description = "VPC Connector ID from shared infrastructure"
  type        = string
  default     = null
}
```

### Dynamic VPC Configuration
```hcl
vpc_connector_id = var.shared_vpc_connector_id != null ? 
  var.shared_vpc_connector_id : 
  (length(module.networking) > 0 ? module.networking[0].vpc_connector_id : null)
```

## Consequences

### Positive
- ✅ **Cost Reduction**: Shared infrastructure reduces overall GCP costs
- ✅ **Consistency**: Uniform networking and security across projects
- ✅ **Operational Efficiency**: Reduced infrastructure maintenance overhead
- ✅ **Security**: Leverage proven security configurations from shared infrastructure
- ✅ **Compliance**: Inherit compliance frameworks from shared infrastructure

### Negative
- ❌ **Dependency**: Creates dependency on shared infrastructure project
- ❌ **Complexity**: Additional complexity in terraform configuration
- ❌ **Coordination**: Requires coordination with shared infrastructure team

### Neutral
- 🔄 **Flexibility**: Maintains ability to deploy standalone when needed
- 🔄 **Testing**: Can test both shared and standalone configurations
- 🔄 **Migration**: Clear migration path between shared and standalone

## Integration Points

### Networking Integration
- **VPC**: Reference shared VPC for private networking
- **Subnets**: Use shared private subnets for Cloud Run
- **VPC Connectors**: Leverage existing VPC connectors
- **Firewall Rules**: Inherit shared security group configurations

### Security Integration
- **IAM Policies**: Align with shared IAM frameworks
- **Secret Management**: Use shared Secret Manager instances where appropriate
- **Security Scanning**: Leverage shared security scanning tools
- **Compliance**: Inherit shared compliance controls

### Monitoring Integration
- **Logging**: Route logs to shared logging infrastructure
- **Monitoring**: Use shared monitoring and alerting systems
- **Metrics**: Contribute metrics to shared observability platform

## Environment Strategy

### Development Environment
- **Integration Level**: Optional shared infrastructure
- **Fallback**: Local infrastructure for independence
- **Testing**: Both shared and standalone configurations

### Staging Environment
- **Integration Level**: Full shared infrastructure integration
- **Purpose**: Test production-like shared infrastructure
- **Validation**: Verify shared resource dependencies

### Production Environment
- **Integration Level**: Full shared infrastructure integration
- **Benefits**: Maximum cost optimization and consistency
- **Resilience**: Documented fallback procedures

## Risk Mitigation

### Shared Infrastructure Unavailability
- **Risk**: Shared infrastructure unavailable or incompatible
- **Mitigation**: Conditional deployment with local infrastructure fallback
- **Testing**: Regular testing of standalone deployment mode

### Version Compatibility
- **Risk**: Shared infrastructure version incompatibilities
- **Mitigation**: Version pinning and compatibility testing
- **Process**: Coordinated updates with shared infrastructure team

### State Dependencies
- **Risk**: Terraform state dependency issues
- **Mitigation**: Proper remote state configuration and error handling
- **Recovery**: Documented state recovery procedures

## Monitoring and Success Criteria

### Success Metrics
- Successful deployment with shared infrastructure in staging/production
- Cost reduction compared to standalone infrastructure
- Consistent security posture across shared and Form.io infrastructure
- Minimal operational overhead for shared resource management

### Monitoring
- Infrastructure cost tracking (shared vs standalone)
- Deployment success rates with shared infrastructure
- Security compliance alignment metrics
- Operational incident correlation with shared infrastructure

## Testing Strategy

### Integration Testing
- Test deployment with shared infrastructure available
- Test deployment with shared infrastructure unavailable
- Validate all networking and security integrations
- Verify monitoring and logging integration

### Compatibility Testing
- Test shared infrastructure version updates
- Validate remote state access and dependencies
- Test disaster recovery scenarios
- Verify cross-environment consistency

## Alternative Considered

### Standalone Infrastructure Only
- **Pros**: Complete independence, no external dependencies
- **Cons**: Higher costs, duplicated infrastructure, inconsistent security
- **Decision**: Rejected due to cost and consistency benefits of shared approach

### Mandatory Shared Infrastructure
- **Pros**: Maximum cost optimization, forced consistency
- **Cons**: Inflexibility, dependency risk, deployment complexity
- **Decision**: Rejected due to flexibility and resilience requirements

## Future Considerations

### Shared Infrastructure Evolution
- Monitor shared infrastructure roadmap and feature evolution
- Evaluate new shared services for integration opportunities
- Assess impact of shared infrastructure changes on Form.io service

### Cost Optimization
- Regular review of shared vs standalone cost implications
- Evaluate additional shared services for integration
- Monitor usage patterns to optimize shared resource utilization

## References
- [Qrius GCP Methodology](/.claude/qrius-terraform-gcp-preferences.md)
- [Shared Infrastructure Project](https://github.com/qrius/gcp-dss-erlich-infra-terraform)
- [Terraform Remote State Documentation](https://www.terraform.io/docs/language/state/remote.html)
- [GCP Shared VPC Documentation](https://cloud.google.com/vpc/docs/shared-vpc)