# =============================================================================
# TERRAFORM CONFIGURATION - Production-Ready Backend Setup
# =============================================================================

terraform {
  required_version = ">= 1.0"

  # Remote state backend for team collaboration and production deployments
  # SECURITY: State file contains sensitive data and must be stored securely
  backend "gcs" {
    bucket = "dss-terraform-state-formio"
    prefix = "formio-service/environments/dev"

    # State locking enabled automatically with GCS backend
    # Prevents concurrent modifications and state corruption
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.39"
    }
  }
}

# =============================================================================
# TERRAFORM STATE BUCKET REQUIREMENTS
# =============================================================================

# The GCS bucket for Terraform state must be configured with:
#
# 1. VERSIONING ENABLED:
#    gsutil versioning set on gs://dss-terraform-state-formio
#
# 2. LIFECYCLE POLICY (30-day retention):
#    gcloud storage buckets update gs://dss-terraform-state-formio \
#      --lifecycle-file=lifecycle.json
#
# 3. IAM PERMISSIONS:
#    - terraform-runner service account: Storage Object Admin
#    - developers: Storage Object Viewer (read-only access)
#
# 4. UNIFORM BUCKET-LEVEL ACCESS:
#    gsutil uniformbucketlevelaccess set on gs://dss-terraform-state-formio
#
# 5. ENCRYPTION:
#    Default Google-managed encryption (sufficient for dev environment)
#    For production: Consider customer-managed encryption keys (CMEK)

# =============================================================================
# LIFECYCLE POLICY FOR STATE BUCKET
# =============================================================================

# Create lifecycle.json with this content:
# {
#   "lifecycle": {
#     "rule": [
#       {
#         "action": {
#           "type": "Delete"
#         },
#         "condition": {
#           "age": 30,
#           "isLive": false
#         }
#       }
#     ]
#   }
# }

# =============================================================================
# BACKEND MIGRATION COMMANDS
# =============================================================================

# To migrate from local to remote state:
# 1. Create the bucket:
#    gsutil mb -p erlich-dev -c STANDARD -l australia-southeast1 gs://dss-terraform-state-formio
#
# 2. Enable versioning:
#    gsutil versioning set on gs://dss-terraform-state-formio
#
# 3. Initialize backend:
#    terraform init -migrate-state
#
# 4. Verify migration:
#    terraform state list
#
# 5. Remove local state:
#    rm terraform.tfstate*

# =============================================================================
# TEAM COLLABORATION BEST PRACTICES
# =============================================================================

# 1. ALWAYS run `terraform plan` before `terraform apply`
# 2. Use consistent Terraform versions across team (specified above)
# 3. Never commit .tfvars files with sensitive data to git
# 4. Use environment variables for provider authentication
# 5. Regular state backups are handled automatically by GCS versioning
# 6. Use `terraform workspace` for multiple environments (dev/staging/prod)