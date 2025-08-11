terraform {
  required_version = ">= 1.0"
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

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Data sources
# Note: Removed unused data "google_project" "current"

# Local values
locals {
  common_labels = {
    environment = var.environment
    project     = "formio"
    managed_by  = "terraform"
  }

  # Note: Image selection is now handled per-service in the formio-service modules
}

# Networking: Using shared VPC infrastructure
# All networking resources are managed by gcp-dss-erlich-infra-terraform

# Storage module
module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  formio_bucket_name = var.formio_bucket_name
}

# MongoDB module (self-hosted on Compute Engine)
module "mongodb" {
  source = "./modules/mongodb"

  project_id  = var.project_id
  region      = var.region
  zone        = "${var.region}-a" # Use zone a in the region
  environment = var.environment
  labels      = local.common_labels

  # Networking - using shared VPC infrastructure
  vpc_network_id = var.shared_vpc_id
  subnet_id      = var.shared_subnet_ids[0]

  # Instance configuration
  machine_type    = var.mongodb_machine_type
  data_disk_size  = var.mongodb_data_disk_size
  mongodb_version = var.mongodb_version

  # Authentication - Using Secret Manager for secure password management
  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = google_secret_manager_secret.mongodb_admin_password.secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = google_secret_manager_secret.mongodb_formio_password.secret_id
  database_name             = var.mongodb_database_name

  # Backup configuration
  backup_retention_days = var.mongodb_backup_retention_days

  # Network security - allow access from shared VPC connector subnet
  allowed_source_ranges = ["10.8.0.0/28"] # VPC connector subnet range from shared infrastructure

  depends_on = [
    module.storage
  ]
}

# Form.io Community Edition Service
module "formio-community" {
  count  = var.deploy_community ? 1 : 0
  source = "./modules/formio-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # Form.io Community configuration
  use_enterprise    = false
  formio_version    = var.formio_version
  community_version = var.community_version
  service_name      = "${var.service_name}-com"
  formio_root_email = var.formio_root_email

  # Secure secret references from Secret Manager
  formio_root_password_secret_id = google_secret_manager_secret.formio_root_password.secret_id
  formio_jwt_secret_secret_id    = google_secret_manager_secret.formio_jwt_secret.secret_id
  formio_db_secret_secret_id     = google_secret_manager_secret.formio_db_secret.secret_id

  portal_enabled = var.portal_enabled

  # Database configuration - separate database for Community
  database_name                       = "${var.mongodb_database_name}_com"
  mongodb_connection_string_secret_id = module.mongodb.mongodb_community_connection_string_secret_id

  # Dependencies
  storage_bucket_name = module.storage.bucket_name

  # Service configuration
  max_instances   = var.max_instances
  min_instances   = var.min_instances
  cpu_request     = var.cpu_request
  memory_request  = var.memory_request
  concurrency     = var.concurrency
  timeout_seconds = var.timeout_seconds

  # Security configuration
  authorized_members = var.authorized_members

  # Networking - using shared VPC connector
  vpc_connector_id = var.shared_vpc_connector_id

  depends_on = [
    module.storage,
    module.mongodb
  ]
}

# Form.io Enterprise Edition Service
module "formio-enterprise" {
  count  = var.deploy_enterprise ? 1 : 0
  source = "./modules/formio-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # Form.io Enterprise configuration
  use_enterprise     = true
  formio_version     = var.formio_version
  community_version  = var.community_version
  formio_license_key = var.formio_license_key
  service_name       = "${var.service_name}-ent"
  formio_root_email  = var.formio_root_email

  # Secure secret references from Secret Manager
  formio_root_password_secret_id = google_secret_manager_secret.formio_root_password.secret_id
  formio_jwt_secret_secret_id    = google_secret_manager_secret.formio_jwt_secret.secret_id
  formio_db_secret_secret_id     = google_secret_manager_secret.formio_db_secret.secret_id

  portal_enabled = var.portal_enabled

  # Database configuration - separate database for Enterprise
  database_name                       = "${var.mongodb_database_name}_ent"
  mongodb_connection_string_secret_id = module.mongodb.mongodb_enterprise_connection_string_secret_id

  # Dependencies
  storage_bucket_name = module.storage.bucket_name

  # Service configuration
  max_instances   = var.max_instances
  min_instances   = var.min_instances
  cpu_request     = var.cpu_request
  memory_request  = var.memory_request
  concurrency     = var.concurrency
  timeout_seconds = var.timeout_seconds

  # Security configuration
  authorized_members = var.authorized_members

  # Networking - using shared VPC connector
  vpc_connector_id = var.shared_vpc_connector_id

  depends_on = [
    module.storage,
    module.mongodb
  ]
}

# Monitoring module (to be implemented later)
# module "monitoring" {
#   source = "./modules/monitoring"
#   
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
#   labels      = local.common_labels
#   
#   cloud_run_service_name = module.cloud_run.service_name
#   notification_channels  = var.notification_channels
#   
#   depends_on = [module.cloud_run]
# }