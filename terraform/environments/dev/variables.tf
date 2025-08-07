# Development Environment Variables
# Form.io Enterprise Service - Development Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for development environment"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for development deployment"
  type        = string
  default     = "us-central1"
  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1", "australia-southeast1", "australia-southeast2"], var.region)
    error_message = "Region must be one of: us-central1, us-east1, us-west1, europe-west1, australia-southeast1, australia-southeast2."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = var.environment == "dev"
    error_message = "Environment must be 'dev' for this configuration."
  }
}

# Service Deployment Controls
variable "deploy_community" {
  description = "Whether to deploy Form.io Community edition service"
  type        = bool
  default     = true
}

variable "deploy_enterprise" {
  description = "Whether to deploy Form.io Enterprise edition service"
  type        = bool
  default     = true
}

# Form.io Enterprise Configuration
variable "formio_version" {
  description = "Form.io Enterprise version tag"
  type        = string
  default     = "9.5.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.formio_version))
    error_message = "Version must be in semantic version format (e.g., 9.5.0)."
  }
}

variable "community_version" {
  description = "Form.io Community edition version tag"
  type        = string
  default     = "v4.6.0-rc.3"
}

variable "formio_license_key" {
  description = "Form.io Enterprise license key"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_license_key) > 10
    error_message = "License key must be provided and be longer than 10 characters."
  }
}

variable "formio_root_email" {
  description = "Form.io root admin email"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.formio_root_email))
    error_message = "Must be a valid email address."
  }
}

variable "formio_root_password" {
  description = "Form.io root admin password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_root_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
}

variable "formio_jwt_secret" {
  description = "JWT secret for Form.io"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters long."
  }
}

variable "formio_db_secret" {
  description = "Database encryption secret for Form.io"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_db_secret) >= 32
    error_message = "Database secret must be at least 32 characters long."
  }
}

# Service Configuration - Development Optimized
variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "dss-formio-api"
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 5 # Reduced for dev environment
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 10
    error_message = "Max instances must be between 1 and 10 for development environment."
  }
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0 # Scale to zero for cost savings
  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 2
    error_message = "Min instances must be between 0 and 2 for development environment."
  }
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance"
  type        = string
  default     = "1000m" # 1 vCPU for dev
  validation {
    condition     = contains(["1000m", "2000m"], var.cpu_request)
    error_message = "CPU request must be either 1000m or 2000m for development environment."
  }
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance"
  type        = string
  default     = "2Gi" # 2GB for dev
  validation {
    condition     = contains(["1Gi", "2Gi", "4Gi"], var.memory_request)
    error_message = "Memory request must be 1Gi, 2Gi, or 4Gi for development environment."
  }
}

variable "concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80
  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 100
    error_message = "Concurrency must be between 1 and 100."
  }
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.timeout_seconds >= 60 && var.timeout_seconds <= 3600
    error_message = "Timeout must be between 60 and 3600 seconds."
  }
}

# Storage Configuration
variable "formio_bucket_name" {
  description = "Name of the GCS bucket for Form.io file storage"
  type        = string
  default     = "" # Will be auto-generated if empty
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
  default     = "e2-small"  # 2GB RAM minimum for dev
  validation {
    condition = contains([
      "e2-small", "e2-medium", "e2-standard-2", "e2-standard-4"
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

variable "mongodb_admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"
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

# Domain Configuration (Optional for dev)
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