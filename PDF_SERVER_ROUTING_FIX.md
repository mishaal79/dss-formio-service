# PDF Server Routing Fix Implementation Guide

## Problem Summary

The PDF server is deployed and running correctly, but client requests to PDF endpoints are failing because the central load balancer lacks proper routing rules for PDF traffic.

**Root Cause:** Missing load balancer path-based routing configuration for `/pdf/*` endpoints.

## Current vs Required Architecture

### Current Setup (Broken)
```
Client Request: https://forms.dev.cloud.dsselectrical.com.au/pdf-proxy/pdf/68b28defc50aa8520e67eb0d/file
  ↓
Load Balancer: No routing rule for /pdf-proxy/* or /pdf/*
  ↓
Default Route: Routes to Form.io Enterprise backend
  ↓
Result: 404 or wrong service handling the request
```

### Required Setup (Fixed)
```
Client Request: https://forms.dev.cloud.dsselectrical.com.au/pdf/68b28defc50aa8520e67eb0d/file
  ↓
Load Balancer: /pdf/* → PDF Server backend
  ↓
PDF Server: dss-formio-api-pdf-backend-dev (port 4005)
  ↓
Result: PDF generated and returned successfully
```

## Infrastructure Analysis

### Form.io Services (✅ Correct)
- **Enterprise Service:** `dss-formio-api-ent-dev` on port 3000
- **PDF Server:** `dss-formio-api-pdf-dev` on port 4005
- **Backend Services:** Both services have backend services created

### Port Configuration (✅ Resolved)
- **Form.io Enterprise:** Uses port 3000 (correct, following Form.io standards)
- **PDF Server:** Uses port 4005 (correct, following Form.io standards)
- **Legacy Module:** cloud-run module (port 3001) is unused - can be ignored

### Backend Service IDs
- **Form.io Enterprise:** `projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev`
- **PDF Server:** `projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev`

## Implementation Steps

### Step 1: Update Central Load Balancer Configuration

**File:** `gcp-dss-erlich-infra-terraform/environments/dev/terraform.tfvars`

**Required Configuration:**
```hcl
lb_host_rules = {
  "forms.dev.cloud.dsselectrical.com.au" = {
    # Default traffic goes to Form.io Enterprise
    default_backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-ent-backend-dev"
    
    # Path-based routing rules
    path_rules = [
      {
        # PDF server routing (following Form.io documentation pattern)
        paths = ["/pdf", "/pdf/*"]
        backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev"
      },
      {
        # Backward compatibility for existing /pdf-proxy paths
        paths = ["/pdf-proxy", "/pdf-proxy/*"]
        backend_service_id = "projects/erlich-dev/global/backendServices/dss-formio-api-pdf-backend-dev"
      }
    ]
  }
}
```

### Step 2: Form.io Configuration Update

**Current PDF_SERVER Environment Variable:**
The Form.io Enterprise service should be configured with:
```
PDF_SERVER=https://forms.dev.cloud.dsselectrical.com.au
```

This tells Form.io to construct PDF URLs as:
`https://forms.dev.cloud.dsselectrical.com.au/pdf/...`

### Step 3: Apply Infrastructure Changes

1. **Update Central Infrastructure:**
   ```bash
   cd gcp-dss-erlich-infra-terraform/environments/dev
   terraform plan
   terraform apply
   ```

2. **Verify Load Balancer Configuration:**
   ```bash
   gcloud compute url-maps describe [URL_MAP_NAME] --global
   ```

### Step 4: Test PDF Functionality

1. **Test PDF Generation:**
   - Access Form.io web interface
   - Create/open a form
   - Generate PDF export
   - Verify PDF downloads successfully

2. **Test API Endpoints:**
   ```bash
   # Test main API
   curl https://forms.dev.cloud.dsselectrical.com.au/status
   
   # Test PDF server routing
   curl https://forms.dev.cloud.dsselectrical.com.au/pdf/health
   ```

## Routing Logic Explanation

### Path-Based Routing Rules
Following Form.io's NGINX configuration pattern, adapted for GCP Load Balancer:

1. **Default Route (`/`):** → Form.io Enterprise Backend
   - Handles main application, API endpoints, web interface
   - Port 3000

2. **PDF Route (`/pdf/*`):** → PDF Server Backend
   - Handles all PDF generation requests
   - Port 4005
   - Direct routing (no path rewrite needed at load balancer level)

3. **Backward Compatibility (`/pdf-proxy/*`):** → PDF Server Backend
   - Maintains compatibility with existing client code
   - Can be removed after client code is updated

### Client URL Patterns
- ✅ **Recommended:** `https://forms.dev.cloud.dsselectrical.com.au/pdf/FORM_ID/file`
- ✅ **Temporary Support:** `https://forms.dev.cloud.dsselectrical.com.au/pdf-proxy/pdf/FORM_ID/file`
- ❌ **Current (Broken):** No routing rule exists for either pattern

## Verification Checklist

- [ ] Load balancer routing rules updated in central infrastructure
- [ ] Form.io Enterprise PDF_SERVER environment variable configured correctly
- [ ] PDF generation works from Form.io web interface
- [ ] Direct PDF API calls work via `/pdf/` paths
- [ ] Main Form.io API endpoints continue to work
- [ ] Load balancer routing logs show correct backend targeting

## Architecture Benefits

1. **Unified Interface:** Single domain for all Form.io services
2. **Proper Isolation:** PDF processing isolated to dedicated service
3. **Scalability:** PDF server can scale independently
4. **Security:** No direct exposure of internal service URLs
5. **Form.io Compliance:** Follows Form.io's documented architecture patterns

## Future Improvements

1. **Remove Legacy Paths:** After testing, remove `/pdf-proxy/*` routing rules
2. **Health Checks:** Add health check routing for both services
3. **Rate Limiting:** Implement rate limiting on PDF endpoints
4. **Caching:** Consider CDN caching for static PDF files