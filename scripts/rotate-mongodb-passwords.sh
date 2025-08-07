#!/bin/bash
# MongoDB Password Rotation Script
# Rotates MongoDB passwords and updates Secret Manager
# Usage: ./rotate-mongodb-passwords.sh [project-id] [environment] [service-name]

set -e

# Configuration
PROJECT_ID="${1:-erlich-dev}"
ENVIRONMENT="${2:-dev}"
SERVICE_NAME="${3:-dss-formio-api}"

echo "=== MongoDB Password Rotation ==="
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Service: $SERVICE_NAME"
echo ""

# Function to generate secure random passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to check if secret exists
secret_exists() {
    local secret_id="$1"
    gcloud secrets describe "$secret_id" --project="$PROJECT_ID" >/dev/null 2>&1
}

# Function to update secret in Secret Manager
update_secret() {
    local secret_id="$1"
    local new_password="$2"
    
    if secret_exists "$secret_id"; then
        echo "Updating secret: $secret_id"
        echo -n "$new_password" | gcloud secrets versions add "$secret_id" --data-file=- --project="$PROJECT_ID"
    else
        echo "ERROR: Secret $secret_id does not exist"
        return 1
    fi
}

# Function to wait for MongoDB to be ready
wait_for_mongodb() {
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for MongoDB to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if gcloud compute instances describe "${PROJECT_ID}-mongodb-${ENVIRONMENT}" \
           --zone="us-central1-a" --project="$PROJECT_ID" --format="value(status)" | grep -q "RUNNING"; then
            echo "MongoDB instance is running"
            sleep 10  # Additional wait for MongoDB service
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: MongoDB not ready, waiting..."
        sleep 10
        ((attempt++))
    done
    
    echo "ERROR: MongoDB did not become ready within timeout"
    return 1
}

# Function to execute command on MongoDB instance
execute_on_mongodb() {
    local command="$1"
    gcloud compute ssh "${PROJECT_ID}-mongodb-${ENVIRONMENT}" \
        --zone="us-central1-a" \
        --project="$PROJECT_ID" \
        --command="$command"
}

# Main rotation process
echo "Step 1: Generating new passwords..."
NEW_ADMIN_PASSWORD=$(generate_password)
NEW_FORMIO_PASSWORD=$(generate_password)

echo "Generated new passwords (${NEW_ADMIN_PASSWORD:0:8}... and ${NEW_FORMIO_PASSWORD:0:8}...)"

# Secret IDs
ADMIN_SECRET_ID="${SERVICE_NAME}-mongodb-admin-password-${ENVIRONMENT}"
FORMIO_SECRET_ID="${SERVICE_NAME}-mongodb-formio-password-${ENVIRONMENT}"
CONNECTION_SECRET_ID="${SERVICE_NAME}-mongodb-connection-string-${ENVIRONMENT}"

echo ""
echo "Step 2: Updating Secret Manager with new passwords..."

# Update admin password secret
update_secret "$ADMIN_SECRET_ID" "$NEW_ADMIN_PASSWORD"

# Update Form.io password secret  
update_secret "$FORMIO_SECRET_ID" "$NEW_FORMIO_PASSWORD"

echo ""
echo "Step 3: Waiting for MongoDB instance to be ready..."
wait_for_mongodb

echo ""
echo "Step 4: Updating MongoDB user passwords..."

# Get MongoDB instance IP
MONGODB_IP=$(gcloud compute instances describe "${PROJECT_ID}-mongodb-${ENVIRONMENT}" \
    --zone="us-central1-a" \
    --project="$PROJECT_ID" \
    --format="value(networkInterfaces[0].networkIP)")

# Update admin user password in MongoDB
echo "Updating admin user password in MongoDB..."
execute_on_mongodb "
    # Get old admin password from Secret Manager
    OLD_ADMIN_PASSWORD=\$(gcloud secrets versions access 1 --secret='$ADMIN_SECRET_ID' --project='$PROJECT_ID')
    
    # Update admin password
    mongosh --authenticationDatabase admin -u 'mongoAdmin' -p \"\$OLD_ADMIN_PASSWORD\" --eval \"
        db = db.getSiblingDB('admin');
        db.changeUserPassword('mongoAdmin', '$NEW_ADMIN_PASSWORD');
    \"
    
    echo 'Admin password updated successfully'
"

# Update Form.io user password in MongoDB
echo "Updating Form.io user password in MongoDB..."
execute_on_mongodb "
    # Update Form.io user password
    mongosh --authenticationDatabase admin -u 'mongoAdmin' -p '$NEW_ADMIN_PASSWORD' --eval \"
        db = db.getSiblingDB('formio');
        db.changeUserPassword('formioUser', '$NEW_FORMIO_PASSWORD');
    \"
    
    echo 'Form.io user password updated successfully'
"

echo ""
echo "Step 5: Updating MongoDB connection string..."

# Generate new connection string
NEW_CONNECTION_STRING="mongodb://formioUser:${NEW_FORMIO_PASSWORD}@${MONGODB_IP}:27017/formio?authSource=formio&replicaSet=rs0"

# Update connection string secret
update_secret "$CONNECTION_SECRET_ID" "$NEW_CONNECTION_STRING"

echo ""
echo "Step 6: Testing new passwords..."

# Test admin authentication
execute_on_mongodb "
    if mongosh --authenticationDatabase admin -u 'mongoAdmin' -p '$NEW_ADMIN_PASSWORD' --eval 'db.runCommand({ping: 1})' >/dev/null 2>&1; then
        echo 'Admin authentication test: PASSED'
    else
        echo 'Admin authentication test: FAILED'
        exit 1
    fi
"

# Test Form.io user authentication
execute_on_mongodb "
    if mongosh --authenticationDatabase formio -u 'formioUser' -p '$NEW_FORMIO_PASSWORD' --eval 'db.runCommand({ping: 1})' >/dev/null 2>&1; then
        echo 'Form.io user authentication test: PASSED'
    else
        echo 'Form.io user authentication test: FAILED'
        exit 1
    fi
"

echo ""
echo "Step 7: Restarting Form.io Cloud Run service to pick up new credentials..."

# Get Cloud Run service name
CLOUD_RUN_SERVICE="${SERVICE_NAME}-${ENVIRONMENT}"

# Restart Cloud Run service by updating a label (forces new revision)
gcloud run services update "$CLOUD_RUN_SERVICE" \
    --region="us-central1" \
    --project="$PROJECT_ID" \
    --update-labels="rotation-timestamp=$(date +%s)" \
    --quiet

echo "Cloud Run service restart initiated"

echo ""
echo "=== Password Rotation Completed Successfully ==="
echo "- Admin password rotated: ${NEW_ADMIN_PASSWORD:0:8}..."
echo "- Form.io password rotated: ${NEW_FORMIO_PASSWORD:0:8}..."
echo "- Connection string updated"
echo "- Cloud Run service restarted"
echo ""
echo "All passwords have been rotated and are stored in Secret Manager."
echo "Old password versions are retained for rollback if needed."

# Clean up variables
unset NEW_ADMIN_PASSWORD
unset NEW_FORMIO_PASSWORD
unset NEW_CONNECTION_STRING