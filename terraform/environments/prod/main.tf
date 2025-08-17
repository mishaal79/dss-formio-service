# Production Environment Configuration
# Form.io Enterprise Service - Production Deployment

# =============================================================================
# PROVIDER CONFIGURATIONS
# =============================================================================

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

# =============================================================================
# DATA SOURCES
# =============================================================================

# Data sources removed - not currently used in this deployment pattern

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

# Static external IP for Cloud NAT (for MongoDB Atlas access)
resource "google_compute_address" "formio_nat_ip" {
  name         = "${var.service_name}-nat-ip-${var.environment}"
  description  = "Static external IP for Form.io Cloud NAT gateway (MongoDB Atlas access)"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  labels = local.common_labels
}

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
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # MongoDB Atlas configuration
  atlas_project_name             = "${var.service_name}-${var.environment}"
  atlas_org_id                   = var.mongodb_atlas_org_id
  cluster_name                   = "${var.service_name}-${var.environment}-flex"
  backing_provider_name          = "GCP"
  atlas_region_name              = "ASIA_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  # Authentication - Using Secret Manager for secure password management
  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id
  database_name             = var.mongodb_database_name

  # Pass database name constants for consistent naming
  community_database_name  = local.mongodb_community_db_name
  enterprise_database_name = local.mongodb_enterprise_db_name

  # Network security - restrict access to dynamically managed Cloud NAT external IP
  cloud_nat_static_ip = "${google_compute_address.formio_nat_ip.address}/32"

  depends_on = [
    module.storage
  ]
}

# Load Balancer with Cloud Armor Security (optional)
module "load_balancer" {
  count  = var.enable_load_balancer ? 1 : 0
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  # Service configuration
  service_name           = var.service_name
  cloud_run_service_name = var.deploy_enterprise ? "${var.service_name}-ent-${var.environment}" : "${var.service_name}-com-${var.environment}"

  # SSL configuration for custom domains
  ssl_domains = var.enable_load_balancer ? (
    length(var.custom_domains) > 0 ? var.custom_domains :
    [var.custom_domain != "" ? var.custom_domain : "${var.service_name}.${var.project_id}.com"]
  ) : []

  # Security configuration
  enable_geo_blocking           = var.enable_geo_blocking
  rate_limit_threshold_count    = var.rate_limit_threshold_count
  rate_limit_threshold_interval = var.rate_limit_threshold_interval
  rate_limit_ban_duration       = var.rate_limit_ban_duration

  # Backend configuration
  health_check_path   = "/health"
  health_check_port   = 80
  backend_timeout_sec = 30
  enable_cdn          = false

  # Logging
  enable_access_logs = true
  log_sample_rate    = 1.0

  labels = local.common_labels

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}

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
  authorized_members   = var.authorized_members
  enable_load_balancer = var.enable_load_balancer

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
  authorized_members   = var.authorized_members
  enable_load_balancer = var.enable_load_balancer

  # Custom domains for whitelabeling
  custom_domains = var.custom_domains

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}