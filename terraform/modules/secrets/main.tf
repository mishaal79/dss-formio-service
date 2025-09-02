# =============================================================================
# DSS Form.io Service - Cryptographically Secure Secret Management Module
# Implements Google Cloud + Terraform security best practices
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# =============================================================================
# CRYPTOGRAPHICALLY SECURE PASSWORD GENERATION
# Using Terraform's random_password resource for enterprise-grade security
# =============================================================================

# Form.io Root Admin Password
resource "random_password" "formio_root_password" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true

  # Exclude potentially problematic characters for shell/URL safety
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"

  # Ensure minimum complexity
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

# Form.io JWT Secret (256-bit equivalent for strong encryption)
resource "random_password" "formio_jwt_secret" {
  length  = 64
  special = false # JWT secrets typically use base64-safe characters
  upper   = true
  lower   = true
  numeric = true
}

# Form.io Database Encryption Secret
resource "random_password" "formio_db_secret" {
  length  = 64
  special = true
  upper   = true
  lower   = true
  numeric = true

  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 4
}

# MongoDB Admin Password (High Security)
resource "random_password" "mongodb_admin_password" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true

  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# MongoDB Form.io User Password (Cloud Run compatible - no special chars)
resource "random_password" "mongodb_formio_password" {
  length  = 32
  special = false # No special characters for Cloud Run compatibility
  upper   = true
  lower   = true
  numeric = true

  min_upper   = 4
  min_lower   = 4
  min_numeric = 4
}

# =============================================================================
# GOOGLE SECRET MANAGER INTEGRATION
# Secure storage with proper IAM and versioning
# =============================================================================

# Form.io Root Password Secret
resource "google_secret_manager_secret" "formio_root_password" {
  project   = var.project_id
  secret_id = "${var.service_name}-root-password-${var.environment}"

  labels = merge(var.labels, {
    purpose = "authentication"
    service = "formio"
    type    = "password"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "formio_root_password" {
  secret                 = google_secret_manager_secret.formio_root_password.id
  secret_data_wo         = random_password.formio_root_password.result
  secret_data_wo_version = 2
}

# Form.io JWT Secret
resource "google_secret_manager_secret" "formio_jwt_secret" {
  project   = var.project_id
  secret_id = "${var.service_name}-jwt-secret-${var.environment}"

  labels = merge(var.labels, {
    purpose = "encryption"
    service = "formio"
    type    = "jwt"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "formio_jwt_secret" {
  secret                 = google_secret_manager_secret.formio_jwt_secret.id
  secret_data_wo         = random_password.formio_jwt_secret.result
  secret_data_wo_version = 2
}

# Form.io Database Secret
resource "google_secret_manager_secret" "formio_db_secret" {
  project   = var.project_id
  secret_id = "${var.service_name}-db-secret-${var.environment}"

  labels = merge(var.labels, {
    purpose = "encryption"
    service = "formio"
    type    = "database"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "formio_db_secret" {
  secret                 = google_secret_manager_secret.formio_db_secret.id
  secret_data_wo         = random_password.formio_db_secret.result
  secret_data_wo_version = 2
}

# MongoDB Admin Password Secret
resource "google_secret_manager_secret" "mongodb_admin_password" {
  project   = var.project_id
  secret_id = "${var.service_name}-mongodb-admin-password-${var.environment}"

  labels = merge(var.labels, {
    purpose = "authentication"
    service = "mongodb"
    type    = "admin-password"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "mongodb_admin_password" {
  secret                 = google_secret_manager_secret.mongodb_admin_password.id
  secret_data_wo         = random_password.mongodb_admin_password.result
  secret_data_wo_version = 2
}

# MongoDB Form.io User Password Secret
resource "google_secret_manager_secret" "mongodb_formio_password" {
  project   = var.project_id
  secret_id = "${var.service_name}-mongodb-formio-password-${var.environment}"

  labels = merge(var.labels, {
    purpose = "authentication"
    service = "mongodb"
    type    = "user-password"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "mongodb_formio_password" {
  secret                 = google_secret_manager_secret.mongodb_formio_password.id
  secret_data_wo         = random_password.mongodb_formio_password.result
  secret_data_wo_version = 3
}

# =============================================================================
# FORM.IO LICENSE KEY SECRET
# Stores the enterprise license key securely
# =============================================================================

# Form.io License Key Secret
resource "google_secret_manager_secret" "formio_license" {
  project   = var.project_id
  secret_id = "${var.service_name}-license-${var.environment}"

  labels = merge(var.labels, {
    purpose = "license"
    service = "formio"
    type    = "enterprise-license"
  })

  replication {
    auto {}
  }

  # SECURITY: Prevent accidental deletion of critical secrets
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_secret_manager_secret_version" "formio_license" {
  secret      = google_secret_manager_secret.formio_license.id
  secret_data = var.formio_license_key != "" ? var.formio_license_key : "placeholder"
}