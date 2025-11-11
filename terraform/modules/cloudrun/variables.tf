/**
 * Terraform Module Variables: Cloud Run Service
 */

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "region" {
  description = "GCP region for Cloud Run deployment"
  type        = string
  default     = "us-central1"
}

variable "container_image" {
  description = "Container image URL (e.g., gcr.io/project-id/formio:tag)"
  type        = string
}

variable "allowed_origins" {
  description = "CORS allowed origins (Cloudflare Pages domains)"
  type        = list(string)
  default = [
    "https://forms.qrius.app",
    "https://staging-forms.qrius.dev",
    "https://tokenized-forms.pages.dev",
    "http://localhost:64849",
  ]
}

variable "custom_domains" {
  description = "Custom domains for SSL certificate"
  type        = list(string)
  default = [
    "api.qrius.app",
    "api-staging.qrius.dev",
  ]
}

variable "jwt_secret" {
  description = "JWT secret for Form.io authentication"
  type        = string
  sensitive   = true
}

variable "db_secret" {
  description = "Database encryption secret"
  type        = string
  sensitive   = true
}

variable "mongo_url" {
  description = "MongoDB connection string"
  type        = string
  sensitive   = true
}

variable "mongo_db_name" {
  description = "MongoDB database name"
  type        = string
  default     = "formioapp"
}

variable "redis_host" {
  description = "Redis host for BullMQ"
  type        = string
  sensitive   = true
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for backend service"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
