# Networking Module Outputs

output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "app_subnet_id" {
  description = "ID of the application subnet"
  value       = google_compute_subnetwork.app_subnet.id
}

output "vpc_connector_id" {
  description = "ID of the VPC Access Connector"
  value       = google_vpc_access_connector.connector.id
}

output "vpc_connector_name" {
  description = "Name of the VPC Access Connector"  
  value       = google_vpc_access_connector.connector.name
}