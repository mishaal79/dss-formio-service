# =============================================================================
# DISCORD ALERTS MODULE - OUTPUTS
# =============================================================================
# Outputs for integrating Discord Alert Proxy with SigNoz and other services
# =============================================================================

output "service_url" {
  description = "Discord Alert Proxy service URL"
  value       = google_cloud_run_v2_service.discord_proxy.uri
}

output "webhook_endpoint" {
  description = "Full webhook endpoint URL for SigNoz configuration"
  value       = "${google_cloud_run_v2_service.discord_proxy.uri}/webhook"
}

output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.discord_proxy.name
}

output "dns_url" {
  description = "Custom DNS URL for the bot (if DNS record created)"
  value       = var.create_dns_record && var.dns_name != "" ? "https://${var.dns_name}" : null
}

output "service_account_email" {
  description = "Service account email for the Discord Alert Proxy"
  value       = google_service_account.discord_proxy.email
}

# =============================================================================
# SECRET MANAGER OUTPUTS
# =============================================================================

output "discord_webhook_secret_id" {
  description = "Legacy: Primary secret ID (critical channel)"
  value       = google_secret_manager_secret.discord_webhook_critical.secret_id
}

output "discord_webhook_secret_ids" {
  description = "Secret Manager secret IDs for each severity channel"
  value = {
    critical = google_secret_manager_secret.discord_webhook_critical.secret_id
    warning  = google_secret_manager_secret.discord_webhook_warning.secret_id
    info     = google_secret_manager_secret.discord_webhook_info.secret_id
    resolved = google_secret_manager_secret.discord_webhook_resolved.secret_id
  }
}

output "discord_webhook_secret_names" {
  description = "Full Secret Manager secret resource names"
  value = {
    critical = google_secret_manager_secret.discord_webhook_critical.name
    warning  = google_secret_manager_secret.discord_webhook_warning.name
    info     = google_secret_manager_secret.discord_webhook_info.name
    resolved = google_secret_manager_secret.discord_webhook_resolved.name
  }
}

# =============================================================================
# SIGNOZ INTEGRATION OUTPUTS
# =============================================================================

output "signoz_notification_config" {
  description = "Configuration snippet for SigNoz webhook notification channel"
  value = {
    name        = "discord-alerts-${var.environment}"
    type        = "webhook"
    webhook_url = "${google_cloud_run_v2_service.discord_proxy.uri}/webhook"
    method      = "POST"
    headers = {
      "Content-Type" = "application/json"
    }
    description = "Discord alerts with severity-based routing (${var.environment})"
  }
}

# =============================================================================
# DISCORD CHANNEL SETUP INSTRUCTIONS
# =============================================================================

output "discord_setup_instructions" {
  description = "Instructions for setting up Discord channels and webhooks"
  value = <<-EOT
    ## Discord Channel Setup

    Create these channels in your Discord server:

    1. #alerts-critical (P1)
       - NEVER mute this channel
       - @here mentions enabled
       - Webhook secret: ${google_secret_manager_secret.discord_webhook_critical.secret_id}

    2. #alerts-warning (P2)
       - Important but not urgent
       - Can mute temporarily during incidents
       - Webhook secret: ${google_secret_manager_secret.discord_webhook_warning.secret_id}

    3. #alerts-info (P3)
       - Low priority notifications
       - Safe to mute
       - Webhook secret: ${google_secret_manager_secret.discord_webhook_info.secret_id}

    4. #alerts-resolved
       - Resolution notifications
       - Safe to mute
       - Webhook secret: ${google_secret_manager_secret.discord_webhook_resolved.secret_id}

    ## Add Webhook URLs to Secret Manager

    For each channel, create a webhook in Discord and add to GCP:

    ```bash
    # Critical channel
    echo -n "https://discord.com/api/webhooks/..." | \
      gcloud secrets versions add ${google_secret_manager_secret.discord_webhook_critical.secret_id} --data-file=-

    # Warning channel
    echo -n "https://discord.com/api/webhooks/..." | \
      gcloud secrets versions add ${google_secret_manager_secret.discord_webhook_warning.secret_id} --data-file=-

    # Info channel
    echo -n "https://discord.com/api/webhooks/..." | \
      gcloud secrets versions add ${google_secret_manager_secret.discord_webhook_info.secret_id} --data-file=-

    # Resolved channel
    echo -n "https://discord.com/api/webhooks/..." | \
      gcloud secrets versions add ${google_secret_manager_secret.discord_webhook_resolved.secret_id} --data-file=-
    ```

    ## Configure SigNoz

    Add webhook notification channel pointing to:
    ${google_cloud_run_v2_service.discord_proxy.uri}/webhook
  EOT
}
