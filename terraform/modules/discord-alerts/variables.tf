# =============================================================================
# DISCORD ALERTS MODULE - VARIABLES
# =============================================================================
# Configuration for Discord Alert Proxy Cloud Run service
# with severity-based channel routing
# =============================================================================

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run deployment"
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

variable "image_url" {
  description = "Container image URL for Discord Alert Proxy (e.g., gcr.io/project/discord-alert-proxy:latest)"
  type        = string
}

# =============================================================================
# DISCORD WEBHOOK CONFIGURATION - SEVERITY CHANNELS
# =============================================================================
# Each severity level routes to a different Discord channel
# This prevents alert fatigue by allowing users to mute low-priority channels

variable "discord_webhook_critical" {
  description = "Discord webhook URL for #alerts-critical channel (P1 alerts). Leave empty to manage via Secret Manager console."
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_webhook_warning" {
  description = "Discord webhook URL for #alerts-warning channel (P2 alerts). Leave empty to manage via Secret Manager console."
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_webhook_info" {
  description = "Discord webhook URL for #alerts-info channel (P3 alerts). Leave empty to manage via Secret Manager console."
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_webhook_resolved" {
  description = "Discord webhook URL for #alerts-resolved channel (resolution notifications). Leave empty to manage via Secret Manager console."
  type        = string
  default     = ""
  sensitive   = true
}

# Legacy single webhook (backwards compatibility)
variable "discord_webhook_url" {
  description = "DEPRECATED: Single Discord webhook URL. Use severity-specific webhooks instead."
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# DISCORD BOT CONFIGURATION (for slash commands)
# =============================================================================

variable "discord_bot_token" {
  description = "Discord bot token for slash commands (from Discord Developer Portal). Leave empty to disable bot features."
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_client_id" {
  description = "Discord application client ID for registering slash commands"
  type        = string
  default     = ""
}

variable "discord_guild_id" {
  description = "Discord server (guild) ID for guild-specific slash commands (dev only)"
  type        = string
  default     = ""
}

# =============================================================================
# DISCORD CHANNEL CONFIGURATION (v2 - channel-based routing)
# =============================================================================
# Bot posts directly to channels using its token (no webhook URLs needed)

variable "discord_channel_alerts" {
  description = "Discord channel ID for all alerts (single channel mode). Bot routes by severity if per-severity channels not set."
  type        = string
  default     = ""
}

variable "discord_channel_critical" {
  description = "Discord channel ID for critical alerts (optional, falls back to discord_channel_alerts)"
  type        = string
  default     = ""
}

variable "discord_channel_warning" {
  description = "Discord channel ID for warning alerts (optional, falls back to discord_channel_alerts)"
  type        = string
  default     = ""
}

variable "discord_channel_info" {
  description = "Discord channel ID for info alerts (optional, falls back to discord_channel_alerts)"
  type        = string
  default     = ""
}

variable "discord_channel_resolved" {
  description = "Discord channel ID for resolved alerts (optional, falls back to discord_channel_alerts)"
  type        = string
  default     = ""
}

# =============================================================================
# WEBHOOK SECURITY
# =============================================================================

variable "webhook_secret" {
  description = "Bearer token for webhook authentication. SigNoz sends: Authorization: Bearer <secret>"
  type        = string
  default     = ""
  sensitive   = true
}

variable "signoz_url" {
  description = "SigNoz instance URL for embedding alert links"
  type        = string
  default     = "https://app.signoz.com"
}

# =============================================================================
# DNS CONFIGURATION
# =============================================================================

variable "create_dns_record" {
  description = "Create DNS record for the bot service"
  type        = bool
  default     = false
}

variable "dns_project_id" {
  description = "GCP project ID containing the DNS zone"
  type        = string
  default     = ""
}

variable "dns_managed_zone" {
  description = "Name of the Cloud DNS managed zone"
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "DNS name for the bot (e.g., discord-bot.dev.cloud.dsselectrical.com.au)"
  type        = string
  default     = ""
}

# =============================================================================
# CLOUD RUN CONFIGURATION
# =============================================================================

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to webhook endpoint (required for SigNoz integration)"
  type        = bool
  default     = true
}

variable "authorized_invokers" {
  description = "List of service accounts authorized to invoke the service (e.g., serviceAccount:sa@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Logging level for the proxy service"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

# =============================================================================
# MONITORING CONFIGURATION
# =============================================================================

variable "enable_monitoring" {
  description = "Enable GCP Cloud Monitoring alerts for proxy service health"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "GCP notification channel IDs for proxy failure alerts (email, PagerDuty, etc.)"
  type        = list(string)
  default     = []
}

# =============================================================================
# LABELS
# =============================================================================

variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
