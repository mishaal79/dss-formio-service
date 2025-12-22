# =============================================================================
# SigNoz Notification Channel Module
# =============================================================================
# Creates notification channels in SigNoz via REST API
# Uses null_resource + local-exec since restapi provider can't be used with count
# =============================================================================

terraform {
  required_version = ">= 1.0"
}

variable "signoz_url" {
  description = "SigNoz instance URL"
  type        = string
  default     = "https://dsselectrical.us.signoz.cloud"
}

variable "signoz_api_key" {
  description = "SigNoz API key for authentication"
  type        = string
  sensitive   = true
}

variable "channel_name" {
  description = "Name of the notification channel"
  type        = string
}

variable "webhook_url" {
  description = "Webhook URL to send alerts to"
  type        = string
}

variable "webhook_secret" {
  description = "Bearer token for webhook authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "send_resolved" {
  description = "Send resolved notifications"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

locals {
  full_channel_name = "${var.channel_name}-${var.environment}"

  # Build the webhook config JSON
  webhook_config = var.webhook_secret != "" ? jsonencode({
    name = local.full_channel_name
    webhook_configs = [{
      send_resolved = var.send_resolved
      url           = var.webhook_url
      http_config = {
        authorization = {
          type        = "Bearer"
          credentials = var.webhook_secret
        }
      }
    }]
  }) : jsonencode({
    name = local.full_channel_name
    webhook_configs = [{
      send_resolved = var.send_resolved
      url           = var.webhook_url
    }]
  })
}

# -----------------------------------------------------------------------------
# Create Notification Channel via API
# -----------------------------------------------------------------------------

resource "null_resource" "create_notification_channel" {
  triggers = {
    channel_name   = local.full_channel_name
    webhook_url    = var.webhook_url
    webhook_secret = var.webhook_secret
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X POST '${var.signoz_url}/api/v1/channels' \
        -H 'SIGNOZ-API-KEY: ${var.signoz_api_key}' \
        -H 'Content-Type: application/json' \
        -d '${local.webhook_config}' \
        || echo "Note: Channel may already exist"
    EOT
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "channel_name" {
  description = "Name of the notification channel"
  value       = local.full_channel_name
}

output "signoz_url" {
  description = "SigNoz URL where channel was created"
  value       = var.signoz_url
}
