# MongoDB Module Outputs

output "mongodb_instance_name" {
  description = "Name of the MongoDB Compute Engine instance"
  value       = google_compute_instance.mongodb.name
}

output "mongodb_instance_id" {
  description = "ID of the MongoDB Compute Engine instance"
  value       = google_compute_instance.mongodb.id
}

output "mongodb_private_ip" {
  description = "Private IP address of the MongoDB instance"
  value       = google_compute_instance.mongodb.network_interface[0].network_ip
}

output "mongodb_connection_string" {
  description = "DEPRECATED: Use mongodb_connection_string_secret_id instead"
  value       = "mongodb://${var.formio_username}:${var.formio_password}@${google_compute_instance.mongodb.network_interface[0].network_ip}:27017/${var.database_name}"
  sensitive   = true
}

output "mongodb_connection_string_internal" {
  description = "Internal MongoDB connection string (without credentials for logging)"
  value       = "mongodb://${google_compute_instance.mongodb.network_interface[0].network_ip}:27017/${var.database_name}"
}

output "mongodb_admin_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin password (centrally managed)"
  value       = var.admin_password_secret_id
}

output "mongodb_formio_secret_id" {
  description = "Secret Manager secret ID for MongoDB Form.io user password (centrally managed)"
  value       = var.formio_password_secret_id
}

output "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID for complete MongoDB connection string"
  value       = google_secret_manager_secret.mongodb_connection_string.secret_id
}

# Separate connection strings for dual deployment
output "mongodb_community_connection_string_secret_id" {
  description = "Secret Manager secret ID for Community edition MongoDB connection string"
  value       = google_secret_manager_secret.mongodb_community_connection_string.secret_id
}

output "mongodb_enterprise_connection_string_secret_id" {
  description = "Secret Manager secret ID for Enterprise edition MongoDB connection string"
  value       = google_secret_manager_secret.mongodb_enterprise_connection_string.secret_id
}

output "mongodb_service_account_email" {
  description = "Email of the MongoDB service account"
  value       = google_service_account.mongodb_service_account.email
}

output "mongodb_data_disk_name" {
  description = "Name of the MongoDB data disk (for backup references)"
  value       = google_compute_disk.mongodb_data_disk.name
}

output "mongodb_zone" {
  description = "Zone where MongoDB instance is deployed"
  value       = google_compute_instance.mongodb.zone
}

output "mongodb_health_check_id" {
  description = "ID of the MongoDB health check"
  value       = google_compute_health_check.mongodb.id
}

output "mongodb_backup_policy_name" {
  description = "Name of the backup policy for MongoDB data disk"
  value       = google_compute_resource_policy.mongodb_backup.name
}

# Networking outputs
output "mongodb_firewall_rule_name" {
  description = "Name of the firewall rule allowing access to MongoDB"
  value       = google_compute_firewall.mongodb_internal.name
}

# Configuration outputs for external use
output "mongodb_port" {
  description = "Port number MongoDB is listening on"
  value       = 27017
}

output "mongodb_database_name" {
  description = "Name of the database created for Form.io"
  value       = var.database_name
}

output "mongodb_version" {
  description = "Version of MongoDB installed"
  value       = var.mongodb_version
}