# =============================================================================
# DISCORD ALERTS MODULE
# =============================================================================
# Deploys Discord Alert Proxy as Cloud Run service
# Routes alerts to severity-specific Discord channels
#
# Architecture:
# SigNoz → Webhook → Discord Alert Proxy (Cloud Run) → Discord Webhooks → Discord Channels
#
# Channel Strategy (prevents alert fatigue):
# - #alerts-critical: P1 alerts, @here mentions, NEVER mute
# - #alerts-warning: P2 alerts, no mentions, can mute temporarily
# - #alerts-info: P3 alerts, low priority, safe to mute
# - #alerts-resolved: Resolution notifications, safe to mute
#
# Features:
# - Severity-based routing to separate channels
# - Rich embeds with color-coded severity
# - @here mentions for P1 critical alerts only
# - Runbook links embedded in alerts
# - Rate limiting protection (25 req/min)
# - Delivery confirmation logging
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  service_name       = "discord-ops-bot-${var.environment}"
  service_account_id = "discord-ops-bot-sa-${var.environment}"

  common_labels = merge(
    var.labels,
    {
      service     = "discord-ops-bot"
      environment = var.environment
      managed_by  = "terraform"
    }
  )

  # Secret names for each severity channel
  secret_names = {
    critical  = "discord-webhook-critical-${var.environment}"
    warning   = "discord-webhook-warning-${var.environment}"
    info      = "discord-webhook-info-${var.environment}"
    resolved  = "discord-webhook-resolved-${var.environment}"
    bot_token = "discord-bot-token-${var.environment}"
  }
}

# =============================================================================
# SECRET MANAGER - DISCORD WEBHOOK URLS
# =============================================================================
# Each severity level has its own webhook pointing to a different Discord channel

# Critical channel webhook
resource "google_secret_manager_secret" "discord_webhook_critical" {
  project   = var.project_id
  secret_id = local.secret_names.critical

  labels = merge(local.common_labels, { severity = "critical" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_critical" {
  count = var.discord_webhook_critical != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_webhook_critical.id
  secret_data = var.discord_webhook_critical
}

# Warning channel webhook
resource "google_secret_manager_secret" "discord_webhook_warning" {
  project   = var.project_id
  secret_id = local.secret_names.warning

  labels = merge(local.common_labels, { severity = "warning" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_warning" {
  count = var.discord_webhook_warning != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_webhook_warning.id
  secret_data = var.discord_webhook_warning
}

# Info channel webhook
resource "google_secret_manager_secret" "discord_webhook_info" {
  project   = var.project_id
  secret_id = local.secret_names.info

  labels = merge(local.common_labels, { severity = "info" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_info" {
  count = var.discord_webhook_info != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_webhook_info.id
  secret_data = var.discord_webhook_info
}

# Resolved channel webhook
resource "google_secret_manager_secret" "discord_webhook_resolved" {
  project   = var.project_id
  secret_id = local.secret_names.resolved

  labels = merge(local.common_labels, { severity = "resolved" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_resolved" {
  count = var.discord_webhook_resolved != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_webhook_resolved.id
  secret_data = var.discord_webhook_resolved
}

# Legacy single webhook (backwards compatibility)
resource "google_secret_manager_secret" "discord_webhook_url" {
  count = var.discord_webhook_url != "" ? 1 : 0

  project   = var.project_id
  secret_id = "discord-webhook-url-${var.environment}"

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_url" {
  count = var.discord_webhook_url != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_webhook_url[0].id
  secret_data = var.discord_webhook_url
}

# =============================================================================
# SECRET MANAGER - DISCORD BOT TOKEN (for slash commands)
# =============================================================================

resource "google_secret_manager_secret" "discord_bot_token" {
  count = var.discord_bot_token != "" ? 1 : 0

  project   = var.project_id
  secret_id = local.secret_names.bot_token

  labels = merge(local.common_labels, { type = "bot-token" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_bot_token" {
  count = var.discord_bot_token != "" ? 1 : 0

  secret      = google_secret_manager_secret.discord_bot_token[0].id
  secret_data = var.discord_bot_token
}

# =============================================================================
# SERVICE ACCOUNT
# =============================================================================

resource "google_service_account" "discord_proxy" {
  project      = var.project_id
  account_id   = local.service_account_id
  display_name = "Discord Alert Proxy Service Account (${var.environment})"
  description  = "Service account for Discord Alert Proxy Cloud Run service"
}

# Grant access to all Discord webhook secrets
resource "google_secret_manager_secret_iam_member" "discord_webhook_critical_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.discord_webhook_critical.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_proxy.email}"
}

resource "google_secret_manager_secret_iam_member" "discord_webhook_warning_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.discord_webhook_warning.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_proxy.email}"
}

resource "google_secret_manager_secret_iam_member" "discord_webhook_info_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.discord_webhook_info.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_proxy.email}"
}

resource "google_secret_manager_secret_iam_member" "discord_webhook_resolved_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.discord_webhook_resolved.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_proxy.email}"
}

# Bot token secret access (only if bot token is configured)
resource "google_secret_manager_secret_iam_member" "discord_bot_token_access" {
  count     = var.discord_bot_token != "" ? 1 : 0
  project   = var.project_id
  secret_id = google_secret_manager_secret.discord_bot_token[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.discord_proxy.email}"
}

# Logging permissions
resource "google_project_iam_member" "discord_proxy_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.discord_proxy.email}"
}

# Monitoring permissions
resource "google_project_iam_member" "discord_proxy_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.discord_proxy.email}"
}

# =============================================================================
# CLOUD RUN SERVICE
# =============================================================================

resource "google_cloud_run_v2_service" "discord_proxy" {
  project  = var.project_id
  name     = local.service_name
  location = var.region

  deletion_protection = false # Allow terraform destroy/replace

  description = "Discord Ops Bot - Unified ops bot with alerts, scheduling, on-call, and incidents (${var.environment})"

  labels = local.common_labels

  template {
    service_account = google_service_account.discord_proxy.email

    scaling {
      min_instance_count = 0 # Scale to zero when no alerts
      max_instance_count = 3 # Limited scaling for alert service
    }

    containers {
      image = var.image_url

      resources {
        limits = {
          cpu    = "500m"  # Lightweight service
          memory = "256Mi" # Minimal memory needed
        }
        cpu_idle = true # CPU throttled when idle
      }

      ports {
        container_port = 8080
      }

      # Environment variables
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "SIGNOZ_URL"
        value = var.signoz_url
      }

      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }

      # Webhook secrets (only if webhooks are configured - legacy mode)
      dynamic "env" {
        for_each = var.discord_webhook_critical != "" ? [1] : []
        content {
          name = "DISCORD_WEBHOOK_CRITICAL"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.discord_webhook_critical.secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.discord_webhook_warning != "" ? [1] : []
        content {
          name = "DISCORD_WEBHOOK_WARNING"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.discord_webhook_warning.secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.discord_webhook_info != "" ? [1] : []
        content {
          name = "DISCORD_WEBHOOK_INFO"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.discord_webhook_info.secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.discord_webhook_resolved != "" ? [1] : []
        content {
          name = "DISCORD_WEBHOOK_RESOLVED"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.discord_webhook_resolved.secret_id
              version = "latest"
            }
          }
        }
      }

      # Discord Bot Token (for slash commands) - optional
      dynamic "env" {
        for_each = var.discord_bot_token != "" ? [1] : []
        content {
          name = "DISCORD_TOKEN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.discord_bot_token[0].secret_id
              version = "latest"
            }
          }
        }
      }

      # Discord Client ID (for registering slash commands)
      dynamic "env" {
        for_each = var.discord_client_id != "" ? [1] : []
        content {
          name  = "DISCORD_CLIENT_ID"
          value = var.discord_client_id
        }
      }

      # Discord Guild ID (for dev environment)
      dynamic "env" {
        for_each = var.discord_guild_id != "" ? [1] : []
        content {
          name  = "DISCORD_GUILD_ID"
          value = var.discord_guild_id
        }
      }

      # Channel-based routing (v2 - bot posts directly to channels)
      dynamic "env" {
        for_each = var.discord_channel_alerts != "" ? [1] : []
        content {
          name  = "DISCORD_CHANNEL_ALERTS"
          value = var.discord_channel_alerts
        }
      }

      dynamic "env" {
        for_each = var.discord_channel_critical != "" ? [1] : []
        content {
          name  = "DISCORD_CHANNEL_CRITICAL"
          value = var.discord_channel_critical
        }
      }

      dynamic "env" {
        for_each = var.discord_channel_warning != "" ? [1] : []
        content {
          name  = "DISCORD_CHANNEL_WARNING"
          value = var.discord_channel_warning
        }
      }

      dynamic "env" {
        for_each = var.discord_channel_info != "" ? [1] : []
        content {
          name  = "DISCORD_CHANNEL_INFO"
          value = var.discord_channel_info
        }
      }

      dynamic "env" {
        for_each = var.discord_channel_resolved != "" ? [1] : []
        content {
          name  = "DISCORD_CHANNEL_RESOLVED"
          value = var.discord_channel_resolved
        }
      }

      # Webhook authentication secret
      dynamic "env" {
        for_each = var.webhook_secret != "" ? [1] : []
        content {
          name  = "WEBHOOK_SECRET"
          value = var.webhook_secret
        }
      }

      # Health check
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 30
        failure_threshold     = 3
      }
    }

    # Request timeout
    timeout = "30s"

    # Max concurrent requests per instance (must be 1 when CPU < 1)
    max_instance_request_concurrency = 1
  }

  # Traffic configuration
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_secret_manager_secret_iam_member.discord_webhook_critical_access,
    google_secret_manager_secret_iam_member.discord_webhook_warning_access,
    google_secret_manager_secret_iam_member.discord_webhook_info_access,
    google_secret_manager_secret_iam_member.discord_webhook_resolved_access,
    google_secret_manager_secret_iam_member.discord_bot_token_access,
    google_project_iam_member.discord_proxy_logging,
    google_project_iam_member.discord_proxy_monitoring,
  ]
}

# =============================================================================
# IAM - ALLOW SIGNOZ TO INVOKE
# =============================================================================

# Allow unauthenticated access (SigNoz webhook doesn't support auth headers)
# Security: Rate limiting is implemented in the service
resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.discord_proxy.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow specific service accounts to invoke (if authentication required)
resource "google_cloud_run_v2_service_iam_member" "authorized_invokers" {
  for_each = toset(var.authorized_invokers)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.discord_proxy.name
  role     = "roles/run.invoker"
  member   = each.value
}

# =============================================================================
# MONITORING - ALERT ON PROXY FAILURES
# =============================================================================

resource "google_monitoring_alert_policy" "discord_proxy_errors" {
  count = var.enable_monitoring ? 1 : 0

  project      = var.project_id
  display_name = "Discord Alert Proxy - High Error Rate (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "Error rate > 10%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${local.service_name}"
        AND metric.type = "run.googleapis.com/request_count"
        AND metric.labels.response_code_class != "2xx"
      EOT

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.1
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s" # Auto-close after 30 minutes
  }

  documentation {
    content = <<-EOT
      ## Discord Alert Proxy Error Rate High

      The Discord Alert Proxy service is experiencing high error rates.
      This means SigNoz alerts may not be reaching Discord.

      **Impact**: Alert notifications not delivered to Discord

      **Actions**:
      1. Check Cloud Run logs for error details
      2. Verify Discord webhook URLs are valid in Secret Manager
      3. Check Discord rate limits (30/min per webhook)
      4. Verify network connectivity

      **Fallback**: Check SigNoz directly for alerts
    EOT
    mime_type = "text/markdown"
  }
}

# =============================================================================
# DNS RECORD (optional)
# =============================================================================

resource "google_dns_record_set" "discord_bot" {
  count = var.create_dns_record && var.dns_name != "" ? 1 : 0

  project      = var.dns_project_id != "" ? var.dns_project_id : var.project_id
  managed_zone = var.dns_managed_zone
  name         = "${var.dns_name}."
  type         = "CNAME"
  ttl          = 300

  rrdatas = [
    "${replace(google_cloud_run_v2_service.discord_proxy.uri, "https://", "")}."
  ]
}

# Outputs defined in outputs.tf
