# Development Environment Outputs
# Form.io Enterprise Service - Development Deployment

# Community Edition Service Outputs
output "formio_community_service_url" {
  description = "URL of the deployed Form.io Community service"
  value       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].service_url : null
}

output "formio_community_service_name" {
  description = "Name of the Community Cloud Run service"
  value       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].service_name : null
}

output "formio_community_admin_url" {
  description = "Form.io Community admin portal URL"
  value       = var.deploy_community && var.portal_enabled && length(module.formio-community) > 0 ? "${module.formio-community[0].service_url}/admin" : null
}

# Enterprise Edition Service Outputs
output "formio_enterprise_service_url" {
  description = "URL of the deployed Form.io Enterprise service"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].service_url : null
}

output "formio_enterprise_service_name" {
  description = "Name of the Enterprise Cloud Run service"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].service_name : null
}

output "formio_enterprise_admin_url" {
  description = "Form.io Enterprise admin portal URL"
  value       = var.deploy_enterprise && var.portal_enabled && length(module.formio-enterprise) > 0 ? "${module.formio-enterprise[0].service_url}/admin" : null
}

# MongoDB Atlas Outputs
output "mongodb_atlas_cluster_id" {
  description = "MongoDB Atlas cluster ID"
  value       = module.mongodb_atlas.cluster_id
}

output "mongodb_atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
  value       = module.mongodb_atlas.cluster_name
}

output "mongodb_atlas_cluster_state" {
  description = "MongoDB Atlas cluster state"
  value       = module.mongodb_atlas.cluster_state
}

output "mongodb_atlas_project_id" {
  description = "MongoDB Atlas project ID"
  value       = module.mongodb_atlas.atlas_project_id
}

output "mongodb_connection_strings_srv" {
  description = "MongoDB Atlas connection string (SRV format)"
  value       = module.mongodb_atlas.connection_strings_standard_srv
  sensitive   = true
}

output "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  value       = module.storage.bucket_name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Legacy Compatibility Outputs (deprecated)
output "formio_service_url" {
  description = "DEPRECATED: Use formio_enterprise_service_url or formio_community_service_url"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].service_url : (var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].service_url : null)
}

output "formio_admin_url" {
  description = "DEPRECATED: Use formio_enterprise_admin_url or formio_community_admin_url"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? "${module.formio-enterprise[0].service_url}/admin" : (var.deploy_community && length(module.formio-community) > 0 ? "${module.formio-community[0].service_url}/admin" : null)
}

# Deployment Summary
output "deployed_services" {
  description = "Summary of deployed Form.io services"
  value = {
    community_deployed  = var.deploy_community
    enterprise_deployed = var.deploy_enterprise
    community_url       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].service_url : null
    enterprise_url      = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].service_url : null
  }
}

# Shared infrastructure integration
output "shared_infrastructure_details" {
  description = "Details about shared infrastructure integration"
  value = {
    using_shared_infra = true # Always using shared infrastructure
    cloud_nat_info     = "Using shared Cloud NAT from gcp-dss-erlich-infra-terraform"
    nat_ip_address     = google_compute_address.formio_nat_ip.address
  }
}

output "using_shared_infrastructure" {
  description = "Whether shared infrastructure is being used"
  value       = true # Always using shared infrastructure
}

# Secret Manager Outputs
output "secret_manager_secrets" {
  description = "Secret Manager secret IDs for use by other modules"
  value = {
    formio_root_password_secret_id    = module.secrets.formio_root_password_secret_id
    formio_jwt_secret_secret_id       = module.secrets.formio_jwt_secret_secret_id
    formio_db_secret_secret_id        = module.secrets.formio_db_secret_secret_id
    mongodb_admin_password_secret_id  = module.secrets.mongodb_admin_password_secret_id
    mongodb_formio_password_secret_id = module.secrets.mongodb_formio_password_secret_id
  }
}

# Secret validation outputs (lengths only, for security verification)
output "secret_validation" {
  description = "Secret validation info (lengths only, for security verification)"
  value       = module.secrets.secret_validation
  sensitive   = true
}