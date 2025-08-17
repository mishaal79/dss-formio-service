# Load Balancer Module Outputs
# Expose key resources for DNS configuration and monitoring

# Static IP Address
output "load_balancer_ip" {
  description = "Static IP address of the load balancer"
  value       = google_compute_global_address.formio_lb_ip.address
}

output "load_balancer_ip_name" {
  description = "Name of the static IP address resource"
  value       = google_compute_global_address.formio_lb_ip.name
}

# SSL Certificate
output "ssl_certificate_id" {
  description = "ID of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.formio_ssl_cert.id
}

output "ssl_certificate_name" {
  description = "Name of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.formio_ssl_cert.name
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate"
  value       = google_compute_managed_ssl_certificate.formio_ssl_cert.managed[0].domains
}

# Security Policy
output "security_policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = google_compute_security_policy.formio_security_policy.id
}

output "security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = google_compute_security_policy.formio_security_policy.name
}

# Backend Service
output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.formio_backend.id
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.formio_backend.name
}

# Network Endpoint Group
output "network_endpoint_group_id" {
  description = "ID of the network endpoint group"
  value       = google_compute_region_network_endpoint_group.formio_neg.id
}

# URL Map
output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.formio_url_map.id
}

# Forwarding Rules
output "https_forwarding_rule_id" {
  description = "ID of the HTTPS forwarding rule"
  value       = google_compute_global_forwarding_rule.formio_https_forwarding_rule.id
}

output "http_forwarding_rule_id" {
  description = "ID of the HTTP forwarding rule (redirects to HTTPS)"
  value       = google_compute_global_forwarding_rule.formio_http_forwarding_rule.id
}

# Health Check
output "health_check_id" {
  description = "ID of the health check"
  value       = google_compute_health_check.formio_health_check.id
}

# DNS Configuration Helper
output "dns_records" {
  description = "DNS A record configuration for the domains"
  value = {
    ip_address  = google_compute_global_address.formio_lb_ip.address
    domains     = var.ssl_domains
    record_type = "A"
    ttl         = 300
  }
}

# Security Configuration Summary
output "security_features" {
  description = "Summary of enabled security features"
  value = {
    ddos_protection        = true
    bot_detection          = true
    rate_limiting          = true
    geo_blocking           = var.enable_geo_blocking
    ssl_termination        = true
    http_to_https_redirect = true
    cloud_armor_policy     = google_compute_security_policy.formio_security_policy.name
  }
}