# Production Environment Configuration
# Form.io Enterprise Service - Production Deployment

terraform {
  required_version = ">= 1.6.0" # Required for native testing
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

# Data source for shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-org-tf-state"
    prefix = "erlich/prod"
  }
}

# Data sources
data "google_project" "current" {}

# Local values
locals {
  common_labels = {
    environment = var.environment
    project     = "dss-formio"
    managed_by  = "terraform"
    cost_center = "engineering"
    tier        = "production"
    compliance  = "required"
  }

  # Use enterprise image for this deployment
  formio_image = "formio/formio-enterprise:${var.formio_version}"
}

# Call the root module with environment-specific configuration
module "formio_service" {
  source = "../../"

  # Project configuration
  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  # Form.io configuration
  use_enterprise       = true
  formio_version       = var.formio_version
  formio_license_key   = var.formio_license_key
  formio_root_email    = var.formio_root_email
  formio_root_password = var.formio_root_password
  formio_jwt_secret    = var.formio_jwt_secret
  formio_db_secret     = var.formio_db_secret
  portal_enabled       = var.portal_enabled

  # Service configuration
  service_name    = var.service_name
  max_instances   = var.max_instances
  min_instances   = var.min_instances
  cpu_request     = var.cpu_request
  memory_request  = var.memory_request
  concurrency     = var.concurrency
  timeout_seconds = var.timeout_seconds

  # Storage configuration
  formio_bucket_name = var.formio_bucket_name

  # MongoDB configuration
  mongodb_atlas_enabled = var.mongodb_atlas_enabled
  mongodb_version       = var.mongodb_version
  mongodb_tier          = var.mongodb_tier
  atlas_org_id          = var.atlas_org_id
  atlas_project_name    = var.atlas_project_name
  atlas_cluster_name    = var.atlas_cluster_name
  atlas_region          = var.atlas_region

  # Monitoring
  notification_channels = var.notification_channels

  # Domain configuration
  custom_domain      = var.custom_domain
  ssl_certificate_id = var.ssl_certificate_id

  # Shared infrastructure references
  shared_vpc_id           = try(data.terraform_remote_state.shared_infra.outputs.vpc_network_id, null)
  shared_subnet_ids       = try([data.terraform_remote_state.shared_infra.outputs.egress_subnet_id], [])
  shared_vpc_connector_id = try(data.terraform_remote_state.shared_infra.outputs.vpc_connector_id, null)
}