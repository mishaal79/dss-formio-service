# Unit Test for PostgreSQL Module
# Tests the postgresql module in isolation

run "postgresql_module_validation" {
  command = plan
  
  module {
    source = "../../terraform/modules/postgresql"
  }
  
  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "true" }
    
    # PostgreSQL configuration
    postgres_version     = "15"
    postgres_tier        = "db-f1-micro"
    database_name        = "formio_test"
    postgres_user        = "formio_user"
    postgres_password    = "test-password"
    
    # Networking
    vpc_id               = "test-vpc"
    authorized_networks  = []
    enable_backup        = true
    backup_start_time    = "03:00"
    maintenance_window   = {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }
  
  # Assertions for PostgreSQL instance
  assert {
    condition     = google_sql_database_instance.postgresql.database_version == "POSTGRES_15"
    error_message = "PostgreSQL version should be set correctly"
  }
  
  assert {
    condition     = google_sql_database_instance.postgresql.region == "us-central1"
    error_message = "PostgreSQL instance should be in the correct region"
  }
  
  assert {
    condition     = google_sql_database_instance.postgresql.settings[0].tier == "db-f1-micro"
    error_message = "PostgreSQL instance should use the specified tier"
  }
  
  # Test backup configuration
  assert {
    condition     = google_sql_database_instance.postgresql.settings[0].backup_configuration[0].enabled == true
    error_message = "Backup should be enabled"
  }
  
  assert {
    condition     = google_sql_database_instance.postgresql.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Public IP should be disabled for security"
  }
}

run "postgresql_security_configuration" {
  command = plan
  
  module {
    source = "../../terraform/modules/postgresql"
  }
  
  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "prod"
    labels      = { environment = "prod", security = "required" }
    
    postgres_version     = "15"
    postgres_tier        = "db-n1-standard-1"
    database_name        = "formio_prod"
    postgres_user        = "formio_user"
    postgres_password    = "very-secure-password"
    
    vpc_id               = "prod-vpc"
    authorized_networks  = []
    enable_backup        = true
    backup_start_time    = "03:00"
    maintenance_window   = {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }
  
  # Security assertions
  assert {
    condition     = google_sql_database_instance.postgresql.settings[0].ip_configuration[0].require_ssl == true
    error_message = "SSL should be required for production databases"
  }
  
  assert {
    condition     = google_sql_database_instance.postgresql.deletion_protection == true
    error_message = "Deletion protection should be enabled for production"
  }
  
  assert {
    condition     = length(google_sql_database_instance.postgresql.settings[0].database_flags) > 0
    error_message = "Security database flags should be configured"
  }
}