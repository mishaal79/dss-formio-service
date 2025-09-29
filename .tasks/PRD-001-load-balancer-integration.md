# PRD-001: Form.io Community Edition Load Balancer Integration

## Executive Summary
Integrate Form.io Community Edition with the centralized Google Cloud Load Balancer to enable production-ready access via `forms-community.dev.cloud.dsselectrical.com.au`.

## Current State
- ✅ Form.io Community service deployed on Cloud Run
- ✅ Backend service created: `formio-community-backend-dev`
- ✅ Network Endpoint Group created: `formio-community-neg-dev`
- ✅ Service healthy with TCP-only health checks
- ⏳ Not yet accessible via custom domain

## Objective
Enable secure, performant access to Form.io Community Edition through the organization's centralized load balancer with CDN caching and SSL termination.

## Requirements

### Technical Requirements
1. **Load Balancer Configuration**
   - Add host rule for `forms-community.dev.cloud.dsselectrical.com.au`
   - Route to backend service `formio-community-backend-dev`
   - Enable Cloud CDN for static content caching
   - Configure session affinity (4-hour cookie persistence)

2. **DNS Configuration**
   - Ensure DNS record exists for `forms-community.dev.cloud.dsselectrical.com.au`
   - Point to centralized load balancer IP

3. **SSL/TLS**
   - Use existing wildcard certificate for `*.dev.cloud.dsselectrical.com.au`
   - Enforce HTTPS-only access

### Performance Requirements
- Response time: <300ms for cached content
- Availability: 99.9% uptime
- Session persistence: 4 hours
- CDN cache hit ratio: >80% for static assets

## Implementation Plan

### Phase 1: Central Infrastructure Update (30 mins)
**Repository**: `gcp-dss-erlich-infra-terraform`

1. **Update terraform.tfvars**
   ```hcl
   # File: environments/dev/terraform.tfvars
   # Add to lb_host_rules section:

   "forms-community.dev.cloud.dsselectrical.com.au" = {
     backend_service_id = "projects/erlich-dev/global/backendServices/formio-community-backend-dev"
   }
   ```

2. **Apply Terraform Changes**
   ```bash
   cd gcp-dss-erlich-infra-terraform/environments/dev
   terraform plan
   terraform apply
   ```

3. **Verify Load Balancer Configuration**
   ```bash
   gcloud compute url-maps describe [URL_MAP_NAME] --format=json | jq '.hostRules'
   ```

### Phase 2: DNS Verification (15 mins)

1. **Check DNS Record**
   ```bash
   nslookup forms-community.dev.cloud.dsselectrical.com.au
   ```

2. **Verify SSL Certificate Coverage**
   - Certificate should cover `*.dev.cloud.dsselectrical.com.au`
   - Already managed by central infrastructure

### Phase 3: Testing & Validation (30 mins)

1. **Connectivity Test**
   ```bash
   curl -I https://forms-community.dev.cloud.dsselectrical.com.au
   # Expected: 200 OK or 404 (Form.io has no root endpoint)
   ```

2. **CDN Cache Verification**
   ```bash
   curl -I https://forms-community.dev.cloud.dsselectrical.com.au/static/file.js
   # Check for: x-cache-status header
   ```

3. **Session Affinity Test**
   - Make multiple requests
   - Verify same backend instance via logs

4. **Performance Test**
   ```bash
   # Response time measurement
   for i in {1..10}; do
     curl -w "@curl-format.txt" -o /dev/null -s https://forms-community.dev.cloud.dsselectrical.com.au
   done
   ```

### Phase 4: Monitoring Setup (15 mins)

1. **Cloud Monitoring Dashboard**
   - Backend service health
   - Request latency
   - Error rates
   - CDN hit ratio

2. **Alerting Policies**
   - Backend unhealthy > 2 mins
   - Error rate > 1%
   - Latency > 1s

## Success Criteria
- [ ] Service accessible via https://forms-community.dev.cloud.dsselectrical.com.au
- [ ] SSL certificate valid and active
- [ ] CDN caching operational (verify headers)
- [ ] Session affinity working (4-hour persistence)
- [ ] Response time <300ms for cached content
- [ ] No health check failures
- [ ] Monitoring dashboards operational

## Rollback Plan
If issues occur:
1. Remove host rule from central load balancer
2. Service remains accessible via direct Cloud Run URL
3. No impact to existing Enterprise Edition

## Dependencies
- Access to `gcp-dss-erlich-infra-terraform` repository
- Terraform apply permissions for central infrastructure
- DNS management access (if new record needed)

## Timeline
- Total implementation: 1.5 hours
- Testing & validation: 30 minutes
- Total effort: 2 hours

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| DNS propagation delay | Medium | Use direct LB IP for testing |
| Certificate mismatch | Low | Using wildcard cert |
| Backend unhealthy | Medium | Service has proven health checks |

## Post-Implementation Tasks
1. Update documentation with new URL
2. Configure Form.io admin portal access
3. Set up user authentication
4. Create initial projects/forms

## Approval
- [ ] Platform Team Lead
- [ ] Security Review
- [ ] Infrastructure Team

---
**Created**: 2025-09-29
**Status**: Ready for Implementation
**Owner**: Platform Team