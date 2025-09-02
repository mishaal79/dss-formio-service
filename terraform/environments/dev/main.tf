# Development Environment Configuration
# Form.io Enterprise Service - Development Deployment

provider "google" {
  project = var.project_id
  region  = var.region
}

# =============================================================================
# CENTRAL INFRASTRUCTURE INTEGRATION
# =============================================================================

# Data source to consume central infrastructure outputs
data "terraform_remote_state" "central_infra" {
  backend = "gcs"
  config = {
    bucket = "dss-org-tf-state"
    prefix = "erlich/${var.environment}" # erlich/dev
  }
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

  project_id         = var.project_id
  environment        = var.environment
  service_name       = var.service_name
  formio_license_key = var.formio_license_key
  labels             = local.common_labels
}

# Legacy NAT IP resource removed - now using central infrastructure
# Static IPs are managed by central Cloud NAT gateway in gcp-dss-erlich-infra-terraform

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
  environment = var.environment
  labels      = local.common_labels

  atlas_project_name             = "${var.service_name}-${var.environment}"
  atlas_org_id                   = var.mongodb_atlas_org_id
  cluster_name                   = "${var.service_name}-${var.environment}-cluster"
  backing_provider_name          = "GCP"
  atlas_region_name              = "ASIA_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id

  community_database_name  = local.mongodb_community_db_name
  enterprise_database_name = local.mongodb_enterprise_db_name

  # cloud_nat_static_ip removed - MongoDB Atlas now accepts all internet traffic

  depends_on = [
    module.storage
  ]
}

# Load balancer module removed - now using centralized load balancer architecture
# Backend services are now created within formio-service modules for central infrastructure integration

module "formio-community" {
  count  = var.deploy_community ? 1 : 0
  source = "../../modules/formio-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # VPC Network Configuration
  vpc_network_id   = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  egress_subnet_id = data.terraform_remote_state.central_infra.outputs.egress_subnet_id

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

  authorized_members = var.authorized_members

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

  # VPC Network Configuration
  vpc_network_id   = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  egress_subnet_id = data.terraform_remote_state.central_infra.outputs.egress_subnet_id

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

  authorized_members = var.authorized_members

  # PDF Server URL for Enterprise PDF generation
  pdf_server_url = var.deploy_pdf_server ? module.pdf-server[0].service_url : ""

  depends_on = [
    module.storage,
    module.mongodb_atlas
  ]
}


# =============================================================================
# PDF SERVER DEPLOYMENT
# =============================================================================

module "pdf-server" {
  count  = var.deploy_pdf_server ? 1 : 0
  source = "../../modules/pdf-server"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  # Network Configuration - using central infrastructure
  vpc_network          = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  vpc_connector_subnet = data.terraform_remote_state.central_infra.outputs.egress_subnet_id

  # PDF Server Configuration
  service_name     = "${var.service_name}-pdf"
  pdf_server_image = var.pdf_server_image
  pdf_libs_image   = var.pdf_libs_image

  # License and MongoDB Configuration (shared with Enterprise)
  formio_license_secret_id     = module.secrets.formio_license_secret_id
  mongodb_connection_secret_id = module.mongodb_atlas.mongodb_enterprise_connection_string_secret_id
  formio_jwt_secret_secret_id  = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id   = module.secrets.formio_db_secret_secret_id
  formio_s3_key_secret_id      = "dss-formio-gcs-s3-key-dev"
  formio_s3_secret_secret_id   = "dss-formio-gcs-s3-secret-dev"
  formio_server_url            = var.deploy_enterprise ? module.formio-enterprise[0].service_url : ""

  # Storage Configuration
  storage_bucket_name = module.storage.bucket_name

  # Resource Configuration
  min_instances   = var.pdf_min_instances
  max_instances   = var.pdf_max_instances
  cpu_request     = var.pdf_cpu_request
  memory_request  = var.pdf_memory_request
  concurrency     = var.pdf_concurrency
  timeout_seconds = var.pdf_timeout_seconds

  # Security Configuration
  allow_public_access = false
  authorized_members = concat(
    var.authorized_members,
    var.deploy_enterprise ? ["serviceAccount:${module.formio-enterprise[0].service_account_email}"] : []
  )

  # Labels
  common_labels = local.common_labels

  # Debug Configuration
  debug_mode = var.debug_mode

  depends_on = [
    module.storage,
    module.mongodb_atlas,
    module.secrets
  ]
}
