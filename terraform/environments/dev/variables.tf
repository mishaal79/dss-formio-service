# Development Environment Variables
# Form.io Enterprise Service - Development Configuration

# Project Configuration
variable "project_id" {
  description = "The GCP project ID for development environment"
  type        = string
  default     = "erlich-dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The GCP region for development deployment"
  type        = string
  default     = "australia-southeast1"
  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1", "australia-southeast1", "australia-southeast2"], var.region)
    error_message = "Region must be one of: us-central1, us-east1, us-west1, europe-west1, australia-southeast1, australia-southeast2."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = var.environment == "dev"
    error_message = "Environment must be 'dev' for this configuration."
  }
}

# Security Configuration
variable "authorized_members" {
  description = "List of members authorized to invoke the Form.io Cloud Run services (e.g., user:your-email@domain.com)"
  type        = list(string)
  default = [
    "user:admin@dsselectrical.com.au",
    "user:mishal@qrius.global"
  ]
}

# Service Deployment Controls
variable "deploy_custom" {
  description = "Whether to deploy Form.io Custom Enhanced edition service"
  type        = bool
  default     = true
}

variable "deploy_community" {
  description = "Whether to deploy Form.io Community edition service (legacy)"
  type        = bool
  default     = false
}

variable "deploy_enterprise" {
  description = "Whether to deploy Form.io Enterprise edition service"
  type        = bool
  default     = true
}

# Form.io Enterprise Configuration
variable "formio_version" {
  description = "Form.io Enterprise version tag"
  type        = string
  default     = "9.6.0-rc.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-rc\\.[0-9]+)?$", var.formio_version))
    error_message = "Version must be in semantic version format (e.g., 9.5.0) or release candidate format (e.g., 9.5.1-rc.10)."
  }
}

variable "community_version" {
  description = "Form.io Community edition version tag"
  type        = string
  default     = "rc"
}

variable "formio_license_key" {
  description = "Form.io Enterprise license key"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.formio_license_key) > 10
    error_message = "License key must be provided and be longer than 10 characters."
  }
}

variable "formio_root_email" {
  description = "Form.io root admin email"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.formio_root_email))
    error_message = "Must be a valid email address."
  }
}




# Service Configuration - Development Optimized
variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "dss-formio-api"
  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 5 # Reduced for dev environment
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 10
    error_message = "Max instances must be between 1 and 10 for development environment."
  }
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1 # Always keep 1 instance to avoid cold starts for Form.io Enterprise
  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 2
    error_message = "Min instances must be between 0 and 2 for development environment."
  }
}

variable "cpu_request" {
  description = "CPU request for each Cloud Run instance"
  type        = string
  default     = "1000m" # 1 vCPU for dev
  validation {
    condition     = contains(["1000m", "2000m"], var.cpu_request)
    error_message = "CPU request must be either 1000m or 2000m for development environment."
  }
}

variable "memory_request" {
  description = "Memory request for each Cloud Run instance"
  type        = string
  default     = "2Gi" # 2GB for dev
  validation {
    condition     = contains(["1Gi", "2Gi", "4Gi"], var.memory_request)
    error_message = "Memory request must be 1Gi, 2Gi, or 4Gi for development environment."
  }
}

variable "concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80
  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 100
    error_message = "Concurrency must be between 1 and 100."
  }
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.timeout_seconds >= 60 && var.timeout_seconds <= 3600
    error_message = "Timeout must be between 60 and 3600 seconds."
  }
}

# Storage Configuration
variable "formio_bucket_name" {
  description = "Name of the GCS bucket for Form.io file storage"
  type        = string
  default     = "" # Will be auto-generated if empty
}

# MongoDB Atlas Configuration
variable "mongodb_atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "mongodb_admin_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "mongoAdmin"
}


variable "mongodb_formio_username" {
  description = "MongoDB username for Form.io application"
  type        = string
  default     = "formioUser"
}


variable "mongodb_database_name" {
  description = "MongoDB database name for Form.io"
  type        = string
  default     = "formio"
}



# Monitoring Configuration (placeholder for future use)
# variable "notification_channels" {
#   description = "List of notification channel IDs for alerts"
#   type        = list(string)
#   default     = []
# }

# Domain Configuration (Optional for dev)
variable "custom_domain" {
  description = "Custom domain for Form.io service"
  type        = string
  default     = ""
}

# SSL certificate configuration (placeholder for future use)
# variable "ssl_certificate_id" {
#   description = "SSL certificate ID for custom domain"
#   type        = string
#   default     = ""
# }

# Portal Configuration
variable "portal_enabled" {
  description = "Enable Form.io developer portal"
  type        = bool
  default     = true
}

# =============================================================================
# LOAD BALANCER CONFIGURATION (REMOVED - NOW USING CENTRALIZED ARCHITECTURE)
# =============================================================================

# Load balancer configuration has been moved to centralized central infrastructure
# This service now focuses solely on application deployment and exposes backend services
# for integration with the centralized load balancer
# =============================================================================
# PDF SERVER CONFIGURATION
# =============================================================================

variable "deploy_pdf_server" {
  description = "Whether to deploy the PDF Plus server for Form.io Enterprise"
  type        = bool
  default     = true
}

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

# PDF Server Resource Configuration
variable "pdf_min_instances" {
  description = "Minimum number of PDF server instances"
  type        = number
  default     = 0
}

variable "pdf_max_instances" {
  description = "Maximum number of PDF server instances"
  type        = number
  default     = 3
}

variable "pdf_cpu_request" {
  description = "CPU request for PDF server instances"
  type        = string
  default     = "1000m"
}

variable "pdf_memory_request" {
  description = "Memory request for PDF server instances"
  type        = string
  default     = "2Gi"
}

variable "pdf_concurrency" {
  description = "Maximum concurrent requests per PDF server instance"
  type        = number
  default     = 50
}

variable "pdf_timeout_seconds" {
  description = "Request timeout for PDF server in seconds"
  type        = number
  default     = 300
}

# Debug Configuration
variable "debug_mode" {
  description = "Enable debug mode for PDF server"
  type        = bool
  default     = false
}

# =============================================================================
# CUSTOM FORM.IO SERVICE CONFIGURATION
# =============================================================================

# Custom Image Configuration
variable "custom_image_tag" {
  description = "Docker image tag for custom Form.io enhanced edition (mutable major tag for auto-updates)"
  type        = string
  default     = "4" # Mutable tag - auto-updates with minor/patch releases (4.6.0, 4.7.0, etc.)
}

variable "enable_blue_green" {
  description = "Enable blue-green deployment for custom service"
  type        = bool
  default     = false
}

variable "traffic_percent_new" {
  description = "Traffic percentage for new version (blue-green)"
  type        = number
  default     = 10
}

variable "new_revision_name" {
  description = "Name of the new revision for blue-green deployment"
  type        = string
  default     = ""
}

# Enhanced File Upload Configuration
variable "enable_async_gcs_upload" {
  description = "Enable asynchronous GCS file uploads with BullMQ"
  type        = bool
  default     = true
}

variable "bullmq_worker_concurrency" {
  description = "Number of BullMQ workers for async file processing"
  type        = number
  default     = 3
}

variable "xxhash_enabled" {
  description = "Enable xxHash for fast file integrity validation"
  type        = bool
  default     = true
}

variable "railway_oriented_uploads" {
  description = "Enable railway-oriented atomic uploads"
  type        = bool
  default     = true
}

# Redis Configuration (BullMQ)
variable "redis_host" {
  description = "Redis host address for BullMQ job queue"
  type        = string
  default     = "10.8.0.2" # VPC connector IP
}

variable "redis_port" {
  description = "Redis port for BullMQ job queue"
  type        = number
  default     = 6379
}

# TUS Upload Configuration
variable "tus_enabled" {
  description = "Enable TUS resumable uploads"
  type        = bool
  default     = true
}

variable "tus_port" {
  description = "TUS server port"
  type        = number
  default     = 1080
}

variable "tus_max_size" {
  description = "Maximum file size for TUS uploads in bytes"
  type        = number
  default     = 5368709120 # 5GB
}

# Email Configuration
variable "email_type" {
  description = "Email service type"
  type        = string
  default     = "smtp"
}

variable "email_host" {
  description = "Email server host"
  type        = string
  default     = "smtp.gmail.com"
}

variable "email_port" {
  description = "Email server port"
  type        = number
  default     = 587
}

variable "email_secure" {
  description = "Use secure connection for email"
  type        = bool
  default     = true
}

variable "email_user" {
  description = "Email authentication username"
  type        = string
  default     = ""
}

variable "email_password_secret_id" {
  description = "Secret Manager secret ID for email password"
  type        = string
  default     = null
}

# CORS Configuration
variable "cors_enabled" {
  description = "Enable CORS"
  type        = bool
  default     = true
}

variable "cors_origin" {
  description = "CORS allowed origins"
  type        = string
  default     = "*"
}

# Cloud Run Configuration
variable "min_instance_count" {
  description = "Minimum number of Cloud Run instances for custom service"
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Run instances for custom service"
  type        = number
  default     = 10
}

variable "container_concurrency" {
  description = "Maximum number of concurrent requests per container"
  type        = number
  default     = 80
}

variable "request_timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

variable "memory_limit" {
  description = "Memory limit per instance"
  type        = string
  default     = "1Gi"
}

variable "cpu_limit" {
  description = "CPU limit per instance"
  type        = string
  default     = "1000m"
}

# CDN Configuration
variable "cache_default_ttl" {
  description = "Default cache TTL in seconds"
  type        = number
  default     = 3600 # 1 hour
}

variable "cache_max_ttl" {
  description = "Maximum cache TTL in seconds"
  type        = number
  default     = 86400 # 24 hours
}

variable "cache_client_ttl" {
  description = "Client cache TTL in seconds"
  type        = number
  default     = 1800 # 30 minutes
}

variable "cache_query_whitelist" {
  description = "Query string parameters to include in cache key"
  type        = list(string)
  default     = ["version", "locale", "v"]
}

variable "cache_headers" {
  description = "HTTP headers to include in cache key"
  type        = list(string)
  default     = ["Authorization", "Cookie"]
}

variable "bypass_cache_headers" {
  description = "Request headers that bypass cache"
  type        = list(string)
  default     = ["Authorization", "Cookie"]
}

variable "log_sample_rate" {
  description = "Sample rate for CDN logging"
  type        = number
  default     = 0.1
}

# IAP Configuration
variable "iap_enabled" {
  description = "Enable Identity-Aware Proxy"
  type        = bool
  default     = false
}

variable "iap_client_id" {
  description = "IAP OAuth2 client ID"
  type        = string
  default     = ""
}

variable "iap_client_secret" {
  description = "IAP OAuth2 client secret"
  type        = string
  default     = ""
  sensitive   = true
}

# DNS Configuration
variable "create_dns_record" {
  description = "Create DNS record for the service"
  type        = bool
  default     = false
}

variable "dns_project_id" {
  description = "DNS project ID"
  type        = string
  default     = "erlich-dev"
}

variable "dns_managed_zone" {
  description = "DNS managed zone name"
  type        = string
  default     = "dsselectrical-com-au"
}

variable "dns_name" {
  description = "DNS record name"
  type        = string
  default     = "forms-custom-dev"
}

# Monitoring and Alerting
variable "enable_alerting" {
  description = "Enable monitoring alerts"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Error rate threshold for alerts"
  type        = number
  default     = 5.0
}

variable "latency_threshold" {
  description = "Latency threshold for alerts (ms)"
  type        = number
  default     = 1000
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "debug_enabled" {
  description = "Enable debug logging"
  type        = bool
  default     = false
}

# GCS Project Configuration
variable "gcs_project_id" {
  description = "GCP project ID for GCS operations"
  type        = string
  default     = "" # Uses project_id if empty
}
