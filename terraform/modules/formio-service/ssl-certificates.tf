# =============================================================================
# SSL CERTIFICATE MANAGEMENT FOR CUSTOM DOMAINS
# =============================================================================
#
# Automated SSL certificate provisioning and management for Form.io whitelabeling
# Supports multiple custom domains with automatic renewal
#

# Google-managed SSL certificates for custom domains
resource "google_compute_managed_ssl_certificate" "formio_ssl_cert" {
  count   = length(var.custom_domains)
  project = var.project_id
  name    = "${var.service_name}-ssl-${count.index}-${var.environment}"

  managed {
    domains = [var.custom_domains[count.index]]
  }

  # Certificate lifecycle management
  lifecycle {
    create_before_destroy = true
  }

}

# Domain mapping for Cloud Run service
resource "google_cloud_run_domain_mapping" "formio_domain_mapping" {
  count    = length(var.custom_domains)
  project  = var.project_id
  location = var.region
  name     = var.custom_domains[count.index]

  metadata {
    namespace = var.project_id
    labels    = local.service_labels
  }

  spec {
    route_name = google_cloud_run_v2_service.formio_service.name
  }

  depends_on = [google_cloud_run_v2_service.formio_service]
}

# Outputs moved to outputs.tf for proper Terraform module structure

# =============================================================================
# IMPLEMENTATION NOTES:
# =============================================================================
#
# 1. SSL certificates are automatically provisioned by Google
# 2. DNS records must be manually configured to point to Cloud Run
# 3. Certificate validation requires proper DNS configuration
# 4. Certificates auto-renew before expiration
#
# DNS Configuration Required:
# - CNAME record: custom.domain.com -> ghs.googlehosted.com
# - Or A record: custom.domain.com -> Cloud Run IP (check console)
#
# =============================================================================