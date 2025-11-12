terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "dss-org-tf-state"
    prefix = "formio-service/environments/dev-formio-custom"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "formio_custom_service" {
  source = "../../modules/formio-custom-service"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  # Docker image configuration (CI/CD-compatible Git SHA tagging)
  # Run: ./scripts/tag-and-push.sh git-sha to build with current commit
  custom_image_tag = "git-3b95aa5"

  # Secret Manager secret IDs (required)
  mongodb_connection_string_secret_id = "dss-formio-api-mongodb-custom-connection-string-dev"
  formio_jwt_secret_secret_id         = "dss-formio-api-jwt-secret-dev"
  formio_db_secret_secret_id          = "dss-formio-api-db-secret-dev"
  formio_root_password_secret_id      = "dss-formio-api-root-password-dev"
  token_private_key_secret_id         = "dss-formio-api-token-private-key-v1-dev"
  token_public_key_secret_id          = "dss-formio-api-token-public-key-v1-dev"

  # Form.io configuration (required)
  formio_root_email   = "admin@erlich.dev"
  storage_bucket_name = "erlich-dev-formio-uploads"

  # Cloud Run configuration (using correct variable names)
  min_instance_count = 0
  max_instance_count = 10
  cpu_limit          = "1000m"
  memory_limit       = "512Mi"
  request_timeout    = 300

  # Disable monitoring alerts (avoiding Terraform module bugs and IAM issues)
  enable_alerting = false

  # Labels for resource management
  labels = {
    environment = "dev"
    application = "formio-custom"
    managed_by  = "terraform"
  }
}
