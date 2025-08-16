# Development Environment Configuration
# Form.io Enterprise Service - Development Deployment

# Terraform configuration is defined in terraform.tf

# Data source for shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-org-tf-state"
    prefix = "erlich/dev"
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
    tier        = "development"
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
  deploy_community   = false
  deploy_enterprise  = true
  formio_version     = var.formio_version
  community_version  = var.community_version
  formio_license_key = var.formio_license_key
  formio_root_email  = var.formio_root_email
  # Secrets are auto-generated in root module's secrets.tf
  portal_enabled = true

  # Security configuration - authorized members for Cloud Run access
  # CHANGED: Enable public access for form submissions (was restricted to admin only)
  authorized_members = ["allUsers"]

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

  # MongoDB Atlas configuration
  mongodb_atlas_org_id    = var.mongodb_atlas_org_id
  mongodb_admin_username  = var.mongodb_admin_username
  mongodb_formio_username = var.mongodb_formio_username
  mongodb_database_name   = var.mongodb_database_name

  # Monitoring
  notification_channels = var.notification_channels

  # Domain configuration
  custom_domain      = var.custom_domain
  ssl_certificate_id = var.ssl_certificate_id
  custom_domains     = var.custom_domains

  # Shared infrastructure references
  shared_vpc_id     = try(data.terraform_remote_state.shared_infra.outputs.vpc_network_id, null)
  shared_subnet_ids = try([data.terraform_remote_state.shared_infra.outputs.app_subnet_id], [])
  # VPC connector removed - using Direct VPC egress with Cloud NAT for cost optimization
}