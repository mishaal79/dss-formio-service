# Unit Test for Cloud Run Module
# Tests the cloud-run module in isolation

run "cloud_run_module_validation" {
  command = plan
  
  module {
    source = "../../terraform/modules/cloud-run"
  }
  
  variables {
    project_id              = "test-project-id"
    region                  = "us-central1"
    environment             = "test"
    labels                  = { test = "true" }
    
    # Form.io configuration
    formio_image            = "formio/formio-enterprise:9.5.0"
    use_enterprise          = true
    formio_license_key      = "test-license-key"
    formio_root_email       = "test@example.com"
    formio_root_password    = "test-password"
    formio_jwt_secret       = "test-jwt-secret-32-characters-long"
    formio_db_secret        = "test-db-secret-32-characters-long"
    portal_enabled          = true
    
    # Service configuration
    service_name            = "test-formio-api"
    max_instances           = 5
    min_instances           = 0
    cpu_request             = "1000m"
    memory_request          = "2Gi"
    concurrency             = 80
    timeout_seconds         = 300
    
    # Dependencies
    mongodb_connection_string = "mongodb://test-connection"
    storage_bucket_name      = "test-bucket"
    vpc_connector_id         = ""
  }
  
  # Assertions
  assert {
    condition     = google_cloud_run_v2_service.formio_service.name == "test-formio-api-test"
    error_message = "Cloud Run service name should follow naming convention"
  }
  
  assert {
    condition     = google_cloud_run_v2_service.formio_service.location == "us-central1"
    error_message = "Cloud Run service should be deployed in the correct region"
  }
  
  assert {
    condition     = length(google_secret_manager_secret.formio_jwt_secret.secret_id) > 0
    error_message = "JWT secret should be created"
  }
  
  assert {
    condition     = google_service_account.formio_service_account.account_id == "test-formio-api-sa-test"
    error_message = "Service account should follow naming convention"
  }
}

run "enterprise_license_configuration" {
  command = plan
  
  module {
    source = "../../terraform/modules/cloud-run"
  }
  
  variables {
    project_id              = "test-project-id"
    region                  = "us-central1"
    environment             = "test"
    labels                  = { test = "true" }
    
    # Enterprise configuration
    formio_image            = "formio/formio-enterprise:9.5.0"
    use_enterprise          = true
    formio_license_key      = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
    formio_root_email       = "test@example.com"
    formio_root_password    = "test-password"
    formio_jwt_secret       = "test-jwt-secret-32-characters-long"
    formio_db_secret        = "test-db-secret-32-characters-long"
    portal_enabled          = true
    
    service_name            = "test-formio-api"
    max_instances           = 5
    min_instances           = 0
    cpu_request             = "1000m"
    memory_request          = "2Gi"
    concurrency             = 80
    timeout_seconds         = 300
    
    mongodb_connection_string = "mongodb://test-connection"
    storage_bucket_name      = "test-bucket"
    vpc_connector_id         = ""
  }
  
  # Test enterprise-specific resources
  assert {
    condition     = length(google_secret_manager_secret.formio_license_key) == 1
    error_message = "Enterprise license secret should be created when use_enterprise is true"
  }
  
  assert {
    condition     = contains(google_cloud_run_v2_service.formio_service.template[0].containers[0].image, "formio-enterprise")
    error_message = "Should use enterprise image when use_enterprise is true"
  }
}