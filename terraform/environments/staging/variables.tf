# Staging Environment Variables
# Form.io Enterprise Service - Staging Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for staging environment"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for staging deployment"
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
  default     = "staging"
  validation {
    condition     = var.environment == "staging"
    error_message = "Environment must be 'staging' for this configuration."
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
    condition     = length(var.formio_root_password) >= 10
    error_message = "Password must be at least 10 characters long for staging."
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

variable "portal_enabled" {
  description = "Enable Form.io developer portal"
  type        = bool
  default     = true  # Enabled for testing in staging
}

# Service Configuration - Staging Optimized
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
  default     = 10  # Mid-range for staging
  validation {
    condition     = var.max_instances >= 2 && var.max_instances <= 20
    error_message = "Max instances must be between 2 and 20 for staging environment."
  }
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1  # One instance for staging
  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 5
    error_message = "Min instances must be between 0 and 5 for staging environment."
  }
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance"
  type        = string
  default     = "1000m"  # 1 vCPU for staging
  validation {
    condition     = contains(["1000m", "2000m"], var.cpu_request)
    error_message = "CPU request must be either 1000m or 2000m for staging environment."
  }
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance"
  type        = string
  default     = "2Gi"  # 2GB for staging
  validation {
    condition     = contains(["1Gi", "2Gi", "4Gi"], var.memory_request)
    error_message = "Memory request must be 1Gi, 2Gi, or 4Gi for staging environment."
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
    condition     = contains(["6.0", "7.0"], var.mongodb_version)
    error_message = "MongoDB version must be 6.0 or 7.0."
  }
}

variable "mongodb_tier" {
  description = "MongoDB Atlas cluster tier"
  type        = string
  default     = "M10"  # Production-ready but cost-effective for staging
  validation {
    condition     = contains(["M0", "M2", "M5", "M10", "M20"], var.mongodb_tier)
    error_message = "MongoDB tier must be M0, M2, M5, M10, or M20 for staging environment."
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
  default     = "dss-formio-staging"
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
  type        = string
  default     = "dss-formio-staging-cluster"
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
}

# Domain Configuration (Optional for staging)
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