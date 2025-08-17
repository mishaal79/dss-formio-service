data "google_secret_manager_secret_version" "mongodb_connection_string" {
  provider = google-beta
  project  = var.project_id
  secret   = var.mongodb_connection_string_secret_id
}

data "google_secret_manager_secret_version" "formio_jwt_secret" {
  provider = google-beta
  project  = var.project_id
  secret   = var.formio_jwt_secret_secret_id
}

locals {
  # Community Edition NODE_CONFIG with Community-specific Atlas connection
  community_node_config = jsonencode({
    mongo = data.google_secret_manager_secret_version.mongodb_connection_string.secret_data
    port  = 3000
    jwt = {
      secret = data.google_secret_manager_secret_version.formio_jwt_secret.secret_data
    }
  })

  # Enterprise Edition uses individual environment variables (MONGO, JWT_SECRET, etc.)
  # Community Edition uses NODE_CONFIG with JSON
  node_config = var.use_enterprise ? "" : local.community_node_config

  # Missing locals restored from interrupted refactoring
  formio_image      = var.use_enterprise ? "formio/formio-enterprise:${var.formio_version}" : "formio/formio:${var.community_version}"
  service_name_full = "${var.service_name}-${var.environment}"
  service_labels = merge(var.labels, {
    edition = var.use_enterprise ? "enterprise" : "community"
    service = var.service_name
  })
}

# Service Account
resource "google_service_account" "formio_service_account" {
  account_id   = "${var.service_name}-sa-${var.environment}"
  display_name = "Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Service Account"
  project      = var.project_id
}

# IAM bindings for service account to access secrets
resource "google_secret_manager_secret_iam_member" "root_password_access" {
  project   = var.project_id
  secret_id = var.formio_root_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  project   = var.project_id
  secret_id = var.formio_jwt_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "db_secret_access" {
  project   = var.project_id
  secret_id = var.formio_db_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "mongodb_connection_access" {
  project   = var.project_id
  secret_id = var.mongodb_connection_string_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# License key access (Enterprise only)
resource "google_secret_manager_secret_iam_member" "license_key_access" {
  count     = var.use_enterprise ? 1 : 0
  project   = var.project_id
  secret_id = google_secret_manager_secret.formio_license_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Additional IAM bindings
resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Enterprise License Key Secret (conditional)
resource "google_secret_manager_secret" "formio_license_key" {
  count     = var.use_enterprise ? 1 : 0
  secret_id = "${var.service_name}-license-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.service_labels
}

resource "google_secret_manager_secret_version" "formio_license_key" {
  count       = var.use_enterprise ? 1 : 0
  secret      = google_secret_manager_secret.formio_license_key[0].id
  secret_data = var.formio_license_key
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "formio_service" {
  name     = local.service_name_full
  location = var.region
  project  = var.project_id

  # SECURITY: Force all traffic through load balancer (prevents bypass attacks)
  ingress = var.enable_load_balancer ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  # Temporarily disable deletion protection for testing
  deletion_protection = false

  # Ignore container image changes - managed by gcloud deployments
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image
    ]
  }

  template {
    service_account = google_service_account.formio_service_account.email

    # Direct VPC egress using shared infrastructure egress subnet
    # Routes all outbound traffic through shared VPC and Cloud NAT gateway
    vpc_access {
      network_interfaces {
        network    = "projects/erlich-dev/global/networks/erlich-vpc-dev"
        subnetwork = "projects/erlich-dev/regions/${var.region}/subnetworks/erlich-vpc-egress-subnet-dev"
        tags       = ["formio-egress"]
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      name  = "formio"
      image = local.formio_image

      ports {
        name           = "http1" # Force HTTP/1.1 protocol (fixes Form.io 502 errors)
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
      }

      # Health checks - startup probe removed to allow service to start naturally
      liveness_probe {
        http_get {
          path = "/health"
          port = 3000
        }
        initial_delay_seconds = 180
        timeout_seconds       = 30
        period_seconds        = 30
        failure_threshold     = 3
      }

      # Community Edition Configuration - NODE_CONFIG with MongoDB Atlas connection
      dynamic "env" {
        for_each = var.use_enterprise ? [] : [1]
        content {
          name  = "NODE_CONFIG"
          value = local.node_config
        }
      }

      # Enterprise Edition Configuration
      dynamic "env" {
        for_each = var.use_enterprise ? [1] : []
        content {
          name = "MONGO"
          value_source {
            secret_key_ref {
              secret  = var.mongodb_connection_string_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.use_enterprise ? [1] : []
        content {
          name = "JWT_SECRET"
          value_source {
            secret_key_ref {
              secret  = var.formio_jwt_secret_secret_id != null ? var.formio_jwt_secret_secret_id : "placeholder-jwt-secret"
              version = "latest"
            }
          }
        }
      }

      env {
        name = "DB_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.formio_db_secret_secret_id != null ? var.formio_db_secret_secret_id : "placeholder-db-secret"
            version = "latest"
          }
        }
      }

      env {
        name  = "PORTAL_ENABLED"
        value = var.portal_enabled ? "1" : "0"
      }

      env {
        name  = "ROOT_EMAIL"
        value = var.formio_root_email
      }

      env {
        name = "ROOT_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.formio_root_password_secret_id != null ? var.formio_root_password_secret_id : "placeholder-root-password"
            version = "latest"
          }
        }
      }

      # Enterprise-only: License key
      dynamic "env" {
        for_each = var.use_enterprise ? [1] : []
        content {
          name = "LICENSE_KEY"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.formio_license_key[0].secret_id
              version = "latest"
            }
          }
        }
      }

      # File storage configuration
      env {
        name  = "FORMIO_FILES_SERVER"
        value = "gcs"
      }

      env {
        name  = "FORMIO_GCS_BUCKET"
        value = var.storage_bucket_name
      }

      env {
        name  = "FORMIO_GCS_PATH"
        value = "${var.use_enterprise ? "ent" : "com"}/${var.environment}/uploads"
      }

      # Node.js memory optimization
      env {
        name  = "NODE_OPTIONS"
        value = "--max-old-space-size=1024"
      }

      # Debug logging for troubleshooting
      env {
        name  = "DEBUG"
        value = "*.*"
      }

      # Admin user configuration (Form.io documentation standard)
      env {
        name  = "ADMIN_EMAIL"
        value = "admin@dsselectrical.com.au"
      }

      env {
        name = "ADMIN_PASS"
        value_source {
          secret_key_ref {
            secret  = var.formio_root_password_secret_id != null ? var.formio_root_password_secret_id : "placeholder-root-password"
            version = "latest"
          }
        }
      }

      # Portal secret for portal configuration
      env {
        name = "PORTAL_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.formio_db_secret_secret_id != null ? var.formio_db_secret_secret_id : "placeholder-db-secret"
            version = "latest"
          }
        }
      }

      # Database name specification
      env {
        name  = "MONGO_DB_NAME"
        value = var.database_name
      }

      # Ensure Form.io binds to all interfaces (not just localhost)
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }

      # Explicitly set port for Form.io (Cloud Run expects PORT env var)
      env {
        name  = "PORT"
        value = "3000"
      }

      # TODO: Add PDF_SERVER configuration once basic deployment is working
      # This enables PDF form generation and export functionality
      # env {
      #   name  = "PDF_SERVER"
      #   value = "http://pdf-server:4005"
      # }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    max_instance_request_concurrency = var.concurrency
    timeout                          = "${var.timeout_seconds}s"
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  labels = local.service_labels
}

# Allow authorized access to Cloud Run service
# When using load balancer, only the load balancer needs access
# When not using load balancer, allow configured members
resource "google_cloud_run_service_iam_binding" "authorized_access" {
  count    = length(var.authorized_members) > 0 ? 1 : 0
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"

  members = var.authorized_members
}

# Allow load balancer to access Cloud Run service
resource "google_cloud_run_service_iam_binding" "load_balancer_access" {
  count    = var.enable_load_balancer ? 1 : 0
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"

  members = ["allUsers"]
}