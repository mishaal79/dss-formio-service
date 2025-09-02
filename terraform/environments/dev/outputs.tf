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

# PDF Server Outputs
output "pdf_server_service_url" {
  description = "URL of the deployed Form.io PDF Plus server"
  value       = var.deploy_pdf_server && length(module.pdf-server) > 0 ? module.pdf-server[0].service_url : null
}

output "pdf_server_service_name" {
  description = "Name of the PDF Plus Cloud Run service"
  value       = var.deploy_pdf_server && length(module.pdf-server) > 0 ? module.pdf-server[0].service_name : null
}

output "pdf_server_backend_service_id" {
  description = "Backend service ID for PDF Plus server (for load balancer integration)"
  value       = var.deploy_pdf_server && length(module.pdf-server) > 0 ? module.pdf-server[0].backend_service_id : null
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

# Central infrastructure integration
output "central_infrastructure_details" {
  description = "Details about central infrastructure integration"
  value = {
    using_central_infra = true # Always using central infrastructure  
    cloud_nat_info      = "Using central Cloud NAT from gcp-dss-erlich-infra-terraform"
    nat_ip_info         = "NAT IPs managed by central infrastructure - see gcp-dss-erlich-infra-terraform outputs"
  }
}

output "using_central_infrastructure" {
  description = "Whether central infrastructure is being used"
  value       = true # Always using central infrastructure
}

# Environment Variables for gcloud Updates
output "enterprise_env_vars" {
  description = "Environment variables for Enterprise service gcloud updates"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].env_vars_for_gcloud : ""
}

output "community_env_vars" {
  description = "Environment variables for Community service gcloud updates"
  value       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].env_vars_for_gcloud : ""
}

output "enterprise_env_vars_debug" {
  description = "List of environment variables for Enterprise service (for debugging)"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].env_vars_list : []
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

# =============================================================================
# SERVICE REGISTRATION OUTPUTS FOR CENTRAL INFRASTRUCTURE
# =============================================================================

# Service registration data for consistent naming and configuration
output "service_registrations" {
  description = "Service registration data for both Community and Enterprise editions"
  value = {
    community = var.deploy_community && length(module.formio-community) > 0 ? {
      service_registration    = module.formio-community[0].service_registration
      service_key             = module.formio-community[0].service_key
      consistent_backend_name = module.formio-community[0].consistent_backend_name
    } : null
    enterprise = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? {
      service_registration    = module.formio-enterprise[0].service_registration
      service_key             = module.formio-enterprise[0].service_key
      consistent_backend_name = module.formio-enterprise[0].consistent_backend_name
    } : null
  }
}

# Primary service registration (for single-service deployments)
output "primary_service_registration" {
  description = "Primary service registration data (Enterprise preferred, falls back to Community)"
  value = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? {
    service_registration    = module.formio-enterprise[0].service_registration
    service_key             = module.formio-enterprise[0].service_key
    consistent_backend_name = module.formio-enterprise[0].consistent_backend_name
    } : (var.deploy_community && length(module.formio-community) > 0 ? {
      service_registration    = module.formio-community[0].service_registration
      service_key             = module.formio-community[0].service_key
      consistent_backend_name = module.formio-community[0].consistent_backend_name
  } : null)
}

# =============================================================================
# CENTRALIZED LOAD BALANCER INTEGRATION OUTPUTS
# =============================================================================

# Form.io Service Backend Information for Centralized Load Balancer
output "formio_backend_service_id" {
  description = "Form.io backend service ID for centralized load balancer"
  value       = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_id : (var.deploy_community ? module.formio-community[0].backend_service_id : null)
}

output "formio_backend_service_name" {
  description = "Form.io backend service name for centralized load balancer"
  value       = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_name : (var.deploy_community ? module.formio-community[0].backend_service_name : null)
}

output "formio_backend_service_self_link" {
  description = "Form.io backend service self link for centralized load balancer"
  value       = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_self_link : (var.deploy_community ? module.formio-community[0].backend_service_self_link : null)
}

output "formio_network_endpoint_group_id" {
  description = "Form.io Network Endpoint Group ID for centralized load balancer"
  value       = var.deploy_enterprise ? module.formio-enterprise[0].network_endpoint_group_id : (var.deploy_community ? module.formio-community[0].network_endpoint_group_id : null)
}

output "formio_network_endpoint_group_name" {
  description = "Form.io Network Endpoint Group name for centralized load balancer"
  value       = var.deploy_enterprise ? module.formio-enterprise[0].network_endpoint_group_name : (var.deploy_community ? module.formio-community[0].network_endpoint_group_name : null)
}

# Centralized load balancer integration summary
output "centralized_load_balancer_integration" {
  description = "Summary of backend services and NEGs for centralized load balancer integration"
  value = {
    backend_service_id   = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_id : (var.deploy_community ? module.formio-community[0].backend_service_id : null)
    backend_service_name = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_name : (var.deploy_community ? module.formio-community[0].backend_service_name : null)
    neg_id               = var.deploy_enterprise ? module.formio-enterprise[0].network_endpoint_group_id : (var.deploy_community ? module.formio-community[0].network_endpoint_group_id : null)
    neg_name             = var.deploy_enterprise ? module.formio-enterprise[0].network_endpoint_group_name : (var.deploy_community ? module.formio-community[0].network_endpoint_group_name : null)
    edition              = var.deploy_enterprise ? "enterprise" : (var.deploy_community ? "community" : "none")
    ready_for_lb         = var.deploy_enterprise || var.deploy_community
  }
}

# =============================================================================
# BACKEND SERVICE CONFIGURATION FOR CENTRAL INFRASTRUCTURE
# =============================================================================

output "backend_service_configuration" {
  description = "Configuration to add to central infrastructure tfvars"
  value = {
    instructions = "Add the following to gcp-dss-erlich-infra-terraform/environments/${var.environment}/terraform.tfvars:"
    lb_host_rules = {
      "forms.${var.environment}.cloud.dsselectrical.com.au" = {
        backend_service_id = var.deploy_enterprise ? module.formio-enterprise[0].backend_service_id : (var.deploy_community ? module.formio-community[0].backend_service_id : null)
      }
    }
    note = "After updating tfvars, run 'terraform apply' in the central infrastructure project to activate routing"
  }
}

# =============================================================================
# MAKEFILE CONFIGURATION OUTPUTS
# =============================================================================
# These outputs provide all configuration needed by the Makefile,
# establishing Terraform as the single source of truth

# Service Names (fully qualified)
output "enterprise_service_name_full" {
  description = "Full name of the Enterprise Cloud Run service"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].service_name : ""
}

output "community_service_name_full" {
  description = "Full name of the Community Cloud Run service"
  value       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].service_name : ""
}

# Docker Images (configured versions)
output "enterprise_image_configured" {
  description = "Configured Docker image for Enterprise edition"
  value       = var.deploy_enterprise ? "formio/formio-enterprise:${var.formio_version}" : ""
}

output "community_image_configured" {
  description = "Configured Docker image for Community edition"
  value       = var.deploy_community ? "formio/formio:${var.community_version}" : ""
}

# Docker Images (currently deployed)
output "enterprise_image_deployed" {
  description = "Currently deployed Docker image for Enterprise edition"
  value       = var.deploy_enterprise && length(module.formio-enterprise) > 0 ? module.formio-enterprise[0].docker_image : ""
}

output "community_image_deployed" {
  description = "Currently deployed Docker image for Community edition"
  value       = var.deploy_community && length(module.formio-community) > 0 ? module.formio-community[0].docker_image : ""
}

# Database Names
output "enterprise_database_name" {
  description = "MongoDB database name for Enterprise edition"
  value       = local.mongodb_enterprise_db_name
}

output "community_database_name" {
  description = "MongoDB database name for Community edition"
  value       = local.mongodb_community_db_name
}

# Deployment Status
output "deployment_status" {
  description = "Current deployment status for Makefile consumption"
  value = {
    enterprise_enabled = var.deploy_enterprise
    community_enabled  = var.deploy_community
    environment        = var.environment
    project_id         = var.project_id
    region             = var.region
  }
}