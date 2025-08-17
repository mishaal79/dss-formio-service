# MongoDB Atlas Terraform Module

This module provisions a MongoDB Atlas Flex cluster for Form.io applications.

## Features

- **MongoDB Atlas Flex Cluster**: Cost-effective development cluster
- **GCP Integration**: Deployed in australia-southeast1 region
- **Automatic Database Users**: Separate users for community and enterprise databases
- **Network Security**: Configured for VPC connector access
- **Secret Management**: Connection strings stored in GCP Secret Manager

## Usage

```hcl
module "mongodb_atlas" {
  source = "./modules/mongodb-atlas"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # MongoDB Atlas configuration
  atlas_project_name    = "my-project-dev"
  atlas_org_id          = var.mongodb_atlas_org_id
  cluster_name          = "my-cluster-dev-flex"
  backing_provider_name = "GCP"
  atlas_region_name     = "AUSTRALIA_SOUTHEAST_1"

  # Authentication
  admin_username            = "mongoAdmin"
  admin_password_secret_id  = google_secret_manager_secret.admin_password.secret_id
  formio_username           = "formioUser"
  formio_password_secret_id = google_secret_manager_secret.formio_password.secret_id

  # Database names
  database_name             = "formio"
  community_database_name   = "formio_community"
  enterprise_database_name  = "formio_enterprise"

  # Network access
  allowed_source_ranges = ["10.8.0.0/28"]
}
```

## Prerequisites

1. **MongoDB Atlas Account**: Create account at https://cloud.mongodb.com
2. **API Keys**: Generate with "Organization Project Creator" role
3. **Environment Variables**:
   ```bash
   export MONGODB_ATLAS_PUBLIC_KEY="your-public-key"
   export MONGODB_ATLAS_PRIVATE_KEY="your-private-key"
   export TF_VAR_mongodb_atlas_org_id="your-org-id"
   ```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| atlas_org_id | MongoDB Atlas organization ID | `string` | n/a | yes |
| atlas_project_name | Name of the MongoDB Atlas project | `string` | n/a | yes |
| cluster_name | Name of the MongoDB Atlas cluster | `string` | n/a | yes |
| admin_password_secret_id | Secret Manager secret ID for admin password | `string` | n/a | yes |
| formio_password_secret_id | Secret Manager secret ID for formio password | `string` | n/a | yes |
| community_database_name | Full name of the Community database | `string` | n/a | yes |
| enterprise_database_name | Full name of the Enterprise database | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The MongoDB Atlas cluster ID |
| atlas_project_id | The MongoDB Atlas project ID |
| mongodb_community_connection_string_secret_id | Secret ID for community connection string |
| mongodb_enterprise_connection_string_secret_id | Secret ID for enterprise connection string |

## Database Structure

The module creates:

- **Admin User**: Full administrative access across all databases
- **Community User**: Read/write access to `formio_community` database
- **Enterprise User**: Read/write access to `formio_enterprise` database

## Network Access

- **Source Ranges**: Configurable CIDR blocks (default: VPC connector subnet)
- **TLS/SSL**: Required for all connections
- **Authentication**: SCRAM-SHA-256

## Cost Optimization

- **Flex Cluster**: Automatically scales based on usage
- **Auto-pause**: Cluster can pause during low usage
- **Backup**: Automatic daily backups included
- **Monitoring**: Built-in performance monitoring

## Security

- **Encryption**: All data encrypted at rest and in transit
- **Network Isolation**: Access restricted to specified IP ranges
- **User Permissions**: Least privilege access per database
- **Secret Management**: Passwords managed via GCP Secret Manager

## Limitations

- **Connection Limits**: Flex clusters have connection limits
- **No Multi-Region**: Single region deployment
- **Development Use**: Optimized for development, not production

## Troubleshooting

1. **Connection Issues**: Check IP access list and VPC connector configuration
2. **Authentication Errors**: Verify user credentials and database permissions
3. **Performance**: Monitor Atlas dashboard for cluster metrics
4. **Costs**: Review usage in Atlas billing dashboard

## Migration from Self-Hosted

If migrating from a self-hosted MongoDB:

1. Export data: `mongodump --uri="mongodb://old-connection-string"`
2. Deploy Atlas cluster: `terraform apply`
3. Import data: `mongorestore --uri="mongodb+srv://new-connection-string"`
4. Update application connection strings
5. Validate data integrity

For more information, see the [main project documentation](../../../CLAUDE.md).