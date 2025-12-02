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
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
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

  formio_bucket_name     = var.formio_bucket_name
  enable_versioning      = var.enable_versioning
  enable_lifecycle_rules = var.enable_lifecycle_rules
  cors_origins           = var.cors_origins
  kms_key_name           = var.kms_key_name
}

module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels

  # MongoDB Atlas Project Configuration
  atlas_project_name = "${var.service_name}-${var.environment}-flex"
  atlas_org_id       = var.mongodb_atlas_org_id

  # Flex Cluster Configuration (Serverless - pay per use, cheapest option)
  # Testing AWS as backing provider - Australia (Sydney)
  cluster_name                   = "formio-cluster-${var.environment}-flex"
  backing_provider_name          = "AWS"
  atlas_region_name              = "AP_SOUTHEAST_2"
  termination_protection_enabled = var.environment == "prod"

  # Database User Configuration
  admin_username            = var.mongodb_admin_username
  admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
  formio_username           = var.mongodb_formio_username
  formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id

  # Database Names
  community_database_name  = local.mongodb_community_db_name
  enterprise_database_name = local.mongodb_enterprise_db_name

  depends_on = [
    module.storage
  ]
}

# Load balancer module removed - now using centralized load balancer architecture
# Backend services are now created within formio-service modules for central infrastructure integration

module "formio-custom" {
  count = var.deploy_custom ? 1 : 0

  source = "../../modules/formio-custom-service"

  # Required
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # Custom Image Configuration
  custom_image_tag    = var.custom_image_tag
  enable_blue_green   = var.enable_blue_green
  traffic_percent_new = var.traffic_percent_new
  new_revision_name   = var.new_revision_name

  # Database Configuration
  mongodb_connection_string_secret_id = module.mongodb_atlas.mongodb_enterprise_connection_string_secret_id
  mongodb_database_name               = var.mongodb_database_name

  # Secrets Configuration
  formio_jwt_secret_secret_id    = module.secrets.formio_jwt_secret_secret_id
  formio_db_secret_secret_id     = module.secrets.formio_db_secret_secret_id
  formio_root_email              = var.formio_root_email
  formio_root_password_secret_id = module.secrets.formio_root_password_secret_id
  # Token keys for JWT signing (secrets exist in Secret Manager)
  token_public_key_secret_id  = "dss-formio-api-token-public-key-v1-dev"
  token_private_key_secret_id = "dss-formio-api-token-private-key-v1-dev"

  # Enhanced File Upload Configuration
  enable_async_gcs_upload   = var.enable_async_gcs_upload
  bullmq_worker_concurrency = var.bullmq_worker_concurrency
  xxhash_enabled            = var.xxhash_enabled
  railway_oriented_uploads  = var.railway_oriented_uploads

  # Storage Configuration
  storage_bucket_name = module.storage.bucket_name
  gcs_project_id      = var.gcs_project_id

  # Redis Configuration (BullMQ)
  redis_host               = var.redis_host
  redis_port               = var.redis_port
  redis_password_secret_id = null # Redis in VPC no auth

  # Service Configuration
  portal_enabled = var.portal_enabled
  debug_enabled  = var.debug_enabled

  # TUS Upload Configuration
  tus_enabled  = var.tus_enabled
  tus_port     = var.tus_port
  tus_max_size = var.tus_max_size

  # Email Configuration
  email_type               = var.email_type
  email_host               = var.email_host
  email_port               = var.email_port
  email_secure             = var.email_secure
  email_user               = var.email_user
  email_password_secret_id = var.email_password_secret_id

  # CORS Configuration
  cors_enabled = var.cors_enabled
  cors_origin  = var.cors_origin

  # Cloud Run Configuration
  min_instance_count    = var.min_instance_count
  max_instance_count    = var.max_instance_count
  container_concurrency = var.container_concurrency
  request_timeout       = var.request_timeout
  memory_limit          = var.memory_limit
  memory_request        = var.memory_request
  cpu_limit             = var.cpu_limit
  cpu_request           = var.cpu_request

  # CDN Configuration
  cache_default_ttl     = var.cache_default_ttl
  cache_max_ttl         = var.cache_max_ttl
  cache_client_ttl      = var.cache_client_ttl
  cache_query_whitelist = var.cache_query_whitelist
  cache_headers         = var.cache_headers
  bypass_cache_headers  = var.bypass_cache_headers
  log_sample_rate       = var.log_sample_rate

  # IAP Configuration
  iap_enabled       = var.iap_enabled
  iap_client_id     = var.iap_client_id
  iap_client_secret = var.iap_client_secret

  # DNS Configuration
  create_dns_record = var.create_dns_record
  dns_project_id    = var.dns_project_id
  dns_managed_zone  = var.dns_managed_zone
  dns_name          = var.dns_name

  # Observability - OTEL Collector for comprehensive tracing
  otel_endpoint = "https://otel-collector-dev-240287924786.australia-southeast1.run.app"

  # Monitoring and Alerting
  enable_alerting       = var.enable_alerting
  error_rate_threshold  = var.error_rate_threshold
  latency_threshold     = var.latency_threshold
  notification_channels = var.notification_channels

  depends_on = [
    module.storage,
    module.mongodb_atlas,
    module.secrets
  ]
}

# Legacy formio-community module - kept for reference
# module "formio-community" {
#   count  = var.deploy_community ? 1 : 0
#   source = "../../modules/formio-community-service"
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
#   labels      = local.common_labels
# }

# =============================================================================
# FORM WEB BFF DEPLOYMENT
# =============================================================================

module "form-web-bff" {
  count  = var.deploy_custom ? 1 : 0 # Deploy BFF when custom is deployed
  source = "../../modules/form-web-bff"

  # Project configuration
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels

  # Docker image from Artifact Registry (must match cloudbuild.yaml)
  image_url = "australia-southeast1-docker.pkg.dev/${var.project_id}/formio-services/form-web-bff:latest"

  # Port configuration (variable-based, not hardcoded)
  container_port = 3002

  # VPC networking (from central infrastructure - Direct VPC Egress)
  vpc_network_id     = data.terraform_remote_state.central_infra.outputs.vpc_network_id
  egress_subnet_id   = data.terraform_remote_state.central_infra.outputs.egress_subnet_id
  vpc_egress_setting = "ALL_TRAFFIC"

  # Service-to-service authentication to formio-custom
  formio_custom_service_name = var.deploy_custom ? module.formio-custom[0].service_name : ""
  formio_custom_service_url  = var.deploy_custom ? module.formio-custom[0].service_url : ""

  # Cloud Run scaling configuration
  min_instance_count    = 0 # Scale to zero in dev
  max_instance_count    = 10
  container_concurrency = 80
  request_timeout       = 60

  # Resource limits (lower for dev to save costs)
  memory_limit = "512Mi"
  cpu_limit    = "1000m"

  # Application configuration
  node_env  = "production"
  log_level = "info"

  # CORS configuration (allow local dev and basedforms.io domains)
  cors_origin = "http://localhost:64849,https://forms.basedforms.io,https://basedforms.io,https://www.basedforms.io,https://*.basedforms.pages.dev"

  # Rate limiting (relaxed for dev)
  rate_limit_max       = 1000
  rate_limit_window_ms = 60000

  # Observability - OTEL Collector for comprehensive tracing
  otel_endpoint = "https://otel-collector-dev-240287924786.australia-southeast1.run.app"

  # Public access for dev environment
  allow_unauthenticated = true

  depends_on = [
    module.formio-custom
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
  # NOTE: Set to empty to break circular dependency - will be configured post-deployment
  pdf_server_url = ""

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
  formio_server_url            = "" # Removed to break circular dependency

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
  allow_public_access = true
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

