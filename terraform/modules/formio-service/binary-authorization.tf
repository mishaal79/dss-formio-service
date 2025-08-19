# =============================================================================
# BINARY AUTHORIZATION POLICY
# =============================================================================
#
# Container image security policy to prevent unauthorized deployments
# Ensures only trusted and verified images can be deployed to Form.io services
#

# Binary Authorization policy for the project
resource "google_binary_authorization_policy" "formio_policy" {
  count   = var.enable_binary_authorization ? 1 : 0
  project = var.project_id

  # Default admission rule - require attestation for all images
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.formio_attestor[0].name
    ]
  }

  # Cluster-specific admission rules for Cloud Run
  cluster_admission_rules {
    cluster          = "*" # Apply to all Cloud Run services
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.formio_attestor[0].name
    ]
  }

  # Allow Google-managed base images (e.g., for buildpacks)
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google-appengine/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/gcp-runtimes/*"
  }
}

# Attestor for verifying container images
resource "google_binary_authorization_attestor" "formio_attestor" {
  count   = var.enable_binary_authorization ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-attestor-${var.environment}"

  attestation_authority_note {
    note_reference = google_container_analysis_note.formio_note[0].name

    public_keys {
      id = "formio-signing-key"

      # PGP public key for image signing (replace with your actual key)
      ascii_armored_pgp_public_key = var.attestor_public_key
    }
  }

  description = "Attestor for Form.io container image verification"
}

# Container Analysis note for attestations
resource "google_container_analysis_note" "formio_note" {
  count   = var.enable_binary_authorization ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-attestation-note-${var.environment}"

  attestation_authority {
    hint {
      human_readable_name = "Form.io Image Attestor"
    }
  }

}

# =============================================================================
# IMPLEMENTATION GUIDANCE
# =============================================================================
#
# To use Binary Authorization:
#
# 1. Generate a key pair for signing:
#    gpg --quick-generate-key "formio-ci@company.com"
#    gpg --armor --export formio-ci@company.com > public-key.asc
#
# 2. Set the attestor_public_key variable to the content of public-key.asc
#
# 3. In your CI/CD pipeline, sign container images:
#    gcloud container binauthz attestations sign-and-create \
#      --attestor="formio-attestor-dev" \
#      --artifact-url="gcr.io/project/formio:tag" \
#      --pgp-key-fingerprint="YOUR_KEY_FINGERPRINT"
#
# 4. Enable Binary Authorization for Cloud Run in the project
#
# =============================================================================

# Outputs for CI/CD integration
output "binary_authorization_policy" {
  description = "Binary Authorization policy ID"
  value       = var.enable_binary_authorization ? google_binary_authorization_policy.formio_policy[0].id : null
}

output "attestor_name" {
  description = "Binary Authorization attestor name for CI/CD signing"
  value       = var.enable_binary_authorization ? google_binary_authorization_attestor.formio_attestor[0].name : null
}