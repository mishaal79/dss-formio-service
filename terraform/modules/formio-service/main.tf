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
  # SERVICE REGISTRATION FOR CENTRALIZED LOAD BALANCER
  # =============================================================================

  # Service registration configuration for consistent naming
  service_registration = {
    service_name = var.service_name
    service_type = "cloud-run"
    edition      = var.use_enterprise ? "enterprise" : "community"
    environment  = var.environment
    backend_config = {
      port                    = 80
      protocol                = "HTTP"
      load_balancing_scheme   = "EXTERNAL"
      timeout_sec             = var.timeout_seconds
      session_affinity        = "CLIENT_IP"
      affinity_cookie_ttl_sec = 3600
      enable_cdn              = false
      enable_logging          = true
      log_sample_rate         = 1.0
    }
  }

  # Generate consistent backend service name using predictable pattern
  consistent_backend_name = "${local.service_registration.service_name}-backend-${local.service_registration.environment}"

  # Service key for identification in centralized load balancer
  service_key = "${local.service_registration.service_type}-${local.service_registration.edition}-${local.service_registration.environment}"

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
      {
        name         = "BASE_URL"
        value        = var.base_url != "" ? var.base_url : "https://forms.${var.environment}.cloud.dsselectrical.com.au"
        value_source = null
      },
      {
        name         = "TRUST_PROXY"
        value        = "true"
        value_source = null
      },
      # Cloud Run automatically injects PORT environment variable
      # Form.io will listen on $PORT (managed by Cloud Run)
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

  # Form.io expects port 3000 (Cloud Run will inject $PORT=3000)
  container_port = 3000

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

# =============================================================================
# CLOUD RUN SERVICE
# =============================================================================

# Cloud Run Service
resource "google_cloud_run_v2_service" "formio_service" {
  name     = local.service_name_full
  location = var.region
  project  = var.project_id

  # SECURITY: Disable IAM invoker check for load balancer health checks
  invoker_iam_disabled = true

  # SECURITY: Allow internal load balancer traffic for centralized architecture
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

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

    # Direct VPC egress using central infrastructure egress subnet
    # Routes only private network traffic through VPC (Google APIs use direct routes)
    vpc_access {
      network_interfaces {
        network    = var.vpc_network_id
        subnetwork = var.egress_subnet_id
        tags       = ["formio-egress"]
      }
      egress = "ALL_TRAFFIC"
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

      # Startup probe - very lenient settings to allow MongoDB lock resolution
      startup_probe {
        http_get {
          path = "/health"
          port = local.container_port
        }
        initial_delay_seconds = 180 # 3 minutes initial delay
        timeout_seconds       = 30  # 30 second timeout
        period_seconds        = 60  # Check every minute
        failure_threshold     = 10  # 10 minutes total startup time (10 * 60s)
      }

      # Health checks - monitors running container health (extended for lock resolution)
      liveness_probe {
        http_get {
          path = "/health"
          port = local.container_port
        }
        initial_delay_seconds = 120 # Extended delay for MongoDB lock resolution
        timeout_seconds       = 30
        period_seconds        = 60 # Less frequent checks
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
# For centralized load balancer architecture, both authorized users and load balancer need access
resource "google_cloud_run_service_iam_binding" "authorized_access" {
  count    = length(var.authorized_members) > 0 ? 1 : 0
  location = google_cloud_run_v2_service.formio_service.location
  project  = google_cloud_run_v2_service.formio_service.project
  service  = google_cloud_run_v2_service.formio_service.name
  role     = "roles/run.invoker"

  members = var.authorized_members
}


# =============================================================================
# BACKEND SERVICE AND NETWORK ENDPOINT GROUP FOR CENTRALIZED LOAD BALANCER
# =============================================================================

# Network Endpoint Group for Cloud Run service
resource "google_compute_region_network_endpoint_group" "formio_neg" {
  name                  = "${var.service_name}-neg-${var.environment}"
  description           = "Network endpoint group for Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Cloud Run"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.formio_service.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Backend service for centralized load balancer integration
resource "google_compute_backend_service" "formio_backend" {
  name                  = local.consistent_backend_name
  description           = "Backend service for Form.io ${var.use_enterprise ? "Enterprise" : "Community"} Cloud Run"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  # timeout_sec is not supported for serverless NEGs (Cloud Run)
  enable_cdn = true

  # CDN Configuration for performance optimization
  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = 3600  # 1 hour for API responses
    max_ttl     = 86400 # 24 hours maximum
    client_ttl  = 1800  # 30 minutes browser cache

    # Enable negative caching to reduce origin load
    negative_caching = true

    # Negative caching policy for 404s
    negative_caching_policy {
      code = 404
      ttl  = 300 # Cache 404s for 5 minutes
    }

    # Intelligent cache key policy
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true # Include query string to use whitelist
      # Only include specific cache-relevant query parameters
      query_string_whitelist = ["version", "locale"]
    }
  }

  # Session affinity for Form.io stateful operations
  session_affinity        = "CLIENT_IP"
  affinity_cookie_ttl_sec = 3600 # 1 hour

  backend {
    group = google_compute_region_network_endpoint_group.formio_neg.id

    # Capacity optimization (max_connections_per_instance not supported for serverless NEGs)
    max_utilization = 0.8
  }

  # Note: Health checks are not supported for serverless NEGs (Cloud Run)
  # Cloud Run handles health checks internally

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  iap {
    enabled = false
  }

  lifecycle {
    create_before_destroy = true
  }
}