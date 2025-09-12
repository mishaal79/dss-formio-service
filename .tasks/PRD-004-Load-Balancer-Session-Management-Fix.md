# PRD-004: Fix Session Expiry - Load Balancer Affinity Mismatch

**Status:** Implementation Required  
**Issue:** Users kicked out after 1 hour  
**Root Cause:** Session affinity TTL (1hr) < JWT token lifetime (4hrs)  

---

## Problem

- **Session affinity:** `CLIENT_IP` with 1-hour TTL
- **JWT tokens:** Valid for 4 hours  
- **Result:** Users redistributed to different backend instances after 1 hour = logged out

---

## Solution

### Central Infrastructure (This Repo)
**No changes required.** Load balancer correctly references backend service IDs from tfvars.

### Service Repository Changes (`dss-formio-service`)

```hcl
# terraform/modules/formio-service/main.tf
resource "google_compute_backend_service" "formio_backend" {
  # Change session affinity to match JWT lifetime
  session_affinity        = "GENERATED_COOKIE"  # was CLIENT_IP
  affinity_cookie_ttl_sec = 14400              # 4 hours (was 3600)
  
  # Keep CDN enabled - it only caches static assets
  enable_cdn = true  # KEEP THIS
  
  # timeout_sec may not work for Cloud Run NEGs - ignore if it fails
  timeout_sec = 90
}
```

```hcl
# Add to Cloud Run environment variables
env {
  name  = "JWT_EXPIRE_TIME"
  value = "240"  # 4 hours in minutes
}
```

---

## Testing

1. Deploy to dev
2. Login and wait 65+ minutes
3. Verify session persists (no logout)
4. Confirm `GENERATED_COOKIE` works with Cloud Run NEGs

---

## Warnings

- **Cloud Run NEGs may ignore** `timeout_sec` on backend service
- **Verify** `GENERATED_COOKIE` session affinity is supported
- **Health checks** not supported for Cloud Run NEGs (automatic)
- **CDN must stay enabled** for form loading performance

---

## Rollback

```bash
# If GENERATED_COOKIE doesn't work, revert to CLIENT_IP
gcloud compute backend-services update dss-formio-api-ent-backend-dev \
  --global --session-affinity=CLIENT_IP --project=erlich-dev
```