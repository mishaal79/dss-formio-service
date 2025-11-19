# Storage Module for Form.io Service
# Provides GCS bucket for file uploads with enhanced security configuration

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# =============================================================================
# CORS CONFIGURATION LOCALS
# =============================================================================

locals {
  # Define approved frontend domains for CORS based on environment
  cors_origins_dev = [
    "http://localhost:64849",           # Local development
    "http://localhost:3000",            # Alternative local dev port
    "http://localhost:5173",            # Vite dev server
    "https://formio-dev.erlich.app"    # Development frontend
  ]

  cors_origins_staging = [
    "https://formio-staging.erlich.app"  # Staging frontend
  ]

  cors_origins_prod = [
    "https://formio.erlich.app",         # Production frontend
    "https://forms.erlich.app"           # Alternative production domain
  ]

  # Select origins based on environment
  cors_origins = var.environment == "prod" ? local.cors_origins_prod : (
    var.environment == "staging" ? concat(local.cors_origins_staging, local.cors_origins_dev) :
    local.cors_origins_dev
  )

  # Methods required for TUS resumable uploads
  tus_methods = [
    "OPTIONS",  # CORS preflight
    "HEAD",     # Check upload status
    "PATCH",    # Upload chunks
    "POST",     # Create upload
    "GET",      # Download files
    "DELETE"    # Cancel upload
  ]

  # Headers required for TUS protocol
  tus_headers = [
    "Tus-Resumable",           # TUS version
    "Upload-Length",           # File size
    "Upload-Offset",           # Current position
    "Upload-Metadata",         # File metadata
    "Upload-Concat",           # Concatenation
    "Upload-Defer-Length",     # Defer length
    "Location",                # Upload URL
    "Content-Type",            # Content type
    "Content-Length",          # Content length
    "Authorization",          # Auth token
    "X-Requested-With",       # AJAX indicator
    "X-HTTP-Method-Override", # Method override
    "*"                       # Allow all headers for compatibility
  ]
}

# =============================================================================
# MAIN STORAGE BUCKET WITH ENHANCED SECURITY (STOR-002, STOR-004)
# =============================================================================

resource "google_storage_bucket" "formio_storage" {
  name     = var.formio_bucket_name != "" ? var.formio_bucket_name : "${var.project_id}-formio-storage-${var.environment}-${random_string.bucket_suffix.result}"
  location = var.region
  project  = var.project_id

  # Storage class
  storage_class = "STANDARD"

  # Force destroy for dev environments only
  force_destroy = var.environment == "dev" ? true : false

  # Uniform bucket-level access for security
  uniform_bucket_level_access = true

  # Public access prevention
  public_access_prevention = "enforced"

  # Versioning for file safety and recovery
  versioning {
    enabled = true
  }

  # ==========================================================================
  # LIFECYCLE RULES FOR COMPLIANCE AND COST OPTIMIZATION (STOR-002)
  # ==========================================================================

  # Rule 1: Clean up incomplete TUS upload chunks after 7 days
  lifecycle_rule {
    condition {
      age            = 7
      matches_prefix = ["tus-chunks/"]
    }
    action {
      type = "Delete"
    }
  }

  # Rule 2: Clean up failed uploads after 1 day
  lifecycle_rule {
    condition {
      age            = 1
      matches_prefix = ["uploads-failed/"]
    }
    action {
      type = "Delete"
    }
  }

  # Rule 3: Clean up temporary uploads after 90 days
  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["uploads-temp/", "temp/"]
    }
    action {
      type = "Delete"
    }
  }

  # Rule 4: Move temporary uploads to Nearline after 30 days
  lifecycle_rule {
    condition {
      age                   = 30
      matches_prefix        = ["uploads-temp/", "temp/"]
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Rule 5: Move production uploads to Nearline after 90 days
  lifecycle_rule {
    condition {
      age                   = 90
      matches_prefix        = ["uploads/"]
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Rule 6: Move production uploads to Coldline after 365 days
  lifecycle_rule {
    condition {
      age                   = 365
      matches_prefix        = ["uploads/"]
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  # Rule 7: Move production uploads to Archive after 3 years
  lifecycle_rule {
    condition {
      age                   = 1095  # 3 years
      matches_prefix        = ["uploads/"]
      matches_storage_class = ["COLDLINE"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }

  # Rule 8: Delete old versions after 30 days to control costs
  lifecycle_rule {
    condition {
      age        = 30
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Rule 9: Abort incomplete multipart uploads after 7 days
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # ==========================================================================
  # RETENTION POLICY FOR COMPLIANCE (7-YEAR RETENTION) (STOR-002)
  # ==========================================================================

  retention_policy {
    retention_period = 2555 * 86400  # 7 years in seconds
    is_locked        = false  # Set to true in production after testing
  }

  # ==========================================================================
  # CORS CONFIGURATION FOR TUS UPLOADS (STOR-004)
  # ==========================================================================

  cors {
    origin          = local.cors_origins
    method          = local.tus_methods
    response_header = local.tus_headers
    max_age_seconds = 3600  # Cache preflight for 1 hour
  }

  labels = merge(var.labels, {
    environment = var.environment
    service     = "formio"
    purpose     = "uploads"
    compliance  = "7-year-retention"
    managed-by  = "terraform"
  })
}

# =============================================================================
# SERVICE ACCOUNTS WITH LEAST PRIVILEGE (STOR-003)
# =============================================================================

# Service account for Form.io server
resource "google_service_account" "formio_server" {
  account_id   = "formio-server-sa-${var.environment}"
  display_name = "Form.io Server Service Account (${var.environment})"
  description  = "Service account for Form.io server to access storage bucket with least privilege"
  project      = var.project_id
}

# Service account for TUS server
resource "google_service_account" "tus_server" {
  account_id   = "tus-server-sa-${var.environment}"
  display_name = "TUS Server Service Account (${var.environment})"
  description  = "Service account for TUS resumable upload server to manage chunks"
  project      = var.project_id
}

# =============================================================================
# IAM BINDINGS WITH LEAST PRIVILEGE (STOR-003)
# =============================================================================

# IAM binding for Form.io server - Object Creator (can create new objects)
resource "google_storage_bucket_iam_member" "formio_server_object_creator" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.formio_server.email}"
}

# IAM binding for Form.io server - Object Viewer (can read objects)
resource "google_storage_bucket_iam_member" "formio_server_object_viewer" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.formio_server.email}"
}

# IAM binding for TUS server - Object Creator (can create chunks)
resource "google_storage_bucket_iam_member" "tus_server_object_creator" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.tus_server.email}"
}

# IAM binding for TUS server - Object Viewer (can read chunks)
resource "google_storage_bucket_iam_member" "tus_server_object_viewer" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.tus_server.email}"
}

# Additional permission for TUS server to delete incomplete chunks (conditional)
resource "google_storage_bucket_iam_member" "tus_server_object_delete" {
  bucket = google_storage_bucket.formio_storage.name
  role   = "roles/storage.objectUser"  # Can also delete objects (for cleanup)
  member = "serviceAccount:${google_service_account.tus_server.email}"

  # Condition to only allow deletion of TUS chunks
  condition {
    title       = "TUS chunks only"
    description = "Only allow deletion of objects in tus-chunks/ prefix"
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.formio_storage.name}/objects/tus-chunks/')"
  }
}

# =============================================================================
# SERVICE ACCOUNT KEYS IN SECRET MANAGER
# =============================================================================

# Generate service account keys for application use
resource "google_service_account_key" "formio_server_key" {
  service_account_id = google_service_account.formio_server.name
  key_algorithm      = "KEY_ALG_RSA_2048"
}

resource "google_service_account_key" "tus_server_key" {
  service_account_id = google_service_account.tus_server.name
  key_algorithm      = "KEY_ALG_RSA_2048"
}

# Store service account keys in Secret Manager
resource "google_secret_manager_secret" "formio_server_sa_key" {
  secret_id = "formio-server-sa-key-${var.environment}"
  project   = var.project_id

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "formio_server_sa_key" {
  secret      = google_secret_manager_secret.formio_server_sa_key.id
  secret_data = base64decode(google_service_account_key.formio_server_key.private_key)
}

resource "google_secret_manager_secret" "tus_server_sa_key" {
  secret_id = "tus-server-sa-key-${var.environment}"
  project   = var.project_id

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "tus_server_sa_key" {
  secret      = google_secret_manager_secret.tus_server_sa_key.id
  secret_data = base64decode(google_service_account_key.tus_server_key.private_key)
}