# =============================================================================
# FORM.IO PDF SERVER MODULE
# =============================================================================
#
# PDF Plus server for pixel-perfect PDF generation with Form.io Enterprise
# Provides advanced PDF capabilities including overlays and dynamic content
#

# =============================================================================
# SERVICE ACCOUNT
# =============================================================================

resource "google_service_account" "pdf_service_account" {
  account_id   = "${var.service_name}-sa-${var.environment}"
  display_name = "Form.io PDF Server Service Account"
  project      = var.project_id
  description  = "Service account for Form.io PDF server with access to secrets and storage"
}

# =============================================================================
# CLOUD RUN SERVICE
# =============================================================================

resource "google_cloud_run_v2_service" "pdf_service" {
  name                = "${var.service_name}-${var.environment}"
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  template {
    service_account = google_service_account.pdf_service_account.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Main PDF Server container - REST API interface
    containers {
      name  = "pdf-server"
      image = var.pdf_server_image

      ports {
        container_port = 4005
        name           = "http1"
      }

      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        cpu_idle = true
      }

      # Environment Variables
      dynamic "env" {
        for_each = local.pdf_env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Secret Environment Variables
      dynamic "env" {
        for_each = local.pdf_secret_env_vars
        content {
          name = env.value.name
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 4005
        }
      }

      liveness_probe {
        initial_delay_seconds = 30
        timeout_seconds       = 3
        period_seconds        = 30
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 4005
        }
      }
    }


    vpc_access {
      network_interfaces {
        network    = var.vpc_network
        subnetwork = var.vpc_connector_subnet
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    annotations = {
      "run.googleapis.com/cpu-throttling"        = "false"
      "run.googleapis.com/execution-environment" = "gen2"
    }

    timeout                          = "${var.timeout_seconds}s"
    max_instance_request_concurrency = var.concurrency
  }

  labels = local.service_labels

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].annotations["run.googleapis.com/operation-id"],
      template[0].labels["run.googleapis.com/startupProbeChecksum"],
    ]
  }
}

# =============================================================================
# IAM PERMISSIONS
# =============================================================================

# Allow PDF server to access secrets
resource "google_secret_manager_secret_iam_member" "license_key_access" {
  count = var.formio_license_secret_id != "" ? 1 : 0

  project   = var.project_id
  secret_id = var.formio_license_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "mongodb_connection_access" {
  project   = var.project_id
  secret_id = var.mongodb_connection_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  project   = var.project_id
  secret_id = var.formio_jwt_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "db_secret_access" {
  project   = var.project_id
  secret_id = var.formio_db_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "s3_key_access" {
  project   = var.project_id
  secret_id = var.formio_s3_key_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "s3_secret_access" {
  project   = var.project_id
  secret_id = var.formio_s3_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

# Allow PDF server to access storage bucket
resource "google_project_iam_member" "storage_access" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pdf_service_account.email}"
}

# =============================================================================
# NETWORK ENDPOINT GROUP FOR LOAD BALANCER
# =============================================================================

resource "google_compute_region_network_endpoint_group" "pdf_neg" {
  name                  = "${var.service_name}-neg-${var.environment}"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = google_cloud_run_v2_service.pdf_service.name
  }
}

# =============================================================================
# BACKEND SERVICE FOR LOAD BALANCER
# =============================================================================

resource "google_compute_backend_service" "pdf_backend" {
  name                  = "${var.service_name}-backend-${var.environment}"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.pdf_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # CDN Configuration for static PDF assets
  enable_cdn = true
  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    client_ttl        = 3600
    negative_caching  = true
    serve_while_stale = 86400

    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = false
    }

    negative_caching_policy {
      code = 404
      ttl  = 120
    }
  }
}

# =============================================================================
# PUBLIC ACCESS CONFIGURATION
# =============================================================================

resource "google_cloud_run_service_iam_binding" "public_access" {
  count    = var.allow_public_access ? 1 : 0
  location = google_cloud_run_v2_service.pdf_service.location
  project  = google_cloud_run_v2_service.pdf_service.project
  service  = google_cloud_run_v2_service.pdf_service.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

resource "google_cloud_run_service_iam_member" "authorized_access" {
  for_each = var.allow_public_access ? toset([]) : toset(distinct(concat(
    ["serviceAccount:${google_service_account.pdf_service_account.email}"],
    var.authorized_members
  )))

  location = google_cloud_run_v2_service.pdf_service.location
  project  = google_cloud_run_v2_service.pdf_service.project
  service  = google_cloud_run_v2_service.pdf_service.name
  role     = "roles/run.invoker"
  member   = each.value
}

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  service_labels = merge(
    var.common_labels,
    {
      service     = var.service_name
      environment = var.environment
      component   = "pdf-server"
    }
  )

  # Environment variables for PDF server
  pdf_env_vars = [
    {
      name  = "FORMIO_PDF_PORT"
      value = "4005"
    },
    {
      name  = "NODE_ENV"
      value = var.environment == "prod" ? "production" : "development"
    },
    {
      name  = "DEBUG"
      value = var.debug_mode ? "*.*" : ""
    },
    {
      name  = "FORMIO_S3_SERVER"
      value = "storage.googleapis.com"
    },
    {
      name  = "FORMIO_S3_BUCKET"
      value = var.storage_bucket_name
    },
    {
      name  = "FORMIO_S3_PATH"
      value = "pdf/${var.environment}/uploads"
    },
    {
      name  = "NODE_OPTIONS"
      value = "--max-old-space-size=2048"
    },
    {
      name  = "FORMIO_SERVER"
      value = var.formio_server_url != "" ? var.formio_server_url : "http://localhost:3000"
    }
  ]

  # Secret environment variables
  pdf_secret_env_vars = concat(
    [
      {
        name   = "MONGO"
        secret = var.mongodb_connection_secret_id
      },
      {
        name   = "JWT_SECRET"
        secret = var.formio_jwt_secret_secret_id
      },
      {
        name   = "DB_SECRET"
        secret = var.formio_db_secret_secret_id
      },
      {
        name   = "FORMIO_S3_KEY"
        secret = var.formio_s3_key_secret_id
      },
      {
        name   = "FORMIO_S3_SECRET"
        secret = var.formio_s3_secret_secret_id
      }
    ],
    var.formio_license_secret_id != "" ? [
      {
        name   = "LICENSE_KEY"
        secret = var.formio_license_secret_id
      }
    ] : []
  )
}