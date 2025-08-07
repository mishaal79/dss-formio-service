# Terraform Backend and Provider Configuration
# Staging Environment

terraform {
  required_version = ">= 1.6.0"
  
  # Remote state backend configuration
  backend "gcs" {
    bucket = "dss-org-tf-state"
    prefix = "formio/staging"
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
  }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
  
  # Default labels for all resources
  default_labels = {
    environment = "staging"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "staging"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  
  # Default labels for all resources
  default_labels = {
    environment = "staging"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "staging"
  }
}