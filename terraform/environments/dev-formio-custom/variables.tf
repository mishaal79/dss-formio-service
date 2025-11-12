variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "erlich-dev"
}

variable "region" {
  description = "GCP region for Cloud Run service"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
