# Development Environment Outputs
# Form.io Services (Community and Enterprise)

output "formio_community_service_url" {
  description = "URL of the deployed Form.io Community service"
  value       = module.formio_service.formio_community_service_url
}

output "formio_enterprise_service_url" {
  description = "URL of the deployed Form.io Enterprise service"
  value       = module.formio_service.formio_enterprise_service_url
}

output "deployed_services" {
  description = "Summary of deployed Form.io services"
  value       = module.formio_service.deployed_services
}

output "mongodb_connection_string" {
  description = "MongoDB connection string (sensitive)"
  value       = module.formio_service.mongodb_connection_string
  sensitive   = true
}

output "storage_bucket_name" {
  description = "Name of the GCS bucket for file storage"
  value       = module.formio_service.storage_bucket_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}