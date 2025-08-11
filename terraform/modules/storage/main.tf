# Storage Module for Form.io Service
# Provides GCS bucket for file uploads and storage

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "google_storage_bucket" "formio_storage" {
  name     = var.formio_bucket_name != "" ? var.formio_bucket_name : "${var.project_id}-formio-storage-${var.environment}-${random_string.bucket_suffix.result}"
  location = var.region
  project  = var.project_id

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Versioning for file safety
  versioning {
    enabled = true
  }

  # Lifecycle management to control costs
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # CORS configuration for Form.io
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  labels = var.labels
}

# Public access prevention
resource "google_storage_bucket_iam_binding" "public_access_prevention" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectViewer"

  members = []
}