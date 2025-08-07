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

# PostgreSQL Instance Configuration
variable "instance_name" {
  description = "Name of the Cloud SQL PostgreSQL instance"
  type        = string
  default     = "formio-postgres"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
  
  validation {
    condition = contains([
      "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "POSTGRES_16"
    ], var.postgres_version)
    error_message = "PostgreSQL version must be one of: POSTGRES_13, POSTGRES_14, POSTGRES_15, POSTGRES_16."
  }
}

variable "tier" {
  description = "The machine type for the PostgreSQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "The availability type of the Cloud SQL instance"
  type        = string
  default     = "ZONAL"
  
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be either ZONAL or REGIONAL."
  }
}

variable "disk_type" {
  description = "The type of disk for the instance"
  type        = string
  default     = "PD_SSD"
  
  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "Disk type must be either PD_SSD or PD_HDD."
  }
}

variable "disk_size" {
  description = "The disk size for the instance in GB"
  type        = number
  default     = 20
}

variable "disk_autoresize" {
  description = "Whether to enable automatic resize of the disk"
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "The maximum size to which storage capacity can be automatically increased"
  type        = number
  default     = 100
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = true
}

# Database Configuration
variable "admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}

variable "formio_username" {
  description = "Form.io application username"
  type        = string
  default     = "formio_user"
}

variable "formio_database_name" {
  description = "Form.io database name"
  type        = string
  default     = "formio"
}

# Network Configuration
variable "public_ip_enabled" {
  description = "Whether to enable public IP for the instance"
  type        = bool
  default     = false
}

variable "private_network" {
  description = "The VPC network from which the Cloud SQL instance is accessible for private IP"
  type        = string
  default     = ""
}

variable "require_ssl" {
  description = "Whether to require SSL connections"
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "List of authorized networks for public IP access"
  type = list(object({
    display_name = string
    cidr_block   = string
  }))
  default = []
}

# Backup Configuration
variable "backup_enabled" {
  description = "Whether to enable automated backups"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "The start time for the backup in HH:MM format"
  type        = string
  default     = "03:00"
}

variable "point_in_time_recovery" {
  description = "Whether to enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "The number of days to retain backups"
  type        = number
  default     = 7
}

# Maintenance Configuration
variable "maintenance_window_day" {
  description = "The day of the week for maintenance (1-7, 1=Monday)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "Maintenance window day must be between 1 and 7."
  }
}

variable "maintenance_window_hour" {
  description = "The hour of the day for maintenance (0-23)"
  type        = number
  default     = 3
  
  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "Maintenance window hour must be between 0 and 23."
  }
}

variable "maintenance_window_update_track" {
  description = "The update track for maintenance"
  type        = string
  default     = "stable"
  
  validation {
    condition     = contains(["canary", "stable"], var.maintenance_window_update_track)
    error_message = "Maintenance window update track must be either 'canary' or 'stable'."
  }
}