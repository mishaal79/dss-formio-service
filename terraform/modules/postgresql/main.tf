terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Generate random password for PostgreSQL admin user
resource "random_password" "postgres_password" {
  length  = 16
  special = true
}

# Store PostgreSQL password in Secret Manager
resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${var.instance_name}-postgres-password-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = random_password.postgres_password.result
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgresql" {
  name             = "${var.instance_name}-${var.environment}"
  database_version = var.postgres_version
  region           = var.region
  
  settings {
    tier                        = var.tier
    availability_type           = var.availability_type
    disk_type                   = var.disk_type
    disk_size                   = var.disk_size
    disk_autoresize            = var.disk_autoresize
    disk_autoresize_limit      = var.disk_autoresize_limit
    deletion_protection_enabled = var.deletion_protection
    
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery
      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }
    
    ip_configuration {
      ipv4_enabled                                  = var.public_ip_enabled
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = var.require_ssl
      
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.display_name
          value = authorized_networks.value.cidr_block
        }
      }
    }
    
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    
    database_flags {
      name  = "log_min_duration_statement"
      value = "5000"
    }
    
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
    
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }
  }
  
  lifecycle {
    prevent_destroy = true
  }
  
  depends_on = [google_secret_manager_secret_version.postgres_password]
}

# Default PostgreSQL user
resource "google_sql_user" "postgres_user" {
  name     = var.admin_username
  instance = google_sql_database_instance.postgresql.name
  password = random_password.postgres_password.result
}

# Form.io application database
resource "google_sql_database" "formio_db" {
  name     = var.formio_database_name
  instance = google_sql_database_instance.postgresql.name
}

# Form.io application user
resource "random_password" "formio_user_password" {
  length  = 16
  special = true
}

resource "google_secret_manager_secret" "formio_user_password" {
  secret_id = "${var.instance_name}-formio-user-password-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "formio_user_password" {
  secret      = google_secret_manager_secret.formio_user_password.id
  secret_data = random_password.formio_user_password.result
}

resource "google_sql_user" "formio_user" {
  name     = var.formio_username
  instance = google_sql_database_instance.postgresql.name
  password = random_password.formio_user_password.result
}

# Additional databases for event-driven architecture
resource "google_sql_database" "form_submissions_db" {
  name     = "${var.formio_database_name}_submissions"
  instance = google_sql_database_instance.postgresql.name
}

resource "google_sql_database" "form_analytics_db" {
  name     = "${var.formio_database_name}_analytics"
  instance = google_sql_database_instance.postgresql.name
}

resource "google_sql_database" "form_templates_db" {
  name     = "${var.formio_database_name}_templates"
  instance = google_sql_database_instance.postgresql.name
}

# Connection string construction
locals {
  connection_string = "postgresql://${google_sql_user.formio_user.name}:${random_password.formio_user_password.result}@${google_sql_database_instance.postgresql.connection_name}/${google_sql_database.formio_db.name}?sslmode=${var.require_ssl ? "require" : "disable"}"
  
  connection_strings = {
    main         = local.connection_string
    submissions  = "postgresql://${google_sql_user.formio_user.name}:${random_password.formio_user_password.result}@${google_sql_database_instance.postgresql.connection_name}/${google_sql_database.form_submissions_db.name}?sslmode=${var.require_ssl ? "require" : "disable"}"
    analytics    = "postgresql://${google_sql_user.formio_user.name}:${random_password.formio_user_password.result}@${google_sql_database_instance.postgresql.connection_name}/${google_sql_database.form_analytics_db.name}?sslmode=${var.require_ssl ? "require" : "disable"}"
    templates    = "postgresql://${google_sql_user.formio_user.name}:${random_password.formio_user_password.result}@${google_sql_database_instance.postgresql.connection_name}/${google_sql_database.form_templates_db.name}?sslmode=${var.require_ssl ? "require" : "disable"}"
  }
}

# Store connection strings in Secret Manager
resource "google_secret_manager_secret" "postgresql_connection_string" {
  secret_id = "${var.instance_name}-connection-string-${var.environment}"
  
  replication {
    auto {}
  }
  
  labels = var.labels
}

resource "google_secret_manager_secret_version" "postgresql_connection_string" {
  secret      = google_secret_manager_secret.postgresql_connection_string.id
  secret_data = jsonencode(local.connection_strings)
}