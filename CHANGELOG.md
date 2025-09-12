# Changelog

All notable changes to the DSS Form.io Service will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-15

### Added
- **GCS S3-Compatible Configuration Guide**: Comprehensive standalone documentation for Form.io support representatives
  - Complete GCS bucket setup instructions with CORS configuration
  - Server environment variable configuration reference
  - Critical portal configuration steps for enabling MinIO mode
  - Form component configuration guidelines
  - Troubleshooting steps and common mistake prevention
  - Technical details about URL generation differences

### Documentation
- **Repository Cleanup**: Removed outdated and redundant documentation files
  - Removed completed PRD documents (1_PRD.md)
  - Removed superseded PDF server docs (PDF_SERVER_DEPLOYMENT.md, PDF_SERVER_ROUTING_FIX.md)
  - Removed duplicate architecture documentation (terraform/ARCHITECTURE.md)
  - Removed outdated Google integration setup guide (docs/google-integration-setup.md)
  - Removed legacy task documents (.tasks/ directory)
  - Cleaned up empty documentation directories

### Changed
- **Documentation Structure**: Streamlined documentation for better maintainability
  - Consolidated critical information in main README.md
  - Created focused GCS configuration guide for external sharing
  - All documentation references updated to current structure

### Technical Implementation
- **GCS S3-Compatible Storage**: Successfully implemented file upload functionality
  - Portal configuration: "Use MinIO Server" checkbox enables path-style URLs
  - Server configuration: All environment variables properly set via Terraform
  - Response validation: Server returns `"minio": true` for correct URL generation
  - S3 Multipart uploads working for large files

## [1.0.0] - 2025-01-12

### Added
- **PRD-003**: S3-compatible file upload functionality using GCS backend
  - HMAC key generation for GCS S3-compatible API access
  - Environment variables for S3 configuration (FORMIO_S3_SERVER, FORMIO_S3_BUCKET, etc.)
  - Comprehensive documentation for Form.io portal file storage configuration
  - Secret Manager integration for secure credential storage
  - Portal configuration reference values in .env.template
  - Configuration defaults in terraform.tfvars.example

- **PRD-004**: Load balancer session management improvements
  - Changed backend service session affinity from CLIENT_IP to GENERATED_COOKIE
  - Increased cookie TTL to 14400 seconds (4 hours) for persistent sessions
  - Added JWT_EXPIRE_TIME environment variable (240 minutes) to match session TTL
  - CDN remains enabled for static asset caching

### Fixed
- **PRD-002**: PDF server 403 authorization errors (previously completed)
  - Enabled public access for PDF server Cloud Run service
  - Fixed IAM bindings for proper service invocation

- **PRD-004**: User session expiry after 1 hour
  - Resolved mismatch between session affinity TTL and JWT token lifetime
  - Users now maintain sessions for full 4-hour JWT validity period

### Changed
- Backend service configuration updated to remove unsupported timeout_sec for serverless NEGs
- Session management moved from IP-based to cookie-based affinity
- File storage configuration changed from GCS-native to S3-compatible for better Form.io integration

### Infrastructure
- Terraform modules updated for S3-compatible storage support
- Secret Manager resources added for HMAC key storage
- Backend service configurations optimized for Cloud Run NEGs
- In-place updates ensure no central load balancer reconfiguration needed

### Documentation
- Added comprehensive S3 storage configuration section to README.md
- Portal configuration instructions with correct GCS endpoints
- Reference configuration values in .env.template
- PRD completion status updated with implementation details

### Security
- All file upload credentials stored in Google Secret Manager
- HMAC keys generated for service account authentication
- No hardcoded credentials in codebase
- Proper IAM bindings for service accounts

## [0.9.0] - Previous Release

### Initial Implementation
- Form.io Enterprise and Community edition deployments
- MongoDB Atlas integration
- PDF server deployment
- Central infrastructure integration
- Basic storage bucket configuration

---

[1.1.0]: https://github.com/dss/dss-formio-service/releases/tag/v1.1.0
[1.0.0]: https://github.com/dss/dss-formio-service/releases/tag/v1.0.0
[0.9.0]: https://github.com/dss/dss-formio-service/releases/tag/v0.9.0