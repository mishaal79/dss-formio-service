# Integration Test for Development Environment
# Tests the complete dev environment configuration

run "dev_environment_plan" {
  command = plan

  module {
    source = "../../terraform/environments/dev"
  }

  variables {
    project_id  = "erlich-dev"
    region      = "us-central1"
    environment = "dev"

    # Form.io configuration
    formio_version       = "9.5.0"
    formio_license_key   = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
    formio_root_email    = "admin@test.com"
    formio_root_password = "test-password"
    formio_jwt_secret    = "test-jwt-secret-32-characters-long"
    formio_db_secret     = "test-db-secret-32-characters-long"

    # Service configuration
    service_name   = "dss-formio-api"
    max_instances  = 3
    min_instances  = 0
    cpu_request    = "1000m"
    memory_request = "2Gi"

    # MongoDB configuration
    mongodb_atlas_enabled = true
    mongodb_version       = "7.0"
    mongodb_tier          = "M10"
    atlas_project_name    = "dss-formio-dev"
    atlas_cluster_name    = "dss-formio-dev-cluster"

    notification_channels = []
    custom_domain         = ""
    ssl_certificate_id    = ""
  }

  # Test that all major components are planned
  assert {
    condition     = module.formio_service.formio_service_name == "dss-formio-api-dev"
    error_message = "Form.io service should be named correctly for dev environment"
  }

  assert {
    condition     = var.environment == "dev"
    error_message = "Environment should be set to dev"
  }

  # Test development-specific configurations
  assert {
    condition     = var.min_instances == 0
    error_message = "Development environment should allow scaling to zero"
  }

  assert {
    condition     = var.max_instances <= 5
    error_message = "Development environment should have limited max instances"
  }
}

run "dev_environment_validation" {
  command = plan

  module {
    source = "../../terraform/environments/dev"
  }

  variables {
    project_id  = "erlich-dev"
    region      = "us-central1"
    environment = "dev"

    formio_version       = "9.5.0"
    formio_license_key   = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
    formio_root_email    = "admin@test.com"
    formio_root_password = "test-password"
    formio_jwt_secret    = "test-jwt-secret-32-characters-long"
    formio_db_secret     = "test-db-secret-32-characters-long"

    service_name   = "dss-formio-api"
    max_instances  = 3
    min_instances  = 0
    cpu_request    = "1000m"
    memory_request = "2Gi"

    mongodb_atlas_enabled = true
    mongodb_version       = "7.0"
    mongodb_tier          = "M10"
    atlas_project_name    = "dss-formio-dev"
    atlas_cluster_name    = "dss-formio-dev-cluster"

    notification_channels = []
    custom_domain         = ""
    ssl_certificate_id    = ""
  }

  # Validate shared infrastructure integration
  assert {
    condition     = can(data.terraform_remote_state.shared_infra.outputs)
    error_message = "Should be able to access shared infrastructure state"
  }

  # Test resource labeling
  assert {
    condition     = contains(keys(local.common_labels), "environment")
    error_message = "Common labels should include environment"
  }

  assert {
    condition     = local.common_labels.environment == "dev"
    error_message = "Environment label should match the environment"
  }
}