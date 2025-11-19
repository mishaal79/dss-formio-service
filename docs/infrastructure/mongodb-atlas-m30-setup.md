# MongoDB Atlas M30 Cluster Setup Guide

## Overview

This guide documents the setup and deployment of MongoDB Atlas M30 dedicated clusters for the Form.io production environment. The M30 tier provides a production-ready replica set with dedicated resources, automated backups, and point-in-time recovery.

## Architecture

### Cluster Specifications

- **Tier**: M30 (Dedicated cluster)
- **Type**: Replica set (3 nodes)
- **Provider**: Google Cloud Platform (GCP)
- **Region**: AUSTRALIA_SOUTHEAST_1
- **MongoDB Version**: 7.0
- **Storage**: Auto-scaling enabled
- **Backup**: Cloud backup with Point-In-Time recovery

### Database Structure

- **Community Database**: `formio_community` - For Form.io Community features
- **Enterprise Database**: `formio_enterprise` - For Form.io Enterprise features

### Users

1. **Admin User** (`mongoAdmin`): Full administrative access
2. **Community User** (`formioUser_community`): Read/write access to community database
3. **Enterprise User** (`formioUser_enterprise`): Read/write access to enterprise database
4. **Monitoring User** (`formioUser_monitoring`): Read-only access for monitoring

## Prerequisites

### 1. MongoDB Atlas Account Setup

1. Create a MongoDB Atlas account at https://cloud.mongodb.com
2. Create an organization or use existing one
3. Note the Organization ID from Organization Settings

### 2. MongoDB Atlas API Keys

1. Navigate to Organization Settings > Access Manager > API Keys
2. Create a new API Key with Organization Owner permissions
3. Save the Public and Private keys securely
4. Whitelist your IP address for API access

### 3. GCP Service Account

Ensure you have a GCP service account with the following permissions:
- Secret Manager Admin
- Storage Admin
- Cloud Run Admin

## Configuration

### 1. Environment Variables

Set the following environment variables before running Terraform:

```bash
# MongoDB Atlas API Credentials (REQUIRED)
export MONGODBATLAS_PUBLIC_KEY="your-public-key"
export MONGODBATLAS_PRIVATE_KEY="your-private-key"

# MongoDB Atlas Organization ID
export TF_VAR_mongodb_atlas_org_id="689def34b9cb4014c2ba192e"

# GCP Authentication
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/keys/dev-mish-key.json"

# Generate secure passwords (if not already in Secret Manager)
export TF_VAR_mongodb_admin_password="$(openssl rand -base64 32)"
export TF_VAR_mongodb_formio_password="$(openssl rand -base64 32)"
```

### 2. Terraform Variables

Update `terraform/environments/dev/terraform.tfvars`:

```hcl
# MongoDB Atlas Configuration
mongodb_atlas_org_id = "your-org-id"

# Cluster naming (follows pattern)
# Dev: formio-cluster-dev-m30
# Prod: formio-cluster-prod-m30
```

### 3. Module Configuration

The M30 module is configured in `terraform/environments/dev/main.tf`:

```hcl
module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas-m30"

  # Cluster configuration
  cluster_tier = "M30"
  mongodb_version = "7.0"

  # Backup settings
  backup_enabled = true
  pit_enabled = true

  # Auto-scaling
  auto_scaling_disk_gb_enabled = true
}
```

## Deployment

### 1. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init -upgrade
```

### 2. Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- 1 MongoDB Atlas Project
- 1 MongoDB Atlas M30 Cluster
- 4 Database Users
- IP Access List entries
- Secret Manager secrets for connection strings

### 3. Apply Infrastructure

```bash
terraform apply tfplan
```

**Note**: M30 cluster creation takes 10-15 minutes.

### 4. Verify Deployment

```bash
# Get connection string
terraform output -raw mongodb_admin_connection_string_secret_id

# Retrieve connection string from Secret Manager
gcloud secrets versions access latest \
  --secret="dss-formio-api-mongodb-admin-connection-string-dev"
```

## Testing Connection

### 1. Install MongoDB Shell

```bash
brew install mongosh
```

### 2. Connect to Cluster

```bash
# Get admin connection string from Secret Manager
CONNECTION_STRING=$(gcloud secrets versions access latest \
  --secret="dss-formio-api-mongodb-admin-connection-string-dev")

# Connect
mongosh "$CONNECTION_STRING"
```

### 3. Verify Databases

```javascript
// In MongoDB shell
show dbs
use formio_community
db.test.insertOne({test: "data", timestamp: new Date()})
db.test.findOne()
```

## Network Security

### IP Access List Configuration

By default, the module configures:
1. Cloud NAT static IPs (when available)
2. Additional custom IP ranges
3. Falls back to 0.0.0.0/0 with warning (dev only)

For production, always configure specific IP ranges:

```hcl
cloud_nat_static_ips = ["34.142.123.45", "34.142.123.46"]
additional_ip_access_list = {
  office = {
    cidr_block = "203.0.113.0/24"
    comment = "Office network"
  }
}
```

### VPC Peering (Optional)

For enhanced security, enable VPC peering:

```hcl
enable_vpc_peering = true
vpc_network_name = "projects/erlich-dev/global/networks/dss-vpc"
atlas_cidr_block = "192.168.248.0/21"  # Must not overlap with GCP VPC
```

## Monitoring

### Connection Strings in Secret Manager

All connection strings are stored in GCP Secret Manager:

- `dss-formio-api-mongodb-admin-connection-string-dev` - Admin access
- `dss-formio-api-mongodb-community-connection-string-dev` - Community database
- `dss-formio-api-mongodb-enterprise-connection-string-dev` - Enterprise database
- `dss-formio-api-mongodb-monitoring-connection-string-dev` - Monitoring access

### MongoDB Atlas Monitoring

1. Login to MongoDB Atlas Console
2. Navigate to your cluster
3. View metrics:
   - Operations per second
   - Query execution times
   - Connection count
   - Storage usage
   - Network traffic

### Backup Monitoring

- Automated snapshots every 6 hours
- Point-in-time recovery for last 7 days
- Check backup status in Atlas Console > Backup

## Troubleshooting

### Common Issues

#### 1. Authentication Failed

**Error**: `MongoServerError: Authentication failed`

**Solution**:
- Verify passwords in Secret Manager
- Check user permissions in Atlas Console
- Ensure connection string format is correct

#### 2. Network Timeout

**Error**: `MongoNetworkTimeoutError`

**Solution**:
- Check IP Access List configuration
- Verify VPC peering status (if enabled)
- Test connectivity from Cloud Run service

#### 3. Cluster Not Ready

**Error**: `Cluster is being created`

**Solution**:
- M30 clusters take 10-15 minutes to provision
- Check status in Atlas Console
- Wait for cluster state to be "IDLE"

#### 4. API Key Issues

**Error**: `Error: error creating MongoDB Atlas Project: POST https://cloud.mongodb.com/api/atlas/v1.0/groups: 401`

**Solution**:
- Verify MONGODBATLAS_PUBLIC_KEY and MONGODBATLAS_PRIVATE_KEY are set
- Check API key permissions in Atlas Console
- Ensure IP is whitelisted for API access

### Validation Commands

```bash
# Check cluster status
terraform output cluster_state

# Verify backup configuration
terraform output backup_enabled
terraform output pit_enabled

# List all outputs
terraform output -json | jq

# Check secrets in Secret Manager
gcloud secrets list | grep mongodb
```

## Maintenance

### Scaling

To upgrade cluster tier (e.g., M30 to M40):

```hcl
# In main.tf
cluster_tier = "M40"
```

Then apply:
```bash
terraform plan
terraform apply
```

### Version Upgrades

MongoDB Atlas handles minor version updates automatically. For major version upgrades:

```hcl
mongodb_version = "8.0"  # Upgrade from 7.0
```

### Backup Restore

1. Navigate to Atlas Console > Backup
2. Select snapshot or point-in-time
3. Choose restore option:
   - Download backup
   - Restore to new cluster
   - Restore to existing cluster

## Cost Optimization

### M30 Tier Costs (Approximate)

- **Base cost**: ~$350/month
- **Storage**: $0.10/GB/month (after 10GB included)
- **Backup**: $0.50/GB/month
- **Data transfer**: $0.015/GB (egress)

### Cost-Saving Tips

1. Enable auto-pause for dev/test clusters
2. Use appropriate cluster tier for workload
3. Configure backup retention appropriately
4. Monitor and optimize storage usage
5. Use VPC peering to reduce data transfer costs

## Security Best Practices

1. **Never commit credentials** - Use environment variables
2. **Rotate API keys** regularly
3. **Use VPC peering** for production
4. **Enable audit logs** for compliance
5. **Configure alerts** for suspicious activity
6. **Use least privilege** for database users
7. **Enable encryption at rest** (default for M30)
8. **Implement IP access lists** - Never use 0.0.0.0/0 in production

## References

- [MongoDB Atlas Terraform Provider](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs)
- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [MongoDB Connection String Format](https://docs.mongodb.com/manual/reference/connection-string/)
- [Form.io MongoDB Configuration](https://help.form.io/deploying/deployment)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)

## Support

For issues or questions:
1. Check MongoDB Atlas status page
2. Review Atlas Console logs
3. Contact MongoDB support (for production issues)
4. Review Terraform debug logs: `TF_LOG=DEBUG terraform plan`