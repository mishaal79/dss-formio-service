# MongoDB Atlas Module Variables

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

variable "service_name" {
  description = "Name of the service (for resource naming)"
  type        = string
  default     = "dss-formio-api"
}

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# MongoDB Atlas Configuration
variable "atlas_project_name" {
  description = "Name of the MongoDB Atlas project"
  type        = string
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the MongoDB Atlas cluster"
  type        = string
}

variable "backing_provider_name" {
  description = "Cloud service provider on which MongoDB Atlas provisions the flex cluster"
  type        = string
  default     = "GCP"
  validation {
    condition     = contains(["AWS", "GCP", "AZURE"], var.backing_provider_name)
    error_message = "Backing provider name must be AWS, GCP, or AZURE."
  }
}

variable "atlas_region_name" {
  description = "Atlas region name for the cluster"
  type        = string
  default     = "AUSTRALIA_SOUTHEAST_1"
}

variable "termination_protection_enabled" {
  description = "Flag that indicates whether termination protection is enabled on the cluster"
  type        = bool
  default     = true
}

# Database Configuration
variable "admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"
}

variable "formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}

variable "database_name" {
  description = "Base name of the database to create for Form.io"
  type        = string
  default     = "formio"
}

variable "community_database_name" {
  description = "Full name of the Community database"
  type        = string
}

variable "enterprise_database_name" {
  description = "Full name of the Enterprise database"
  type        = string
}

# Network Security Configuration
variable "cloud_nat_static_ip" {
  description = "CIDR block for VPC egress subnet or static IP for secure Atlas connectivity"
  type        = string
}

# Secret Manager Configuration
variable "admin_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin password"
  type        = string
}

variable "formio_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB Form.io user password"
  type        = string
}

# Cluster Tags
variable "cluster_tags" {
  description = "Tags to apply to the MongoDB Atlas cluster"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}