# Basic Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "labels" {
  description = "Common labels to apply to resources"
  type        = map(string)
  default     = {}
}

# Form.io Configuration
variable "formio_image" {
  description = "Form.io Docker image (enterprise or community)"
  type        = string
}

variable "use_enterprise" {
  description = "Whether to use Form.io Enterprise edition"
  type        = bool
  default     = true
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

# Dependencies
variable "mongodb_connection_string" {
  description = "DEPRECATED: MongoDB connection string (use mongodb_connection_string_secret_id)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID containing the MongoDB connection string"
  type        = string
}

variable "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  type        = string
}

variable "vpc_connector_id" {
  description = "VPC connector ID for private networking (supports shared infrastructure)"
  type        = string
  default     = null
}

# PostgreSQL Configuration (New)
variable "postgresql_connection_string" {
  description = "PostgreSQL connection string for custom integrations"
  type        = string
  default     = ""
  sensitive   = true
}

# Event-driven Configuration (New)
variable "webhook_url" {
  description = "Webhook URL for form events"
  type        = string
  default     = ""
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic name for form events"
  type        = string
  default     = ""
}

# Custom API Layer Configuration (New)
variable "custom_api_url" {
  description = "Custom API layer URL for PostgreSQL integration"
  type        = string
  default     = ""
}