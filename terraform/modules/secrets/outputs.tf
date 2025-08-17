# =============================================================================
# SECRETS MODULE OUTPUTS
# Providing secret references (not values) to other modules
# =============================================================================

output "formio_root_password_secret_id" {
  description = "Secret Manager secret ID for Form.io root password"
  value       = google_secret_manager_secret.formio_root_password.secret_id
}

output "formio_jwt_secret_secret_id" {
  description = "Secret Manager secret ID for Form.io JWT secret"
  value       = google_secret_manager_secret.formio_jwt_secret.secret_id
}

output "formio_db_secret_secret_id" {
  description = "Secret Manager secret ID for Form.io database secret"
  value       = google_secret_manager_secret.formio_db_secret.secret_id
}

output "mongodb_admin_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin password"
  value       = google_secret_manager_secret.mongodb_admin_password.secret_id
}

output "mongodb_formio_password_secret_id" {
  description = "Secret Manager secret ID for MongoDB Form.io user password"
  value       = google_secret_manager_secret.mongodb_formio_password.secret_id
}

# Secret validation outputs (lengths only, for security verification)
output "secret_validation" {
  description = "Secret validation info (lengths only, for security verification)"
  value = {
    formio_root_password_length    = length(random_password.formio_root_password.result)
    formio_jwt_secret_length       = length(random_password.formio_jwt_secret.result)
    formio_db_secret_length        = length(random_password.formio_db_secret.result)
    mongodb_admin_password_length  = length(random_password.mongodb_admin_password.result)
    mongodb_formio_password_length = length(random_password.mongodb_formio_password.result)
  }
}