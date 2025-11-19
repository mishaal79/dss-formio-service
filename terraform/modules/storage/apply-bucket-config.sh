#!/bin/bash

# Script to apply bucket configurations (STOR-002, STOR-004)
# Service accounts already exist

set -e

PROJECT_ID="erlich-dev"
BUCKET_NAME="erlich-dev-formio-storage-dev-g004azjs"
ENVIRONMENT="dev"

echo "=========================================="
echo "Applying Bucket Security Configurations"
echo "Project: $PROJECT_ID"
echo "Bucket: $BUCKET_NAME"
echo "=========================================="

FORMIO_SA="formio-server-sa-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"
TUS_SA="tus-server-sa-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"

# =============================================================================
# STOR-003: Configure remaining IAM Bindings
# =============================================================================

echo ""
echo "Configuring remaining IAM bindings (STOR-003)..."

# Grant viewer permission to Form.io server SA (already has creator)
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${FORMIO_SA}" \
    --role="roles/storage.objectViewer" \
    --project=${PROJECT_ID} 2>/dev/null || echo "Form.io SA viewer role may already exist"

# Grant permissions to TUS server SA
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${TUS_SA}" \
    --role="roles/storage.objectCreator" \
    --project=${PROJECT_ID} 2>/dev/null || echo "TUS SA creator role may already exist"

gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${TUS_SA}" \
    --role="roles/storage.objectViewer" \
    --project=${PROJECT_ID} 2>/dev/null || echo "TUS SA viewer role may already exist"

echo "IAM bindings configured"

# =============================================================================
# STOR-002: Configure Lifecycle Rules
# =============================================================================

echo ""
echo "Configuring lifecycle rules (STOR-002)..."

# Create lifecycle configuration file
cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 7,
          "matchesPrefix": ["tus-chunks/"]
        }
      },
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 1,
          "matchesPrefix": ["uploads-failed/"]
        }
      },
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["uploads-temp/", "temp/"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["uploads-temp/", "temp/"],
          "matchesStorageClass": ["STANDARD"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["uploads/"],
          "matchesStorageClass": ["STANDARD"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["uploads/"],
          "matchesStorageClass": ["NEARLINE"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"},
        "condition": {
          "age": 1095,
          "matchesPrefix": ["uploads/"],
          "matchesStorageClass": ["COLDLINE"]
        }
      },
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      },
      {
        "action": {"type": "AbortIncompleteMultipartUpload"},
        "condition": {
          "age": 7
        }
      }
    ]
  }
}
EOF

# Apply lifecycle configuration
gcloud storage buckets update gs://${BUCKET_NAME} --lifecycle-file=/tmp/lifecycle.json

echo "Lifecycle rules configured successfully"

# =============================================================================
# STOR-002: Configure Retention Policy (7-year)
# =============================================================================

echo ""
echo "Configuring 7-year retention policy (STOR-002)..."

# Set retention policy (7 years = 2555 days)
gcloud storage buckets update gs://${BUCKET_NAME} \
    --retention-period=2555d \
    --project=${PROJECT_ID}

echo "Retention policy configured (7 years, unlocked)"

# =============================================================================
# STOR-004: Configure CORS
# =============================================================================

echo ""
echo "Configuring CORS for TUS uploads (STOR-004)..."

# Create CORS configuration file
cat > /tmp/cors.json <<EOF
[
  {
    "origin": [
      "http://localhost:64849",
      "http://localhost:3000",
      "http://localhost:5173",
      "https://formio-dev.erlich.app"
    ],
    "method": ["OPTIONS", "HEAD", "PATCH", "POST", "GET", "DELETE"],
    "responseHeader": [
      "Tus-Resumable",
      "Upload-Length",
      "Upload-Offset",
      "Upload-Metadata",
      "Upload-Concat",
      "Upload-Defer-Length",
      "Location",
      "Content-Type",
      "Content-Length",
      "Authorization",
      "X-Requested-With",
      "X-HTTP-Method-Override",
      "*"
    ],
    "maxAgeSeconds": 3600
  }
]
EOF

# Apply CORS configuration
gcloud storage buckets update gs://${BUCKET_NAME} --cors-file=/tmp/cors.json

echo "CORS configuration applied successfully"

# =============================================================================
# Additional Security Settings
# =============================================================================

echo ""
echo "Applying additional security settings..."

# Enable versioning
gcloud storage buckets update gs://${BUCKET_NAME} --versioning

# Enable uniform bucket-level access
gcloud storage buckets update gs://${BUCKET_NAME} --uniform-bucket-level-access

# Set public access prevention
gcloud storage buckets update gs://${BUCKET_NAME} --public-access-prevention

echo "Additional security settings applied"

# =============================================================================
# Verification
# =============================================================================

echo ""
echo "=========================================="
echo "Configuration Complete! Verification:"
echo "=========================================="

echo ""
echo "1. Lifecycle Rules:"
gcloud storage buckets describe gs://${BUCKET_NAME} --format=json | jq '.lifecycle.rule | length' | xargs echo "   Total rules configured:"

echo ""
echo "2. Retention Policy:"
gcloud storage buckets describe gs://${BUCKET_NAME} --format=json | jq '.retentionPolicy.retentionPeriod' | xargs echo "   Retention period (seconds):"

echo ""
echo "3. CORS Origins:"
gcloud storage buckets describe gs://${BUCKET_NAME} --format=json | jq '.cors[0].origin[]' | head -5

echo ""
echo "4. IAM Bindings for Service Accounts:"
echo "   Form.io SA (${FORMIO_SA}):"
gcloud storage buckets get-iam-policy gs://${BUCKET_NAME} --format=json | jq -r '.bindings[] | select(.members[] | contains("formio-server-sa")) | "     - \(.role)"'
echo "   TUS SA (${TUS_SA}):"
gcloud storage buckets get-iam-policy gs://${BUCKET_NAME} --format=json | jq -r '.bindings[] | select(.members[] | contains("tus-server-sa")) | "     - \(.role)"'

echo ""
echo "=========================================="
echo "All configurations applied successfully!"
echo "=========================================="