# =============================================================================
# FORM.IO COMMUNITY EDITION MODULE OUTPUTS
# =============================================================================
# Outputs for standalone Form.io Community Edition deployment
# Provides integration points for centralized load balancer

# Service Information
output "service_name" {
  description = "Name of the Form.io Community Cloud Run service"
  value       = google_cloud_run_v2_service.formio_community_service.name
}

output "service_url" {
  description = "Direct URL of the Form.io Community service (internal)"
  value       = google_cloud_run_v2_service.formio_community_service.uri
}

output "service_id" {
  description = "Full resource ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_community_service.id
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_community_service.location
}

# Service Account Information
output "service_account_email" {
  description = "Email of the Form.io Community service account"
  value       = google_service_account.formio_community_service_account.email
}

output "service_account_id" {
  description = "ID of the Form.io Community service account"
  value       = google_service_account.formio_community_service_account.id
}

# Community-Specific Secret Information
output "community_s3_key_secret_id" {
  description = "Secret Manager secret ID for Community S3-compatible access key"
  value       = google_secret_manager_secret.formio_community_s3_key.secret_id
}

output "community_s3_secret_secret_id" {
  description = "Secret Manager secret ID for Community S3-compatible secret key"
  value       = google_secret_manager_secret.formio_community_s3_secret.secret_id
}

# Configuration Information
output "edition" {
  description = "Form.io edition (always 'community' for this module)"
  value       = "community"
}

output "database_name" {
  description = "MongoDB database name used by Community edition"
  value       = "formio_community"
}

output "docker_image" {
  description = "Docker image used by the Community service"
  value       = "formio/formio:${var.community_version}"
}

output "container_port" {
  description = "Container port used by Community edition (3001)"
  value       = 3001
}

# =============================================================================
# CENTRALIZED LOAD BALANCER INTEGRATION OUTPUTS
# =============================================================================

output "backend_service_id" {
  description = "Backend service ID for centralized load balancer integration"
  value       = google_compute_backend_service.formio_community_backend.id
}

output "backend_service_name" {
  description = "Backend service name for centralized load balancer integration"
  value       = google_compute_backend_service.formio_community_backend.name
}

output "consistent_backend_name" {
  description = "Mathematically consistent backend service name"
  value       = local.backend_service_name
}

output "backend_service_self_link" {
  description = "Backend service self link for centralized load balancer integration"
  value       = google_compute_backend_service.formio_community_backend.self_link
}

output "network_endpoint_group_id" {
  description = "Network Endpoint Group ID for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_community_neg.id
}

output "network_endpoint_group_name" {
  description = "Network Endpoint Group name for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_community_neg.name
}

output "network_endpoint_group_self_link" {
  description = "Network Endpoint Group self link for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_community_neg.self_link
}

# =============================================================================
# SERVICE REGISTRATION FOR CENTRALIZED LOAD BALANCER
# =============================================================================

output "service_registration" {
  description = "Service registration data for centralized load balancer integration"
  value = {
    service_name = "formio-community"
    service_type = "cloud-run"
    edition      = "community"
    environment  = var.environment
    backend_config = {
      port                    = 80
      protocol                = "HTTP"
      load_balancing_scheme   = "EXTERNAL"
      timeout_sec             = var.timeout_seconds
      session_affinity        = "CLIENT_IP"
      affinity_cookie_ttl_sec = 14400
      enable_cdn              = true
      enable_logging          = true
      log_sample_rate         = 1.0
    }
  }
}

output "service_key" {
  description = "Unique service key for identification in centralized load balancer"
  value       = "cloud-run-community-${var.environment}"
}

# =============================================================================
# BACKEND SERVICE CONFIGURATION FOR MANUAL LOAD BALANCER SETUP
# =============================================================================

output "backend_service_configuration" {
  description = "Backend service configuration for manual integration with central load balancer"
  value = {
    backend_service_id   = google_compute_backend_service.formio_community_backend.id
    backend_service_name = google_compute_backend_service.formio_community_backend.name
    host_rule_pattern    = "forms-community.${var.environment}.cloud.dsselectrical.com.au"
    description          = "Form.io Community Edition backend service for ${var.environment} environment"
    service_edition      = "community"
    recommended_config = {
      path_matcher = "formio-community-matcher"
      url_map_path = "/formio-community/*"
    }
  }
}

# =============================================================================
# MONITORING OUTPUTS
# =============================================================================

output "monitoring_dashboard_url" {
  description = "URL to the Cloud Run monitoring dashboard"
  value       = "https://console.cloud.google.com/run/detail/${var.region}/${google_cloud_run_v2_service.formio_community_service.name}/metrics?project=${var.project_id}"
}

output "logs_url" {
  description = "URL to view Cloud Run logs"
  value       = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%0Aresource.labels.service_name%3D%22${google_cloud_run_v2_service.formio_community_service.name}%22?project=${var.project_id}"
}

# =============================================================================
# DEPLOYMENT HELPER OUTPUTS
# =============================================================================

output "gcloud_deploy_command" {
  description = "Suggested gcloud command for deploying Community edition"
  value       = "gcloud run deploy ${google_cloud_run_v2_service.formio_community_service.name} --image=formio/formio:${var.community_version} --region=${var.region} --project=${var.project_id}"
}

output "base_url" {
  description = "Configured base URL for Form.io Community"
  value       = var.base_url != "" ? var.base_url : "https://forms-community.${var.environment}.cloud.dsselectrical.com.au"
}

# =============================================================================
# STORAGE CONFIGURATION OUTPUTS
# =============================================================================

output "storage_configuration" {
  description = "S3-compatible storage configuration for Community edition"
  value = {
    bucket_name = var.storage_bucket_name
    s3_path     = "com/${var.environment}/uploads"
    s3_server   = "https://storage.googleapis.com"
    s3_region   = "auto"
  }
}

# =============================================================================
# ENVIRONMENT VARIABLES OUTPUT FOR GCLOUD COMMANDS
# =============================================================================

output "env_vars_for_gcloud" {
  description = "Non-secret environment variables formatted for gcloud --update-env-vars"
  value = join(",", [
    "PORTAL_ENABLED=${var.portal_enabled ? "1" : "0"}",
    "ROOT_EMAIL=${var.formio_root_email}",
    "FORMIO_FILES_SERVER=s3",
    "FORMIO_S3_SERVER=https://storage.googleapis.com",
    "FORMIO_S3_BUCKET=${var.storage_bucket_name}",
    "FORMIO_S3_REGION=auto",
    "FORMIO_S3_PATH=com/${var.environment}/uploads",
    "NODE_OPTIONS=--max-old-space-size=1024",
    "DEBUG=*.*",
    "LOG_FORMAT=json",
    "LOG_LEVEL=${var.environment == "prod" ? "warn" : "info"}",
    "ADMIN_EMAIL=admin@dsselectrical.com.au",
    "MONGO_DB_NAME=formio_community",
    "HOST=0.0.0.0",
    "BASE_URL=${var.base_url != "" ? var.base_url : "https://forms-community.${var.environment}.cloud.dsselectrical.com.au"}",
    "TRUST_PROXY=true",
    "JWT_EXPIRE_TIME=240"
  ])
}

output "secret_env_vars" {
  description = "List of secret environment variables (requires Secret Manager access)"
  value = [
    "ROOT_PASSWORD",
    "ADMIN_PASS",
    "PORTAL_SECRET",
    "FORMIO_S3_KEY",
    "FORMIO_S3_SECRET",
    "NODE_CONFIG" # Contains MongoDB connection string and JWT secret
  ]
}