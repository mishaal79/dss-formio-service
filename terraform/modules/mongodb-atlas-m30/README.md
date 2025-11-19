# MongoDB Atlas M30 Dedicated Cluster Module

## Purpose

This Terraform module deploys a MongoDB Atlas M30 dedicated cluster for
production workloads. The M30 tier provides dedicated resources, automated
backups, and enterprise-grade features suitable for production Form.io
deployments.

## Features

- **Dedicated M30 Cluster**: 3-node replica set with dedicated resources
- **Automated Backups**: Cloud backup with Point-In-Time recovery
- **Multiple Database Users**: Admin, application, and monitoring users
- **Secret Manager Integration**: Connection strings stored in GCP Secret
  Manager
- **VPC Peering Support**: Optional private connectivity
- **IP Access Control**: Configurable access lists for security
- **Auto-scaling**: Automatic disk scaling to handle growth
- **Monitoring User**: Read-only user for observability tools

## Module Structure

```
mongodb-atlas-m30/
├── main.tf       # Main resource definitions
├── variables.tf  # Input variable definitions
├── outputs.tf    # Output definitions
└── README.md     # This file
```

## Usage

### Basic Example

```hcl
module "mongodb_atlas_m30" {
  source = "./modules/mongodb-atlas-m30"

  # Project configuration
  project_id  = "my-gcp-project"
  environment = "production"

  # MongoDB Atlas configuration
  atlas_org_id       = "your-atlas-org-id"
  atlas_project_name = "my-project-prod"
  cluster_name       = "my-cluster-prod-m30"

  # Cluster specifications
  cluster_tier      = "M30"
  mongodb_version   = "7.0"
  atlas_region_name = "AUSTRALIA_SOUTHEAST_1"

  # Database configuration
  community_database_name  = "formio_community"
  enterprise_database_name = "formio_enterprise"

  # Secrets
  admin_password_secret_id  = "mongodb-admin-password"
  formio_password_secret_id = "mongodb-formio-password"
}
```

### Advanced Example with VPC Peering

```hcl
module "mongodb_atlas_m30" {
  source = "./modules/mongodb-atlas-m30"

  # ... basic configuration ...

  # Enable VPC peering for private connectivity
  enable_vpc_peering = true
  vpc_network_name   = "projects/my-project/global/networks/my-vpc"
  atlas_cidr_block   = "192.168.248.0/21"

  # Configure IP access list
  cloud_nat_static_ips = [
    "34.142.123.45",
    "34.142.123.46"
  ]

  additional_ip_access_list = {
    office = {
      cidr_block = "203.0.113.0/24"
      comment    = "Office network"
    }
    vpn = {
      cidr_block = "10.0.0.0/8"
      comment    = "VPN users"
    }
  }

  # Advanced configuration
  backup_enabled               = true
  pit_enabled                  = true
  auto_scaling_disk_gb_enabled = true
  javascript_enabled           = true
  oplog_size_mb               = 4096
}
```

## Input Variables

### Required Variables

| Name                        | Description                           | Type     |
| --------------------------- | ------------------------------------- | -------- |
| `project_id`                | GCP project ID                        | `string` |
| `environment`               | Environment name (dev, staging, prod) | `string` |
| `atlas_org_id`              | MongoDB Atlas organization ID         | `string` |
| `atlas_project_name`        | Name of the MongoDB Atlas project     | `string` |
| `cluster_name`              | Name of the MongoDB cluster           | `string` |
| `admin_password_secret_id`  | Secret Manager ID for admin password  | `string` |
| `formio_password_secret_id` | Secret Manager ID for formio password | `string` |
| `community_database_name`   | Name of the community database        | `string` |
| `enterprise_database_name`  | Name of the enterprise database       | `string` |

### Optional Variables

| Name                             | Description                      | Type           | Default                   |
| -------------------------------- | -------------------------------- | -------------- | ------------------------- |
| `cluster_tier`                   | MongoDB Atlas cluster tier       | `string`       | `"M30"`                   |
| `mongodb_version`                | MongoDB major version            | `string`       | `"7.0"`                   |
| `backing_provider_name`          | Cloud provider (AWS, GCP, AZURE) | `string`       | `"GCP"`                   |
| `atlas_region_name`              | Atlas region name                | `string`       | `"AUSTRALIA_SOUTHEAST_1"` |
| `backup_enabled`                 | Enable cloud backup              | `bool`         | `true`                    |
| `pit_enabled`                    | Enable Point-In-Time recovery    | `bool`         | `true`                    |
| `auto_scaling_disk_gb_enabled`   | Enable auto-scaling for disk     | `bool`         | `true`                    |
| `enable_vpc_peering`             | Enable VPC peering               | `bool`         | `false`                   |
| `vpc_network_name`               | GCP VPC network name for peering | `string`       | `""`                      |
| `atlas_cidr_block`               | CIDR block for Atlas network     | `string`       | `"192.168.248.0/21"`      |
| `cloud_nat_static_ips`           | List of Cloud NAT static IPs     | `list(string)` | `[]`                      |
| `termination_protection_enabled` | Enable termination protection    | `bool`         | `true`                    |

## Outputs

### Cluster Information

| Name                       | Description                   |
| -------------------------- | ----------------------------- |
| `cluster_id`               | MongoDB Atlas cluster ID      |
| `cluster_name`             | MongoDB Atlas cluster name    |
| `cluster_state`            | Current cluster state         |
| `cluster_tier`             | Cluster tier (M30, M40, etc.) |
| `cluster_mongo_db_version` | MongoDB version               |

### Connection Strings (Secret IDs)

| Name                                             | Description                    |
| ------------------------------------------------ | ------------------------------ |
| `mongodb_admin_connection_string_secret_id`      | Secret ID for admin connection |
| `mongodb_community_connection_string_secret_id`  | Secret ID for community DB     |
| `mongodb_enterprise_connection_string_secret_id` | Secret ID for enterprise DB    |
| `mongodb_monitoring_connection_string_secret_id` | Secret ID for monitoring       |

### Database Users

| Name                         | Description        |
| ---------------------------- | ------------------ |
| `admin_username`             | Admin user name    |
| `formio_community_username`  | Community DB user  |
| `formio_enterprise_username` | Enterprise DB user |
| `formio_monitoring_username` | Monitoring user    |

## Database Users Created

1. **Admin User** (`mongoAdmin`)
   - Role: `atlasAdmin`
   - Access: Full cluster administration

2. **Community User** (`formioUser_community`)
   - Role: `readWrite` on community database
   - Access: Application access for community features

3. **Enterprise User** (`formioUser_enterprise`)
   - Role: `readWrite` on enterprise database
   - Access: Application access for enterprise features

4. **Monitoring User** (`formioUser_monitoring`)
   - Roles: `read` on both databases, `clusterMonitor` on admin
   - Access: Read-only for monitoring tools

## Secret Manager Integration

All sensitive connection strings are automatically stored in GCP Secret Manager:

```bash
# List all MongoDB secrets
gcloud secrets list | grep mongodb

# Access a connection string
gcloud secrets versions access latest \
  --secret="dss-formio-api-mongodb-admin-connection-string-dev"
```

## Network Security

### IP Access List Priority

1. If `cloud_nat_static_ips` provided → Use those IPs
2. If `additional_ip_access_list` provided → Add those ranges
3. If neither provided → Falls back to `0.0.0.0/0` (NOT recommended for
   production)

### VPC Peering Setup

When `enable_vpc_peering = true`:

1. Creates MongoDB Atlas network container
2. Establishes peering with specified GCP VPC
3. Requires non-overlapping CIDR blocks

## Cluster Tiers

| Tier | RAM   | Storage     | vCPUs | Use Case                |
| ---- | ----- | ----------- | ----- | ----------------------- |
| M30  | 8 GB  | 40-500 GB   | 2     | Production starter      |
| M40  | 16 GB | 80-1000 GB  | 4     | Growing production      |
| M50  | 32 GB | 160-2000 GB | 8     | High-traffic production |

## Backup Configuration

- **Snapshots**: Every 6 hours
- **Retention**: 7 days for snapshots
- **Point-In-Time**: Last 7 days (1-second granularity)
- **Cross-region**: Automatic backup replication

## Monitoring

### Metrics Available

- Operations per second
- Query execution time
- Connection count
- CPU/Memory utilization
- Disk IOPS
- Network traffic

### Alerting

Configure alerts in MongoDB Atlas Console for:

- High CPU/Memory usage
- Slow queries
- Connection limits
- Disk space
- Replication lag

## Migration from Flex Cluster

If migrating from Flex cluster to M30:

1. Backup existing data
2. Update module source from `mongodb-atlas` to `mongodb-atlas-m30`
3. Add new required variables (cluster_tier, backup settings)
4. Run `terraform plan` to review changes
5. Apply during maintenance window
6. Update application connection strings

## Cost Considerations

### M30 Pricing (Approximate)

- **Base**: ~$350/month
- **Storage**: $0.10/GB/month (after included)
- **Backup**: $0.50/GB/month
- **Data Transfer**: $0.015/GB

### Cost Optimization

1. Use appropriate tier for workload
2. Enable auto-pause for dev/test
3. Configure backup retention appropriately
4. Use VPC peering to reduce transfer costs
5. Monitor and optimize indexes

## Troubleshooting

### Common Issues

#### Module Not Found

```
Error: Module not found
```

Solution: Ensure path is correct and run `terraform init -upgrade`

#### API Authentication Failed

```
Error: 401 Unauthorized
```

Solution: Set MongoDB Atlas API credentials:

```bash
export MONGODBATLAS_PUBLIC_KEY="your-key"
export MONGODBATLAS_PRIVATE_KEY="your-secret"
```

#### IP Not Whitelisted

```
Error: Client IP not whitelisted
```

Solution: Add your IP to `cloud_nat_static_ips` or `additional_ip_access_list`

#### VPC Peering Failed

```
Error: CIDR block overlaps
```

Solution: Choose non-overlapping `atlas_cidr_block` (e.g., 192.168.248.0/21)

## Best Practices

1. **Always enable termination protection** for production
2. **Use VPC peering** for enhanced security
3. **Configure specific IP ranges**, never use 0.0.0.0/0 in production
4. **Enable backups** with appropriate retention
5. **Use separate databases** for different environments
6. **Rotate passwords** regularly
7. **Monitor cluster metrics** and set up alerts
8. **Plan maintenance windows** for upgrades

## Dependencies

- Terraform >= 1.0
- MongoDB Atlas Provider ~> 1.39
- Google Provider ~> 6.0
- Google Beta Provider ~> 6.0

## License

This module is part of the DSS Form.io infrastructure and follows the project's
licensing terms.

## Support

For issues or questions:

1. Check the [MongoDB Atlas documentation](https://docs.atlas.mongodb.com/)
2. Review the
   [Terraform provider docs](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs)
3. Contact the infrastructure team
