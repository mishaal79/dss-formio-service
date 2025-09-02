# =============================================================================
# PDF SERVER MODULE OUTPUTS
# =============================================================================

output "service_name" {
  description = "The name of the PDF server Cloud Run service"
  value       = google_cloud_run_v2_service.pdf_service.name
}

output "service_url" {
  description = "The URL of the PDF server Cloud Run service"
  value       = google_cloud_run_v2_service.pdf_service.uri
}

output "service_id" {
  description = "The ID of the PDF server Cloud Run service"
  value       = google_cloud_run_v2_service.pdf_service.id
}

output "service_account_email" {
  description = "The email of the PDF server service account"
  value       = google_service_account.pdf_service_account.email
}

output "backend_service_id" {
  description = "The ID of the backend service for load balancer integration"
  value       = google_compute_backend_service.pdf_backend.id
}

output "backend_service_name" {
  description = "The name of the backend service"
  value       = google_compute_backend_service.pdf_backend.name
}

output "neg_id" {
  description = "The ID of the network endpoint group"
  value       = google_compute_region_network_endpoint_group.pdf_neg.id
}

output "neg_name" {
  description = "The name of the network endpoint group"
  value       = google_compute_region_network_endpoint_group.pdf_neg.name
}