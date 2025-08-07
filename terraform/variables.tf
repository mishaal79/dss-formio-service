# Project Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Service Deployment Controls
variable "deploy_community" {
  description = "Whether to deploy Form.io Community edition service"
  type        = bool
  default     = false
}

variable "deploy_enterprise" {
  description = "Whether to deploy Form.io Enterprise edition service"
  type        = bool
  default     = true
}

variable "formio_version" {
  description = "Form.io Enterprise version tag"
  type        = string
  default     = "9.5.0"
}

variable "community_version" {
  description = "Form.io Community edition version tag"
  type        = string
  default     = "v4.6.0-rc.3"
}

variable "formio_license_key" {
  description = "Form.io Enterprise license key (required for enterprise edition)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "formio_root_email" {
  description = "Form.io root admin email"
  type        = string
}

variable "formio_root_password" {
  description = "Form.io root admin password"
  type        = string
  sensitive   = true
}

variable "formio_jwt_secret" {
  description = "JWT secret for Form.io"
  type        = string
  sensitive   = true
}

variable "formio_db_secret" {
  description = "Database encryption secret for Form.io"
  type        = string
  sensitive   = true
}

variable "portal_enabled" {
  description = "Enable Form.io developer portal"
  type        = bool
  default     = true
}

# Service Configuration
variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "formio-api"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must follow kebab-case format: lowercase letters, numbers, and hyphens only, starting and ending with alphanumeric characters."
  }
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance"
  type        = string
  default     = "2Gi"
}

variable "concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

# Storage Configuration
variable "formio_bucket_name" {
  description = "Name of the GCS bucket for Form.io file storage"
  type        = string
  default     = ""
  
  validation {
    condition = var.formio_bucket_name == "" || can(regex("^dss-formio-[a-z0-9]+-[a-z]+-[a-z0-9]+$", var.formio_bucket_name))
    error_message = "Bucket name must follow pattern: dss-formio-{service}-{environment}-{suffix} (e.g., dss-formio-storage-dev-a1b2c3)."
  }
}

# MongoDB Self-Hosted Configuration
variable "mongodb_version" {
  description = "MongoDB version to install"
  type        = string
  default     = "7.0"

  validation {
    condition     = contains(["6.0", "7.0"], var.mongodb_version)
    error_message = "MongoDB version must be 6.0 or 7.0."
  }
}

variable "mongodb_machine_type" {
  description = "Machine type for MongoDB Compute Engine instance"
  type        = string
  default     = "e2-small"  # 2GB RAM minimum per Gemini recommendation

  validation {
    condition = contains([
      "e2-small", "e2-medium", "e2-standard-2", "e2-standard-4",
      "n1-standard-1", "n1-standard-2", "n1-standard-4"
    ], var.mongodb_machine_type)
    error_message = "Machine type must be e2-small or larger for MongoDB."
  }
}

variable "mongodb_data_disk_size" {
  description = "Size of MongoDB data disk in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.mongodb_data_disk_size >= 20
    error_message = "MongoDB data disk size must be at least 20GB."
  }
}

# MongoDB Authentication Configuration
variable "mongodb_admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"

  validation {
    condition     = length(var.mongodb_admin_username) > 0
    error_message = "MongoDB admin username cannot be empty."
  }
}

variable "mongodb_admin_password" {
  description = "MongoDB admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mongodb_admin_password) >= 8
    error_message = "MongoDB admin password must be at least 8 characters long."
  }
}

variable "mongodb_formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}

variable "mongodb_formio_password" {
  description = "MongoDB password for Form.io application"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mongodb_formio_password) >= 8
    error_message = "MongoDB Form.io password must be at least 8 characters long."
  }
}

variable "mongodb_database_name" {
  description = "MongoDB database name for Form.io"
  type        = string
  default     = "formio"
}

variable "mongodb_backup_retention_days" {
  description = "Number of days to retain MongoDB backups"
  type        = number
  default     = 7

  validation {
    condition     = var.mongodb_backup_retention_days >= 1 && var.mongodb_backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

# Monitoring Configuration
variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

# Domain Configuration (Optional)
variable "custom_domain" {
  description = "Custom domain for Form.io service"
  type        = string
  default     = ""
}

variable "ssl_certificate_id" {
  description = "SSL certificate ID for custom domain"
  type        = string
  default     = ""
}

# Shared Infrastructure Integration
variable "shared_vpc_id" {
  description = "VPC ID from shared infrastructure (gcp-dss-erlich-infra-terraform)"
  type        = string
  default     = null
}

variable "shared_subnet_ids" {
  description = "Private subnet IDs from shared infrastructure"
  type        = list(string)
  default     = []
}

variable "shared_vpc_connector_id" {
  description = "VPC Connector ID from shared infrastructure"
  type        = string
  default     = null
}