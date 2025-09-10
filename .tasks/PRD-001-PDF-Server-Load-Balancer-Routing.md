# PRD-001: Form.io PDF Server Load Balancer Routing Integration

**Project:** gcp-dss-erlich-infra-terraform  
**Impact:** High - Critical functionality for PDF generation  
**Urgency:** High - Service degradation for users  
**Status:** Implementation Required  
**Created:** 2025-01-14  
**Owner:** Infrastructure Team  

---

## Executive Summary

The Form.io PDF server has been successfully deployed as a separate Cloud Run service but is currently unreachable due to missing load balancer routing configuration. This PRD defines the requirements for adding path-based routing rules to the centralized load balancer to enable PDF functionality.

---

## Problem Statement

### Current State
- ✅ Form.io Enterprise service deployed and accessible at `https://forms.dev.cloud.dsselectrical.com.au`
- ✅ PDF server service deployed as separate Cloud Run service
- ✅ Backend services created for both Form.io and PDF server
- ❌ **Missing:** Load balancer routing rules for PDF endpoints

### Issue Description
Client requests to PDF endpoints (e.g., `/pdf-proxy/pdf/68b28defc50aa8520e67eb0d/file`) are failing because:
1. No routing rule exists for `/pdf/*` or `/pdf-proxy/*` paths
2. All traffic currently routes to Form.io Enterprise backend by default
3. PDF server backend service exists but is not integrated into load balancer

### Business Impact
- **User Impact:** PDF generation features are completely non-functional
- **Service Impact:** Core Form.io functionality degraded
- **Compliance Impact:** Document generation workflows broken

---

## Technical Requirements

### Architecture Pattern
Following Form.io's official load balancer documentation pattern:

```
Main Application (/) → Form.io Enterprise Backend (port 3000)
PDF Endpoints (/pdf/*) → PDF Server Backend (port 4005)
```

### Backend Service Information
From `dss-formio-service` terraform outputs:

#### Form.io Enterprise Backend
- **Service:** `dss-formio-api-ent-dev`
- **Backend Service ID:** `projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev`
- **Port:** 3000
- **Purpose:** Main Form.io application, APIs, web interface

#### PDF Server Backend  
- **Service:** `dss-formio-api-pdf-dev`
- **Backend Service ID:** `projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev`
- **Port:** 4005
- **Purpose:** PDF generation, file processing

### Routing Requirements

#### Path-Based Routing Rules
The load balancer must route traffic based on URL paths:

1. **Default Route (`/`)**
   - **Target:** Form.io Enterprise backend
   - **Backend Service ID:** `projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev`
   - **Purpose:** Main application traffic

2. **PDF Route (`/pdf/*`)**
   - **Target:** PDF server backend
   - **Backend Service ID:** `projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev`
   - **Purpose:** PDF generation requests
   - **Path Rewriting:** Not required (PDF server expects `/pdf/` prefix)

3. **Legacy PDF Route (`/pdf-proxy/*`)** *(Backward Compatibility)*
   - **Target:** PDF server backend
   - **Backend Service ID:** `projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev`
   - **Purpose:** Support existing client code during transition
   - **Path Rewriting:** May require rewriting `/pdf-proxy/(.*)` → `/pdf/$1`

---

## Implementation Specification

### File Location
**Project:** `gcp-dss-erlich-infra-terraform`  
**File:** `environments/dev/terraform.tfvars`

### Configuration Changes Required

#### Current Configuration Template
```hcl
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev"
  }
}
```

#### Required New Configuration
```hcl
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    # Default traffic routes to Form.io Enterprise
    default_backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev"
    
    # Path-based routing rules
    path_rules = [
      {
        # PDF server routing (primary path)
        paths = ["/pdf", "/pdf/*"]
        backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev"
        description = "Route PDF generation requests to dedicated PDF server"
      },
      {
        # Backward compatibility for existing clients
        paths = ["/pdf-proxy", "/pdf-proxy/*"]
        backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev"
        description = "Legacy PDF routing for backward compatibility"
        # Note: May require path rewriting depending on implementation
      }
    ]
  }
}
```

### Path Rewriting Considerations
Depending on the load balancer module implementation, path rewriting may be needed for `/pdf-proxy/*` paths:
- **If supported:** Rewrite `/pdf-proxy/(.*)` → `/pdf/$1`
- **If not supported:** PDF server must handle both path patterns

---

## Verification Requirements

### Pre-Implementation Validation
- [ ] Confirm both backend services exist and are healthy
- [ ] Verify backend service IDs match the specification above
- [ ] Test current load balancer routing (should show Form.io Enterprise only)

### Implementation Validation
- [ ] **Terraform Plan:** Review plan output for correct resource changes
- [ ] **No Service Disruption:** Existing Form.io functionality remains operational
- [ ] **Clean Apply:** Terraform apply completes without errors

### Post-Implementation Testing

#### Automated Testing
```bash
# Test main application (should continue working)
curl -I https://forms.dev.cloud.dsselectrical.com.au/

# Test PDF server routing (should now work)
curl -I https://forms.dev.cloud.dsselectrical.com.au/pdf/health

# Test legacy PDF routing (if implemented)
curl -I https://forms.dev.cloud.dsselectrical.com.au/pdf-proxy/pdf/health
```

#### Functional Testing
- [ ] **Form.io Web Interface:** Access main application successfully
- [ ] **PDF Generation:** Create and export PDF from Form.io interface
- [ ] **API Endpoints:** Verify Form.io REST API continues functioning
- [ ] **PDF API Endpoints:** Test direct PDF API calls work correctly

#### Load Balancer Verification
```bash
# Check load balancer configuration
gcloud compute url-maps describe [URL_MAP_NAME] --global

# Monitor load balancer logs for correct backend targeting
gcloud logging read "resource.type=http_load_balancer" --limit=50
```

---

## Implementation Steps

### Phase 1: Preparation
1. **Backend Service Verification**
   ```bash
   # In dss-formio-service project
   cd terraform/environments/dev
   terraform output pdf_server_backend_service_id
   terraform output formio_backend_service_id
   ```

2. **Current State Documentation**
   - Document current load balancer configuration
   - Take screenshots of working Form.io functionality
   - Record current routing behavior

### Phase 2: Configuration Update
1. **Update terraform.tfvars**
   - Add path-based routing configuration as specified above
   - Validate syntax and structure

2. **Terraform Validation**
   ```bash
   # In gcp-dss-erlich-infra-terraform project
   terraform validate
   terraform plan
   ```

### Phase 3: Implementation
1. **Apply Changes**
   ```bash
   terraform apply
   ```

2. **Monitor Deployment**
   - Watch terraform apply progress
   - Monitor load balancer health status
   - Check for any error conditions

### Phase 4: Validation
1. **Execute all verification tests** (as defined above)
2. **User Acceptance Testing**
   - Test PDF generation through Form.io interface
   - Verify no regression in existing functionality

---

## Risk Assessment & Mitigation

### High Risk: Service Disruption
- **Risk:** Load balancer changes could disrupt existing Form.io service
- **Mitigation:** 
  - Implement during maintenance window
  - Have rollback plan ready
  - Test in staging environment first (if available)

### Medium Risk: Path Rewriting Issues
- **Risk:** `/pdf-proxy/*` paths may not route correctly without proper rewriting
- **Mitigation:**
  - Implement `/pdf/*` routing first (primary requirement)
  - Add `/pdf-proxy/*` as secondary enhancement
  - Update client code to use `/pdf/*` paths gradually

### Low Risk: Backend Service Changes
- **Risk:** Backend service IDs may change between deployment and implementation
- **Mitigation:**
  - Verify backend service IDs immediately before implementation
  - Use terraform outputs to get current values

---

## Rollback Plan

### Immediate Rollback
If issues occur during or immediately after deployment:
```bash
# Revert to previous terraform state
git checkout HEAD~1 -- terraform.tfvars
terraform apply
```

### Partial Rollback
If PDF routing causes issues but main service works:
```hcl
# Remove path_rules temporarily, keep default routing
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev"
  }
}
```

### Full Rollback Criteria
- Main Form.io service becomes inaccessible
- Terraform apply fails or causes infrastructure errors
- Load balancer health checks fail consistently

---

## Success Criteria

### Primary Success Criteria
- [ ] **PDF Generation Works:** Users can generate PDFs through Form.io interface
- [ ] **No Service Regression:** Existing Form.io functionality remains unchanged
- [ ] **Clean Implementation:** No terraform errors or warnings

### Secondary Success Criteria  
- [ ] **API Access:** Direct PDF API calls work via `/pdf/*` endpoints
- [ ] **Backward Compatibility:** Legacy `/pdf-proxy/*` paths work (if implemented)
- [ ] **Performance:** No degradation in load balancer response times

### Acceptance Criteria
- [ ] **User Testing:** Business users confirm PDF functionality works end-to-end
- [ ] **Technical Testing:** All automated tests pass
- [ ] **Monitoring:** Load balancer logs show correct routing to both backends

---

## Dependencies & Prerequisites

### Infrastructure Dependencies
- ✅ Form.io Enterprise service deployed and healthy
- ✅ PDF server service deployed and healthy  
- ✅ Backend services created for both services
- ✅ Central infrastructure project accessible

### Access Requirements
- [ ] Access to `gcp-dss-erlich-infra-terraform` project
- [ ] Terraform apply permissions for central infrastructure
- [ ] GCP project admin access for verification commands

### Knowledge Requirements
- Understanding of GCP Load Balancer path-based routing
- Familiarity with terraform configuration structure
- Knowledge of Form.io PDF functionality for testing

---

## Appendix

### Backend Service Health Check
```bash
# Verify Form.io Enterprise backend health
gcloud run services describe dss-formio-api-ent-dev --region=australia-southeast1

# Verify PDF server backend health  
gcloud run services describe dss-formio-api-pdf-dev --region=australia-southeast1
```

### Terraform Output Reference
```bash
# Get complete backend service configuration template
cd terraform/environments/dev
terraform output backend_service_configuration

# Get specific PDF server backend service ID
terraform output pdf_server_backend_service_id

# Get Form.io backend service ID
terraform output formio_backend_service_id
```

### Related Documentation
- [Form.io Load Balancer Configuration](https://help.form.io/deployments/deployment-configurations/load-balancer-configuration)
- [PDF_SERVER_DEPLOYMENT.md](../PDF_SERVER_DEPLOYMENT.md)
- [CLAUDE.md - Central Infrastructure Integration](../CLAUDE.md#central-infrastructure-integration)

---

**Document Status:** Ready for Implementation  
**Next Action:** Infrastructure team to implement configuration changes  
**Review Required:** Solution Architect approval before implementation