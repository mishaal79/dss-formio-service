# Service Information
output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_service.name
}

output "service_url" {
  description = "URL of the Form.io service"
  value       = google_cloud_run_v2_service.formio_service.uri
}

output "service_id" {
  description = "Full resource ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_service.id
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_service.location
}

# Service Account Information
output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.formio_service_account.email
}

output "service_account_id" {
  description = "ID of the service account"
  value       = google_service_account.formio_service_account.id
}

# Secret Information (centrally managed)
output "jwt_secret_id" {
  description = "Secret Manager secret ID for JWT secret (centrally managed)"
  value       = var.formio_jwt_secret_secret_id
}

output "db_secret_id" {
  description = "Secret Manager secret ID for DB secret (centrally managed)"
  value       = var.formio_db_secret_secret_id
}

output "root_password_secret_id" {
  description = "Secret Manager secret ID for root password (centrally managed)"
  value       = var.formio_root_password_secret_id
}

output "license_key_secret_id" {
  description = "Secret Manager secret ID for license key (Enterprise only)"
  value       = var.use_enterprise ? google_secret_manager_secret.formio_license_key[0].secret_id : null
}

# Configuration Information
output "edition" {
  description = "Form.io edition (enterprise or community)"
  value       = var.use_enterprise ? "enterprise" : "community"
}

output "database_name" {
  description = "MongoDB database name used by this service"
  value       = var.database_name
}

output "docker_image" {
  description = "Docker image used by the service"
  value       = local.formio_image
}

# =============================================================================
# CENTRALIZED LOAD BALANCER INTEGRATION OUTPUTS
# =============================================================================

output "backend_service_id" {
  description = "Backend service ID for centralized load balancer integration"
  value       = google_compute_backend_service.formio_backend.id
}

output "backend_service_name" {
  description = "Backend service name for centralized load balancer integration"
  value       = google_compute_backend_service.formio_backend.name
}

output "backend_service_self_link" {
  description = "Backend service self link for centralized load balancer integration"
  value       = google_compute_backend_service.formio_backend.self_link
}

output "network_endpoint_group_id" {
  description = "Network Endpoint Group ID for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_neg.id
}

output "network_endpoint_group_name" {
  description = "Network Endpoint Group name for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_neg.name
}

output "network_endpoint_group_self_link" {
  description = "Network Endpoint Group self link for centralized load balancer integration"
  value       = google_compute_region_network_endpoint_group.formio_neg.self_link
}