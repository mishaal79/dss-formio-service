# Staging Environment Outputs
# Form.io Enterprise Service

output "formio_service_url" {
  description = "URL of the deployed Form.io service"
  value       = module.formio_service.formio_service_url
}

output "formio_service_name" {
  description = "Name of the Cloud Run service"
  value       = module.formio_service.formio_service_name
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

output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = module.formio_service.service_account_email
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