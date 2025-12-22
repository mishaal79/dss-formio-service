# =============================================================================
# DISCORD SERVER MODULE
# =============================================================================
# Creates Discord infrastructure for alerting:
# - Category for organizing alert channels
# - Severity-based text channels (critical, warning, info, resolved)
# - Webhooks for each channel (outputs to discord-alerts module)
#
# Prerequisites:
# 1. Create Discord Bot at https://discord.com/developers/applications
# 2. Enable "Server Members Intent" and "Message Content Intent"
# 3. Invite bot to server with Administrator permission
# 4. Get bot token and server ID
#
# Bot Permission Integer: 8 (Administrator) or 536870912 (Manage Webhooks + Manage Channels)
# OAuth2 Scopes: bot, applications.commands
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    discord = {
      source  = "Lucky3028/discord"
      version = "~> 1.0"
    }
  }
}

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  # Channel naming convention
  category_name = "📊 Monitoring ${upper(var.environment)}"

  channels = {
    critical = {
      name        = "🚨-alerts-critical"
      topic       = "P1 Critical Alerts - NEVER MUTE - @here mentions enabled"
      position    = 0
      sync_perms  = true
    }
    warning = {
      name        = "⚠️-alerts-warning"
      topic       = "P2 Warning Alerts - Important but not urgent"
      position    = 1
      sync_perms  = true
    }
    info = {
      name        = "ℹ️-alerts-info"
      topic       = "P3 Info Alerts - Low priority, safe to mute"
      position    = 2
      sync_perms  = true
    }
    resolved = {
      name        = "✅-alerts-resolved"
      topic       = "Alert Resolutions - Safe to mute"
      position    = 3
      sync_perms  = true
    }
  }
}

# =============================================================================
# CATEGORY CHANNEL
# =============================================================================

resource "discord_category_channel" "monitoring" {
  server_id = var.discord_server_id
  name      = local.category_name
  position  = var.category_position
}

# =============================================================================
# TEXT CHANNELS
# =============================================================================

resource "discord_text_channel" "alerts_critical" {
  server_id   = var.discord_server_id
  name        = local.channels.critical.name
  topic       = local.channels.critical.topic
  category    = discord_category_channel.monitoring.id
  position    = local.channels.critical.position
  sync_perms_with_category = local.channels.critical.sync_perms
}

resource "discord_text_channel" "alerts_warning" {
  server_id   = var.discord_server_id
  name        = local.channels.warning.name
  topic       = local.channels.warning.topic
  category    = discord_category_channel.monitoring.id
  position    = local.channels.warning.position
  sync_perms_with_category = local.channels.warning.sync_perms
}

resource "discord_text_channel" "alerts_info" {
  server_id   = var.discord_server_id
  name        = local.channels.info.name
  topic       = local.channels.info.topic
  category    = discord_category_channel.monitoring.id
  position    = local.channels.info.position
  sync_perms_with_category = local.channels.info.sync_perms
}

resource "discord_text_channel" "alerts_resolved" {
  server_id   = var.discord_server_id
  name        = local.channels.resolved.name
  topic       = local.channels.resolved.topic
  category    = discord_category_channel.monitoring.id
  position    = local.channels.resolved.position
  sync_perms_with_category = local.channels.resolved.sync_perms
}

# =============================================================================
# WEBHOOKS
# =============================================================================

resource "discord_webhook" "critical" {
  channel_id = discord_text_channel.alerts_critical.id
  name       = "SigNoz Critical Alerts"

  # Optional: Set avatar from URL or data URI
  # avatar_url = "https://signoz.io/img/SigNozLogo-orange.svg"
}

resource "discord_webhook" "warning" {
  channel_id = discord_text_channel.alerts_warning.id
  name       = "SigNoz Warning Alerts"
}

resource "discord_webhook" "info" {
  channel_id = discord_text_channel.alerts_info.id
  name       = "SigNoz Info Alerts"
}

resource "discord_webhook" "resolved" {
  channel_id = discord_text_channel.alerts_resolved.id
  name       = "SigNoz Resolved Alerts"
}

# =============================================================================
# CHANNEL PERMISSIONS (Optional - restrict @everyone from posting)
# =============================================================================

# Deny @everyone from sending messages (only webhooks can post)
resource "discord_channel_permission" "critical_deny_everyone" {
  count = var.restrict_posting ? 1 : 0

  channel_id   = discord_text_channel.alerts_critical.id
  type         = "role"
  overwrite_id = var.discord_server_id  # @everyone role ID = server ID
  deny         = 2048                    # SEND_MESSAGES permission
}

resource "discord_channel_permission" "warning_deny_everyone" {
  count = var.restrict_posting ? 1 : 0

  channel_id   = discord_text_channel.alerts_warning.id
  type         = "role"
  overwrite_id = var.discord_server_id
  deny         = 2048
}

resource "discord_channel_permission" "info_deny_everyone" {
  count = var.restrict_posting ? 1 : 0

  channel_id   = discord_text_channel.alerts_info.id
  type         = "role"
  overwrite_id = var.discord_server_id
  deny         = 2048
}

resource "discord_channel_permission" "resolved_deny_everyone" {
  count = var.restrict_posting ? 1 : 0

  channel_id   = discord_text_channel.alerts_resolved.id
  type         = "role"
  overwrite_id = var.discord_server_id
  deny         = 2048
}
