# Storage Module Variables

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

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "labels" {
  description = "Common labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "formio_bucket_name" {
  description = "Name of the GCS bucket for Form.io file storage"
  type        = string
  default     = ""

  # Validation temporarily disabled for existing bucket
  # validation {
  #   condition     = var.formio_bucket_name == "" || can(regex("^formio-uploads-[a-z0-9-]+$", var.formio_bucket_name))
  #   error_message = "Bucket name must follow pattern: formio-uploads-{environment}-{project}-{suffix}."
  # }
}

variable "enable_versioning" {
  description = "Enable versioning on the storage bucket"
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for cost optimization"
  type        = bool
  default     = true
}

variable "cors_origins" {
  description = "List of origins allowed for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "kms_key_name" {
  description = "The Cloud KMS key name for CMEK encryption (optional)"
  type        = string
  default     = null
}