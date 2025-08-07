output "service_url" {
  description = "URL of the deployed Form.io service"
  value       = google_cloud_run_v2_service.formio_service.uri
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_service.name
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.formio_service.id
}

output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = google_service_account.formio_service_account.email
}

output "jwt_secret_id" {
  description = "Secret Manager secret ID for JWT secret"
  value       = google_secret_manager_secret.formio_jwt_secret.secret_id
}

output "db_secret_id" {
  description = "Secret Manager secret ID for DB secret"
  value       = google_secret_manager_secret.formio_db_secret.secret_id
}

output "root_password_secret_id" {
  description = "Secret Manager secret ID for root password"
  value       = google_secret_manager_secret.formio_root_password.secret_id
}

output "license_key_secret_id" {
  description = "Secret Manager secret ID for license key (enterprise only)"
  value       = var.use_enterprise ? google_secret_manager_secret.formio_license_key[0].secret_id : null
}