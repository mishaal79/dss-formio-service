# Development Environment Configuration
# Form.io Enterprise Service - Development Deployment

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

provider "mongodbatlas" {
}

locals {
  common_labels = {
    environment = var.environment
    project     = "dss-formio"
    managed_by  = "terraform"
    cost_center = "engineering"
    tier        = "development"
  }

  mongodb_community_db_name  = "${var.mongodb_database_name}_community"
  mongodb_enterprise_db_name = "${var.mongodb_database_name}_enterprise"
}

module "secrets" {
  source = "../../modules/secrets"

  project_id   = var.project_id
  environment  = var.environment
  service_name = var.service_name
  labels       = local.common_labels
}

resource "google_compute_address" "formio_nat_ip" {
  name         = "${var.service_name}-nat-ip-${var.environment}"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  labels = local.common_labels
}

module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  formio_bucket_name = var.formio_bucket_name
}

module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  atlas_project_name             = "${var.service_name}-${var.environment}"
  atlas_org_id                   = var.mongodb_atlas_org_id
  cluster_name                   = "${var.service_name}-${var.environment}-flex"
  backing_provider_name          = "GCP"
  atlas_region_name              = "ASIA_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id
  database_name             = var.mongodb_database_name

  community_database_name  = local.mongodb_community_db_name
  enterprise_database_name = local.mongodb_enterprise_db_name

  cloud_nat_static_ip = "${google_compute_address.formio_nat_ip.address}/32"

  depends_on = [
    module.storage
  ]
}

module "load_balancer" {
  count  = var.enable_load_balancer ? 1 : 0
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  service_name           = var.service_name
  cloud_run_service_name = var.deploy_enterprise ? "${var.service_name}-ent-${var.environment}" : "${var.service_name}-com-${var.environment}"

  ssl_domains = var.enable_load_balancer ? (
    length(var.custom_domains) > 0 ? var.custom_domains :
    [var.custom_domain != "" ? var.custom_domain : "${var.service_name}.${var.project_id}.com"]
  ) : []

  enable_geo_blocking           = var.enable_geo_blocking
  rate_limit_threshold_count    = var.rate_limit_threshold_count
  rate_limit_threshold_interval = var.rate_limit_threshold_interval
  rate_limit_ban_duration       = var.rate_limit_ban_duration

  health_check_path   = "/health"
  health_check_port   = 80
  backend_timeout_sec = 30
  enable_cdn          = false

  enable_access_logs = true
  log_sample_rate    = 1.0

  labels = local.common_labels

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}

module "formio-community" {
  count  = var.deploy_community ? 1 : 0
  source = "../../modules/formio-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  use_enterprise    = false
  formio_version    = var.formio_version
  community_version = var.community_version
  service_name      = "${var.service_name}-com"
  formio_root_email = var.formio_root_email

  formio_root_password_secret_id = module.secrets.formio_root_password_secret_id
  formio_jwt_secret_secret_id    = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id     = module.secrets.formio_db_secret_secret_id

  portal_enabled = var.portal_enabled

  database_name                       = local.mongodb_community_db_name
  mongodb_connection_string_secret_id = module.mongodb_atlas.mongodb_community_connection_string_secret_id

  storage_bucket_name = module.storage.bucket_name

  max_instances   = var.max_instances
  min_instances   = var.min_instances
  cpu_request     = var.cpu_request
  memory_request  = var.memory_request
  concurrency     = var.concurrency
  timeout_seconds = var.timeout_seconds

  authorized_members   = var.authorized_members
  enable_load_balancer = var.enable_load_balancer

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}

module "formio-enterprise" {
  count  = var.deploy_enterprise ? 1 : 0
  source = "../../modules/formio-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  use_enterprise     = true
  formio_version     = var.formio_version
  community_version  = var.community_version
  formio_license_key = var.formio_license_key
  service_name       = "${var.service_name}-ent"
  formio_root_email  = var.formio_root_email

  formio_root_password_secret_id = module.secrets.formio_root_password_secret_id
  formio_jwt_secret_secret_id    = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id     = module.secrets.formio_db_secret_secret_id

  portal_enabled = var.portal_enabled

  database_name                       = local.mongodb_enterprise_db_name
  mongodb_connection_string_secret_id = module.mongodb_atlas.mongodb_enterprise_connection_string_secret_id

  storage_bucket_name = module.storage.bucket_name

  max_instances   = var.max_instances
  min_instances   = var.min_instances
  cpu_request     = var.cpu_request
  memory_request  = var.memory_request
  concurrency     = var.concurrency
  timeout_seconds = var.timeout_seconds

  authorized_members   = var.authorized_members
  enable_load_balancer = var.enable_load_balancer

  custom_domains = var.custom_domains

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}
