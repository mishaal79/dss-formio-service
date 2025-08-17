# MongoDB Atlas Module Outputs

# =============================================================================
# CLUSTER INFORMATION
# =============================================================================

output "cluster_id" {
  description = "The MongoDB Atlas cluster ID"
  value       = mongodbatlas_flex_cluster.main.id
}

output "cluster_name" {
  description = "The MongoDB Atlas cluster name"
  value       = mongodbatlas_flex_cluster.main.name
}

output "cluster_state" {
  description = "Current state of the MongoDB Atlas cluster"
  value       = mongodbatlas_flex_cluster.main.state_name
}

output "cluster_mongo_db_version" {
  description = "MongoDB version running on the cluster"
  value       = mongodbatlas_flex_cluster.main.mongo_db_version
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
  value       = mongodbatlas_flex_cluster.main.connection_strings.standard
  sensitive   = true
}

output "connection_strings_standard_srv" {
  description = "Standard SRV MongoDB connection string"
  value       = mongodbatlas_flex_cluster.main.connection_strings.standard_srv
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

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

output "backing_provider_name" {
  description = "Cloud provider for the MongoDB Atlas cluster"
  value       = mongodbatlas_flex_cluster.main.provider_settings.backing_provider_name
}

output "region_name" {
  description = "Region where the MongoDB Atlas cluster is deployed"
  value       = mongodbatlas_flex_cluster.main.provider_settings.region_name
}

output "disk_size_gb" {
  description = "Disk size of the MongoDB Atlas cluster in GB"
  value       = mongodbatlas_flex_cluster.main.provider_settings.disk_size_gb
}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

output "backup_enabled" {
  description = "Whether backup is enabled for the MongoDB Atlas cluster"
  value       = mongodbatlas_flex_cluster.main.backup_settings.enabled
}