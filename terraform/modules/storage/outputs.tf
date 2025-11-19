# Storage Module Outputs

# Primary bucket outputs
output "bucket_name" {
  description = "Name of the primary GCS bucket"
  value       = google_storage_bucket.formio_storage.name
}

output "bucket_url" {
  description = "URL of the GCS bucket (gs:// format)"
  value       = google_storage_bucket.formio_storage.url
}

output "bucket_self_link" {
  description = "Self-link of the GCS bucket"
  value       = google_storage_bucket.formio_storage.self_link
}

output "bucket_location" {
  description = "Location of the GCS bucket"
  value       = google_storage_bucket.formio_storage.location
}

output "bucket_storage_class" {
  description = "Storage class of the GCS bucket"
  value       = google_storage_bucket.formio_storage.storage_class
}

output "bucket_https_url" {
  description = "HTTPS URL for accessing the bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.formio_storage.name}"
}

# =============================================================================
# SERVICE ACCOUNT OUTPUTS (STOR-003)
# =============================================================================

output "formio_server_service_account_email" {
  description = "Email of the Form.io server service account"
  value       = google_service_account.formio_server.email
}

output "formio_server_service_account_id" {
  description = "ID of the Form.io server service account"
  value       = google_service_account.formio_server.id
}

output "formio_server_sa_key_secret_id" {
  description = "Secret ID for Form.io server service account key"
  value       = google_secret_manager_secret.formio_server_sa_key.secret_id
}

output "tus_server_service_account_email" {
  description = "Email of the TUS server service account"
  value       = google_service_account.tus_server.email
}

output "tus_server_service_account_id" {
  description = "ID of the TUS server service account"
  value       = google_service_account.tus_server.id
}

output "tus_server_sa_key_secret_id" {
  description = "Secret ID for TUS server service account key"
  value       = google_secret_manager_secret.tus_server_sa_key.secret_id
}

# =============================================================================
# LIFECYCLE AND COMPLIANCE OUTPUTS (STOR-002)
# =============================================================================

output "retention_period_days" {
  description = "Retention period in days for compliance"
  value       = 2555  # 7 years
}

output "retention_locked" {
  description = "Whether retention policy is locked"
  value       = google_storage_bucket.formio_storage.retention_policy[0].is_locked
}

# =============================================================================
# CORS CONFIGURATION OUTPUT (STOR-004)
# =============================================================================

output "cors_origins" {
  description = "Allowed CORS origins for the bucket"
  value       = local.cors_origins
}

output "cors_methods" {
  description = "Allowed CORS methods for TUS uploads"
  value       = local.tus_methods
}