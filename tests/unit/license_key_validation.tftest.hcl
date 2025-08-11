# License Key Validation Tests
# Comprehensive tests to validate Form.io license key configuration
# Tests variable handling, secret creation, IAM permissions, and Cloud Run environment variables

# Test 1: License Key Variable Validation
run "license_key_variable_validation" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "license-validation" }

    # Enterprise configuration with valid license key
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMtTestKey12345"
    formio_root_email  = "admin@test.com"

    # Required secret references (simulated)
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "test-formio-ent"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"

    # Service configuration
    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  # Assert license key variable is properly set
  assert {
    condition     = var.formio_license_key != null && var.formio_license_key != ""
    error_message = "License key variable must not be null or empty for enterprise deployments"
  }

  assert {
    condition     = length(var.formio_license_key) >= 20
    error_message = "License key must be at least 20 characters long"
  }

  assert {
    condition     = var.use_enterprise == true
    error_message = "Enterprise flag must be true for license key validation tests"
  }
}

# Test 2: Enterprise License Secret Creation
run "enterprise_license_secret_creation" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "dev"
    labels      = { test = "secret-creation" }

    # Enterprise configuration
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMtEnterpriseLicense"
    formio_root_email  = "admin@test.com"

    # Required secret references
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "dss-formio-api-ent"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"

    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  # Assert license key secret is created
  assert {
    condition     = length(google_secret_manager_secret.formio_license_key) == 1
    error_message = "License key secret should be created for enterprise deployments"
  }

  # Assert secret ID follows naming convention
  assert {
    condition     = google_secret_manager_secret.formio_license_key[0].secret_id == "dss-formio-api-ent-license-key-dev"
    error_message = "License key secret ID should follow naming convention: {service_name}-license-key-{environment}"
  }

  # Assert secret version is created
  assert {
    condition     = length(google_secret_manager_secret_version.formio_license_key) == 1
    error_message = "License key secret version should be created for enterprise deployments"
  }

  # Assert secret version references the correct secret
  assert {
    condition     = google_secret_manager_secret_version.formio_license_key[0].secret == google_secret_manager_secret.formio_license_key[0].id
    error_message = "Secret version should reference the correct secret resource"
  }

  # Assert secret has proper labels
  assert {
    condition     = google_secret_manager_secret.formio_license_key[0].labels.edition == "enterprise"
    error_message = "License key secret should be labeled as enterprise edition"
  }
}

# Test 3: Enterprise IAM Permissions
run "enterprise_iam_permissions" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "iam-permissions" }

    # Enterprise configuration
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMtIAMTest"
    formio_root_email  = "admin@test.com"

    # Required secret references
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "test-formio-ent"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"

    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  # Assert IAM binding for license key access is created
  assert {
    condition     = length(google_secret_manager_secret_iam_member.license_key_access) == 1
    error_message = "IAM binding for license key access should be created for enterprise deployments"
  }

  # Assert IAM binding has correct role
  assert {
    condition     = google_secret_manager_secret_iam_member.license_key_access[0].role == "roles/secretmanager.secretAccessor"
    error_message = "License key IAM binding should grant secretmanager.secretAccessor role"
  }

  # Assert IAM binding references correct service account
  assert {
    condition     = contains(google_secret_manager_secret_iam_member.license_key_access[0].member, google_service_account.formio_service_account.email)
    error_message = "License key IAM binding should reference the Form.io service account"
  }

  # Assert IAM binding references correct secret
  assert {
    condition     = google_secret_manager_secret_iam_member.license_key_access[0].secret_id == google_secret_manager_secret.formio_license_key[0].secret_id
    error_message = "License key IAM binding should reference the correct secret"
  }
}

# Test 4: Cloud Run LICENSE_KEY Environment Variable Configuration
run "cloud_run_license_key_environment_variable" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "environment-variables" }

    # Enterprise configuration
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMtEnvVarTest"
    formio_root_email  = "admin@test.com"

    # Required secret references
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "test-formio-ent"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"
    vpc_connector_id                    = "projects/test-project/locations/us-central1/connectors/test-connector"

    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  # Assert Cloud Run service is created
  assert {
    condition     = google_cloud_run_v2_service.formio_service.name == "test-formio-ent-test"
    error_message = "Cloud Run service should be created with correct name"
  }

  # Assert enterprise image is used
  assert {
    condition     = google_cloud_run_v2_service.formio_service.template[0].containers[0].image == "formio/formio-enterprise:9.5.1-rc.10"
    error_message = "Cloud Run service should use the correct enterprise image"
  }

  # Critical Test: Assert LICENSE_KEY environment variable exists
  # This checks if the dynamic env block creates the LICENSE_KEY environment variable
  assert {
    condition = length([
      for env in google_cloud_run_v2_service.formio_service.template[0].containers[0].env :
      env if env.name == "LICENSE_KEY"
    ]) == 1
    error_message = "Cloud Run container must have LICENSE_KEY environment variable for enterprise deployments"
  }

  # Assert LICENSE_KEY environment variable sources from secret
  assert {
    condition = length([
      for env in google_cloud_run_v2_service.formio_service.template[0].containers[0].env :
      env if env.name == "LICENSE_KEY" &&
      env.value_source[0].secret_key_ref[0].secret == google_secret_manager_secret.formio_license_key[0].secret_id
    ]) == 1
    error_message = "LICENSE_KEY environment variable must source from the license key secret"
  }

  # Assert LICENSE_KEY uses latest version
  assert {
    condition = length([
      for env in google_cloud_run_v2_service.formio_service.template[0].containers[0].env :
      env if env.name == "LICENSE_KEY" &&
      env.value_source[0].secret_key_ref[0].version == "latest"
    ]) == 1
    error_message = "LICENSE_KEY environment variable must use latest secret version"
  }

  # Assert VPC connector is properly configured for license validation
  assert {
    condition     = google_cloud_run_v2_service.formio_service.template[0].vpc_access[0].connector == "projects/test-project/locations/us-central1/connectors/test-connector"
    error_message = "VPC connector should be configured to allow license server communication"
  }

  assert {
    condition     = google_cloud_run_v2_service.formio_service.template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    error_message = "VPC egress should be ALL_TRAFFIC to allow license validation"
  }
}

# Test 5: Community Deployment Should Not Create License Resources
run "community_no_license_key" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "community-no-license" }

    # Community configuration (no license key)
    use_enterprise    = false
    formio_version    = "9.5.1-rc.10"
    community_version = "rc"
    formio_root_email = "admin@test.com"

    # Required secret references
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "test-formio-com"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"

    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  # Assert NO license key secret is created for community
  assert {
    condition     = length(google_secret_manager_secret.formio_license_key) == 0
    error_message = "License key secret should NOT be created for community deployments"
  }

  # Assert NO license key secret version is created for community
  assert {
    condition     = length(google_secret_manager_secret_version.formio_license_key) == 0
    error_message = "License key secret version should NOT be created for community deployments"
  }

  # Assert NO license key IAM binding is created for community
  assert {
    condition     = length(google_secret_manager_secret_iam_member.license_key_access) == 0
    error_message = "License key IAM binding should NOT be created for community deployments"
  }

  # Assert community image is used
  assert {
    condition     = google_cloud_run_v2_service.formio_service.template[0].containers[0].image == "formio/formio:rc"
    error_message = "Cloud Run service should use the community image for community deployments"
  }

  # Assert NO LICENSE_KEY environment variable for community
  assert {
    condition = length([
      for env in google_cloud_run_v2_service.formio_service.template[0].containers[0].env :
      env if env.name == "LICENSE_KEY"
    ]) == 0
    error_message = "Cloud Run container should NOT have LICENSE_KEY environment variable for community deployments"
  }
}

# Test 6: Invalid License Key Handling
run "invalid_license_key_handling" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "test-project-id"
    region      = "us-central1"
    environment = "test"
    labels      = { test = "invalid-license" }

    # Enterprise configuration with potentially invalid license key
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "invalid-short" # Too short
    formio_root_email  = "admin@test.com"

    # Required secret references
    formio_root_password_secret_id = "test-root-password-secret"
    formio_jwt_secret_secret_id    = "test-jwt-secret"
    formio_db_secret_secret_id     = "test-db-secret"

    service_name                        = "test-formio-ent"
    mongodb_connection_string_secret_id = "test-mongo-connection"
    storage_bucket_name                 = "test-bucket"

    max_instances   = 5
    min_instances   = 0
    cpu_request     = "1000m"
    memory_request  = "2Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true
  }

  expect_failures = [
    var.formio_license_key
  ]
}

# Test 7: End-to-End License Flow Validation
run "end_to_end_license_flow" {
  command = plan

  module {
    source = "../../terraform/modules/formio-service"
  }

  variables {
    project_id  = "erlich-dev"
    region      = "australia-southeast1"
    environment = "dev"
    labels      = { test = "e2e-license-flow" }

    # Realistic enterprise configuration
    use_enterprise     = true
    formio_version     = "9.5.1-rc.10"
    community_version  = "rc"
    formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMtE2ETestFlowValidation"
    formio_root_email  = "admin@dsselectrical.com.au"

    # Required secret references
    formio_root_password_secret_id = "dss-formio-api-root-password-dev"
    formio_jwt_secret_secret_id    = "dss-formio-api-jwt-secret-dev"
    formio_db_secret_secret_id     = "dss-formio-api-db-secret-dev"

    service_name                        = "dss-formio-api-ent"
    mongodb_connection_string_secret_id = "dss-formio-api-mongodb-enterprise-connection-string-dev"
    storage_bucket_name                 = "erlich-dev-formio-storage-dev"
    vpc_connector_id                    = "projects/erlich-dev/locations/australia-southeast1/connectors/erlich-vpc-connector-dev"

    # Realistic service configuration
    max_instances   = 10
    min_instances   = 1
    cpu_request     = "2000m"
    memory_request  = "4Gi"
    concurrency     = 80
    timeout_seconds = 300
    portal_enabled  = true

    authorized_members = [
      "user:admin@dsselectrical.com.au",
      "user:mishal@qrius.global"
    ]
  }

  # Complete license flow validation
  assert {
    condition = alltrue([
      # 1. License key variable is properly set
      var.formio_license_key != null && length(var.formio_license_key) >= 20,
      # 2. License secret is created
      length(google_secret_manager_secret.formio_license_key) == 1,
      # 3. Service account has proper access
      length(google_secret_manager_secret_iam_member.license_key_access) == 1,
      # 4. Cloud Run has LICENSE_KEY environment variable
      length([for env in google_cloud_run_v2_service.formio_service.template[0].containers[0].env : env if env.name == "LICENSE_KEY"]) == 1
    ])
    error_message = "Complete license key flow validation failed - check variable, secret, IAM, and environment variable configuration"
  }

  # Assert proper service naming for production use
  assert {
    condition     = google_cloud_run_v2_service.formio_service.name == "dss-formio-api-ent-dev"
    error_message = "Service name should follow production naming convention"
  }

  # Assert authorized access is configured
  assert {
    condition     = length(google_cloud_run_service_iam_binding.authorized_access) == 1
    error_message = "Authorized access IAM binding should be configured"
  }
}