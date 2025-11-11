# =============================================================================
# FORM WEB BFF MODULE - OUTPUTS
# =============================================================================

output "service_url" {
  description = "Form Web BFF service URL"
  value       = google_cloud_run_v2_service.form_web_bff.uri
}

output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.form_web_bff.name
}

output "backend_service_id" {
  description = "Backend service ID for load balancer integration"
  value       = google_compute_backend_service.form_web_bff.id
}

output "backend_service_name" {
  description = "Backend service name"
  value       = google_compute_backend_service.form_web_bff.name
}

output "backend_service_self_link" {
  description = "Backend service self link"
  value       = google_compute_backend_service.form_web_bff.self_link
}

output "service_account_email" {
  description = "Service account email"
  value       = google_service_account.form_web_bff.email
}

output "service_account_id" {
  description = "Service account ID"
  value       = google_service_account.form_web_bff.name
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "${google_cloud_run_v2_service.form_web_bff.uri}/health/ready"
}

output "latest_revision" {
  description = "Latest deployed revision"
  value       = google_cloud_run_v2_service.form_web_bff.latest_ready_revision
}

output "container_port" {
  description = "Container port"
  value       = var.container_port
}

output "network_endpoint_group_id" {
  description = "Network Endpoint Group ID"
  value       = google_compute_region_network_endpoint_group.form_web_bff.id
}

output "network_endpoint_group_name" {
  description = "Network Endpoint Group name"
  value       = google_compute_region_network_endpoint_group.form_web_bff.name
}

output "health_check_id" {
  description = "Health check ID"
  value       = google_compute_health_check.form_web_bff.id
}

# =============================================================================
# CONFIGURATION OUTPUTS
# =============================================================================

output "configuration" {
  description = "Service configuration summary"
  value = {
    # Basic configuration
    environment = var.environment
    project_id  = var.project_id
    region      = var.region

    # Port configuration
    container_port = var.container_port

    # Service configuration
    node_env  = var.node_env
    log_level = var.log_level

    # Scaling configuration
    min_instances         = var.min_instance_count
    max_instances         = var.max_instance_count
    container_concurrency = var.container_concurrency
    memory_limit          = var.memory_limit
    cpu_limit             = var.cpu_limit

    # Networking
    vpc_egress_setting = var.vpc_egress_setting

    # Backend integration
    formio_custom_service_url = var.formio_custom_service_url
  }
}

# =============================================================================
# INTEGRATION OUTPUTS
# =============================================================================

output "integration" {
  description = "Configuration for external integrations"
  value = {
    # Load balancer configuration
    load_balancer = {
      backend_service_id     = google_compute_backend_service.form_web_bff.id
      backend_service_name   = google_compute_backend_service.form_web_bff.name
      health_check_path      = "/health/ready"
      network_endpoint_group = google_compute_region_network_endpoint_group.form_web_bff.id
    }

    # Service account configuration
    service_account = {
      email        = google_service_account.form_web_bff.email
      name         = google_service_account.form_web_bff.name
      display_name = google_service_account.form_web_bff.display_name
    }

    # Backend service configuration
    backend = {
      service_name = var.formio_custom_service_name
      service_url  = var.formio_custom_service_url
    }
  }
}
