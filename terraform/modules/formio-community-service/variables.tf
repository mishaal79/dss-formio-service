# =============================================================================
# FORM.IO COMMUNITY EDITION MODULE VARIABLES
# =============================================================================
# Variables for standalone Form.io Community Edition deployment
# COMPLETELY INDEPENDENT from Enterprise edition module

# Project Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for deployment"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# VPC Network Configuration
variable "vpc_network_id" {
  description = "The ID of the VPC network for Direct VPC Egress"
  type        = string
}

variable "egress_subnet_id" {
  description = "The ID of the egress subnet for Direct VPC Egress"
  type        = string
}

# Security Configuration
variable "authorized_members" {
  description = "List of members authorized to invoke the Cloud Run service (e.g., user:email@domain.com, serviceAccount:account@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for member in var.authorized_members :
      can(regex("^(user:|serviceAccount:|group:|domain:|allUsers$|allAuthenticatedUsers$)", member))
    ])
    error_message = "Members must start with user:, serviceAccount:, group:, domain: prefix or be 'allUsers' or 'allAuthenticatedUsers'"
  }
}

# Form.io Community Configuration
variable "community_version" {
  description = "Form.io Community edition version tag"
  type        = string
  default     = "rc"
}

variable "formio_root_email" {
  description = "Form.io root admin email"
  type        = string

  validation {
    condition     = can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", var.formio_root_email))
    error_message = "formio_root_email must be a valid email address"
  }
}

variable "base_url" {
  description = "Public URL where Form.io Community will be accessed (e.g., https://forms-community.dev.cloud.dsselectrical.com.au)"
  type        = string
  default     = ""
}

# Secret Manager Integration
variable "formio_root_password_secret_id" {
  description = "Secret Manager secret ID for Form.io root admin password"
  type        = string
}

variable "formio_jwt_secret_secret_id" {
  description = "Secret Manager secret ID for JWT secret"
  type        = string
}

variable "formio_db_secret_secret_id" {
  description = "Secret Manager secret ID for database encryption secret"
  type        = string
}

variable "portal_enabled" {
  description = "Whether to enable Form.io portal"
  type        = bool
  default     = true
}

# Database Configuration - Community specific
variable "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID containing MongoDB connection string"
  type        = string
}

# Note: Community edition uses hardcoded database name "formio_community"
# This ensures complete separation from Enterprise edition database

# Storage Configuration
variable "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  type        = string
}

# Resource Configuration
variable "max_instances" {
  description = "Maximum number of Cloud Run instances. Recommended: 10 for development, 50+ for production with high traffic"
  type        = number
  default     = 10

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 1000
    error_message = "max_instances must be between 1 and 1000"
  }
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances. 0=cold starts (cost-effective), 1=always warm (recommended for production), 2+=high availability"
  type        = number
  default     = 1

  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 100
    error_message = "min_instances must be between 0 and 100"
  }
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance. Recommended: 500m (light), 1000m (standard), 2000m (heavy workloads)"
  type        = string
  default     = "1000m"

  validation {
    condition     = can(regex("^[0-9]+m?$", var.cpu_request))
    error_message = "cpu_request must be a valid CPU value (e.g., 1000m, 2000m)"
  }
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance. 1Gi or 2Gi is sufficient for most workloads"
  type        = string
  default     = "2Gi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.memory_request))
    error_message = "memory_request must be a valid memory value (e.g., 512Mi, 1Gi, 2Gi)"
  }
}

variable "concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80

  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 1000
    error_message = "concurrency must be between 1 and 1000"
  }
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 3600
    error_message = "timeout_seconds must be between 1 and 3600 (1 hour)"
  }
}

# Monitoring and alerting configuration
variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts for service issues"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.alert_email_addresses :
      can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All alert_email_addresses must be valid email addresses"
  }
}

# Binary Authorization configuration
variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for container image security. Requires attestor setup."
  type        = bool
  default     = false
}

variable "attestor_public_key" {
  description = "PGP public key for Binary Authorization attestor (ASCII armored format)"
  type        = string
  default     = ""
  sensitive   = false # Public key is not sensitive
}