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

# Load balancer configuration removed - now using centralized architecture
# Backend service and NEG are always created for centralized load balancer integration

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

variable "base_url" {
  description = "Public URL where Form.io will be accessed (e.g., https://forms.dev.cloud.dsselectrical.com.au)"
  type        = string
  default     = ""
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

# Legacy variables removed for security - use Secret Manager exclusively

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

# Removed: enable_cloud_nat - Cloud NAT managed by central infrastructure

# Monitoring and alerting configuration
variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts for service issues"
  type        = list(string)
  default     = []
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

variable "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  type        = string
}

# Resource Configuration
variable "max_instances" {
  description = "Maximum number of Cloud Run instances. Recommended: 10 for development, 50+ for production with high traffic"
  type        = number
  default     = 10
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances. 0=cold starts (cost-effective), 1=always warm (recommended for production), 2+=high availability"
  type        = number
  default     = 0
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance. Recommended: 500m (light), 1000m (standard), 2000m (heavy workloads)"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance. 1Gi or 2Gi is sufficient for most workloads"
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

