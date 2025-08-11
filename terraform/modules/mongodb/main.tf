# MongoDB Self-Hosted Module
# Deploys MongoDB Community Edition on Compute Engine
# Cost-effective alternative to MongoDB Atlas

locals {
  mongodb_instance_name = "${var.project_id}-mongodb-${var.environment}"

  # Standard labels
  common_labels = merge(var.labels, {
    service   = "mongodb"
    component = "database"
    tier      = var.environment
  })
}

# Service account for MongoDB instance
resource "google_service_account" "mongodb_service_account" {
  account_id   = "${var.service_name}-mongodb-sa-${var.environment}"
  display_name = "MongoDB Service Account"
  description  = "Service account for MongoDB Compute Engine instance"
  project      = var.project_id
}

# IAM bindings for service account
resource "google_project_iam_member" "mongodb_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

resource "google_project_iam_member" "mongodb_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

# Allow service account to access secrets
# IAM bindings for specific secrets (least privilege approach)
resource "google_secret_manager_secret_iam_member" "admin_password_access" {
  project   = var.project_id
  secret_id = var.admin_password_secret_id != null ? var.admin_password_secret_id : "placeholder-admin-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "formio_password_access" {
  project   = var.project_id
  secret_id = var.formio_password_secret_id != null ? var.formio_password_secret_id : "placeholder-formio-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

# Boot disk for MongoDB instance
resource "google_compute_disk" "mongodb_boot_disk" {
  name  = "${local.mongodb_instance_name}-boot"
  type  = "pd-standard"
  zone  = var.zone
  image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
  size  = var.boot_disk_size

  labels = local.common_labels
}

# Data disk for MongoDB storage (persistent)
resource "google_compute_disk" "mongodb_data_disk" {
  name = "${local.mongodb_instance_name}-data"
  type = "pd-ssd"
  zone = var.zone
  size = var.data_disk_size

  labels = local.common_labels

  # Temporarily disabled for regional migration
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# MongoDB startup script
locals {
  startup_script = templatefile("${path.module}/scripts/mongodb-install.sh", {
    mongodb_version        = var.mongodb_version
    admin_username         = var.admin_username
    formio_username        = var.formio_username
    database_name          = var.database_name
    admin_password_secret  = var.admin_password_secret_id != null ? var.admin_password_secret_id : "placeholder-admin-password"
    formio_password_secret = var.formio_password_secret_id != null ? var.formio_password_secret_id : "placeholder-formio-password"
    project_id             = var.project_id
  })
}

# Compute Engine instance for MongoDB
resource "google_compute_instance" "mongodb" {
  name         = local.mongodb_instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["mongodb-server", "internal-database"]

  boot_disk {
    source      = google_compute_disk.mongodb_boot_disk.name
    auto_delete = false
  }

  # Attach data disk
  attached_disk {
    source      = google_compute_disk.mongodb_data_disk.name
    device_name = "mongodb-data"
  }

  network_interface {
    network    = var.vpc_network_id
    subnetwork = var.subnet_id
    # No external IP - private only
  }

  service_account {
    email  = google_service_account.mongodb_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = local.startup_script
    user-data      = local.startup_script
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [metadata["startup-script"]]
  }

  depends_on = [
    google_compute_disk.mongodb_boot_disk,
    google_compute_disk.mongodb_data_disk
  ]
}

# =============================================================================
# SECRET MANAGER INTEGRATION
# MongoDB passwords are now managed centrally in the root module's secrets.tf
# This module only creates connection string secrets for Form.io services
# =============================================================================

# Data source to retrieve Form.io password from centrally managed Secret Manager
data "google_secret_manager_secret_version" "formio_password" {
  count   = var.formio_password_secret_id != null ? 1 : 0
  secret  = var.formio_password_secret_id
  project = var.project_id
}

# Secret for complete MongoDB connection string (for Form.io)
resource "google_secret_manager_secret" "mongodb_connection_string" {
  secret_id = "${var.service_name}-mongodb-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_connection_string" {
  secret      = google_secret_manager_secret.mongodb_connection_string.id
  secret_data = var.formio_password_secret_id != null ? "mongodb://${urlencode(var.formio_username)}:${urlencode(data.google_secret_manager_secret_version.formio_password[0].secret_data)}@${google_compute_instance.mongodb.network_interface[0].network_ip}:27017/${var.database_name}?authSource=${var.database_name}&replicaSet=rs0" : "mongodb://placeholder:placeholder@localhost:27017/placeholder"
}

# Separate connection strings for Community and Enterprise editions
resource "google_secret_manager_secret" "mongodb_community_connection_string" {
  secret_id = "${var.service_name}-mongodb-community-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_community_connection_string" {
  secret      = google_secret_manager_secret.mongodb_community_connection_string.id
  secret_data = var.formio_password_secret_id != null ? "mongodb://${urlencode(var.formio_username)}:${urlencode(data.google_secret_manager_secret_version.formio_password[0].secret_data)}@${google_compute_instance.mongodb.network_interface[0].network_ip}:27017/${var.database_name}_community?authSource=${var.database_name}_community&replicaSet=rs0" : "mongodb://placeholder:placeholder@localhost:27017/placeholder_community?replicaSet=rs0"
}

resource "google_secret_manager_secret" "mongodb_enterprise_connection_string" {
  secret_id = "${var.service_name}-mongodb-enterprise-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_enterprise_connection_string" {
  secret      = google_secret_manager_secret.mongodb_enterprise_connection_string.id
  secret_data = var.formio_password_secret_id != null ? "mongodb://${urlencode(var.formio_username)}:${urlencode(data.google_secret_manager_secret_version.formio_password[0].secret_data)}@${google_compute_instance.mongodb.network_interface[0].network_ip}:27017/${var.database_name}_enterprise?authSource=${var.database_name}_enterprise&replicaSet=rs0" : "mongodb://placeholder:placeholder@localhost:27017/placeholder_enterprise?replicaSet=rs0"
}

# Firewall rule for MongoDB access from Form.io Cloud Run (via VPC Connector)
resource "google_compute_firewall" "mongodb_internal" {
  name    = "${local.mongodb_instance_name}-internal-access"
  network = var.vpc_network_id
  project = var.project_id

  description = "Allow internal access to MongoDB from Form.io Cloud Run services"

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  # Allow from VPC connector subnet (Cloud Run services)
  source_ranges = var.allowed_source_ranges
  target_tags   = ["mongodb-server"]

  priority = 1000
}

# Health check for MongoDB
resource "google_compute_health_check" "mongodb" {
  name               = "${local.mongodb_instance_name}-health-check"
  check_interval_sec = 30
  timeout_sec        = 10
  project            = var.project_id

  tcp_health_check {
    port = "27017"
  }
}

# Scheduled snapshots for data backup
resource "google_compute_resource_policy" "mongodb_backup" {
  name    = "${local.mongodb_instance_name}-backup-policy"
  region  = var.region
  project = var.project_id

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "02:00"
      }
    }
    retention_policy {
      max_retention_days    = var.backup_retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
    snapshot_properties {
      labels            = local.common_labels
      storage_locations = [var.region]
      guest_flush       = false
    }
  }
}

# Attach backup policy to data disk
resource "google_compute_disk_resource_policy_attachment" "mongodb_backup" {
  name = google_compute_resource_policy.mongodb_backup.name
  disk = google_compute_disk.mongodb_data_disk.name
  zone = var.zone
}