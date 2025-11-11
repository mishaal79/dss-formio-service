/**
 * Terraform Module: Cloud Run Service for Form.io Backend API
 *
 * This module deploys the Form.io backend API to Google Cloud Run with:
 * - CORS headers for cross-origin requests from Cloudflare Pages
 * - Automatic HTTPS with Google-managed certificates
 * - Cloud Load Balancer with CDN and edge caching
 * - Secret Manager integration for sensitive configuration
 * - Health checks and auto-scaling
 * - Cloud SQL connection (if enabled)
 *
 * Resources:
 * - Cloud Run service
 * - Cloud Load Balancer (HTTPS)
 * - Backend service with CORS configuration
 * - URL map and SSL certificate
 * - Service accounts and IAM bindings
 */

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Service account for Cloud Run
resource "google_service_account" "formio_api" {
  account_id   = "${var.environment}-formio-api"
  display_name = "Form.io API Service Account (${var.environment})"
  description  = "Service account for Form.io Cloud Run service"
  project      = var.project_id
}

# IAM: Allow Cloud Run to access Secret Manager
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.formio_api.email}"
}

# IAM: Allow Cloud Run to write logs
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.formio_api.email}"
}

# Cloud Run service
resource "google_cloud_run_service" "formio_api" {
  name     = "${var.environment}-formio-api"
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.formio_api.email

      # Auto-scaling configuration
      container_concurrency = 80

      containers {
        image = var.container_image

        # Resource limits
        resources {
          limits = {
            cpu    = "2000m"  # 2 vCPU
            memory = "2Gi"    # 2GB RAM
          }
        }

        # Environment variables (non-sensitive)
        env {
          name  = "NODE_ENV"
          value = var.environment
        }

        env {
          name  = "PORT"
          value = "8080"
        }

        env {
          name  = "MONGO_DB_NAME"
          value = var.mongo_db_name
        }

        env {
          name  = "ENABLE_ASYNC_GCS_UPLOAD"
          value = "true"
        }

        env {
          name  = "BULLMQ_WORKER_CONCURRENCY"
          value = "3"
        }

        # CORS configuration
        env {
          name  = "CORS_ORIGIN"
          value = join(",", var.allowed_origins)
        }

        # Secret Manager references (sensitive data)
        env {
          name = "JWT_SECRET"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.jwt_secret.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name = "DB_SECRET"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_secret.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name = "MONGO"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.mongo_url.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name = "REDIS_HOST"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.redis_host.secret_id
              key  = "latest"
            }
          }
        }

        # Health check endpoint
        liveness_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 30
          timeout_seconds       = 5
          period_seconds        = 10
          failure_threshold     = 3
        }

        startup_probe {
          http_get {
            path = "/health"
            port = 8080
          }
          initial_delay_seconds = 0
          timeout_seconds       = 5
          period_seconds        = 10
          failure_threshold     = 10
        }
      }

      timeout_seconds = 300  # 5 minutes
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = var.min_instances
        "autoscaling.knative.dev/maxScale" = var.max_instances
        "run.googleapis.com/client-name"   = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all"  # Allow all ingress (controlled by load balancer)
    }
  }
}

# Secret Manager: JWT Secret
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${var.environment}-formio-jwt-secret"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = var.jwt_secret
}

# Secret Manager: Database Secret
resource "google_secret_manager_secret" "db_secret" {
  secret_id = "${var.environment}-formio-db-secret"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_secret" {
  secret      = google_secret_manager_secret.db_secret.id
  secret_data = var.db_secret
}

# Secret Manager: MongoDB URL
resource "google_secret_manager_secret" "mongo_url" {
  secret_id = "${var.environment}-formio-mongo-url"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongo_url" {
  secret      = google_secret_manager_secret.mongo_url.id
  secret_data = var.mongo_url
}

# Secret Manager: Redis Host
resource "google_secret_manager_secret" "redis_host" {
  secret_id = "${var.environment}-formio-redis-host"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "redis_host" {
  secret      = google_secret_manager_secret.redis_host.id
  secret_data = var.redis_host
}

# IAM: Allow public access to Cloud Run (controlled by load balancer)
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.formio_api.name
  location = google_cloud_run_service.formio_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "formio_neg" {
  name                  = "${var.environment}-formio-neg"
  region                = var.region
  project               = var.project_id
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_service.formio_api.name
  }
}

# Backend Service with CORS headers
resource "google_compute_backend_service" "formio_backend" {
  name                  = "${var.environment}-formio-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.formio_neg.id
  }

  # Cloud CDN configuration
  enable_cdn = var.enable_cdn

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    client_ttl                   = 3600
    default_ttl                  = 300
    max_ttl                      = 86400
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 7200
  }

  # CORS headers (applied to all responses)
  custom_response_headers = [
    "Access-Control-Allow-Origin: ${join(", ", var.allowed_origins)}",
    "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers: Content-Type, Authorization, X-Idempotency-Key, X-Device-Fingerprint, X-Trace-ID, X-Session-ID",
    "Access-Control-Max-Age: 86400",
    "Access-Control-Allow-Credentials: true",
    "X-Content-Type-Options: nosniff",
    "X-Frame-Options: DENY",
    "X-XSS-Protection: 1; mode=block",
    "Strict-Transport-Security: max-age=31536000; includeSubDomains",
  ]

  # Health check
  health_checks = [google_compute_health_check.formio_health.id]

  # Session affinity
  session_affinity = "NONE"

  # Timeout
  timeout_sec = 30

  log_config {
    enable      = true
    sample_rate = var.environment == "production" ? 0.1 : 1.0  # 10% sampling in prod
  }
}

# Health check for backend service
resource "google_compute_health_check" "formio_health" {
  name    = "${var.environment}-formio-health"
  project = var.project_id

  https_health_check {
    port         = 443
    request_path = "/health"
  }

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# URL Map
resource "google_compute_url_map" "formio_url_map" {
  name            = "${var.environment}-formio-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.formio_backend.id
}

# SSL Certificate (Google-managed)
resource "google_compute_managed_ssl_certificate" "formio_cert" {
  name    = "${var.environment}-formio-cert"
  project = var.project_id

  managed {
    domains = var.custom_domains
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "formio_https_proxy" {
  name             = "${var.environment}-formio-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.formio_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.formio_cert.id]
}

# Global Forwarding Rule (HTTPS)
resource "google_compute_global_forwarding_rule" "formio_https" {
  name       = "${var.environment}-formio-https"
  project    = var.project_id
  target     = google_compute_target_https_proxy.formio_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.formio_lb.address
}

# Global IP Address
resource "google_compute_global_address" "formio_lb" {
  name    = "${var.environment}-formio-lb-ip"
  project = var.project_id
}
