data "google_secret_manager_secret_version" "mongodb_connection_string" {
  provider = google-beta
  project  = var.project_id
  secret   = var.mongodb_connection_string_secret_id
}

data "google_secret_manager_secret_version" "formio_jwt_secret" {
  provider = google-beta
  project  = var.project_id
  secret   = var.formio_jwt_secret_secret_id
}

locals {
  # Community Edition NODE_CONFIG with Community-specific Atlas connection
  community_node_config = jsonencode({
    mongo = data.google_secret_manager_secret_version.mongodb_connection_string.secret_data
    port  = 3000
    jwt = {
      secret = data.google_secret_manager_secret_version.formio_jwt_secret.secret_data
    }
  })

  # Enterprise Edition uses individual environment variables (MONGO, JWT_SECRET, etc.)
  # Community Edition uses NODE_CONFIG with JSON
  node_config = var.use_enterprise ? "" : local.community_node_config

  # Missing locals restored from interrupted refactoring
  formio_image      = var.use_enterprise ? "formio/formio-enterprise:${var.formio_version}" : "formio/formio:${var.community_version}"
  service_name_full = "${var.service_name}-${var.environment}"

  # Comprehensive labeling for cost tracking, compliance, and operational excellence
  service_labels = merge(var.labels, {
    # Core service identification
    service     = var.service_name
    edition     = var.use_enterprise ? "enterprise" : "community"
    environment = var.environment

    # Cost and compliance tracking
    cost-center    = "dss-electrical"
    application-id = "formio-service"
    owner          = "platform-team"

    # Operational metadata
    managed-by    = "terraform"
    project-type  = "form-management"
    backup-policy = "daily"

    # Security and compliance
    data-classification = "confidential"
    compliance-scope    = "pci-dss"
  })

  # =============================================================================
  # INTELLIGENT PORT HANDLING FOR CLOUD RUN V2
  # Cloud Run v2 reserves PORT env var, so we extract it and use for container_port
  # =============================================================================

  # Define all environment variables as objects
  all_env_vars = concat(
    # Community Edition NODE_CONFIG
    var.use_enterprise ? [] : [
      {
        name         = "NODE_CONFIG"
        value        = local.node_config
        value_source = null
      }
    ],

    # Enterprise Edition MONGO connection
    var.use_enterprise ? [
      {
        name  = "MONGO"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.mongodb_connection_string_secret_id
            version = "latest"
          }
        }
      }
    ] : [],

    # Enterprise Edition JWT_SECRET
    var.use_enterprise ? [
      {
        name  = "JWT_SECRET"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.formio_jwt_secret_secret_id != null ? var.formio_jwt_secret_secret_id : "placeholder-jwt-secret"
            version = "latest"
          }
        }
      }
    ] : [],

    # Common environment variables
    [
      {
        name  = "DB_SECRET"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.formio_db_secret_secret_id != null ? var.formio_db_secret_secret_id : "placeholder-db-secret"
            version = "latest"
          }
        }
      },
      {
        name         = "PORTAL_ENABLED"
        value        = var.portal_enabled ? "1" : "0"
        value_source = null
      },
      {
        name         = "ROOT_EMAIL"
        value        = var.formio_root_email
        value_source = null
      },
      {
        name  = "ROOT_PASSWORD"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.formio_root_password_secret_id != null ? var.formio_root_password_secret_id : "placeholder-root-password"
            version = "latest"
          }
        }
      },
      {
        name         = "FORMIO_FILES_SERVER"
        value        = "gcs"
        value_source = null
      },
      {
        name         = "FORMIO_GCS_BUCKET"
        value        = var.storage_bucket_name
        value_source = null
      },
      {
        name         = "FORMIO_GCS_PATH"
        value        = "${var.use_enterprise ? "ent" : "com"}/${var.environment}/uploads"
        value_source = null
      },
      {
        name         = "NODE_OPTIONS"
        value        = "--max-old-space-size=1024"
        value_source = null
      },
      {
        name         = "DEBUG"
        value        = "*.*"
        value_source = null
      },
      # Structured logging configuration for better observability
      {
        name         = "LOG_FORMAT"
        value        = "json"
        value_source = null
      },
      {
        name         = "LOG_LEVEL"
        value        = var.environment == "prod" ? "warn" : "info"
        value_source = null
      },
      {
        name         = "ADMIN_EMAIL"
        value        = "admin@dsselectrical.com.au"
        value_source = null
      },
      {
        name  = "ADMIN_PASS"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.formio_root_password_secret_id != null ? var.formio_root_password_secret_id : "placeholder-root-password"
            version = "latest"
          }
        }
      },
      {
        name  = "PORTAL_SECRET"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = var.formio_db_secret_secret_id != null ? var.formio_db_secret_secret_id : "placeholder-db-secret"
            version = "latest"
          }
        }
      },
      {
        name         = "MONGO_DB_NAME"
        value        = var.database_name
        value_source = null
      },
      {
        name         = "HOST"
        value        = "0.0.0.0"
        value_source = null
      },
      # Form.io expects PORT env var (as per documentation)
      {
        name         = "PORT"
        value        = "3000"
        value_source = null
      }
    ],

    # Enterprise-only LICENSE_KEY
    var.use_enterprise ? [
      {
        name  = "LICENSE_KEY"
        value = null
        value_source = {
          secret_key_ref = {
            secret  = google_secret_manager_secret.formio_license_key[0].secret_id
            version = "latest"
          }
        }
      }
    ] : []
  )

  # Extract PORT value for container_port (Cloud Run requirement)
  port_env_vars  = [for env in local.all_env_vars : env if env.name == "PORT"]
  container_port = length(local.port_env_vars) > 0 ? tonumber(local.port_env_vars[0].value) : 3000

  # Filter out PORT from environment variables (Cloud Run will inject it automatically)
  filtered_env_vars = [for env in local.all_env_vars : env if env.name != "PORT"]
}

# Service Account
resource "google_service_account" "formio_service_account" {
  account_id   = "${var.service_name}-sa-${var.environment}"
  display_name = "Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Service Account"
  project      = var.project_id
}

# IAM bindings for service account to access secrets
resource "google_secret_manager_secret_iam_member" "root_password_access" {
  project   = var.project_id
  secret_id = var.formio_root_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  project   = var.project_id
  secret_id = var.formio_jwt_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "db_secret_access" {
  project   = var.project_id
  secret_id = var.formio_db_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "mongodb_connection_access" {
  project   = var.project_id
  secret_id = var.mongodb_connection_string_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# License key access (Enterprise only)
resource "google_secret_manager_secret_iam_member" "license_key_access" {
  count     = var.use_enterprise ? 1 : 0
  project   = var.project_id
  secret_id = google_secret_manager_secret.formio_license_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Additional IAM bindings
resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.formio_service_account.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.formio_service_account.email}"
}

# Enterprise License Key Secret (conditional)
resource "google_secret_manager_secret" "formio_license_key" {
  count     = var.use_enterprise ? 1 : 0
  secret_id = "${var.service_name}-license-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.service_labels
}

resource "google_secret_manager_secret_version" "formio_license_key" {
  count       = var.use_enterprise ? 1 : 0
  secret      = google_secret_manager_secret.formio_license_key[0].id
  secret_data = var.formio_license_key
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "formio_service" {
  name     = local.service_name_full
  location = var.region
  project  = var.project_id

  # SECURITY: Force all traffic through load balancer (prevents bypass attacks)
  ingress = var.enable_load_balancer ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  # Temporarily disable deletion protection for testing
  deletion_protection = false

  # Ignore container image changes - managed by gcloud deployments
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image
    ]
  }

  template {
    service_account = google_service_account.formio_service_account.email

    # Enable session affinity and request-based billing optimizations
    annotations = {
      "run.googleapis.com/sessionAffinity"       = "true"
      "run.googleapis.com/cpu-throttling"        = "false"
      "run.googleapis.com/execution-environment" = "gen2"
    }

    # Direct VPC egress using shared infrastructure egress subnet
    # Routes only private network traffic through VPC (Google APIs use direct routes)
    vpc_access {
      network_interfaces {
        network    = "projects/erlich-dev/global/networks/erlich-vpc-dev"
        subnetwork = "projects/erlich-dev/regions/${var.region}/subnetworks/erlich-vpc-egress-subnet-dev"
        tags       = ["formio-egress"]
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name  = "formio"
      image = local.formio_image

      ports {
        name           = "http1" # Force HTTP/1.1 protocol (fixes Form.io 502 errors)
        container_port = local.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        # Startup CPU boost provides double CPU during initialization + 10 seconds
        # Critical for Form.io's heavy startup (DB connections, license validation)
        startup_cpu_boost = true
      }

      # Startup probe - essential for proper cold start detection
      startup_probe {
        http_get {
          path = "/health"
          port = local.container_port
        }
        initial_delay_seconds = 0
        timeout_seconds       = 8  # Must be < period_seconds
        period_seconds        = 10
        failure_threshold     = 18 # 3 minutes total startup time (18 * 10s)
      }

      # Health checks - monitors running container health
      liveness_probe {
        http_get {
          path = "/health"
          port = local.container_port
        }
        initial_delay_seconds = 30 # Reduced since startup probe handles initial startup
        timeout_seconds       = 30
        period_seconds        = 30
        failure_threshold     = 3
      }

      # =============================================================================
      # DYNAMIC ENVIRONMENT VARIABLES WITH INTELLIGENT PORT HANDLING
      # Automatically filters out PORT (Cloud Run reserved) and handles secrets
      # =============================================================================

      dynamic "env" {
        for_each = local.filtered_env_vars
        content {
          name = env.value.name

          # Use value if it's a simple string, otherwise use value_source for secrets
          value = env.value.value_source == null ? env.value.value : null

          # Handle secret references when value_source is provided
          dynamic "value_source" {
            for_each = env.value.value_source != null ? [env.value.value_source] : []
            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }

      # TODO: Add PDF_SERVER configuration once basic deployment is working
      # This enables PDF form generation and export functionality
      # env {
      #   name  = "PDF_SERVER"
      #   value = "http://pdf-server:4005"
      # }
    }

    # =============================================================================
    # SCALING CONFIGURATION - OPTIMIZED FOR INSTANCE-BASED BILLING
    # =============================================================================
    # With cpu-throttling=false (instance-based billing) and startup CPU boost:
    # - min_instances=0: Cold starts occur, but startup CPU boost helps
    # - min_instances=1: No cold starts, always warm instance (recommended for production)
    # - min_instances>1: Multiple warm instances for high availability
    #
    # Cost vs Performance Trade-offs:
    # - min_instances=0: Lower cost, occasional cold start latency
    # - min_instances=1: Higher cost, consistent performance
    # - Consider traffic patterns and SLA requirements
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    max_instance_request_concurrency = var.concurrency
    timeout                          = "${var.timeout_seconds}s"
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  labels = local.service_labels
}

# Allow authorized access to Cloud Run service
# When using load balancer, only the load balancer needs access
# When not using load balancer, allow configured members
resource "google_cloud_run_service_iam_binding" "authorized_access" {
  count    = length(var.authorized_members) > 0 ? 1 : 0
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"

  members = var.authorized_members
}

# Allow load balancer to access Cloud Run service
resource "google_cloud_run_service_iam_binding" "load_balancer_access" {
  count    = var.enable_load_balancer ? 1 : 0
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"

  members = ["allUsers"]
}