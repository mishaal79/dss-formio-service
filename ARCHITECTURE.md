# Architecture Design Rationale

## Executive Summary

The DSS Form.io Service implements a cloud-native form management platform using Form.io on Google Cloud Platform. The architecture prioritizes simplicity, cost-effectiveness, and integration with central organizational infrastructure.

## Core Architectural Decisions

### 1. Database Strategy: MongoDB Only

**Decision**: Use MongoDB Atlas as the sole database platform.

**Rationale**:
- Form.io requires MongoDB as its primary datastore
- MongoDB Atlas provides managed operations, reducing maintenance overhead
- Flex tier offers cost-effective development/staging environments (~$9/month)
- Eliminates complexity of multi-database synchronization

**Rejected Alternatives**:
- PostgreSQL integration: Added unnecessary complexity without clear benefits
- Self-hosted MongoDB: Higher operational overhead and cost
- Multi-database architecture: Increased complexity and potential data consistency issues

### 2. Centralized Load Balancer Architecture

**Decision**: Leverage central infrastructure's centralized load balancer instead of service-specific load balancers.

**Rationale**:
- **Cost Reduction**: Single load balancer serves multiple services ($1,104/year savings for 5 services)
- **Simplified Management**: Centralized configuration and monitoring
- **Consistent Security**: Uniform security policies across services
- **Avoid Circular Dependencies**: Manual tfvars configuration prevents dependency loops

**Implementation Pattern**:

1. **Service creates backend**:
```hcl
# This service creates its backend service
resource "google_compute_backend_service" "formio_backend" {
  name = "formio-backend-${var.environment}"
  ...
}
```

2. **Service exports configuration**:
```hcl
output "backend_service_configuration" {
  value = {
    lb_host_rules = {
      "forms.dev.cloud.dsselectrical.com.au" = {
        backend_service_id = google_compute_backend_service.formio_backend.id
      }
    }
  }
}
```

3. **Central infrastructure configures routing** (manual step):
```hcl
# In gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/PROJECT/global/backendServices/formio-backend-dev"
  }
}
```

**Why Not Remote State?**
- Prevents circular dependencies (central infra reads service state, service reads central infra state)
- Explicit configuration control
- Stable production deployments
- Can be automated via CI/CD

### 3. Dual Edition Strategy

**Decision**: Deploy both Community and Enterprise editions of Form.io.

**Rationale**:
- **Risk Mitigation**: Fallback option if license expires
- **Feature Comparison**: Evaluate enterprise features against community
- **Cost Optimization**: Use community for non-critical forms
- **Gradual Migration**: Smooth transition path between editions

**Trade-offs**:
- Increased infrastructure complexity
- Higher resource consumption
- Requires careful traffic management

### 4. Serverless Compute (Cloud Run)

**Decision**: Use Cloud Run instead of Kubernetes or VMs.

**Rationale**:
- **Scale to Zero**: No costs during idle periods
- **Automatic Scaling**: Handles traffic spikes automatically
- **Simplified Operations**: No cluster management
- **Built-in HTTPS**: Automatic TLS termination

**Configuration**:
- Min instances: 0 (dev), 1 (prod)
- Max instances: 10 (dev), 100 (prod)
- Concurrency: 80 requests per instance
- Memory: 2Gi per instance

### 5. Secret Management Strategy

**Decision**: Use Google Secret Manager for all sensitive data.

**Rationale**:
- **Security**: Encrypted at rest and in transit
- **Audit Trail**: Complete access logging
- **Rotation Support**: Automated password rotation capability
- **Integration**: Native Cloud Run integration

**Implementation**:
- Auto-generated passwords for services
- Versioned secrets for rollback capability
- IAM-based access control

## Infrastructure Architecture

### Network Topology

```
Internet
    │
    ▼
Centralized Load Balancer (Shared Infrastructure)
    │
    ├──► Cloud Run (Form.io Community)
    │         │
    │         ├──► MongoDB Atlas (formio_community DB)
    │         └──► GCS Bucket (File Storage)
    │
    └──► Cloud Run (Form.io Enterprise)
              │
              ├──► MongoDB Atlas (formio_enterprise DB)
              └──► GCS Bucket (File Storage)
```

### Shared Infrastructure Integration

**VPC Architecture**:
- Shared VPC from `gcp-dss-erlich-infra-terraform`
- VPC Connector for private networking
- Cloud NAT for egress (license validation)

**Service Discovery**:
- Service registration via Terraform outputs
- Remote state consumption pattern
- Consistent backend naming convention

## Security Architecture

### Defense in Depth

1. **Network Security**
   - Private VPC with controlled egress
   - Cloud NAT for outbound connections
   - No direct internet exposure for databases

2. **Application Security**
   - Form.io built-in authentication
   - JWT token validation
   - Role-based access control

3. **Data Security**
   - TLS encryption in transit
   - Encryption at rest (GCS, MongoDB Atlas)
   - Secret Manager for credentials

4. **Operational Security**
   - Audit logging enabled
   - Least privilege IAM roles
   - Automated security updates

### Compliance Considerations

- **PCI-DSS**: Form data may contain payment information
- **Data Residency**: Australia-southeast region for data sovereignty
- **Backup**: Daily automated backups with point-in-time recovery

## Cost Optimization Strategy

### Resource Optimization

1. **MongoDB Atlas Flex Tier**
   - Cost: ~$9/month vs $57 for M10
   - Suitable for development/staging
   - Auto-scaling storage

2. **Cloud Run Scale-to-Zero**
   - No charges when idle
   - Automatic scaling based on load
   - Per-request billing model

3. **Shared Infrastructure**
   - Centralized load balancer reduces costs
   - Shared VPC and Cloud NAT
   - Consolidated monitoring and logging

### Estimated Monthly Costs (Dev Environment)

| Component | Cost |
|-----------|------|
| MongoDB Atlas Flex | $9 |
| Cloud Run (idle mostly) | $5-10 |
| Storage (GCS) | $2 |
| Load Balancer (shared) | $0 |
| **Total** | **~$16-21** |

## Operational Excellence

### Deployment Strategy

**GitOps Approach**:
```bash
make infra-plan    # Review changes
make infra-apply   # Deploy infrastructure
make deploy-all    # Deploy applications
```

**Blue-Green Deployments**:
- Deploy new version alongside existing
- Gradually shift traffic
- Quick rollback capability

### Monitoring and Observability

**Metrics**:
- Cloud Run request latency
- MongoDB connection pool stats
- Storage usage trends

**Logging**:
- Structured JSON logging
- Centralized in Cloud Logging
- Query-able via Log Explorer

**Alerting**:
- Service health checks
- License expiration warnings
- Resource quota alerts

## Technical Debt and Future Improvements

### Identified Technical Debt

1. **MongoDB Initialization Script**: Currently non-functional, needs implementation
2. **Environment Variable Management**: Should migrate to external secrets operator
3. **Testing Coverage**: Limited integration tests

### Planned Improvements

1. **Multi-Region Deployment**: For disaster recovery
2. **Advanced Monitoring**: Custom dashboards and SLO tracking
3. **Automated Backups**: Scheduled MongoDB exports to GCS
4. **CI/CD Pipeline**: Automated testing and deployment

## Decision Log

| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| 2024-01 | Remove PostgreSQL | Unnecessary complexity | -30% codebase |
| 2024-01 | Centralized LB | Cost and management | -$50/month |
| 2024-01 | MongoDB Atlas | Managed operations | -2 FTE hours/week |
| 2024-01 | Cloud Run | Serverless benefits | Scale-to-zero |

## Architecture Principles

### 1. Simplicity First
- Eliminate special cases
- Single source of truth
- Clear separation of concerns

### 2. Cost-Conscious Design
- Use managed services wisely
- Optimize for actual usage patterns
- Share infrastructure where possible

### 3. Security by Default
- Encrypt everything
- Least privilege access
- Defense in depth

### 4. Operational Excellence
- Infrastructure as Code
- Automated deployments
- Comprehensive monitoring

## Conclusion

This architecture balances simplicity, security, and cost-effectiveness while providing a robust platform for form management. The use of managed services reduces operational overhead, while the centralized load balancer pattern promotes infrastructure reuse and cost optimization.

The elimination of PostgreSQL and adoption of MongoDB-only architecture significantly simplifies the system, following the principle that "good taste" in engineering means eliminating special cases rather than adding complexity to handle them.

---
Last Updated: January 2025
Architecture Version: 2.0