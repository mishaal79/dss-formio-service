# Development Environment Variables
# Form.io Enterprise Service - Development Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for development environment"
  type        = string
  default     = "erlich-dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for development deployment"
  type        = string
  default     = "australia-southeast1"
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

# Security Configuration
variable "authorized_members" {
  description = "List of members authorized to invoke the Form.io Cloud Run services (e.g., user:your-email@domain.com)"
  type        = list(string)
  default = [
    "user:admin@dsselectrical.com.au",
    "user:mishal@qrius.global"
  ]
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

# Form.io Enterprise Configuration
variable "formio_version" {
  description = "Form.io Enterprise version tag"
  type        = string
  default     = "9.6.0-rc.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-rc\\.[0-9]+)?$", var.formio_version))
    error_message = "Version must be in semantic version format (e.g., 9.5.0) or release candidate format (e.g., 9.5.1-rc.10)."
  }
}

variable "community_version" {
  description = "Form.io Community edition version tag"
  type        = string
  default     = "rc"
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
  default     = 1 # Always keep 1 instance to avoid cold starts for Form.io Enterprise
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

# MongoDB Atlas Configuration
variable "mongodb_atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "mongodb_admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"
}


variable "mongodb_formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}


variable "mongodb_database_name" {
  description = "MongoDB database name for Form.io"
  type        = string
  default     = "formio"
}



# Monitoring Configuration (placeholder for future use)
# variable "notification_channels" {
#   description = "List of notification channel IDs for alerts"
#   type        = list(string)
#   default     = []
# }

# Domain Configuration (Optional for dev)
variable "custom_domain" {
  description = "Custom domain for Form.io service"
  type        = string
  default     = ""
}

# SSL certificate configuration (placeholder for future use)
# variable "ssl_certificate_id" {
#   description = "SSL certificate ID for custom domain"
#   type        = string
#   default     = ""
# }

# Custom Domains for Whitelabeling
variable "custom_domains" {
  description = "List of custom domains for Form.io whitelabeling (DNS configured in gcp-dss-erlich-infra-terraform)"
  type        = list(string)
  default = [
    # DNS configured in gcp-dss-erlich-infra-terraform:
    "forms.dev.cloud.dsselectrical.com.au"
    # Future domains:
    # "admin.dev.cloud.dsselectrical.com.au",
    # "api.dev.cloud.dsselectrical.com.au"
  ]
}

# Portal Configuration
variable "portal_enabled" {
  description = "Enable Form.io developer portal"
  type        = bool
  default     = true
}

# =============================================================================
# LOAD BALANCER CONFIGURATION (REMOVED - NOW USING CENTRALIZED ARCHITECTURE)
# =============================================================================

# Load balancer configuration has been moved to centralized shared infrastructure
# This service now focuses solely on application deployment and exposes backend services
# for integration with the centralized load balancer