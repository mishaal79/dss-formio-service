/**
 * Terraform Module Outputs: Cloud Run Service
 */

output "cloud_run_url" {
  description = "Cloud Run service URL (direct access)"
  value       = google_cloud_run_service.formio_api.status[0].url
}

output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_service.formio_api.name
}

output "load_balancer_ip" {
  description = "External IP address of HTTPS load balancer"
  value       = google_compute_global_address.formio_lb.address
}

output "load_balancer_name" {
  description = "Name of the load balancer"
  value       = google_compute_global_forwarding_rule.formio_https.name
}

output "service_account_email" {
  description = "Service account email for Cloud Run"
  value       = google_service_account.formio_api.email
}

output "backend_service_id" {
  description = "Backend service ID"
  value       = google_compute_backend_service.formio_backend.id
}

output "ssl_certificate_domains" {
  description = "Domains covered by SSL certificate"
  value       = google_compute_managed_ssl_certificate.formio_cert.managed[0].domains
}

output "dns_records" {
  description = "DNS A records to create (point custom domains to load balancer IP)"
  value = {
    for domain in var.custom_domains :
    domain => google_compute_global_address.formio_lb.address
  }
}
