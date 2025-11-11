# =============================================================================
# FORM.IO CUSTOM SERVICE - INPUT VARIABLES
# =============================================================================

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region for deployment"
  type        = string
  default     = "australia-southeast1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "dss-formio"
  }
}

# =============================================================================
# CUSTOM IMAGE CONFIGURATION
# =============================================================================

variable "custom_image_tag" {
  description = "Custom Docker image tag for Form.io enhanced edition"
  type        = string
  default     = "latest"
}

variable "enable_blue_green" {
  description = "Enable blue-green deployment strategy"
  type        = bool
  default     = false
}

variable "traffic_percent_new" {
  description = "Traffic percentage for new version (blue-green)"
  type        = number
  default     = 10
  validation {
    condition = var.traffic_percent_new >= 0 && var.traffic_percent_new <= 100
    error_message = "Traffic percent must be between 0 and 100."
  }
}

variable "new_revision_name" {
  description = "Name of the new revision for blue-green deployment"
  type        = string
  default     = ""
}

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================

variable "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID for MongoDB connection string"
  type        = string
}

variable "mongodb_database_name" {
  description = "MongoDB database name for Form.io"
  type        = string
  default     = "formioapp"
}

# =============================================================================
# SECRETS CONFIGURATION
# =============================================================================

variable "formio_jwt_secret_secret_id" {
  description = "Secret Manager secret ID for Form.io JWT secret"
  type        = string
}

variable "formio_db_secret_secret_id" {
  description = "Secret Manager secret ID for Form.io database secret"
  type        = string
}

variable "formio_root_email" {
  description = "Form.io root administrator email"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.formio_root_email))
    error_message = "Root email must be a valid email address."
  }
}

variable "formio_root_password_secret_id" {
  description = "Secret Manager secret ID for Form.io root password"
  type        = string
}

# =============================================================================
# ENHANCED FILE UPLOAD CONFIGURATION
# =============================================================================

variable "enable_async_gcs_upload" {
  description = "Enable asynchronous GCS file uploads with BullMQ"
  type        = bool
  default     = true
}

variable "bullmq_worker_concurrency" {
  description = "Number of BullMQ workers for async file processing"
  type        = number
  default     = 3
  validation {
    condition = var.bullmq_worker_concurrency >= 1 && var.bullmq_worker_concurrency <= 20
    error_message = "Worker concurrency must be between 1 and 20."
  }
}

variable "xxhash_enabled" {
  description = "Enable xxHash for fast file integrity validation"
  type        = bool
  default     = true
}

variable "railway_oriented_uploads" {
  description = "Enable railway-oriented atomic uploads (zero orphaned files)"
  type        = bool
  default     = true
}

# =============================================================================
# STORAGE CONFIGURATION
# =============================================================================

variable "storage_bucket_name" {
  description = "Google Cloud Storage bucket name for file uploads"
  type        = string
}

variable "gcs_project_id" {
  description = "GCP project ID for GCS operations"
  type        = string
  default     = ""
}

# =============================================================================
# REDIS CONFIGURATION (BullMQ)
# =============================================================================

variable "redis_host" {
  description = "Redis host address for BullMQ job queue"
  type        = string
  default     = "10.8.0.2"  # Default VPC connector IP
}

variable "redis_port" {
  description = "Redis port for BullMQ job queue"
  type        = number
  default     = 6379
  validation {
    condition = var.redis_port >= 1 && var.redis_port <= 65535
    error_message = "Redis port must be between 1 and 65535."
  }
}

variable "redis_password_secret_id" {
  description = "Secret Manager secret ID for Redis password (optional)"
  type        = string
  default     = null
}

# =============================================================================
# SERVICE CONFIGURATION
# =============================================================================

variable "portal_enabled" {
  description = "Enable Form.io admin portal"
  type        = bool
  default     = true
}

variable "debug_enabled" {
  description = "Enable debug logging"
  type        = bool
  default     = false
}

# =============================================================================
# TUS UPLOAD CONFIGURATION
# =============================================================================

variable "tus_enabled" {
  description = "Enable TUS resumable uploads"
  type        = bool
  default     = true
}

variable "tus_port" {
  description = "TUS server port"
  type        = number
  default     = 1080
  validation {
    condition = var.tus_port >= 1 && var.tus_port <= 65535
    error_message = "TUS port must be between 1 and 65535."
  }
}

variable "tus_max_size" {
  description = "Maximum file size for TUS uploads in bytes"
  type        = number
  default     = 5368709120  # 5GB
  validation {
    condition = var.tus_max_size >= 0
    error_message = "TUS max size must be non-negative."
  }
}

# =============================================================================
# EMAIL CONFIGURATION
# =============================================================================

variable "email_type" {
  description = "Email service type (smtp, sendgrid, ses)"
  type        = string
  default     = "smtp"
  validation {
    condition = contains(["smtp", "sendgrid", "ses", "local"], var.email_type)
    error_message = "Email type must be one of: smtp, sendgrid, ses, local."
  }
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
  validation {
    condition = var.email_port >= 1 && var.email_port <= 65535
    error_message = "Email port must be between 1 and 65535."
  }
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

# =============================================================================
# CORS CONFIGURATION
# =============================================================================

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

# =============================================================================
# CLOUD RUN CONFIGURATION
# =============================================================================

variable "min_instance_count" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
  validation {
    condition = var.min_instance_count >= 0
    error_message = "Minimum instance count must be non-negative."
  }
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 100
  validation {
    condition = var.max_instance_count > 0
    error_message = "Maximum instance count must be positive."
  }
}

variable "container_concurrency" {
  description = "Maximum number of concurrent requests per container"
  type        = number
  default     = 80
  validation {
    condition = var.container_concurrency >= 0
    error_message = "Container concurrency must be non-negative."
  }
}

variable "request_timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition = var.request_timeout >= 1
    error_message = "Request timeout must be at least 1 second."
  }
}

variable "memory_limit" {
  description = "Memory limit per instance"
  type        = string
  default     = "1Gi"
  validation {
    condition = can(regex("^[0-9]+(Ki|Mi|Gi)$", var.memory_limit))
    error_message = "Memory limit must be in format: <number><unit>, where unit is Ki, Mi, or Gi."
  }
}

variable "memory_request" {
  description = "Memory request per instance"
  type        = string
  default     = "512Mi"
  validation {
    condition = can(regex("^[0-9]+(Ki|Mi|Gi)$", var.memory_request))
    error_message = "Memory request must be in format: <number><unit>, where unit is Ki, Mi, or Gi."
  }
}

variable "cpu_limit" {
  description = "CPU limit per instance"
  type        = string
  default     = "1000m"
  validation {
    condition = can(regex("^[0-9]+m?$", var.cpu_limit))
    error_message = "CPU limit must be in format: <number>m or <number>, where m indicates millicores."
  }
}

variable "cpu_request" {
  description = "CPU request per instance"
  type        = string
  default     = "500m"
  validation {
    condition = can(regex("^[0-9]+m?$", var.cpu_request))
    error_message = "CPU request must be in format: <number>m or <number>, where m indicates millicores."
  }
}

# =============================================================================
# CDN CONFIGURATION
# =============================================================================

variable "cache_default_ttl" {
  description = "Default cache TTL in seconds"
  type        = number
  default     = 3600  # 1 hour
  validation {
    condition = var.cache_default_ttl >= 0
    error_message = "Default TTL must be non-negative."
  }
}

variable "cache_max_ttl" {
  description = "Maximum cache TTL in seconds"
  type        = number
  default     = 86400  # 24 hours
  validation {
    condition = var.cache_max_ttl >= 0
    error_message = "Max TTL must be non-negative."
  }
}

variable "cache_client_ttl" {
  description = "Client cache TTL in seconds"
  type        = number
  default     = 1800  # 30 minutes
  validation {
    condition = var.cache_client_ttl >= 0
    error_message = "Client TTL must be non-negative."
  }
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

variable "cache_named_headers" {
  description = "Named HTTP headers to include in cache key"
  type        = list(string)
  default     = []
}

variable "bypass_cache_headers" {
  description = "Request headers that bypass cache"
  type        = list(string)
  default     = ["Authorization", "Cookie"]
}

variable "log_sample_rate" {
  description = "Sample rate for CDN logging (0.0 to 1.0)"
  type        = number
  default     = 0.1
  validation {
    condition = var.log_sample_rate >= 0.0 && var.log_sample_rate <= 1.0
    error_message = "Log sample rate must be between 0.0 and 1.0."
  }
}

# =============================================================================
# IDENTITY-AWARE PROXY (IAP) CONFIGURATION
# =============================================================================

variable "iap_enabled" {
  description = "Enable Identity-Aware Proxy for additional security"
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

# =============================================================================
# DNS CONFIGURATION
# =============================================================================

variable "create_dns_record" {
  description = "Create DNS record for the service"
  type        = bool
  default     = false
}

variable "dns_project_id" {
  description = "DNS project ID"
  type        = string
  default     = ""
}

variable "dns_managed_zone" {
  description = "DNS managed zone name"
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "DNS record name"
  type        = string
  default     = ""
}

# =============================================================================
# MONITORING AND ALERTING
# =============================================================================

variable "enable_alerting" {
  description = "Enable monitoring alerts"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Error rate threshold for alerts (percentage)"
  type        = number
  default     = 5.0
  validation {
    condition = var.error_rate_threshold >= 0.0 && var.error_rate_threshold <= 100.0
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "latency_threshold" {
  description = "Latency threshold for alerts (milliseconds)"
  type        = number
  default     = 1000
  validation {
    condition = var.latency_threshold >= 0
    error_message = "Latency threshold must be non-negative."
  }
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

# =============================================================================
# DEPRECATED VARIABLES (for backward compatibility)
# =============================================================================

variable "formio_license_key" {
  description = "Form.io license key (not needed for custom edition)"
  type        = string
  default     = ""
  validation {
    condition     = var.formio_license_key == ""
    error_message = "License key is not needed for custom edition."
  }
}