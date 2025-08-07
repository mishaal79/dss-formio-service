# Production Environment Variables
# Form.io Enterprise Service - Production Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for production environment"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for production deployment"
  type        = string
  default     = "us-central1"
  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1"], var.region)
    error_message = "Region must be one of: us-central1, us-east1, us-west1, europe-west1."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
  validation {
    condition     = var.environment == "prod"
    error_message = "Environment must be 'prod' for this configuration."
  }
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
    condition     = length(var.formio_root_password) >= 12
    error_message = "Password must be at least 12 characters long for production."
  }
}

variable "formio_jwt_secret" {
  description = "JWT secret for Form.io"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_jwt_secret) >= 64
    error_message = "JWT secret must be at least 64 characters long for production."
  }
}

variable "formio_db_secret" {
  description = "Database encryption secret for Form.io"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_db_secret) >= 64
    error_message = "Database secret must be at least 64 characters long for production."
  }
}

variable "portal_enabled" {
  description = "Enable Form.io developer portal"
  type        = bool
  default     = false  # Typically disabled in production
}

# Service Configuration - Production Optimized
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
  default     = 20  # Higher for production load
  validation {
    condition     = var.max_instances >= 5 && var.max_instances <= 100
    error_message = "Max instances must be between 5 and 100 for production environment."
  }
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 2  # Always-on for production
  validation {
    condition     = var.min_instances >= 1 && var.min_instances <= 10
    error_message = "Min instances must be between 1 and 10 for production environment."
  }
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance"
  type        = string
  default     = "2000m"  # 2 vCPU for production
  validation {
    condition     = contains(["1000m", "2000m", "4000m"], var.cpu_request)
    error_message = "CPU request must be 1000m, 2000m, or 4000m for production environment."
  }
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance"
  type        = string
  default     = "4Gi"  # 4GB for production
  validation {
    condition     = contains(["2Gi", "4Gi", "8Gi"], var.memory_request)
    error_message = "Memory request must be 2Gi, 4Gi, or 8Gi for production environment."
  }
}

variable "concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80
  validation {
    condition     = var.concurrency >= 10 && var.concurrency <= 100
    error_message = "Concurrency must be between 10 and 100."
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
  default     = ""  # Will be auto-generated if empty
}

# MongoDB Configuration
variable "mongodb_atlas_enabled" {
  description = "Use MongoDB Atlas instead of self-hosted MongoDB"
  type        = bool
  default     = true
}

variable "mongodb_version" {
  description = "MongoDB version"
  type        = string
  default     = "7.0"
  validation {
    condition     = contains(["7.0"], var.mongodb_version)
    error_message = "MongoDB version must be 7.0 for production environment."
  }
}

variable "mongodb_tier" {
  description = "MongoDB Atlas cluster tier"
  type        = string
  default     = "M30"  # Production-ready tier
  validation {
    condition     = contains(["M10", "M20", "M30", "M40"], var.mongodb_tier)
    error_message = "MongoDB tier must be M10, M20, M30, or M40 for production environment."
  }
}

# MongoDB Atlas Configuration
variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
  default     = ""
}

variable "atlas_project_name" {
  description = "MongoDB Atlas project name"
  type        = string
  default     = "dss-formio-prod"
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
  type        = string
  default     = "dss-formio-prod-cluster"
}

variable "atlas_region" {
  description = "MongoDB Atlas region"
  type        = string
  default     = "US_CENTRAL1"
}

# Monitoring Configuration
variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.notification_channels) > 0
    error_message = "At least one notification channel must be configured for production environment."
  }
}

# Domain Configuration (Required for production)
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