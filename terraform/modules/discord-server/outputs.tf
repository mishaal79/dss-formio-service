# =============================================================================
# DISCORD SERVER MODULE - OUTPUTS
# =============================================================================
# Webhook URLs are SENSITIVE - handle with care
# =============================================================================

# =============================================================================
# CHANNEL IDs
# =============================================================================

output "category_id" {
  description = "Monitoring category channel ID"
  value       = discord_category_channel.monitoring.id
}

output "channel_ids" {
  description = "Map of severity to channel IDs"
  value = {
    critical = discord_text_channel.alerts_critical.id
    warning  = discord_text_channel.alerts_warning.id
    info     = discord_text_channel.alerts_info.id
    resolved = discord_text_channel.alerts_resolved.id
  }
}

# =============================================================================
# WEBHOOK URLs - SENSITIVE
# =============================================================================

output "webhook_urls" {
  description = "Webhook URLs for each severity channel (SENSITIVE - store in Secret Manager)"
  sensitive   = true
  value = {
    critical = discord_webhook.critical.url
    warning  = discord_webhook.warning.url
    info     = discord_webhook.info.url
    resolved = discord_webhook.resolved.url
  }
}

output "webhook_url_critical" {
  description = "Webhook URL for critical alerts channel"
  sensitive   = true
  value       = discord_webhook.critical.url
}

output "webhook_url_warning" {
  description = "Webhook URL for warning alerts channel"
  sensitive   = true
  value       = discord_webhook.warning.url
}

output "webhook_url_info" {
  description = "Webhook URL for info alerts channel"
  sensitive   = true
  value       = discord_webhook.info.url
}

output "webhook_url_resolved" {
  description = "Webhook URL for resolved alerts channel"
  sensitive   = true
  value       = discord_webhook.resolved.url
}

# =============================================================================
# WEBHOOK IDs (for import/reference)
# =============================================================================

output "webhook_ids" {
  description = "Webhook IDs for each severity channel"
  value = {
    critical = discord_webhook.critical.id
    warning  = discord_webhook.warning.id
    info     = discord_webhook.info.id
    resolved = discord_webhook.resolved.id
  }
}

# =============================================================================
# SLACK-COMPATIBLE URLs (Discord provides these)
# =============================================================================

output "slack_compatible_urls" {
  description = "Slack-compatible webhook URLs (can be used with Slack integrations)"
  sensitive   = true
  value = {
    critical = discord_webhook.critical.slack_url
    warning  = discord_webhook.warning.slack_url
    info     = discord_webhook.info.slack_url
    resolved = discord_webhook.resolved.slack_url
  }
}
