# =============================================================================
# FORM.IO COMMUNITY EDITION - STANDALONE TERRAFORM MODULE
# =============================================================================
# This module creates a completely independent Form.io Community Edition deployment
# NOT coupled with Enterprise - can be deployed with or without Enterprise
# Uses port 3001 (Community standard) and NODE_CONFIG JSON pattern

# Fetch secrets from Secret Manager
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

data "google_secret_manager_secret_version" "formio_db_secret" {
  provider = google-beta
  project  = var.project_id
  secret   = var.formio_db_secret_secret_id
}

locals {
  # SECURITY: NODE_CONFIG is now assembled at runtime in the container
  # This prevents secrets from appearing in Terraform state files
  # The wrapper script uses jq to build NODE_CONFIG from environment variables

  # Service naming - completely independent from Enterprise
  service_name_full = "formio-community-${var.environment}"

  # Comprehensive labeling for operational excellence
  service_labels = merge(var.labels, {
    # Core service identification
    service     = "formio-community"
    edition     = "community"
    environment = var.environment

    # Cost and compliance tracking
    cost-center    = "dss-electrical"
    application-id = "formio-community-service"
    owner          = "platform-team"

    # Operational metadata
    managed-by    = "terraform"
    project-type  = "form-management"
    backup-policy = "daily"

    # Security and compliance
    data-classification = "confidential"
    compliance-scope    = "pci-dss"
  })

  # Backend service naming for load balancer integration
  backend_service_name = "formio-community-backend-${var.environment}"

  # Use Community Edition's default port
  container_port = 3001

  # Environment variables for Community Edition
  # SECURITY: Secrets are now passed as references, not values
  # The wrapper script assembles NODE_CONFIG at runtime
  env_vars = [
    # MongoDB connection string from Secret Manager
    {
      name  = "MONGO_URI"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = var.mongodb_connection_string_secret_id
          version = "latest"
        }
      }
    },
    # JWT secret from Secret Manager
    {
      name  = "JWT_SECRET"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = var.formio_jwt_secret_secret_id
          version = "latest"
        }
      }
    },
    # DB secret from Secret Manager
    {
      name  = "DB_SECRET"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = var.formio_db_secret_secret_id
          version = "latest"
        }
      }
    },
    # Protocol and host configuration
    {
      name         = "PROTOCOL"
      value        = "http"
      value_source = null
    },
    {
      name         = "HOST"
      value        = "0.0.0.0"
      value_source = null
    },
    # PORT is reserved by Cloud Run and set automatically
    # Community runs on port 3001 defined in container_port
    # Common environment variables
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
          secret  = var.formio_root_password_secret_id
          version = "latest"
        }
      }
    },
    # S3-compatible storage configuration for file uploads
    {
      name         = "FORMIO_FILES_SERVER"
      value        = "s3"
      value_source = null
    },
    {
      name         = "FORMIO_S3_SERVER"
      value        = "https://storage.googleapis.com"
      value_source = null
    },
    {
      name         = "FORMIO_S3_BUCKET"
      value        = var.storage_bucket_name
      value_source = null
    },
    {
      name         = "FORMIO_S3_REGION"
      value        = "auto"
      value_source = null
    },
    {
      name         = "FORMIO_S3_PATH"
      value        = "com/${var.environment}/uploads"
      value_source = null
    },
    {
      name  = "FORMIO_S3_KEY"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = google_secret_manager_secret.formio_community_s3_key.secret_id
          version = "latest"
        }
      }
    },
    {
      name  = "FORMIO_S3_SECRET"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = google_secret_manager_secret.formio_community_s3_secret.secret_id
          version = "latest"
        }
      }
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
    # Structured logging configuration
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
          secret  = var.formio_root_password_secret_id
          version = "latest"
        }
      }
    },
    {
      name  = "PORTAL_SECRET"
      value = null
      value_source = {
        secret_key_ref = {
          secret  = var.formio_db_secret_secret_id
          version = "latest"
        }
      }
    },
    # Community-specific database name
    {
      name         = "MONGO_DB_NAME"
      value        = "formio_community"
      value_source = null
    },
    {
      name         = "HOST"
      value        = "0.0.0.0"
      value_source = null
    },
    {
      name         = "BASE_URL"
      value        = var.base_url != "" ? var.base_url : "https://forms-community.${var.environment}.cloud.dsselectrical.com.au"
      value_source = null
    },
    {
      name         = "TRUST_PROXY"
      value        = "true"
      value_source = null
    },
    {
      name         = "JWT_EXPIRE_TIME"
      value        = "240"
      value_source = null
    }
  ]
}

# =============================================================================
# SERVICE ACCOUNT - COMMUNITY SPECIFIC
# =============================================================================

resource "google_service_account" "formio_community_service_account" {
  account_id   = "formio-community-sa-${var.environment}"
  display_name = "Form.io Community Service Account"
  project      = var.project_id
}

# =============================================================================
# HMAC KEYS FOR S3-COMPATIBLE GCS ACCESS (COMMUNITY SPECIFIC)
# =============================================================================

# Generate HMAC key for S3-compatible access to GCS
resource "google_storage_hmac_key" "formio_community_gcs_key" {
  service_account_email = google_service_account.formio_community_service_account.email
  project               = var.project_id
}

# Store HMAC access key in Secret Manager
resource "google_secret_manager_secret" "formio_community_s3_key" {
  secret_id = "formio-community-gcs-s3-key-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.service_labels
}

resource "google_secret_manager_secret_version" "formio_community_s3_key" {
  secret      = google_secret_manager_secret.formio_community_s3_key.id
  secret_data = google_storage_hmac_key.formio_community_gcs_key.access_id
}

# Store HMAC secret key in Secret Manager
resource "google_secret_manager_secret" "formio_community_s3_secret" {
  secret_id = "formio-community-gcs-s3-secret-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.service_labels
}

resource "google_secret_manager_secret_version" "formio_community_s3_secret" {
  secret      = google_secret_manager_secret.formio_community_s3_secret.id
  secret_data = google_storage_hmac_key.formio_community_gcs_key.secret
}

# =============================================================================
# IAM PERMISSIONS - COMMUNITY SPECIFIC
# =============================================================================

# Grant service account access to the HMAC key secrets
resource "google_secret_manager_secret_iam_member" "community_s3_key_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.formio_community_s3_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "community_s3_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.formio_community_s3_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

# IAM bindings for service account to access shared secrets
resource "google_secret_manager_secret_iam_member" "community_root_password_access" {
  project   = var.project_id
  secret_id = var.formio_root_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "community_jwt_secret_access" {
  project   = var.project_id
  secret_id = var.formio_jwt_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "community_db_secret_access" {
  project   = var.project_id
  secret_id = var.formio_db_secret_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "community_mongodb_connection_access" {
  project   = var.project_id
  secret_id = var.mongodb_connection_string_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

# Additional IAM bindings
resource "google_project_iam_member" "community_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

resource "google_project_iam_member" "community_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.formio_community_service_account.email}"
}

# =============================================================================
# CLOUD RUN SERVICE - COMMUNITY EDITION
# =============================================================================

resource "google_cloud_run_v2_service" "formio_community_service" {
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
    service_account = google_service_account.formio_community_service_account.email

    # Enable session affinity and request-based billing optimizations
    annotations = {
      "run.googleapis.com/sessionAffinity"       = "true"
      "run.googleapis.com/cpu-throttling"        = "false"
      "run.googleapis.com/execution-environment" = "gen2"
    }

    # Direct VPC egress using central infrastructure egress subnet
    vpc_access {
      network_interfaces {
        network    = var.vpc_network_id
        subnetwork = var.egress_subnet_id
        tags       = ["formio-community-egress"]
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      name  = "formio-community"
      image = "formio/formio:${var.community_version}"

      # Override entrypoint to use wrapper script for secure NODE_CONFIG assembly
      # This prevents secrets from appearing in Terraform state files
      command = ["/bin/sh"]
      args = [
        "-c",
        <<-EOT
        # Install jq for JSON assembly
        apk add --no-cache jq || apt-get update && apt-get install -y jq

        # Assemble NODE_CONFIG from environment variables
        # Use Form.io Community's default port 3001
        export NODE_CONFIG=$(jq -n \
          --arg mongo "$MONGO_URI" \
          --arg jwt "$JWT_SECRET" \
          --arg db "$DB_SECRET" \
          --arg host "$${HOST:-0.0.0.0}" \
          --arg protocol "$${PROTOCOL:-http}" \
          --argjson port 3001 \
          --argjson trust $${TRUST_PROXY:-true} \
          '{mongo: $mongo, port: $port, host: $host, protocol: $protocol, jwt: {secret: $jwt}, db: {secret: $db}, trust_proxy: $trust}')

        echo "[$(date)] NODE_CONFIG assembled successfully"

        # Start Form.io
        exec node main.js
        EOT
      ]

      ports {
        name           = "http1" # Force HTTP/1.1 protocol
        container_port = local.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        # Startup CPU boost for heavy initialization
        startup_cpu_boost = true
      }

      # Startup probe - using TCP socket (proven to work for Community)
      startup_probe {
        tcp_socket {
          port = local.container_port # Port 3001
        }
        initial_delay_seconds = 240 # 4 minutes max allowed by Cloud Run
        timeout_seconds       = 60  # 60 second timeout
        period_seconds        = 60  # Check every minute
        failure_threshold     = 20  # 20 minutes additional time after initial delay
      }

      # Liveness probe removed - Form.io Community has no public endpoints
      # All API endpoints require MongoDB initialization and/or authentication
      # TCP startup probe is sufficient for health checking

      # Environment variables
      dynamic "env" {
        for_each = local.env_vars
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
    }

    # Scaling configuration - optimized for instance-based billing
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
resource "google_cloud_run_service_iam_binding" "community_authorized_access" {
  count    = length(var.authorized_members) > 0 ? 1 : 0
  location = google_cloud_run_v2_service.formio_community_service.location
  project  = google_cloud_run_v2_service.formio_community_service.project
  service  = google_cloud_run_v2_service.formio_community_service.name
  role     = "roles/run.invoker"

  members = var.authorized_members
}

# =============================================================================
# BACKEND SERVICE AND NETWORK ENDPOINT GROUP FOR LOAD BALANCER INTEGRATION
# =============================================================================

# Network Endpoint Group for Cloud Run service
resource "google_compute_region_network_endpoint_group" "formio_community_neg" {
  name                  = "formio-community-neg-${var.environment}"
  description           = "Network endpoint group for Form.io Community Cloud Run"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.formio_community_service.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Backend service for centralized load balancer integration
resource "google_compute_backend_service" "formio_community_backend" {
  name                  = local.backend_service_name
  description           = "Backend service for Form.io Community Cloud Run"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  enable_cdn            = true

  # CDN configuration for performance
  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = 3600
    max_ttl     = 86400
    client_ttl  = 1800

    negative_caching = true

    negative_caching_policy {
      code = 404
      ttl  = 300
    }

    cache_key_policy {
      include_host           = true
      include_protocol       = true
      include_query_string   = true
      query_string_whitelist = ["version", "locale"]
    }
  }

  # Session affinity with cookie for 4 hours
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 14400

  backend {
    group = google_compute_region_network_endpoint_group.formio_community_neg.id

    # Capacity optimization
    max_utilization = 0.8
  }

  # Request logging
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # IAP disabled
  iap {
    enabled = false
  }

  lifecycle {
    create_before_destroy = true
  }
}