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

  validation {
    condition     = var.formio_bucket_name == "" || can(regex("^dss-formio-[a-z0-9]+-[a-z]+-[a-z0-9]+$", var.formio_bucket_name))
    error_message = "Bucket name must follow pattern: dss-formio-{service}-{environment}-{suffix} (e.g., dss-formio-storage-dev-a1b2c3)."
  }
}