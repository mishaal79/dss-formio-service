#!/bin/bash
# Set environment variables for MongoDB Atlas M30 deployment

# GCP Service Account Authentication
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/keys/dev-mish-key.json"

# MongoDB Atlas API Credentials (REQUIRED - Update these with actual values)
# Get these from MongoDB Atlas Console > Organization Settings > Access Manager > API Keys
export MONGODBATLAS_PUBLIC_KEY="<YOUR_PUBLIC_KEY>"
export MONGODBATLAS_PRIVATE_KEY="<YOUR_PRIVATE_KEY>"

# MongoDB Atlas Organization ID (from terraform.tfvars)
export TF_VAR_mongodb_atlas_org_id="689def34b9cb4014c2ba192e"

# Form.io Secrets (Generate these if not already set)
export TF_VAR_formio_root_password="$(openssl rand -base64 32)"
export TF_VAR_formio_jwt_secret="$(openssl rand -base64 32)"
export TF_VAR_formio_db_secret="$(openssl rand -base64 32)"

# MongoDB passwords (Generate if not set)
export TF_VAR_mongodb_admin_password="$(openssl rand -base64 32)"
export TF_VAR_mongodb_formio_password="$(openssl rand -base64 32)"

echo "Environment variables set. Don't forget to update MongoDB Atlas API credentials!"
echo "MONGODBATLAS_PUBLIC_KEY and MONGODBATLAS_PRIVATE_KEY must be set."