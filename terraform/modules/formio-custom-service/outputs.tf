# =============================================================================
# FORM.IO CUSTOM SERVICE - OUTPUTS
# =============================================================================

output "service_url" {
  description = "Form.io Custom Service URL"
  value       = google_cloud_run_service.formio_custom.status[0].url
}

output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_service.formio_custom.name
}

output "backend_service_id" {
  description = "Backend service ID for load balancer integration"
  value       = google_compute_backend_service.formio_custom.id
}

output "backend_service_name" {
  description = "Backend service name"
  value       = google_compute_backend_service.formio_custom.name
}

output "service_account_email" {
  description = "Service account email"
  value       = google_service_account.formio_custom.email
}

output "service_account_id" {
  description = "Service account ID"
  value       = google_service_account.formio_custom.name
}

output "image_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.formio_custom.repository_id
}

output "image_repository_url" {
  description = "Full Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.formio_custom.repository_id}"
}

output "docker_image_path" {
  description = "Full Docker image path for deployment"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/formio-custom/formio"
}

output "docker_image_full" {
  description = "Full Docker image with tag"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/formio-custom/formio:${var.custom_image_tag}"
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "${google_cloud_run_service.formio_custom.status[0].url}/health"
}

output "latest_revision" {
  description = "Latest deployed revision"
  value       = google_cloud_run_service.formio_custom.status[0].latest_ready_revision_name
}

output "container_port" {
  description = "Container port"
  value       = 3001
}

output "network_endpoint_group" {
  description = "Network Endpoint Group ID"
  value       = google_compute_network_endpoint_group.formio_custom.id
}

output "health_check_id" {
  description = "Health check ID"
  value       = google_compute_health_check.formio_custom.id
}

output "cdn_enabled" {
  description = "Whether CDN is enabled"
  value       = google_compute_backend_service.formio_custom.enable_cdn
}

output "dns_record" {
  description = "DNS record (if created)"
  value       = var.create_dns_record ? try(google_dns_record_set.formio_custom[0].name, null) : null
}

# =============================================================================
# CONFIGURATION OUTPUTS
# =============================================================================

output "configuration" {
  description = "Service configuration summary"
  value = {
    # Basic configuration
    version                    = var.custom_image_tag
    environment               = var.environment
    project_id                = var.project_id
    region                    = var.region

    # Enhanced features
    enable_async_gcs_upload   = var.enable_async_gcs_upload
    bullmq_worker_concurrency = var.bullmq_worker_concurrency
    xxhash_enabled            = var.xxhash_enabled
    railway_oriented_uploads  = var.railway_oriented_uploads

    # Service configuration
    portal_enabled            = var.portal_enabled
    debug_enabled             = var.debug_enabled
    tus_enabled               = var.tus_enabled
    tus_max_size              = var.tus_max_size

    # Scaling configuration
    min_instances             = var.min_instance_count
    max_instances             = var.max_instance_count
    container_concurrency     = var.container_concurrency
    memory_limit              = var.memory_limit
    memory_request            = var.memory_request
    cpu_limit                 = var.cpu_limit
    cpu_request               = var.cpu_request

    # CDN configuration
    cdn_enabled               = google_compute_backend_service.formio_custom.enable_cdn
    cache_default_ttl         = var.cache_default_ttl
    cache_max_ttl             = var.cache_max_ttl
    cache_client_ttl          = var.cache_client_ttl

    # Security configuration
    iap_enabled               = var.iap_enabled
    cors_enabled              = var.cors_enabled
    cors_origin               = var.cors_origin

    # Monitoring
    enable_alerting           = var.enable_alerting
    error_rate_threshold      = var.error_rate_threshold
    latency_threshold         = var.latency_threshold
  }
}

# =============================================================================
# DEPLOYMENT COMMANDS OUTPUT
# =============================================================================

output "deployment_commands" {
  description = "Useful deployment commands"
  value = {
    build_and_push = format("docker build -t %s ./formio && docker push %s",
      "${var.region}-docker.pkg.dev/${var.project_id}/formio-custom/formio:${var.custom_image_tag}",
      "${var.region}-docker.pkg.dev/${var.project_id}/formio-custom/formio:${var.custom_image_tag}"
    )

    deploy_image = format("gcloud run services update %s --region=%s --image=%s",
      google_cloud_run_service.formio_custom.name,
      var.region,
      "${var.region}-docker.pkg.dev/${var.project_id}/formio-custom/formio:${var.custom_image_tag}"
    )

    view_logs = format("gcloud logs tail 'resource.type=cloud_run_revision AND resource.labels.service_name=%s'",
      google_cloud_run_service.formio_custom.name
    )

    test_health = "curl -f ${google_cloud_run_service.formio_custom.status[0].url}/health"
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
      backend_service_id = google_compute_backend_service.formio_custom.id
      backend_service_name = google_compute_backend_service.formio_custom.name
      health_check_path = "/health"
      network_endpoint_group = google_compute_network_endpoint_group.formio_custom.id
    }

    # Service account configuration
    service_account = {
      email = google_service_account.formio_custom.email
      name = google_service_account.formio_custom.name
      display_name = google_service_account.formio_custom.display_name
    }

    # Storage configuration
    storage = {
      bucket_name = var.storage_bucket_name
      gcs_project_id = var.gcs_project_id != "" ? var.gcs_project_id : var.project_id
      provider = "s3"
      server = "https://storage.googleapis.com"
    }

    # Database configuration
    database = {
      type = "mongodb"
      database_name = var.mongodb_database_name
      connection_secret = var.mongodb_connection_string_secret_id
    }

    # Redis configuration (for BullMQ)
    redis = {
      host = var.redis_host
      port = var.redis_port
      has_password = var.redis_password_secret_id != null
    }
  }
}

# =============================================================================
# MONITORING OUTPUTS
# =============================================================================

output "monitoring" {
  description = "Monitoring and alerting configuration"
  value = {
    service = {
      id = google_monitoring_service.formio_custom.service_id
      display_name = google_monitoring_service.formio_custom.display_name
      type = "CLOUD_RUN"
    }

    alerts = {
      error_rate = var.enable_alerting ? {
        policy_id = try(google_monitoring_alert_policy.formio_custom_error_rate[0].id, null)
        threshold = var.error_rate_threshold
        enabled = true
      } : null

      latency = var.enable_alerting ? {
        policy_id = try(google_monitoring_alert_policy.formio_custom_latency[0].id, null)
        threshold = var.latency_threshold
        enabled = true
      } : null
    }
  }
}

# =============================================================================
# SECURITY OUTPUTS
# =============================================================================

output "security" {
  description = "Security-related configuration"
  value = {
    secrets = {
      mongodb_connection = var.mongodb_connection_string_secret_id
      jwt_secret = var.formio_jwt_secret_secret_id
      db_secret = var.formio_db_secret_secret_id
      root_password = var.formio_root_password_secret_id
      redis_password = var.redis_password_secret_id
      email_password = var.email_password_secret_id
    }

    permissions = {
      service_account_roles = [
        "roles/secretmanager.secretAccessor",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/cloudtrace.agent",
        "roles/opsconfigviewer",
        "roles/storage.objectViewer"
      ]
    }

    features = {
      railway_oriented_uploads = var.railway_oriented_uploads
      xxhash_integrity = var.xxhash_enabled
      async_processing = var.enable_async_gcs_upload
      iap_protection = var.iap_enabled
    }
  }
}