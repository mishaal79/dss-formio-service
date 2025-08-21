# Load Balancer Module - DEPRECATED

## ⚠️ DEPRECATION NOTICE

**This module is deprecated and will be removed in a future version.**

**Migration Date**: 2025-08-21
**Reason**: Transitioning to centralized load balancer architecture

## Migration Path

This load balancer module has been replaced by a **centralized load balancer architecture** managed in the shared infrastructure repository (`gcp-dss-erlich-infra-terraform`).

### What Changed

1. **Load balancer resources** (URL maps, forwarding rules, SSL certificates) are now managed centrally
2. **Backend services and NEGs** have been moved to individual service modules for better integration
3. **Cloud Armor security policies** are now applied at the centralized level

### Migration Steps

1. **Backend services and NEGs** are now created within the `formio-service` module
2. **Outputs** are exposed for centralized load balancer integration
3. **Security policies** and **SSL certificates** are managed by shared infrastructure
4. **DNS routing** is handled by the centralized load balancer

### New Architecture Benefits

- **Centralized SSL management**: Single place for certificate lifecycle
- **Unified security policies**: Consistent Cloud Armor rules across services
- **Simplified DNS routing**: Central management of domain-to-service mapping
- **Reduced resource duplication**: Shared load balancer infrastructure
- **Better cost optimization**: Single load balancer for multiple services

### Integration with Centralized Load Balancer

The Form.io service now exposes these outputs for centralized integration:

```hcl
# Backend service for load balancer integration
output "backend_service_id" {
  value = module.formio-service.backend_service_id
}

# Network endpoint group for load balancer integration
output "network_endpoint_group_id" {
  value = module.formio-service.network_endpoint_group_id
}
```

### Legacy Code

This module will remain available for a transition period but should not be used for new deployments.

---

**Last Updated**: 2025-08-21
**Status**: Deprecated - Do Not Use