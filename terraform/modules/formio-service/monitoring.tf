# =============================================================================
# MONITORING AND ALERTING POLICIES
# =============================================================================
#
# SLA-based monitoring and alerting for Form.io service reliability
# Covers availability, performance, and error rate monitoring
#

# Notification channels for alerting
resource "google_monitoring_notification_channel" "email_alerts" {
  count        = length(var.alert_email_addresses)
  project      = var.project_id
  display_name = "Form.io Alerts - ${var.alert_email_addresses[count.index]}"
  type         = "email"

  labels = {
    email_address = var.alert_email_addresses[count.index]
  }

  enabled = true
}

# Service availability alerting policy
resource "google_monitoring_alert_policy" "service_availability" {
  count        = length(var.alert_email_addresses) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "Form.io Service Availability - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Run service availability below 99%"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.formio_service.name}\""
      duration        = "300s" # 5 minutes
      comparison      = "COMPARISON_LESS_THAN"
      threshold_value = 0.99

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email_alerts[*].name

  alert_strategy {
    auto_close = "86400s"
  }
}

# High error rate alerting policy
resource "google_monitoring_alert_policy" "high_error_rate" {
  count        = length(var.alert_email_addresses) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "Form.io High Error Rate - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Error rate above 5% for 5 minutes"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.formio_service.name}\" AND metric.type=\"run.googleapis.com/request_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.05

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name", "metric.label.response_code_class"]
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email_alerts[*].name
}

# High response latency alerting policy
resource "google_monitoring_alert_policy" "high_latency" {
  count        = length(var.alert_email_addresses) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "Form.io High Response Latency - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "95th percentile latency above 5 seconds"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.formio_service.name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 5000 # 5 seconds in milliseconds

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email_alerts[*].name
}

# Database connection alerting (based on logs)
resource "google_monitoring_alert_policy" "database_errors" {
  count        = length(var.alert_email_addresses) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "Form.io Database Connection Errors - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "MongoDB connection errors detected"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.formio_service.name}\" AND textPayload=~\"mongo.*error|connection.*failed|atlas.*timeout\""
      duration        = "60s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email_alerts[*].name
}

# License validation alerting
resource "google_monitoring_alert_policy" "license_errors" {
  count        = var.use_enterprise && length(var.alert_email_addresses) > 0 ? 1 : 0
  project      = var.project_id
  display_name = "Form.io License Validation Errors - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "License validation failures detected"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.formio_service.name}\" AND textPayload=~\"license.*error|license.*invalid|license.*expired\""
      duration        = "60s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email_alerts[*].name
}

# Outputs moved to outputs.tf for proper Terraform module structure