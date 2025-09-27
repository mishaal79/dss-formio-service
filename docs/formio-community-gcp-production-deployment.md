# Form.io Community Edition GCP Production Deployment Guide

## Overview

This guide documents the complete deployment of Form.io Community Edition on Google Cloud Platform (GCP) with production-grade infrastructure including Cloud Run, Load Balancer integration, TLS termination, and MongoDB Atlas.

## Architecture Summary

- **Application**: Form.io Community Edition (Open Source)
- **Container Platform**: GCP Cloud Run
- **Database**: MongoDB Atlas Flex Cluster
- **Storage**: Google Cloud Storage with S3-compatible API
- **Load Balancer**: GCP Application Load Balancer with HTTPS termination
- **Networking**: VPC integration with central infrastructure
- **Secrets**: Google Secret Manager

## Key Research Findings

### GCP Load Balancer Integration ✅
- Form.io Community Edition fully supports GCP Cloud Run load balancer integration
- Uses standard Serverless Network Endpoint Groups (NEGs)
- HTTPS termination at load balancer level with Express.js trust proxy support
- Official Form.io documentation confirms GCP Cloud Run deployment capabilities

### TLS Termination Capabilities ✅
- Standard Express.js trust proxy configuration for X-Forwarded headers
- TLS termination at GCP Load Balancer (industry best practice)
- Same security model as Enterprise edition
- No special licensing or Enterprise features required

### Community Edition Configuration ✅
- Official `formio/formio:rc` Docker image from Docker Hub
- Port 3001 (vs Enterprise 3000)
- NODE_CONFIG JSON structure for configuration
- No license key required (open source)

## Prerequisites

### Required Access
- GCP Project with enabled APIs (Cloud Run, Secret Manager, Storage)
- MongoDB Atlas account with API keys
- Access to central infrastructure repository (`gcp-dss-erlich-infra-terraform`)

### Required Software
- **Terraform** >= 1.6.0
- **Google Cloud SDK** (gcloud authenticated)
- **Make** (for automation commands)
- **Docker** (for local development)

## Local Development Setup

### Directory Structure
```
formio-community-local/
├── docker-compose.yml          # Local Form.io + MongoDB
├── .env                        # Environment variables
├── config/
│   └── formio-config.json     # Form.io configuration
└── data/
    └── mongodb/               # MongoDB data persistence
```

### Local Docker Compose Configuration

**Environment Variables (.env):**
```bash
# MongoDB Configuration
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=securepassword
MONGO_DATABASE=formio

# Form.io Configuration
FORMIO_ROOT_EMAIL=admin@example.com
FORMIO_ROOT_PASSWORD=admin123
FORMIO_JWT_SECRET=your-jwt-secret-change-me-now
FORMIO_DB_SECRET=your-db-secret-change-me-now

# GCS Storage (Optional for local testing)
GCS_BUCKET_NAME=your-test-bucket
GCS_ACCESS_KEY=your-access-key
GCS_SECRET_KEY=your-secret-key
```

**Docker Compose Services:**
- **MongoDB**: mongo:6.0 with authentication
- **Form.io Community**: formio/formio:rc with NODE_CONFIG
- **Networking**: Bridge network for service communication
- **Persistence**: MongoDB data volume mounting

### Local Development Commands
```bash
# Start local environment
cd formio-community-local
docker-compose up -d

# Access Form.io
open http://localhost:3001

# View logs
docker-compose logs -f formio-community

# Stop environment
docker-compose down
```

## GCP Production Deployment

### Infrastructure Components

**1. Cloud Run Service:**
- Container: `formio/formio:rc`
- Port: 3001 (Community Edition standard)
- Ingress: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`
- Scaling: Min instances 1 (always warm)

**2. Backend Service:**
- Protocol: HTTP
- Load balancing scheme: EXTERNAL
- CDN enabled for static content
- Trust proxy headers for TLS termination

**3. Network Endpoint Group:**
- Type: Serverless NEG
- Backend: Cloud Run service
- Region: australia-southeast1

**4. Load Balancer Integration:**
- HTTPS termination at load balancer
- Custom request headers for proxy trust
- CDN configuration for performance

### Environment Variable Configuration

**NODE_CONFIG Structure:**
```json
{
  "mongo": "mongodb://connection-string",
  "port": 3001,
  "host": "0.0.0.0",
  "protocol": "http",
  "jwt": {
    "secret": "from-secret-manager",
    "expireTime": 240
  },
  "db": {
    "secret": "from-secret-manager"
  },
  "trust_proxy": true
}
```

**Additional Environment Variables:**
- `ROOT_EMAIL`: Admin account email
- `ROOT_PASSWORD`: Admin account password (from Secret Manager)
- `DB_SECRET`: Database encryption secret
- `FORMIO_FILES_SERVER`: "s3" for GCS integration
- `FORMIO_S3_SERVER`: "https://storage.googleapis.com"
- `FORMIO_S3_BUCKET`: GCS bucket name
- `FORMIO_S3_REGION`: "auto"

### Terraform Configuration

**Community Service Module:**
```hcl
resource "google_cloud_run_v2_service" "formio_community" {
  name     = "formio-community-${var.environment}"
  location = var.region
  project  = var.project_id

  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    containers {
      image = "formio/formio:rc"
      ports {
        name           = "http1"
        container_port = 3001
      }

      env {
        name  = "NODE_CONFIG"
        value = jsonencode({
          mongo = data.google_secret_manager_secret_version.mongodb_connection.secret_data
          port  = 3001
          host  = "0.0.0.0"
          protocol = "http"
          jwt = {
            secret = data.google_secret_manager_secret_version.jwt_secret.secret_data
          }
          trust_proxy = true
        })
      }
    }
  }
}
```

**Backend Service Configuration:**
```hcl
resource "google_compute_backend_service" "formio_community_backend" {
  name                  = "formio-community-backend-${var.environment}"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  enable_cdn            = true

  backend {
    group = google_compute_region_network_endpoint_group.formio_community_neg.id
  }

  custom_request_headers = [
    "X-Forwarded-Proto:https"
  ]
}
```

## Database Configuration

### MongoDB Atlas Integration
- **Cluster Type**: Flex (cost-effective development)
- **Provider**: GCP australia-southeast1
- **Database Name**: `formio_community`
- **Connection**: SRV format with authentication
- **Security**: TLS encryption + credential authentication

### Connection String Format
```
mongodb+srv://username:password@cluster-url/formio_community?retryWrites=true&w=majority
```

## Storage Configuration

### Google Cloud Storage Integration
- **Bucket**: Auto-generated with environment suffix
- **API**: S3-compatible interface
- **Authentication**: HMAC keys via Service Account
- **Path Structure**: `com/dev/uploads/`

### HMAC Key Configuration
```bash
# Access Key ID from Secret Manager
gcloud secrets versions access latest \
  --secret="formio-community-gcs-s3-key-dev"

# Secret Access Key from Secret Manager
gcloud secrets versions access latest \
  --secret="formio-community-gcs-s3-secret-dev"
```

## Load Balancer & TLS Configuration

### TLS Termination
- **Location**: GCP Application Load Balancer
- **Certificate**: Google-managed SSL certificate
- **Backend Communication**: HTTP (load balancer to Cloud Run)
- **Trust Proxy**: Enabled for proper header handling

### Load Balancer Features
- **CDN**: Enabled for static content caching
- **Session Affinity**: Cookie-based (14400 seconds)
- **Health Checks**: Cloud Run internal health checks
- **Logging**: Full request logging enabled

### Trust Proxy Configuration
Form.io Community Edition handles proxy headers correctly:
- `X-Forwarded-Host`: Used for hostname determination
- `X-Forwarded-Proto`: Used for protocol detection
- `X-Forwarded-For`: Used for client IP detection

## Deployment Workflow

### Phase 1: Infrastructure Setup
```bash
# Update Terraform configuration
# terraform/environments/dev/terraform.tfvars
deploy_community = true
community_version = "rc"
deploy_enterprise = true  # Keep both for comparison

# Deploy infrastructure
make init
make plan
make apply
```

### Phase 2: Application Deployment
```bash
# Deploy community service
make deploy-com IMG=formio/formio:rc

# Verify deployment
make status
make show-versions
make logs-com
```

### Phase 3: Load Balancer Integration
```bash
# Get backend service configuration
cd terraform/environments/dev
terraform output backend_service_configuration

# Update central infrastructure
# Add backend service ID to gcp-dss-erlich-infra-terraform tfvars
# Apply central infrastructure changes
```

## Service Access & Testing

### Access Points
- **Community Edition**: `https://forms-community.dev.cloud.dsselectrical.com.au`
- **Enterprise Edition**: `https://forms.dev.cloud.dsselectrical.com.au`

### API Testing
```bash
# Health check
curl -X GET https://forms-community.dev.cloud.dsselectrical.com.au/health

# Current user endpoint
curl -X GET https://forms-community.dev.cloud.dsselectrical.com.au/current

# Project listing
curl -X GET https://forms-community.dev.cloud.dsselectrical.com.au/project
```

### Admin Portal Access
- **URL**: `https://forms-community.dev.cloud.dsselectrical.com.au/admin`
- **Email**: Configured via `ROOT_EMAIL` environment variable
- **Password**: Auto-generated in Secret Manager

## Monitoring & Operations

### Health Monitoring
```bash
# Service status
make status

# Application logs
make logs-com

# Resource usage
gcloud run services describe formio-community-dev \
  --region=australia-southeast1 \
  --format="value(status.conditions)"
```

### Performance Metrics
- **CDN Hit Rate**: Monitor via GCP Console
- **Response Times**: Cloud Run metrics
- **Error Rates**: Application logs
- **Database Performance**: MongoDB Atlas dashboard

## Security Considerations

### Network Security
- **VPC Integration**: Private network communication
- **Ingress Control**: Internal load balancer only
- **Egress Control**: Controlled via central VPC

### Data Security
- **Secrets Management**: Google Secret Manager
- **Database Encryption**: TLS in transit, encryption at rest
- **File Storage**: Private GCS bucket with IAM controls
- **Authentication**: JWT tokens with secure secrets

### Compliance
- **PCI DSS**: Considerations for form data handling
- **GDPR**: Data residency in australia-southeast1
- **SOC 2**: Cloud provider compliance inheritance

## Cost Optimization

### Resource Optimization
- **Cloud Run**: Scales to zero when idle
- **MongoDB Atlas Flex**: Cost-effective cluster type (~$9/month)
- **CDN**: Reduces origin requests and bandwidth costs
- **Storage Lifecycle**: Automatic archival of old files

### Cost Monitoring
```bash
# Cloud Run billing
gcloud billing budgets list

# Storage usage
gsutil du -s gs://bucket-name

# MongoDB Atlas costs
# Monitor via Atlas dashboard
```

## Troubleshooting

### Common Issues

**1. Service Unavailable (503)**
- Check Cloud Run service status
- Verify load balancer backend health
- Review application logs for startup errors

**2. Database Connection Failed**
- Verify MongoDB Atlas connection string
- Check network connectivity from Cloud Run
- Validate credentials in Secret Manager

**3. File Upload Errors**
- Verify GCS bucket permissions
- Check HMAC key configuration
- Confirm S3-compatible API settings

### Debug Commands
```bash
# Service details
gcloud run services describe formio-community-dev \
  --region=australia-southeast1

# Secret values (careful)
gcloud secrets versions access latest \
  --secret=formio-community-root-password-dev

# Network connectivity test
gcloud run services proxy formio-community-dev \
  --port=8080 --region=australia-southeast1
```

## Maintenance & Updates

### Update Procedure
1. Test new version in local Docker environment
2. Update image tag in deployment command
3. Deploy to Cloud Run service
4. Monitor health checks and logs
5. Roll back if issues detected

### Backup Strategy
- **Database**: MongoDB Atlas automated backups
- **Configuration**: Terraform state in GCS
- **Secrets**: Secret Manager versioning
- **Application Code**: Git repository backup

## Production Readiness Checklist

### Pre-Deployment
- [ ] Environment variables configured
- [ ] Secrets stored in Secret Manager
- [ ] MongoDB Atlas cluster provisioned
- [ ] GCS bucket created with proper IAM
- [ ] Load balancer configuration verified

### Post-Deployment
- [ ] Health checks passing
- [ ] Admin portal accessible
- [ ] File upload functionality working
- [ ] API endpoints responding correctly
- [ ] Monitoring and alerting configured

### Performance Validation
- [ ] Response times < 300ms
- [ ] CDN hit rate > 80%
- [ ] Database connection stable
- [ ] Zero error rate
- [ ] Scaling behavior verified

## Support & Documentation

### Internal Resources
- **Repository**: `dss-formio-service`
- **Branch**: `feature/formio-community-edition`
- **Central Infrastructure**: `gcp-dss-erlich-infra-terraform`

### External Resources
- **Form.io Community Docs**: [GitHub - formio/formio](https://github.com/formio/formio)
- **GCP Cloud Run Docs**: [cloud.google.com/run/docs](https://cloud.google.com/run/docs)
- **MongoDB Atlas Docs**: [docs.atlas.mongodb.com](https://docs.atlas.mongodb.com)

---

**Last Updated**: January 2025
**Version**: 1.0
**Environment**: Development/Production Ready