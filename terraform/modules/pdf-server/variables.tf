# =============================================================================
# PDF SERVER MODULE VARIABLES
# =============================================================================

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

variable "service_name" {
  description = "Name of the PDF server service (without environment suffix)"
  type        = string
  default     = "formio-pdf"
}

# Form.io Configuration
variable "pdf_server_image" {
  description = "Docker image for Form.io PDF Plus server"
  type        = string
  default     = "formio/pdf-server:5.11.0-rc.34"
}

variable "pdf_libs_image" {
  description = "Docker image for Form.io PDF rendering libraries"
  type        = string
  default     = "formio/pdf-libs:2.2.4"
}

variable "formio_license_secret_id" {
  description = "Secret Manager secret ID for Form.io Enterprise license key"
  type        = string
  default     = ""
}

variable "mongodb_connection_secret_id" {
  description = "Secret Manager secret ID containing MongoDB connection string"
  type        = string
}

# Storage Configuration
variable "storage_bucket_name" {
  description = "Name of the GCS bucket for PDF storage"
  type        = string
}

# Network Configuration
variable "vpc_network" {
  description = "VPC network ID for Direct VPC Egress"
  type        = string
}

variable "vpc_connector_subnet" {
  description = "Subnet ID for VPC connector"
  type        = string
}

# Resource Configuration
variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 3
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
  default     = 50
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

# Security Configuration
variable "allow_public_access" {
  description = "Whether to allow public access to the PDF server"
  type        = bool
  default     = false
}

variable "authorized_members" {
  description = "List of members authorized to invoke the PDF server"
  type        = list(string)
  default     = []
}

# Labels
variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Debug Configuration
variable "debug_mode" {
  description = "Enable debug mode for PDF server"
  type        = bool
  default     = false
}