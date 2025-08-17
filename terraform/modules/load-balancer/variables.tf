# Load Balancer Module Variables
# Security-focused load balancer with Cloud Armor protection

# Project Configuration
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

# Service Configuration
variable "service_name" {
  description = "Name of the service for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service for backend"
  type        = string
}

# Security Configuration
variable "enable_geo_blocking" {
  description = "Enable geographic blocking to allow only Australia traffic"
  type        = bool
  default     = true
}

variable "ssl_domains" {
  description = "List of domains for managed SSL certificate"
  type        = list(string)
  validation {
    condition     = length(var.ssl_domains) > 0
    error_message = "At least one SSL domain must be specified."
  }
}

# Rate Limiting Configuration
variable "rate_limit_threshold_count" {
  description = "Number of requests allowed before rate limiting kicks in"
  type        = number
  default     = 100
  validation {
    condition     = var.rate_limit_threshold_count >= 10 && var.rate_limit_threshold_count <= 1000
    error_message = "Rate limit threshold must be between 10 and 1000 requests."
  }
}

variable "rate_limit_threshold_interval" {
  description = "Time window in seconds for rate limiting"
  type        = number
  default     = 60
  validation {
    condition     = var.rate_limit_threshold_interval >= 30 && var.rate_limit_threshold_interval <= 300
    error_message = "Rate limit interval must be between 30 and 300 seconds."
  }
}

variable "rate_limit_ban_duration" {
  description = "Duration in seconds to ban IPs that exceed rate limits"
  type        = number
  default     = 600
  validation {
    condition     = var.rate_limit_ban_duration >= 300 && var.rate_limit_ban_duration <= 3600
    error_message = "Ban duration must be between 300 and 3600 seconds (5 minutes to 1 hour)."
  }
}

# Health Check Configuration
variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Port for health checks"
  type        = number
  default     = 80
  validation {
    condition     = var.health_check_port > 0 && var.health_check_port <= 65535
    error_message = "Health check port must be between 1 and 65535."
  }
}

# Backend Configuration
variable "backend_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.backend_timeout_sec >= 10 && var.backend_timeout_sec <= 300
    error_message = "Backend timeout must be between 10 and 300 seconds."
  }
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for backend service"
  type        = bool
  default     = false
}

# Logging Configuration
variable "enable_access_logs" {
  description = "Enable access logging for backend service"
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sample rate for access logs (0.0 to 1.0)"
  type        = number
  default     = 1.0
  validation {
    condition     = var.log_sample_rate >= 0.0 && var.log_sample_rate <= 1.0
    error_message = "Log sample rate must be between 0.0 and 1.0."
  }
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}