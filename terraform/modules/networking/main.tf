# Networking Module for Form.io Service
# This module is only used when shared infrastructure is not available

# Create VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-formio-vpc-${var.environment}"
  project                 = var.project_id
  auto_create_subnetworks = false
  description             = "VPC for Form.io service in ${var.environment} environment"
}

# Create subnet for Cloud Run services
resource "google_compute_subnetwork" "app_subnet" {
  name          = "${var.project_id}-formio-app-subnet-${var.environment}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.1.0.0/24"
  description   = "Subnet for Form.io Cloud Run services"
}

# Create VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name    = "formio-connector-${var.environment}"
  project = var.project_id
  region  = var.region
  
  subnet {
    name       = google_compute_subnetwork.connector_subnet.name
    project_id = var.project_id
  }
  
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

# Dedicated subnet for VPC Access Connector
resource "google_compute_subnetwork" "connector_subnet" {
  name          = "${var.project_id}-formio-connector-subnet-${var.environment}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.2.0.0/28"
  description   = "Subnet for VPC Access Connector"
}