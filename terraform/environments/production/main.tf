/**
 * Terraform Configuration: Production Environment
 *
 * Usage:
 *   terraform init
 *   terraform plan -var-file="production.tfvars"
 *   terraform apply -var-file="production.tfvars"
 */

terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "qrius-terraform-state-prod"
    prefix = "formio/production"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Cloud Run module for Form.io backend API
module "formio_api" {
  source = "../../modules/cloudrun"

  project_id      = var.project_id
  environment     = "production"
  region          = var.region
  container_image = var.container_image

  # CORS configuration
  allowed_origins = var.allowed_origins
  custom_domains  = var.custom_domains

  # Secrets (from Secret Manager or tfvars)
  jwt_secret    = var.jwt_secret
  db_secret     = var.db_secret
  mongo_url     = var.mongo_url
  mongo_db_name = var.mongo_db_name
  redis_host    = var.redis_host

  # Auto-scaling
  min_instances = 2  # Production: always keep 2 instances warm
  max_instances = 20 # Production: scale up to 20 instances

  # CDN enabled for production
  enable_cdn = true

  tags = {
    environment = "production"
    managed_by  = "terraform"
    project     = "qrius-forms"
  }
}

# Outputs for DNS configuration
output "dns_records" {
  description = "DNS A records to create in your DNS provider"
  value       = module.formio_api.dns_records
}

output "load_balancer_ip" {
  description = "HTTPS load balancer IP address"
  value       = module.formio_api.load_balancer_ip
}

output "cloud_run_url" {
  description = "Cloud Run service URL (for debugging)"
  value       = module.formio_api.cloud_run_url
  sensitive   = true
}
