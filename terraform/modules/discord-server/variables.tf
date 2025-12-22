# =============================================================================
# DISCORD SERVER MODULE - VARIABLES
# =============================================================================

variable "discord_server_id" {
  description = "Discord server (guild) ID. Find via Server Settings → Widget → Server ID, or enable Developer Mode and right-click server."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.discord_server_id))
    error_message = "Discord server ID must be a numeric string (snowflake ID)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod) - used in category naming"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "category_position" {
  description = "Position of the Monitoring category in the channel list (0 = top)"
  type        = number
  default     = 0
}

variable "restrict_posting" {
  description = "Restrict @everyone from posting in alert channels (only webhooks can post)"
  type        = bool
  default     = true
}
