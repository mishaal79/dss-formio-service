# =============================================================================
# TERRAFORM CONFIGURATION - Development Environment
# =============================================================================

terraform {
  required_version = ">= 1.0"

  # Remote state backend for development environment
  # SECURITY: State file contains sensitive data and must be stored securely
  backend "gcs" {
    bucket = "dss-terraform-state-formio"
    prefix = "formio-service/environments/dev"

    # State locking enabled automatically with GCS backend
    # Prevents concurrent modifications and state corruption
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.39"
    }
  }
}