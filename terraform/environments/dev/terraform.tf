# Terraform Backend and Provider Configuration
# Development Environment

terraform {
  required_version = ">= 1.6.0"

  # Remote state backend configuration
  backend "gcs" {
    bucket = "dss-org-tf-state"
    prefix = "formio/dev"
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
  }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region

  # Default labels for all resources
  default_labels = {
    environment = "dev"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "development"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region

  # Default labels for all resources
  default_labels = {
    environment = "dev"
    project     = "dss-formio"
    managed_by  = "terraform"
    tier        = "development"
  }
}