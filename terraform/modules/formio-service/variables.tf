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
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
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

variable "enable_load_balancer" {
  description = "Enable load balancer access (grants allUsers access for load balancer backends)"
  type        = bool
  default     = false
}

# Form.io Edition Configuration
variable "use_enterprise" {
  description = "Whether to use Form.io Enterprise edition"
  type        = bool
  default     = false
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
  description = "Form.io Enterprise license key (required if use_enterprise = true)"
  type        = string
  default     = ""
  sensitive   = true
}

# Service Configuration
variable "service_name" {
  description = "Name of the Cloud Run service (without environment suffix)"
  type        = string
}

variable "formio_root_email" {
  description = "Form.io root admin email"
  type        = string
}

variable "formio_root_password_secret_id" {
  description = "Secret Manager secret ID for Form.io root admin password"
  type        = string
  default     = null
}

variable "formio_jwt_secret_secret_id" {
  description = "Secret Manager secret ID for JWT secret"
  type        = string
  default     = null
}

variable "formio_db_secret_secret_id" {
  description = "Secret Manager secret ID for database encryption secret"
  type        = string
  default     = null
}

# Legacy variables for backward compatibility (deprecated)
variable "formio_root_password" {
  description = "DEPRECATED: Use formio_root_password_secret_id instead"
  type        = string
  default     = ""
  sensitive   = true
}

variable "formio_jwt_secret" {
  description = "DEPRECATED: Use formio_jwt_secret_secret_id instead"
  type        = string
  default     = ""
  sensitive   = true
}

variable "formio_db_secret" {
  description = "DEPRECATED: Use formio_db_secret_secret_id instead"
  type        = string
  default     = ""
  sensitive   = true
}

variable "portal_enabled" {
  description = "Whether to enable Form.io portal"
  type        = bool
  default     = true
}

# Database Configuration
variable "database_name" {
  description = "MongoDB database name for this Form.io service"
  type        = string
}

variable "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID containing MongoDB connection string"
  type        = string
}

# Infrastructure Dependencies
# VPC connector removed - using Direct VPC egress with Cloud NAT for cost optimization

variable "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  type        = string
}

# Resource Configuration
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

# Custom Domain Configuration
variable "custom_domains" {
  description = "List of custom domains for whitelabeling (will be activated when DNS is configured)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for domain in var.custom_domains :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\\.[a-zA-Z]{2,}$", domain))
    ])
    error_message = "All custom domains must be valid domain names"
  }
}