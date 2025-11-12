output "service_url" {
  description = "URL of the deployed Form.io Custom service"
  value       = module.formio_custom_service.service_url
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = module.formio_custom_service.service_name
}

output "backend_service_id" {
  description = "Backend service ID for load balancer integration"
  value       = module.formio_custom_service.backend_service_id
}

output "service_account_email" {
  description = "Service account email"
  value       = module.formio_custom_service.service_account_email
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = module.formio_custom_service.health_check_url
}

output "configuration" {
  description = "Service configuration summary"
  value       = module.formio_custom_service.configuration
}

output "deployment_commands" {
  description = "Useful deployment commands"
  value       = module.formio_custom_service.deployment_commands
}
