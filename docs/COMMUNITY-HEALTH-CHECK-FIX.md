# Form.io Community Edition Health Check Configuration

## Issue Summary
The Form.io Community Edition service was failing health checks on Cloud Run because:
1. The `/health` endpoint doesn't exist in the Community edition (unlike Enterprise)
2. The service was configured to use port 8080 (Cloud Run's default) instead of 3001 (Community's default)
3. HTTP health probes were checking a non-existent endpoint

## Root Cause Analysis

### Port Mismatch
- **Cloud Run v2** automatically sets the `PORT` environment variable to 8080
- **Form.io Community** defaults to port 3001 (configured in `/app/config/default.json`)
- Our wrapper script was using `${PORT:-8080}` which conflicted with Community's expectations

### Missing Health Endpoint
- The Community edition routes (in `index.js`) don't define a `/health` endpoint
- Available endpoints include: `/spec.json`, `/config.json`, `/access`, `/token`
- HTTP health checks to `/health` would timeout waiting for a response

## Solution Implemented

### 1. Port Configuration
Changed the container port from 8080 to 3001 throughout:
```hcl
locals {
  container_port = 3001  # Community Edition's default port
}
```

### 2. Wrapper Script Fix
Updated the wrapper script to explicitly use port 3001:
```bash
--argjson port 3001  # Previously: ${PORT:-8080}
```

### 3. Health Probe Configuration
Replaced HTTP health checks with TCP socket probes:

#### Startup Probe
```hcl
startup_probe {
  tcp_socket {
    port = 3001
  }
  initial_delay_seconds = 180  # 3 minutes for MongoDB connection
  timeout_seconds       = 30
  period_seconds        = 60
  failure_threshold     = 10
}
```

#### Liveness Probe
```hcl
liveness_probe {
  tcp_socket {
    port = 3001
  }
  initial_delay_seconds = 120
  timeout_seconds       = 30
  period_seconds        = 60
  failure_threshold     = 3
}
```

## Alternative Approaches

### Using Existing HTTP Endpoints
If HTTP health checks are preferred, use existing endpoints:
- `/spec.json` - Returns OpenAPI specification
- `/config.json` - Returns public configuration
- `/access` - Access handler endpoint

Example:
```hcl
startup_probe {
  http_get {
    path = "/spec.json"
    port = 3001
  }
  # ... timing configuration
}
```

### TCP Socket Advantages
- Simpler - just checks if service is listening on the port
- More reliable - doesn't depend on specific endpoint implementation
- Faster - no HTTP request processing overhead

## Deployment Notes

### Manual gcloud Update
Due to Terraform state lock issues, the probes were updated via gcloud:
```bash
gcloud run services update formio-community-dev \
  --project=erlich-dev \
  --region=australia-southeast1 \
  --startup-probe="tcpSocket.port=3001,..." \
  --liveness-probe="httpGet.port=3001,httpGet.path=/spec.json,..."
```

### Service Status
- Service URL: `https://formio-community-dev-kx62qbq7iq-ts.a.run.app`
- Port: 3001
- Health Check: TCP socket probe on port 3001
- Status: ✅ Ready and serving

## Lessons Learned

1. **Know Your Defaults**: Form.io Community uses port 3001, not 3000 (Enterprise) or 8080 (Cloud Run)
2. **Verify Endpoints**: Always check if health endpoints exist before configuring HTTP probes
3. **TCP Probes**: Consider TCP socket probes for simpler health checking when HTTP endpoints are problematic
4. **Port Variables**: Be careful with Cloud Run's reserved `PORT` environment variable in v2

## References
- Form.io Community routes: See `index.js` in the Form.io repository
- Cloud Run probe documentation: https://cloud.google.com/run/docs/configuring/healthchecks
- TCP socket probe benefits: Simple port listening check without endpoint dependencies