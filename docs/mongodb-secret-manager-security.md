# MongoDB Secret Manager Security Implementation

## Overview
This document describes the enhanced security implementation for MongoDB authentication using Google Cloud Secret Manager instead of plaintext passwords.

## Architecture

### Secret Manager Integration
- **Admin Password**: `${service_name}-mongodb-admin-password-${environment}`
- **Form.io Password**: `${service_name}-mongodb-formio-password-${environment}`  
- **Connection String**: `${service_name}-mongodb-connection-string-${environment}`

### Security Benefits
1. **Zero Plaintext Passwords**: No passwords stored in Terraform state or configuration files
2. **Runtime Retrieval**: Passwords retrieved from Secret Manager at runtime
3. **Audit Trail**: All secret access logged in Cloud Audit Logs
4. **IAM Control**: Fine-grained access control via Service Account permissions
5. **Automatic Rotation Ready**: Infrastructure supports password rotation for production

## Cost Analysis
- **Storage**: 3 secrets × $0.06/month = $0.18/month
- **API Calls**: ~100 calls/month × $0.03/10k = $0.003/month
- **Total**: ~$2.52/year for MongoDB secrets

## Implementation Details

### MongoDB Module Changes
- Added separate Secret Manager secrets for admin and Form.io passwords
- Updated startup script to retrieve passwords securely
- Enhanced backup script with Secret Manager integration
- Added proper IAM bindings for service account access

### Cloud Run Integration
- Updated MONGO environment variable to use Secret Manager
- Added IAM binding for connection string secret access
- Maintains secure Form.io container deployment

### Security Features
- Password variables cleared from memory after use
- Enhanced error handling for secret retrieval failures
- Separate authentication testing for both users
- Secure backup operations using Secret Manager

## Usage

### Initial Deployment
```bash
# Generate secrets
./scripts/setup-deployment-secrets.sh

# Deploy infrastructure
cd terraform/environments/dev
terraform plan
terraform apply
```

### Accessing Secrets (Admin)
```bash
# Get admin password
gcloud secrets versions access latest \
  --secret="dss-formio-api-mongodb-admin-password-dev" \
  --project="erlich-dev"

# Get connection string
gcloud secrets versions access latest \
  --secret="dss-formio-api-mongodb-connection-string-dev" \
  --project="erlich-dev"
```

### MongoDB Access
```bash
# Connect as admin
mongosh --authenticationDatabase admin -u mongoAdmin -p [password]

# Connect as Form.io user
mongosh --authenticationDatabase formio -u formioUser -p [password]
```

## Production Considerations

### Password Rotation (Future)
- Script created: `scripts/rotate-mongodb-passwords.sh` (parked for production)
- Supports automated password rotation with zero downtime
- Updates Secret Manager and restarts Cloud Run service

### Monitoring
- Secret access events logged in Cloud Audit Logs
- MongoDB authentication logged via Cloud Ops Agent
- Cloud Run service health monitored

### Backup Security
- Backup script uses Secret Manager for authentication
- Encrypted backups stored in Cloud Storage
- Automatic cleanup of local backup files

## Security Best Practices Implemented
1. ✅ Least privilege IAM permissions
2. ✅ No hardcoded credentials
3. ✅ Secure secret storage and retrieval
4. ✅ Memory cleanup after password use
5. ✅ Comprehensive error handling
6. ✅ Audit logging for all operations
7. ✅ Network isolation via VPC
8. ✅ Encrypted data at rest and in transit

This implementation provides enterprise-level security for MongoDB authentication while maintaining cost efficiency compared to MongoDB Atlas.