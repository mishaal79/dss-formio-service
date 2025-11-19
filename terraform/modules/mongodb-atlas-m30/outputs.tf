# MongoDB Atlas Module Outputs

# =============================================================================
# CLUSTER INFORMATION
# =============================================================================

output "cluster_id" {
  description = "The MongoDB Atlas cluster ID"
  value       = mongodbatlas_cluster.main.id
}

output "cluster_name" {
  description = "The MongoDB Atlas cluster name"
  value       = mongodbatlas_cluster.main.name
}

output "cluster_state" {
  description = "Current state of the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.state_name
}

output "cluster_mongo_db_version" {
  description = "MongoDB version running on the cluster"
  value       = mongodbatlas_cluster.main.mongo_db_version
}

# =============================================================================
# PROJECT INFORMATION
# =============================================================================

output "atlas_project_id" {
  description = "The MongoDB Atlas project ID"
  value       = mongodbatlas_project.main.id
}

output "atlas_project_name" {
  description = "The MongoDB Atlas project name"
  value       = mongodbatlas_project.main.name
}

# =============================================================================
# CONNECTION STRINGS (Public)
# =============================================================================

output "connection_strings_standard" {
  description = "Standard MongoDB connection string"
  value       = mongodbatlas_cluster.main.connection_strings[0].standard
  sensitive   = true
}

output "connection_strings_standard_srv" {
  description = "Standard SRV MongoDB connection string"
  value       = mongodbatlas_cluster.main.connection_strings[0].standard_srv
  sensitive   = true
}

# =============================================================================
# SECRET MANAGER SECRET IDS (for Form.io services)
# =============================================================================

output "mongodb_connection_string_secret_id" {
  description = "Secret Manager secret ID for legacy MongoDB connection string"
  value       = google_secret_manager_secret.mongodb_connection_string.secret_id
}

output "mongodb_community_connection_string_secret_id" {
  description = "Secret Manager secret ID for MongoDB community connection string"
  value       = google_secret_manager_secret.mongodb_community_connection_string.secret_id
}

output "mongodb_enterprise_connection_string_secret_id" {
  description = "Secret Manager secret ID for MongoDB enterprise connection string"
  value       = google_secret_manager_secret.mongodb_enterprise_connection_string.secret_id
}

output "mongodb_admin_connection_string_secret_id" {
  description = "Secret Manager secret ID for MongoDB admin connection string"
  value       = google_secret_manager_secret.mongodb_admin_connection_string.secret_id
}

output "mongodb_monitoring_connection_string_secret_id" {
  description = "Secret Manager secret ID for MongoDB monitoring connection string"
  value       = google_secret_manager_secret.mongodb_monitoring_connection_string.secret_id
}

# =============================================================================
# DATABASE USER INFORMATION
# =============================================================================

output "admin_username" {
  description = "MongoDB Atlas admin username"
  value       = mongodbatlas_database_user.admin.username
}

output "formio_community_username" {
  description = "MongoDB Atlas Form.io community username"
  value       = mongodbatlas_database_user.formio_community.username
}

output "formio_enterprise_username" {
  description = "MongoDB Atlas Form.io enterprise username"
  value       = mongodbatlas_database_user.formio_enterprise.username
}

output "formio_monitoring_username" {
  description = "MongoDB Atlas Form.io monitoring username"
  value       = mongodbatlas_database_user.monitoring.username
}

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

output "backing_provider_name" {
  description = "Cloud provider for the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.provider_name
}

output "region_name" {
  description = "Region where the MongoDB Atlas cluster is deployed"
  value       = mongodbatlas_cluster.main.provider_region_name
}

output "cluster_tier" {
  description = "MongoDB Atlas cluster tier (M30, M40, etc.)"
  value       = mongodbatlas_cluster.main.provider_instance_size_name
}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

output "backup_enabled" {
  description = "Whether cloud backup is enabled for the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.cloud_backup
}

output "pit_enabled" {
  description = "Whether Point-In-Time recovery is enabled for the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.pit_enabled
}