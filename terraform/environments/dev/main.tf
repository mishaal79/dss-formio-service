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
  deploy_community     = true
  deploy_enterprise    = true
  formio_version       = var.formio_version
  community_version    = "v4.6.0-rc.3"
  formio_license_key   = var.formio_license_key
  formio_root_email    = var.formio_root_email
  formio_root_password = var.formio_root_password
  formio_jwt_secret    = var.formio_jwt_secret
  formio_db_secret     = var.formio_db_secret
  portal_enabled       = true

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

  # MongoDB self-hosted configuration
  mongodb_version            = var.mongodb_version
  mongodb_machine_type       = var.mongodb_machine_type
  mongodb_data_disk_size     = var.mongodb_data_disk_size
  mongodb_admin_username     = var.mongodb_admin_username
  mongodb_admin_password     = var.mongodb_admin_password
  mongodb_formio_username    = var.mongodb_formio_username
  mongodb_formio_password    = var.mongodb_formio_password
  mongodb_database_name      = var.mongodb_database_name
  mongodb_backup_retention_days = var.mongodb_backup_retention_days

  # Monitoring
  notification_channels = var.notification_channels

  # Domain configuration
  custom_domain      = var.custom_domain
  ssl_certificate_id = var.ssl_certificate_id

  # Shared infrastructure references (temporarily disabled for initial deployment)
  shared_vpc_id           = null  # Use local networking
  shared_subnet_ids       = []    # Use local networking  
  shared_vpc_connector_id = null  # Use local networking
}