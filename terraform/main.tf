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
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.39"
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

provider "mongodbatlas" {
  # Terraform-native authentication using environment variables:
  # MONGODB_ATLAS_PUBLIC_API_KEY
  # MONGODB_ATLAS_PRIVATE_API_KEY
  # 
  # This is the proper separation of concerns - provider credentials
  # are handled outside the infrastructure being provisioned
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

  # Database name constants (DRY principle)
  mongodb_community_db_name  = "${var.mongodb_database_name}_community"
  mongodb_enterprise_db_name = "${var.mongodb_database_name}_enterprise"

  # Note: Image selection is now handled per-service in the formio-service modules
}

# =============================================================================
# NETWORKING INFRASTRUCTURE
# Using shared infrastructure from gcp-dss-erlich-infra-terraform
# =============================================================================

# Get Cloud NAT static IP from shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-org-tf-state"
    prefix = "erlich/dev"
  }
}

# Get Cloud NAT external IPs from shared infrastructure  
data "google_compute_router_nat" "shared_nat" {
  name    = "erlich-vpc-dev-nat-gateway"
  project = "erlich-dev" # Shared infrastructure project
  region  = var.region
  router  = "erlich-vpc-dev-nat-router"
}

# Networking: Using shared VPC infrastructure
# Shared Cloud NAT provides outbound connectivity for MongoDB Atlas access

# Storage module
module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  formio_bucket_name = var.formio_bucket_name
}

# MongoDB Atlas module (managed MongoDB cluster)
module "mongodb_atlas" {
  source = "./modules/mongodb-atlas"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # MongoDB Atlas configuration
  atlas_project_name            = "${var.service_name}-${var.environment}"
  atlas_org_id                  = var.mongodb_atlas_org_id
  cluster_name                  = "${var.service_name}-${var.environment}-flex"
  backing_provider_name         = "GCP"
  atlas_region_name             = "ASIA_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  # Authentication - Using Secret Manager for secure password management
  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = google_secret_manager_secret.mongodb_admin_password.secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = google_secret_manager_secret.mongodb_formio_password.secret_id
  database_name             = var.mongodb_database_name
  
  # Pass database name constants for consistent naming
  community_database_name   = local.mongodb_community_db_name
  enterprise_database_name  = local.mongodb_enterprise_db_name

  # Network security - temporarily allow all IPs for testing Cloud NAT connectivity
  # TODO: Narrow down to actual Cloud NAT external IPs once identified
  cloud_nat_static_ip = "0.0.0.0/0" # Temporary - allow all IPs to test connectivity

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
  database_name                       = local.mongodb_community_db_name
  mongodb_connection_string_secret_id = module.mongodb_atlas.mongodb_community_connection_string_secret_id

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

  # Networking - using Direct VPC egress with Cloud NAT (VPC connector removed for cost optimization)

  depends_on = [
    module.storage,
    module.mongodb_atlas
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
  database_name                       = local.mongodb_enterprise_db_name
  mongodb_connection_string_secret_id = module.mongodb_atlas.mongodb_enterprise_connection_string_secret_id

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

  # Custom domains for whitelabeling
  custom_domains = var.custom_domains

  # Networking - using Direct VPC egress with Cloud NAT (VPC connector removed for cost optimization)

  depends_on = [
    module.storage,
    module.mongodb_atlas
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