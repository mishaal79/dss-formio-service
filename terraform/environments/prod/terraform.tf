# Terraform Backend and Provider Configuration
# Production Environment

terraform {
  required_version = ">= 1.6.0"
  
  # Remote state backend configuration
  backend "gcs" {
    bucket = "dss-org-tf-state"
    prefix = "formio/prod"
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
    environment = "prod"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "production"
    compliance  = "required"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  
  # Default labels for all resources
  default_labels = {
    environment = "prod"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "production"
    compliance  = "required"
  }
}