# =============================================================================
# SECRETS MODULE VARIABLES
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "service_name" {
  description = "Name of the service for secret naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must follow kebab-case format: lowercase letters, numbers, and hyphens only, starting and ending with alphanumeric characters."
  }
}

variable "labels" {
  description = "Common labels to apply to all secrets"
  type        = map(string)
  default     = {}
}

variable "formio_license_key" {
  description = "Form.io Enterprise license key (optional, will create placeholder if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}