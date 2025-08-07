terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Secret Manager secrets for sensitive configuration
resource "google_secret_manager_secret" "formio_jwt_secret" {
  secret_id = "${var.service_name}-jwt-secret-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "formio_jwt_secret" {
  secret      = google_secret_manager_secret.formio_jwt_secret.id
  secret_data = var.formio_jwt_secret
}

resource "google_secret_manager_secret" "formio_db_secret" {
  secret_id = "${var.service_name}-db-secret-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "formio_db_secret" {
  secret      = google_secret_manager_secret.formio_db_secret.id
  secret_data = var.formio_db_secret
}

resource "google_secret_manager_secret" "formio_root_password" {
  secret_id = "${var.service_name}-root-password-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "formio_root_password" {
  secret      = google_secret_manager_secret.formio_root_password.id
  secret_data = var.formio_root_password
}

# Enterprise license key secret (only if using enterprise)
resource "google_secret_manager_secret" "formio_license_key" {
  count     = var.use_enterprise ? 1 : 0
  secret_id = "${var.service_name}-license-key-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "formio_license_key" {
  count       = var.use_enterprise ? 1 : 0
  secret       = google_secret_manager_secret.formio_license_key[0].id
  secret_data = var.formio_license_key
}

# Service Account for Cloud Run
resource "google_service_account" "formio_service_account" {
  account_id   = "${var.service_name}-sa-${var.environment}"
  display_name = "Form.io Cloud Run Service Account"
  description  = "Service account for Form.io Cloud Run service"
}

# IAM bindings for Secret Manager access
resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  secret_id = google_secret_manager_secret.formio_jwt_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "db_secret_access" {
  secret_id = google_secret_manager_secret.formio_db_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "root_password_access" {
  secret_id = google_secret_manager_secret.formio_root_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "license_key_access" {
  count     = var.use_enterprise ? 1 : 0
  secret_id = google_secret_manager_secret.formio_license_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Cloud Storage access for file uploads
resource "google_storage_bucket_iam_member" "formio_storage_access" {
  bucket = var.storage_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# MongoDB connection string secret access
resource "google_secret_manager_secret_iam_member" "mongodb_connection_access" {
  secret_id = var.mongodb_connection_string_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "formio_service" {
  name     = "${var.service_name}-${var.environment}"
  location = var.region
  
  # Temporarily disable deletion protection for regional migration
  deletion_protection = false
  
  template {
    service_account = google_service_account.formio_service_account.email
    
    # VPC Connector (if provided - supports both shared and local infrastructure)
    dynamic "vpc_access" {
      for_each = var.vpc_connector_id != null && var.vpc_connector_id != "" ? [1] : []
      content {
        connector = var.vpc_connector_id
        egress    = "ALL_TRAFFIC"  # Route all traffic through VPC for security
      }
    }
    
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    
    containers {
      image = var.formio_image
      
      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
      }
      
      # Form.io specific environment variables
      env {
        name  = "DEBUG"
        value = "formio:*"
      }
      
      env {
        name  = "ROOT_EMAIL"
        value = var.formio_root_email
      }
      
      env {
        name = "ROOT_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.formio_root_password.secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "MONGO"
        value_source {
          secret_key_ref {
            secret  = var.mongodb_connection_string_secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.formio_jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "DB_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.formio_db_secret.secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name  = "PORTAL_ENABLED"
        value = var.portal_enabled ? "true" : "false"
      }
      
      # Enterprise-specific environment variables
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
        value = "${var.environment}/uploads"
      }
      
      # Node.js memory optimization
      env {
        name  = "NODE_OPTIONS"
        value = "--max-old-space-size=1536"
      }
      
      # Health check port
      ports {
        container_port = 3001
      }
      
      # Startup probe
      startup_probe {
        http_get {
          path = "/health"
          port = 3001
        }
        initial_delay_seconds = 30
        timeout_seconds       = 10
        period_seconds        = 10
        failure_threshold     = 10
      }
      
      # Liveness probe
      liveness_probe {
        http_get {
          path = "/health"
          port = 3001
        }
        initial_delay_seconds = 60
        timeout_seconds       = 10
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
    
    timeout = "${var.timeout_seconds}s"
    
    # Maximum concurrent requests per instance
    max_instance_request_concurrency = var.concurrency
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = var.labels
  
  depends_on = [
    google_secret_manager_secret_version.formio_jwt_secret,
    google_secret_manager_secret_version.formio_db_secret,
    google_secret_manager_secret_version.formio_root_password
  ]
}

# Allow unauthenticated access to the service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.formio_service.location
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}