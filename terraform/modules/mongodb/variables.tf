# MongoDB Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone for the MongoDB instance"
  type        = string
}

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

# Networking Configuration
variable "vpc_network_id" {
  description = "The VPC network ID to deploy MongoDB in"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID to deploy MongoDB in"
  type        = string
}

# Instance Configuration
variable "machine_type" {
  description = "Machine type for MongoDB instance"
  type        = string
  default     = "e2-small" # 2GB RAM minimum per Gemini recommendation

  validation {
    condition = contains([
      "e2-small", "e2-medium", "e2-standard-2", "e2-standard-4",
      "n1-standard-1", "n1-standard-2", "n1-standard-4"
    ], var.machine_type)
    error_message = "Machine type must be e2-small or larger for MongoDB."
  }
}

variable "boot_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size >= 20
    error_message = "Boot disk size must be at least 20GB."
  }
}

variable "data_disk_size" {
  description = "Size of the data disk for MongoDB storage in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.data_disk_size >= 20
    error_message = "Data disk size must be at least 20GB for MongoDB."
  }
}

# MongoDB Configuration
variable "mongodb_version" {
  description = "MongoDB version to install"
  type        = string
  default     = "7.0"

  validation {
    condition     = contains(["6.0", "7.0"], var.mongodb_version)
    error_message = "MongoDB version must be 6.0 or 7.0."
  }
}

variable "admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"

  validation {
    condition     = length(var.admin_username) > 0
    error_message = "Admin username cannot be empty."
  }
}

variable "admin_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin password"
  type        = string
  default     = null
}

# Legacy variable for backward compatibility (deprecated)
variable "admin_password" {
  description = "DEPRECATED: Use admin_password_secret_id instead. MongoDB admin password"
  type        = string
  default     = ""
  sensitive   = true
}

# Database Configuration
variable "database_name" {
  description = "Name of the database to create for Form.io"
  type        = string
  default     = "formio"
}

variable "formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}

variable "formio_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB Form.io user password"
  type        = string
  default     = null
}

# Legacy variable for backward compatibility (deprecated)
variable "formio_password" {
  description = "DEPRECATED: Use formio_password_secret_id instead. MongoDB password for Form.io application"
  type        = string
  default     = ""
  sensitive   = true
}

# Backup Configuration
variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable Cloud Monitoring for MongoDB"
  type        = bool
  default     = true
}

# Security Configuration
variable "allowed_source_ranges" {
  description = "CIDR ranges allowed to access MongoDB (in addition to service tags)"
  type        = list(string)
  default     = []
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for MongoDB connections"
  type        = bool
  default     = true
}