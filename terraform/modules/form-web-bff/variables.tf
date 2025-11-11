# =============================================================================
# FORM WEB BFF MODULE - INPUT VARIABLES
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
    condition     = contains(["dev", "staging", "prod"], var.environment)
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
# DOCKER IMAGE CONFIGURATION
# =============================================================================

variable "image_url" {
  description = "Full Docker image URL including tag (gcr.io/PROJECT_ID/form-web-bff:TAG)"
  type        = string
}

# =============================================================================
# PORT CONFIGURATION
# =============================================================================

variable "container_port" {
  description = "Container port for Fastify server (matches Dockerfile ARG PORT)"
  type        = number
  default     = 3002
  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "Container port must be between 1024 and 65535."
  }
}

# =============================================================================
# VPC NETWORKING CONFIGURATION
# =============================================================================

variable "vpc_connector_id" {
  description = "VPC connector ID for private networking (from central infrastructure)"
  type        = string
}

variable "vpc_egress_setting" {
  description = "VPC egress setting (PRIVATE_RANGES_ONLY recommended)"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_setting)
    error_message = "VPC egress setting must be either ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

# =============================================================================
# SERVICE-TO-SERVICE AUTHENTICATION
# =============================================================================

variable "formio_custom_service_name" {
  description = "Form.io custom service name for IAM binding (service-to-service auth)"
  type        = string
}

variable "formio_custom_service_url" {
  description = "Form.io custom service URL for backend requests"
  type        = string
}

# =============================================================================
# CLOUD RUN CONFIGURATION
# =============================================================================

variable "min_instance_count" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
  validation {
    condition     = var.min_instance_count >= 0
    error_message = "Minimum instance count must be non-negative."
  }
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
  validation {
    condition     = var.max_instance_count > 0
    error_message = "Maximum instance count must be positive."
  }
}

variable "container_concurrency" {
  description = "Maximum number of concurrent requests per container"
  type        = number
  default     = 80
  validation {
    condition     = var.container_concurrency >= 0
    error_message = "Container concurrency must be non-negative."
  }
}

variable "request_timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.request_timeout >= 1
    error_message = "Request timeout must be at least 1 second."
  }
}

variable "memory_limit" {
  description = "Memory limit per instance"
  type        = string
  default     = "512Mi"
  validation {
    condition     = can(regex("^[0-9]+(Ki|Mi|Gi)$", var.memory_limit))
    error_message = "Memory limit must be in format: <number><unit>, where unit is Ki, Mi, or Gi."
  }
}

variable "cpu_limit" {
  description = "CPU limit per instance"
  type        = string
  default     = "1000m"
  validation {
    condition     = can(regex("^[0-9]+m?$", var.cpu_limit))
    error_message = "CPU limit must be in format: <number>m or <number>, where m indicates millicores."
  }
}

# =============================================================================
# APPLICATION CONFIGURATION
# =============================================================================

variable "node_env" {
  description = "Node.js environment (development, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "production"], var.node_env)
    error_message = "Node environment must be development or production."
  }
}

variable "log_level" {
  description = "Logging level (debug, info, warn, error)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "cors_origin" {
  description = "CORS allowed origins (comma-separated or *)"
  type        = string
  default     = "*"
}

variable "rate_limit_max" {
  description = "Maximum requests per time window"
  type        = number
  default     = 100
  validation {
    condition     = var.rate_limit_max > 0 && var.rate_limit_max <= 10000
    error_message = "Rate limit max must be between 1 and 10000."
  }
}

variable "rate_limit_window_ms" {
  description = "Rate limiting time window in milliseconds"
  type        = number
  default     = 60000
  validation {
    condition     = var.rate_limit_window_ms >= 1000 && var.rate_limit_window_ms <= 3600000
    error_message = "Rate limit window must be between 1000ms and 3600000ms."
  }
}

# =============================================================================
# OBSERVABILITY CONFIGURATION
# =============================================================================

variable "otel_endpoint" {
  description = "OpenTelemetry collector endpoint (empty to disable)"
  type        = string
  default     = ""
}

# =============================================================================
# IAM CONFIGURATION
# =============================================================================

variable "allow_unauthenticated" {
  description = "Allow public access without authentication (dev/staging only)"
  type        = bool
  default     = false
}
