# =============================================================================
# FORM WEB BFF MODULE - MAIN INFRASTRUCTURE
# =============================================================================
# Cloud Run Backend-for-Frontend service with VPC integration, load balancer
# support, and service-to-service authentication to Form.io custom service.
#
# Following formio-custom-service pattern with improvements:
# - Configurable container port (not hardcoded)
# - VPC egress: PRIVATE_RANGES_ONLY
# - Service-to-service authentication via IAM
# - Load balancer ready (NEG + Backend Service + Health Check)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
}

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  # Service naming
  service_name = "form-web-bff-${var.environment}"

  # Resource naming
  service_account_id   = "form-web-bff-sa-${var.environment}"
  backend_service_name = "form-web-bff-backend-${var.environment}"
  neg_name             = "form-web-bff-neg-${var.environment}"
  health_check_name    = "form-web-bff-hc-${var.environment}"

  # Common labels following Qrius standards
  common_labels = merge(
    var.labels,
    {
      service             = "form-web-bff"
      application         = "form-web-bff"
      environment         = var.environment
      cost-center         = "dss-electrical"
      application-id      = "form-web-bff-service"
      owner               = "platform-team"
      managed-by          = "terraform"
      project-type        = "form-management"
      data-classification = "confidential"
      compliance-scope    = "pci-dss"
    }
  )

  # Environment variables for Cloud Run container
  # PORT is configurable via var.container_port
  environment_vars = [
    {
      name  = "NODE_ENV"
      value = var.node_env
    },
    {
      name  = "PORT"
      value = tostring(var.container_port)
    },
    {
      name  = "LOG_LEVEL"
      value = var.log_level
    },
    {
      name  = "CORS_ORIGIN"
      value = var.cors_origin
    },
    {
      name  = "RATE_LIMIT_MAX"
      value = tostring(var.rate_limit_max)
    },
    {
      name  = "RATE_LIMIT_WINDOW_MS"
      value = tostring(var.rate_limit_window_ms)
    },
    {
      name  = "FORMIO_CUSTOM_SERVICE_URL"
      value = var.formio_custom_service_url
    },
    {
      name  = "OTEL_ENDPOINT"
      value = var.otel_endpoint
    },
  ]
}

# =============================================================================
# SERVICE ACCOUNT
# =============================================================================

resource "google_service_account" "form_web_bff" {
  project      = var.project_id
  account_id   = local.service_account_id
  display_name = "Form Web BFF Service Account (${var.environment})"
  description  = "Service account for Form Web BFF Cloud Run service with minimal permissions"
}

# Service account IAM roles
resource "google_project_iam_member" "form_web_bff_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.form_web_bff.email}"
}

resource "google_project_iam_member" "form_web_bff_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.form_web_bff.email}"
}

resource "google_project_iam_member" "form_web_bff_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.form_web_bff.email}"
}

# Service-to-service authentication: Grant BFF permission to invoke formio-custom
resource "google_cloud_run_service_iam_member" "formio_custom_invoker" {
  project  = var.project_id
  location = var.region
  service  = var.formio_custom_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.form_web_bff.email}"
}

# =============================================================================
# CLOUD RUN SERVICE
# =============================================================================

resource "google_cloud_run_v2_service" "form_web_bff" {
  project  = var.project_id
  name     = local.service_name
  location = var.region

  description = "Form Web BFF - Backend-for-Frontend service for React application (${var.environment})"

  labels = local.common_labels

  template {
    # Scaling configuration
    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    # Service account
    service_account = google_service_account.form_web_bff.email

    # VPC connector for private networking
    vpc_access {
      connector = var.vpc_connector_id
      egress    = var.vpc_egress_setting # PRIVATE_RANGES_ONLY recommended
    }

    # Request timeout
    timeout = "${var.request_timeout}s"

    # Container configuration
    containers {
      # Docker image from Artifact Registry
      image = var.image_url

      # Resource limits
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle = true
      }

      # Port configuration - VARIABLE-BASED (not hardcoded)
      ports {
        name           = "http1"
        container_port = var.container_port
      }

      # Environment variables
      dynamic "env" {
        for_each = local.environment_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Startup probe for health checking
      startup_probe {
        http_get {
          path = "/health/ready"
          port = var.container_port
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 3
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/health/ready"
          port = var.container_port
        }
        initial_delay_seconds = 30
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    # Container concurrency
    max_instance_request_concurrency = var.container_concurrency
  }

  # Traffic configuration (all traffic to latest revision)
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_service_account.form_web_bff,
    google_project_iam_member.form_web_bff_logging,
    google_project_iam_member.form_web_bff_monitoring,
    google_project_iam_member.form_web_bff_trace,
  ]
}

# =============================================================================
# IAM - PUBLIC ACCESS (DEV/STAGING ONLY)
# =============================================================================

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.form_web_bff.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# =============================================================================
# NETWORK ENDPOINT GROUP (SERVERLESS)
# =============================================================================
# NEG for Cloud Load Balancer integration

resource "google_compute_region_network_endpoint_group" "form_web_bff" {
  project = var.project_id
  name    = local.neg_name
  region  = var.region

  description = "Serverless NEG for Form Web BFF (${var.environment})"

  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.form_web_bff.name
  }
}

# =============================================================================
# HEALTH CHECK
# =============================================================================

resource "google_compute_health_check" "form_web_bff" {
  project = var.project_id
  name    = local.health_check_name

  description = "Health check for Form Web BFF backend service (${var.environment})"

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = var.container_port # Variable-based port
    request_path       = "/health/ready"
    port_specification = "USE_FIXED_PORT"
  }

  log_config {
    enable = true
  }
}

# =============================================================================
# BACKEND SERVICE
# =============================================================================
# Backend service for load balancer integration

resource "google_compute_backend_service" "form_web_bff" {
  project = var.project_id
  name    = local.backend_service_name

  description = "Backend service for Form Web BFF load balancer (${var.environment})"

  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_region_network_endpoint_group.form_web_bff.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [
    google_compute_health_check.form_web_bff.id
  ]

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Security settings
  security_policy = null # Can be added later for Cloud Armor

  # Session affinity
  session_affinity = "NONE"

  # Connection draining
  connection_draining_timeout_sec = 300
}

# =============================================================================
# OUTPUTS (FOR DEBUGGING)
# =============================================================================

# Debug output to verify port configuration
output "debug_container_port" {
  description = "Container port being used (for verification)"
  value       = var.container_port
}

output "debug_health_check_port" {
  description = "Health check port being used (for verification)"
  value       = var.container_port
}

output "debug_service_url" {
  description = "Cloud Run service URL (for verification)"
  value       = google_cloud_run_v2_service.form_web_bff.uri
}
