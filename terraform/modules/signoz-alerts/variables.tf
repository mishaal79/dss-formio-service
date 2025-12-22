# =============================================================================
# SIGNOZ ALERTS MODULE - VARIABLES
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "signoz_endpoint" {
  description = "SigNoz instance endpoint (e.g., https://your-instance.signoz.cloud)"
  type        = string
}

variable "signoz_api_token" {
  description = "SigNoz API token for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "notification_channels" {
  description = "Notification channel names by severity (must exist in SigNoz). Use Discord webhook for unified comms."
  type = object({
    critical = list(string)
    warning  = list(string)
    info     = list(string)
  })
  default = {
    critical = ["discord-alerts"]  # P1: @here mentions
    warning  = ["discord-alerts"]  # P2: Standard notification
    info     = ["discord-alerts"]  # P3: Low priority
  }
}

variable "api_endpoint" {
  description = "Public API endpoint URL for synthetic monitoring"
  type        = string
  default     = ""
}

variable "bff_endpoint" {
  description = "Public BFF endpoint URL for synthetic monitoring"
  type        = string
  default     = ""
}

variable "enable_synthetic_monitoring" {
  description = "Enable synthetic HTTP check monitoring alerts"
  type        = bool
  default     = false
}

# =============================================================================
# THRESHOLD OVERRIDES
# =============================================================================
# Allow environment-specific threshold adjustments

variable "error_rate_threshold_critical" {
  description = "Critical error rate threshold percentage"
  type        = number
  default     = 10.0
  validation {
    condition     = var.error_rate_threshold_critical > 0 && var.error_rate_threshold_critical <= 100
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "latency_p95_threshold_ms" {
  description = "P95 latency threshold in milliseconds"
  type        = number
  default     = 2000
  validation {
    condition     = var.latency_p95_threshold_ms > 0
    error_message = "Latency threshold must be positive."
  }
}

variable "auth_failure_threshold" {
  description = "Authentication failure count threshold"
  type        = number
  default     = 50
  validation {
    condition     = var.auth_failure_threshold > 0
    error_message = "Auth failure threshold must be positive."
  }
}
