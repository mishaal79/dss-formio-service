/**
 * Terraform Variables: Production Environment
 */

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "container_image" {
  description = "Container image URL"
  type        = string
}

variable "allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default = [
    "https://forms.qrius.app",
    "https://tokenized-forms.pages.dev",
  ]
}

variable "custom_domains" {
  description = "Custom domains for SSL certificate"
  type        = list(string)
  default = [
    "api.qrius.app",
  ]
}

variable "jwt_secret" {
  description = "JWT secret"
  type        = string
  sensitive   = true
}

variable "db_secret" {
  description = "Database secret"
  type        = string
  sensitive   = true
}

variable "mongo_url" {
  description = "MongoDB URL"
  type        = string
  sensitive   = true
}

variable "mongo_db_name" {
  description = "MongoDB database name"
  type        = string
  default     = "formioapp"
}

variable "redis_host" {
  description = "Redis host"
  type        = string
  sensitive   = true
}
