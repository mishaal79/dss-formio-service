# =============================================================================
# SIGNOZ ALERTS MODULE - OUTPUTS
# =============================================================================

output "alert_ids" {
  description = "Map of alert names to their SigNoz IDs"
  value = {
    service_down_api          = signoz_alert.service_down_api.id
    service_down_bff          = signoz_alert.service_down_bff.id
    mongodb_connection        = signoz_alert.mongodb_connection_failure.id
    high_error_rate_api       = signoz_alert.high_error_rate_api.id
    form_submission_failures  = signoz_alert.form_submission_failures.id
    auth_failure_spike        = signoz_alert.auth_failure_spike.id
    file_upload_failures      = signoz_alert.file_upload_failures.id
    high_latency_api          = signoz_alert.high_latency_api.id
    rate_limiting_triggered   = signoz_alert.rate_limiting_triggered.id
    elevated_4xx_errors       = signoz_alert.elevated_4xx_errors.id
  }
}

output "critical_alerts" {
  description = "List of P1 critical alert IDs"
  value = [
    signoz_alert.service_down_api.id,
    signoz_alert.service_down_bff.id,
    signoz_alert.mongodb_connection_failure.id,
    signoz_alert.high_error_rate_api.id,
  ]
}

output "warning_alerts" {
  description = "List of P2/P3 warning alert IDs"
  value = [
    signoz_alert.form_submission_failures.id,
    signoz_alert.auth_failure_spike.id,
    signoz_alert.file_upload_failures.id,
    signoz_alert.high_latency_api.id,
    signoz_alert.rate_limiting_triggered.id,
    signoz_alert.elevated_4xx_errors.id,
  ]
}

output "alert_summary" {
  description = "Summary of configured alerts by priority"
  value = {
    p1_critical = 4
    p2_high     = 4
    p3_medium   = 2
    total       = 10
  }
}
