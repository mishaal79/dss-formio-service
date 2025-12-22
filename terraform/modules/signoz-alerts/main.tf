# =============================================================================
# SIGNOZ ALERTS MODULE - PRODUCTION OBSERVABILITY
# =============================================================================
# Risk-prioritized alerting for DSS Form.io infrastructure
#
# Alert Philosophy:
# - Only actionable alerts (no vanity metrics)
# - Risk-based severity (business impact)
# - Recovery-focused (what action to take)
# - Avoid alert fatigue (minimal false positives)
#
# Priority Framework:
# P1 (Critical): Revenue/data loss, complete outage
# P2 (High): Degraded service, user-impacting
# P3 (Medium): Performance degradation, capacity warning
# P4 (Low): Informational, proactive maintenance
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    signoz = {
      source  = "SigNoz/signoz"
      version = "~> 0.0.4"
    }
  }
}

# =============================================================================
# LOCAL VARIABLES - THRESHOLDS AND CONFIGURATION
# =============================================================================

locals {
  # Service identifiers (match OTEL service names)
  services = {
    api = "dss.formio.api-${var.environment}"
    bff = "dss.formio.bff-${var.environment}"
  }

  # Notification channel routing by severity
  # All alerts → Discord (unified comms)
  # P1 Critical: @here mention in Discord
  # P2 High: Standard Discord notification
  # P3 Medium: Low priority Discord notification
  channels = {
    critical = var.notification_channels.critical
    warning  = var.notification_channels.warning
    info     = var.notification_channels.info
  }

  # Common labels for all alerts
  common_labels = {
    environment = var.environment
    team        = "platform"
    managed_by  = "terraform"
  }
}

# =============================================================================
# P1 CRITICAL ALERTS - IMMEDIATE ACTION REQUIRED
# =============================================================================
# These indicate complete service failure or data loss risk
# Target: <5 min detection, immediate notification

# -----------------------------------------------------------------------------
# P1.1: Service Completely Down (Zero Requests)
# Impact: Complete outage, all users affected
# Recovery: Check Cloud Run status, restart service
# -----------------------------------------------------------------------------
resource "signoz_alert" "service_down_api" {
  alert      = "P1: Form.io API Service Down"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "critical"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "count()"
            attribute  = "http.server.request.count"
          }]
          filter = {
            expression = "service.name='${local.services.api}'"
          }
        }
      }]
      queryType = "builder"
    }
    alertOnAbsent = true
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "critical"
        target    = 0
        matchType = "3" # Equal to
        channels  = local.channels.critical
      }]
    }
  })

  description = <<-EOT
    ## Service Down Alert

    **Impact**: Complete Form.io API outage - no forms can be loaded or submitted

    **Immediate Actions**:
    1. Check Cloud Run console: https://console.cloud.google.com/run
    2. Check service logs for crash reason
    3. Verify MongoDB Atlas connectivity
    4. Check recent deployments for regression

    **Escalation**: If not resolved in 15 minutes, escalate to on-call lead
  EOT

  eval_window      = "2m0s"
  frequency        = "30s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P1" })
}

resource "signoz_alert" "service_down_bff" {
  alert      = "P1: BFF Service Down"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "critical"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "count()"
            attribute  = "http.server.request.count"
          }]
          filter = {
            expression = "service.name='${local.services.bff}'"
          }
        }
      }]
      queryType = "builder"
    }
    alertOnAbsent = true
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "critical"
        target    = 0
        matchType = "3"
        channels  = local.channels.critical
      }]
    }
  })

  description = <<-EOT
    ## BFF Service Down Alert

    **Impact**: Frontend cannot communicate with backend - complete user-facing outage

    **Immediate Actions**:
    1. Check Cloud Run console for BFF service
    2. Verify service-to-service auth (IAM invoker role)
    3. Check if Form.io API is healthy (upstream dependency)
    4. Review recent deployments

    **Escalation**: If Form.io API is healthy but BFF is down, check BFF-specific logs
  EOT

  eval_window      = "2m0s"
  frequency        = "30s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P1" })
}

# -----------------------------------------------------------------------------
# P1.2: Database Connection Failure
# Impact: All data operations fail
# Recovery: Check MongoDB Atlas, VPC peering, connection string
# -----------------------------------------------------------------------------
resource "signoz_alert" "mongodb_connection_failure" {
  alert      = "P1: MongoDB Connection Failure"
  alert_type = "LOGS_BASED_ALERT"
  severity   = "critical"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "logs"
          aggregations = [{
            expression = "count()"
          }]
          filter = {
            expression = "body CONTAINS 'MongoServerSelectionError' OR body CONTAINS 'ECONNREFUSED' OR body CONTAINS 'MongoNetworkError'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "critical"
        target    = 5 # 5 connection errors in window
        matchType = "1"
        channels  = local.channels.critical
      }]
    }
  })

  description = <<-EOT
    ## MongoDB Connection Failure

    **Impact**: All form submissions and loads fail - data operations impossible

    **Immediate Actions**:
    1. Check MongoDB Atlas dashboard: https://cloud.mongodb.com
    2. Verify cluster is running and not paused
    3. Check VPC peering connection status
    4. Verify connection string secret is correct
    5. Check for IP whitelist changes

    **Common Causes**:
    - Atlas cluster maintenance/upgrade
    - VPC peering disruption
    - Secret rotation without service restart
    - Network connectivity issues
  EOT

  eval_window      = "2m0s"
  frequency        = "30s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P1" })
}

# -----------------------------------------------------------------------------
# P1.3: High Error Rate (>10%)
# Impact: Significant portion of requests failing
# Recovery: Identify error type, check dependencies
# -----------------------------------------------------------------------------
resource "signoz_alert" "high_error_rate_api" {
  alert      = "P1: High API Error Rate (>10%)"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "critical"

  condition = jsonencode({
    compositeQuery = {
      queries = [
        {
          type = "builder_query"
          spec = {
            name   = "errors"
            signal = "metrics"
            aggregations = [{
              expression = "count()"
              attribute  = "http.server.request.count"
            }]
            filter = {
              expression = "service.name='${local.services.api}' AND http.status_code>=500"
            }
          }
        },
        {
          type = "builder_query"
          spec = {
            name   = "total"
            signal = "metrics"
            aggregations = [{
              expression = "count()"
              attribute  = "http.server.request.count"
            }]
            filter = {
              expression = "service.name='${local.services.api}'"
            }
          }
        }
      ]
      queryType = "builder"
      formula   = "(errors / total) * 100"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "critical"
        target    = 10.0 # 10% error rate
        matchType = "1"
        channels  = local.channels.critical
      }]
    }
  })

  description = <<-EOT
    ## High API Error Rate

    **Impact**: >10% of API requests are failing - significant user impact

    **Immediate Actions**:
    1. Check error breakdown by status code in SigNoz traces
    2. Identify which endpoints are failing
    3. Check MongoDB connection health
    4. Review recent code deployments
    5. Check for external dependency failures

    **Diagnostic Queries**:
    - Traces: service.name='${local.services.api}' AND status.code=ERROR
    - Group by: http.route, http.status_code
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P1" })
}

# =============================================================================
# P2 HIGH ALERTS - DEGRADED SERVICE
# =============================================================================
# Service is working but degraded performance or partial failures
# Target: <15 min detection

# -----------------------------------------------------------------------------
# P2.1: Form Submission Failures
# Impact: Users cannot submit forms
# Recovery: Check validation errors, database writes
# -----------------------------------------------------------------------------
resource "signoz_alert" "form_submission_failures" {
  alert      = "P2: Form Submission Failure Spike"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "count()"
            attribute  = "form.submissions.total"
          }]
          filter = {
            expression = "status='error'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 10 # 10 failed submissions in window
        matchType = "1"
        channels  = local.channels.warning
      }]
    }
  })

  description = <<-EOT
    ## Form Submission Failures

    **Impact**: Users are experiencing form submission failures

    **Investigation**:
    1. Check for validation errors vs server errors
    2. Review failed submission traces
    3. Check MongoDB write performance
    4. Verify form schema hasn't changed unexpectedly

    **Common Causes**:
    - Schema validation failures
    - Database write timeouts
    - Rate limiting triggered
    - File upload size exceeded
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P2" })
}

# -----------------------------------------------------------------------------
# P2.2: Authentication Failures Spike
# Impact: Users cannot authenticate, potential security issue
# Recovery: Check JWT service, potential attack detection
# -----------------------------------------------------------------------------
resource "signoz_alert" "auth_failure_spike" {
  alert      = "P2: Authentication Failure Spike"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "count()"
            attribute  = "token.validations.total"
          }]
          filter = {
            expression = "status='invalid' OR status='expired'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 50 # 50 auth failures in window
        matchType = "1"
        channels  = local.channels.warning
      }]
    }
  })

  description = <<-EOT
    ## Authentication Failure Spike

    **Impact**: High rate of authentication failures - potential security concern

    **Investigation**:
    1. Check if failures are from single IP (potential attack)
    2. Verify JWT signing keys are correct
    3. Check token expiry settings
    4. Review for clock skew issues

    **Security Actions**:
    - If concentrated from single IP: Consider blocking
    - If distributed: Check for key rotation issues
    - If after deployment: Check JWT secret changes
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P2" })
}

# -----------------------------------------------------------------------------
# P2.3: File Upload Failures
# Impact: Users cannot upload files to forms
# Recovery: Check GCS connectivity, TUS server
# -----------------------------------------------------------------------------
resource "signoz_alert" "file_upload_failures" {
  alert      = "P2: File Upload Failure Spike"
  alert_type = "LOGS_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "logs"
          aggregations = [{
            expression = "count()"
          }]
          filter = {
            expression = "(body CONTAINS 'upload failed' OR body CONTAINS 'GCS error' OR body CONTAINS 'storage error') AND service.name='${local.services.api}'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 5
        matchType = "1"
        channels  = local.channels.warning
      }]
    }
  })

  description = <<-EOT
    ## File Upload Failures

    **Impact**: Users cannot upload files to forms

    **Investigation**:
    1. Check GCS bucket accessibility
    2. Verify service account permissions
    3. Check for storage quota issues
    4. Review TUS server logs if using resumable uploads

    **Common Causes**:
    - GCS IAM permission changes
    - Storage bucket quota exceeded
    - Network connectivity to GCS
    - File size exceeding limits
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P2" })
}

# -----------------------------------------------------------------------------
# P2.4: High Latency (P95 > 2s)
# Impact: Poor user experience, potential timeouts
# Recovery: Check database queries, external services
# -----------------------------------------------------------------------------
resource "signoz_alert" "high_latency_api" {
  alert      = "P2: High API Latency (P95 > 2s)"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "p95()"
            attribute  = "http.server.duration"
          }]
          filter = {
            expression = "service.name='${local.services.api}'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 2000 # 2000ms = 2s
        matchType = "1"
        channels  = local.channels.warning
      }]
    }
  })

  description = <<-EOT
    ## High API Latency

    **Impact**: Slow response times affecting user experience, risk of timeouts

    **Investigation**:
    1. Check MongoDB query performance
    2. Review slow traces in SigNoz
    3. Check for N+1 query patterns
    4. Review CPU/memory usage

    **Common Causes**:
    - Slow database queries
    - Cold start latency
    - Large form schema processing
    - External service delays
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P2" })
}

# =============================================================================
# P3 MEDIUM ALERTS - CAPACITY AND PERFORMANCE WARNINGS
# =============================================================================
# Proactive alerts before issues become critical
# Target: <30 min detection

# -----------------------------------------------------------------------------
# P3.1: Rate Limiting Triggered
# Impact: Some users being throttled
# Recovery: Review rate limit settings, check for abuse
# -----------------------------------------------------------------------------
resource "signoz_alert" "rate_limiting_triggered" {
  alert      = "P3: Rate Limiting Active"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "count()"
            attribute  = "http.server.request.count"
          }]
          filter = {
            expression = "http.status_code=429"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 20
        matchType = "1"
        channels  = local.channels.warning
      }]
    }
  })

  description = <<-EOT
    ## Rate Limiting Triggered

    **Impact**: Some requests are being rate limited (429 responses)

    **Investigation**:
    1. Check if single client or distributed
    2. Review rate limit configuration
    3. Check for automated scripts hitting API
    4. Determine if legitimate traffic spike

    **Actions**:
    - If abuse: Block offending IP
    - If legitimate: Consider rate limit increase
    - If bot: Implement better bot detection
  EOT

  eval_window      = "5m0s"
  frequency        = "1m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P3" })
}

# -----------------------------------------------------------------------------
# P3.2: Elevated 4xx Error Rate
# Impact: Client-side errors, potential integration issues
# Recovery: Review error patterns, update documentation
# -----------------------------------------------------------------------------
resource "signoz_alert" "elevated_4xx_errors" {
  alert      = "P3: Elevated Client Errors (4xx)"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "warning"

  condition = jsonencode({
    compositeQuery = {
      queries = [
        {
          type = "builder_query"
          spec = {
            name   = "client_errors"
            signal = "metrics"
            aggregations = [{
              expression = "count()"
              attribute  = "http.server.request.count"
            }]
            filter = {
              expression = "service.name='${local.services.api}' AND http.status_code>=400 AND http.status_code<500 AND http.status_code!=429"
            }
          }
        },
        {
          type = "builder_query"
          spec = {
            name   = "total"
            signal = "metrics"
            aggregations = [{
              expression = "count()"
              attribute  = "http.server.request.count"
            }]
            filter = {
              expression = "service.name='${local.services.api}'"
            }
          }
        }
      ]
      queryType = "builder"
      formula   = "(client_errors / total) * 100"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "warning"
        target    = 15.0 # 15% client error rate
        matchType = "1"
        channels  = local.channels.info
      }]
    }
  })

  description = <<-EOT
    ## Elevated Client Errors

    **Impact**: High rate of 4xx errors - potential API misuse or integration issues

    **Investigation**:
    1. Check error breakdown by status code
    2. Identify problematic endpoints
    3. Review for common patterns (auth, validation, not found)
    4. Check for integration partner issues

    **Common Causes**:
    - API schema changes without client updates
    - Validation rule changes
    - Authentication configuration changes
    - Deprecated endpoint usage
  EOT

  eval_window      = "15m0s"
  frequency        = "5m0s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P3" })
}

# =============================================================================
# SYNTHETIC MONITORING - EXTERNAL HEALTH CHECKS
# =============================================================================
# These use SigNoz's HTTP Check Receiver for endpoint monitoring
# Complements Checkly for external perspective

resource "signoz_alert" "synthetic_health_check_api" {
  count = var.enable_synthetic_monitoring ? 1 : 0

  alert      = "P1: Synthetic Health Check Failed - API"
  alert_type = "METRIC_BASED_ALERT"
  severity   = "critical"

  condition = jsonencode({
    compositeQuery = {
      queries = [{
        type = "builder_query"
        spec = {
          name   = "A"
          signal = "metrics"
          aggregations = [{
            expression = "avg()"
            attribute  = "httpcheck_status"
          }]
          filter = {
            expression = "http.url CONTAINS '${var.api_endpoint}/health'"
          }
        }
      }]
      queryType = "builder"
    }
    thresholds = {
      kind = "basic"
      spec = [{
        name      = "critical"
        target    = 0 # Status 0 = failure
        matchType = "3"
        channels  = local.channels.critical
      }]
    }
  })

  description = <<-EOT
    ## Synthetic Health Check Failed

    **Impact**: External health check to API is failing - service may be down

    **Immediate Actions**:
    1. This is an EXTERNAL perspective - service may still be running but unreachable
    2. Check Cloud Run service status
    3. Verify load balancer health
    4. Check DNS resolution
    5. Verify SSL certificate validity

    **Note**: This alert fires from external synthetic monitoring, not internal metrics
  EOT

  eval_window      = "2m0s"
  frequency        = "30s"
  # broadcast_to_all deprecated in provider v0.0.11
  labels           = merge(local.common_labels, { priority = "P1", type = "synthetic" })
}
