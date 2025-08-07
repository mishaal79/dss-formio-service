terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Local values for image selection and common configurations
locals {
  # Use different version schemes for Community vs Enterprise
  formio_image = var.use_enterprise ? "formio/formio-enterprise:${var.formio_version}" : "formio/formio:${var.community_version}"
  
  # Service-specific naming (service_name already includes edition abbreviation)
  service_name_full = "${var.service_name}-${var.environment}"
  
  # Common labels
  service_labels = merge(var.labels, {
    edition = var.use_enterprise ? "enterprise" : "community"
    service = var.service_name
  })
}

# Service account for Form.io Cloud Run service
resource "google_service_account" "formio_service_account" {
  account_id   = "${var.service_name}-sa-${var.environment}"
  display_name = "Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Service Account"
  description  = "Service account for Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Cloud Run service"
  project      = var.project_id
}

# IAM bindings for service account
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

# IAM bindings for specific secrets (least privilege approach)
resource "google_secret_manager_secret_iam_member" "root_password_access" {
  project   = var.project_id
  secret_id = var.formio_root_password_secret_id != null ? var.formio_root_password_secret_id : "placeholder-root-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  project   = var.project_id
  secret_id = var.formio_jwt_secret_secret_id != null ? var.formio_jwt_secret_secret_id : "placeholder-jwt-secret"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "db_secret_access" {
  project   = var.project_id
  secret_id = var.formio_db_secret_secret_id != null ? var.formio_db_secret_secret_id : "placeholder-db-secret"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "mongodb_connection_access" {
  project   = var.project_id
  secret_id = var.mongodb_connection_string_secret_id != null ? var.mongodb_connection_string_secret_id : "placeholder-mongodb-connection"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Note: License key access is handled later in the file for enterprise resources

# =============================================================================
# SECRET MANAGER INTEGRATION
# Secrets are now managed centrally in the root module's secrets.tf
# This module only references existing secrets for Cloud Run integration
# =============================================================================

# Enterprise-only: License key secret
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

# IAM binding for license key access (Enterprise only)
resource "google_secret_manager_secret_iam_member" "license_key_access" {
  count     = var.use_enterprise ? 1 : 0
  project   = var.project_id
  secret_id = google_secret_manager_secret.formio_license_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "formio_service" {
  name     = local.service_name_full
  location = var.region
  project  = var.project_id
  
  # Temporarily disable deletion protection for testing
  deletion_protection = false
  
  template {
    service_account = google_service_account.formio_service_account.email
    
    # VPC Connector (if provided)
    dynamic "vpc_access" {
      for_each = var.vpc_connector_id != null ? [1] : []
      content {
        connector = var.vpc_connector_id
        egress    = "ALL_TRAFFIC"
      }
    }
    
    containers {
      name  = "formio"
      image = local.formio_image
      
      ports {
        name           = "http1"
        container_port = 3001
      }
      
      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
      }
      
      # MongoDB connection
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
            secret  = var.formio_jwt_secret_secret_id != null ? var.formio_jwt_secret_secret_id : "placeholder-jwt-secret"
            version = "latest"
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
        value = var.portal_enabled ? "true" : "false"
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
      
      # Database name specification
      env {
        name  = "MONGO_DB_NAME"
        value = var.database_name
      }
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

# Allow unauthenticated access to Cloud Run service
resource "google_cloud_run_service_iam_binding" "public_access" {
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"
  
  members = [
    "allUsers"
  ]
}