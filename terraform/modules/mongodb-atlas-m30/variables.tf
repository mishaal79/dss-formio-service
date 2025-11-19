# MongoDB Atlas M30 Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

# Removed: region - not used by MongoDB Atlas module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Name of the service (for resource naming)"
  type        = string
  default     = "dss-formio-api"
}

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# MongoDB Atlas Configuration
variable "atlas_project_name" {
  description = "Name of the MongoDB Atlas project"
  type        = string
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the MongoDB Atlas cluster"
  type        = string
}

variable "cluster_tier" {
  description = "MongoDB Atlas cluster tier (M30 for production)"
  type        = string
  default     = "M30"
  validation {
    condition     = contains(["M30", "M40", "M50"], var.cluster_tier)
    error_message = "Cluster tier must be M30, M40, or M50 for production workloads."
  }
}

variable "backing_provider_name" {
  description = "Cloud service provider on which MongoDB Atlas provisions the cluster"
  type        = string
  default     = "GCP"
  validation {
    condition     = contains(["AWS", "GCP", "AZURE"], var.backing_provider_name)
    error_message = "Backing provider name must be AWS, GCP, or AZURE."
  }
}

variable "mongodb_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
  validation {
    condition     = contains(["6.0", "7.0", "8.0"], var.mongodb_version)
    error_message = "MongoDB version must be 6.0, 7.0, or 8.0."
  }
}

variable "atlas_region_name" {
  description = "Atlas region name for the cluster"
  type        = string
  default     = "AUSTRALIA_SOUTHEAST_1"
}

variable "termination_protection_enabled" {
  description = "Flag that indicates whether termination protection is enabled on the cluster"
  type        = bool
  default     = true
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable cloud backup for the cluster"
  type        = bool
  default     = true
}

variable "pit_enabled" {
  description = "Enable Point-In-Time recovery (requires backup_enabled)"
  type        = bool
  default     = true
}

# Auto-scaling Configuration
variable "auto_scaling_disk_gb_enabled" {
  description = "Enable auto-scaling for disk storage"
  type        = bool
  default     = true
}

# Advanced Configuration
variable "javascript_enabled" {
  description = "Enable server-side JavaScript execution"
  type        = bool
  default     = true
}

variable "oplog_size_mb" {
  description = "Size of the oplog in MB (1024-51200 for M30)"
  type        = number
  default     = 2048
  validation {
    condition     = var.oplog_size_mb >= 1024 && var.oplog_size_mb <= 51200
    error_message = "Oplog size must be between 1024 and 51200 MB for M30 cluster."
  }
}

variable "sample_size_bi_connector" {
  description = "Number of documents to sample for BI Connector"
  type        = number
  default     = 1000
}

variable "sample_refresh_interval_bi_connector" {
  description = "Interval in seconds between BI Connector sampling"
  type        = number
  default     = 300
}

# VPC Peering Configuration
variable "enable_vpc_peering" {
  description = "Enable VPC peering for private connectivity"
  type        = bool
  default     = false
}

variable "vpc_network_name" {
  description = "Name of the GCP VPC network for peering"
  type        = string
  default     = ""
}

variable "atlas_cidr_block" {
  description = "CIDR block for MongoDB Atlas network container (must not overlap with GCP VPC)"
  type        = string
  default     = "192.168.248.0/21"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.atlas_cidr_block))
    error_message = "Must be a valid CIDR block (e.g., 192.168.248.0/21)."
  }
}

# Network Security Configuration
variable "cloud_nat_static_ips" {
  description = "List of Cloud NAT static IP addresses for Cloud Run egress"
  type        = list(string)
  default     = []
}

variable "additional_ip_access_list" {
  description = "Additional IP addresses or CIDR blocks to allow access"
  type = map(object({
    cidr_block = string
    comment    = string
  }))
  default = {}
}

# Database Configuration
variable "admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"
}

variable "formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}

# Removed: database_name - not used, databases named via community/enterprise variables

variable "community_database_name" {
  description = "Full name of the Community database"
  type        = string
}

variable "enterprise_database_name" {
  description = "Full name of the Enterprise database"
  type        = string
}

# Secret Manager Configuration
variable "admin_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin password"
  type        = string
}

variable "formio_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB Form.io user password"
  type        = string
}

# Cluster Tags
variable "cluster_tags" {
  description = "Tags to apply to the MongoDB Atlas cluster"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}