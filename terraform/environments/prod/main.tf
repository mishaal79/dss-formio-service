# Production Environment Configuration
# Form.io Enterprise Service - Production Deployment

# =============================================================================
# PROVIDER CONFIGURATIONS
# =============================================================================

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

provider "mongodbatlas" {
  # Terraform-native authentication using environment variables:
  # MONGODB_ATLAS_PUBLIC_API_KEY
  # MONGODB_ATLAS_PRIVATE_API_KEY
  # 
  # This is the proper separation of concerns - provider credentials
  # are handled outside the infrastructure being provisioned
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Data source to consume central infrastructure outputs
data "terraform_remote_state" "central_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-org-tf-state"
    prefix = "erlich/${var.environment}" # erlich/prod
  }
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  common_labels = {
    environment = var.environment
    project     = "dss-formio"
    managed_by  = "terraform"
    cost_center = "engineering"
    tier        = "production"
    compliance  = "required"
  }

  # Database name constants (DRY principle)
  mongodb_community_db_name  = "${var.mongodb_database_name}_community"
  mongodb_enterprise_db_name = "${var.mongodb_database_name}_enterprise"
}

# =============================================================================
# SECRETS MODULE
# =============================================================================

module "secrets" {
  source = "../../modules/secrets"

  project_id   = var.project_id
  environment  = var.environment
  service_name = var.service_name
  labels       = local.common_labels
}

# =============================================================================
# NETWORKING INFRASTRUCTURE
# =============================================================================

# Legacy NAT IP resource removed - now using central infrastructure  
# Static IPs are managed by central Cloud NAT gateway in gcp-dss-erlich-infra-terraform

# =============================================================================
# INFRASTRUCTURE MODULES
# =============================================================================

# Storage module
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  formio_bucket_name = var.formio_bucket_name
}

# MongoDB Atlas module (managed MongoDB cluster)
module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels

  # MongoDB Atlas configuration
  atlas_project_name             = "${var.service_name}-${var.environment}"
  atlas_org_id                   = var.mongodb_atlas_org_id
  cluster_name                   = "${var.service_name}-${var.environment}-cluster"
  backing_provider_name          = "GCP"
  atlas_region_name              = "ASIA_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  # Authentication - Using Secret Manager for secure password management
  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id

  # Pass database name constants for consistent naming
  community_database_name  = local.mongodb_community_db_name
  enterprise_database_name = local.mongodb_enterprise_db_name

  # Network security simplified - MongoDB Atlas now accepts all internet traffic
  # cloud_nat_static_ip removed - using 0.0.0.0/0 with TLS + credentials security

  depends_on = [
    module.storage
  ]
}

# Load balancer module removed - now using centralized load balancer architecture
# Backend services are now created within formio-service modules for centralized integration

# Form.io Community Edition Service
module "formio-community" {
  count  = var.deploy_community ? 1 : 0
  source = "../../modules/formio-service"

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
  formio_root_password_secret_id = module.secrets.formio_root_password_secret_id
  formio_jwt_secret_secret_id    = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id     = module.secrets.formio_db_secret_secret_id

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

  # VPC Network Configuration
  vpc_network_id   = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  egress_subnet_id = data.terraform_remote_state.central_infra.outputs.egress_subnet_id

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}

# Form.io Enterprise Edition Service
module "formio-enterprise" {
  count  = var.deploy_enterprise ? 1 : 0
  source = "../../modules/formio-service"

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
  formio_root_password_secret_id = module.secrets.formio_root_password_secret_id
  formio_jwt_secret_secret_id    = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id     = module.secrets.formio_db_secret_secret_id

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

  # VPC Network Configuration
  vpc_network_id   = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  egress_subnet_id = data.terraform_remote_state.central_infra.outputs.egress_subnet_id

  # Custom domains for whitelabeling
  custom_domains = var.custom_domains

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}