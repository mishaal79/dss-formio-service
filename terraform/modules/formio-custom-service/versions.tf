# =============================================================================
# TERRAFORM PROVIDER VERSIONS
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }

  # Optional: Configure remote state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "formio-custom"
  # }
}