#!/bin/bash
# MongoDB Installation Script for Ubuntu 20.04
# Installs MongoDB Community Edition with authentication and monitoring

set -e

# Configuration variables are templated directly by Terraform
# mongodb_version, admin_username, admin_password_secret, project_id

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/mongodb-install.log
}

log "Starting MongoDB ${mongodb_version} installation..."

# Update system packages
log "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
log "Installing required packages..."
apt-get install -y curl wget gnupg lsb-release

# Add MongoDB repository
log "Adding MongoDB repository..."
curl -fsSL https://www.mongodb.org/static/pgp/server-${mongodb_version}.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${mongodb_version} multiverse" > /etc/apt/sources.list.d/mongodb-org-${mongodb_version}.list

# Update package list and install MongoDB
log "Installing MongoDB Community Edition ${mongodb_version}..."
apt-get update
apt-get install -y mongodb-org

# Pin MongoDB version to prevent automatic updates
log "Pinning MongoDB version..."
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-database hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

# Create MongoDB data directory on attached disk
log "Setting up MongoDB data directory..."
mkdir -p /mnt/mongodb-data
chown mongodb:mongodb /mnt/mongodb-data
chmod 755 /mnt/mongodb-data

# Format and mount the data disk
log "Formatting and mounting data disk..."
DEVICE_NAME="/dev/disk/by-id/google-mongodb-data"
if [ -b "$DEVICE_NAME" ]; then
    # Check if disk is already formatted
    if ! blkid "$DEVICE_NAME"; then
        log "Formatting data disk..."
        mkfs.ext4 -F "$DEVICE_NAME"
    fi
    
    # Mount the disk
    mount "$DEVICE_NAME" /mnt/mongodb-data
    chown mongodb:mongodb /mnt/mongodb-data
    
    # Add to fstab for persistent mounting
    DISK_UUID=$(blkid -s UUID -o value "$DEVICE_NAME")
    echo "UUID=$DISK_UUID /mnt/mongodb-data ext4 defaults 0 2" >> /etc/fstab
else
    log "Warning: Data disk not found, using local storage"
    mkdir -p /var/lib/mongodb-data
    chown mongodb:mongodb /var/lib/mongodb-data
fi

# Configure MongoDB
log "Configuring MongoDB..."
cat > /etc/mongod.conf << EOF
# MongoDB configuration for production deployment

# Where to store data
storage:
  dbPath: /mnt/mongodb-data
  journal:
    enabled: true

# Where to write logging data
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0  # Listen on all interfaces (secured by firewall)

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid

# Security settings
security:
  authorization: enabled  # Enable authentication

# Operation profiling (for monitoring)
operationProfiling:
  slowOpThresholdMs: 100

# Set up replication (single node for now, but enables oplog)
replication:
  replSetName: "rs0"
EOF

# Install Google Cloud Ops Agent for monitoring
log "Installing Google Cloud Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Configure Ops Agent for MongoDB monitoring
log "Configuring MongoDB monitoring..."
cat > /etc/google-cloud-ops-agent/config.yaml << EOF
metrics:
  receivers:
    mongodb:
      type: mongodb
      endpoint: localhost:27017
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics, mongodb]

logging:
  receivers:
    mongodb_log:
      type: files
      include_paths:
        - /var/log/mongodb/mongod.log
      record_log_file_path: true
  service:
    pipelines:
      default_pipeline:
        receivers: [syslog, mongodb_log]
EOF

# Start MongoDB service
log "Starting MongoDB service..."
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to start
log "Waiting for MongoDB to start..."
sleep 10

# Initialize replica set (required for oplog)
log "Initializing replica set..."
mongosh --eval "rs.initiate({_id: 'rs0', members: [{_id: 0, host: 'localhost:27017'}]})"

# Wait for replica set to be ready
log "Waiting for replica set initialization..."
sleep 15

# Securely retrieve passwords from Secret Manager
log "Retrieving passwords from Secret Manager..."

# Get admin password
ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret="${admin_password_secret}" --project="${project_id}")
if [ -z "$ADMIN_PASSWORD" ]; then
    log "ERROR: Failed to retrieve admin password from Secret Manager"
    exit 1
fi

# Get Form.io user password
FORMIO_PASSWORD=$(gcloud secrets versions access latest --secret="${formio_password_secret}" --project="${project_id}")
if [ -z "$FORMIO_PASSWORD" ]; then
    log "ERROR: Failed to retrieve Form.io password from Secret Manager"
    exit 1
fi

log "Successfully retrieved passwords from Secret Manager"

# Create admin user
log "Creating MongoDB admin user..."
mongosh --eval "
db = db.getSiblingDB('admin');
db.createUser({
  user: '${admin_username}',
  pwd: '$ADMIN_PASSWORD',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
});
"

# Create Form.io databases and users with separate password
log "Creating Form.io databases and users..."

# Create main database (legacy compatibility)
mongosh --authenticationDatabase admin -u "${admin_username}" -p "$ADMIN_PASSWORD" --eval "
db = db.getSiblingDB('${database_name}');
db.createUser({
  user: '${formio_username}',
  pwd: '$FORMIO_PASSWORD',
  roles: [
    { role: 'readWrite', db: '${database_name}' }
  ]
});
db.createCollection('forms');
db.createCollection('submissions');
"

# Create Community edition database
log "Creating Community edition database..."
mongosh --authenticationDatabase admin -u "${admin_username}" -p "$ADMIN_PASSWORD" --eval "
db = db.getSiblingDB('${database_name}_community');
db.createUser({
  user: '${formio_username}',
  pwd: '$FORMIO_PASSWORD',
  roles: [
    { role: 'readWrite', db: '${database_name}_community' }
  ]
});
db.createCollection('forms');
db.createCollection('submissions');
db.createCollection('actions');
db.createCollection('roles');
"

# Create Enterprise edition database
log "Creating Enterprise edition database..."
mongosh --authenticationDatabase admin -u "${admin_username}" -p "$ADMIN_PASSWORD" --eval "
db = db.getSiblingDB('${database_name}_enterprise');
db.createUser({
  user: '${formio_username}',
  pwd: '$FORMIO_PASSWORD',
  roles: [
    { role: 'readWrite', db: '${database_name}_enterprise' }
  ]
});
db.createCollection('forms');
db.createCollection('submissions');
db.createCollection('actions');
db.createCollection('roles');
"

# Restart MongoDB to ensure all settings take effect
log "Restarting MongoDB with authentication enabled..."
systemctl restart mongod

# Wait for restart
sleep 10

# Test authentication for admin user
log "Testing MongoDB admin authentication..."
if mongosh --authenticationDatabase admin -u "${admin_username}" -p "$ADMIN_PASSWORD" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
    log "MongoDB admin authentication test successful"
else
    log "ERROR: MongoDB admin authentication test failed"
    exit 1
fi

# Test authentication for Form.io user (main database)
log "Testing MongoDB Form.io user authentication..."
if mongosh --authenticationDatabase "${database_name}" -u "${formio_username}" -p "$FORMIO_PASSWORD" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
    log "MongoDB Form.io user authentication test successful"
else
    log "ERROR: MongoDB Form.io user authentication test failed"
    exit 1
fi

# Test authentication for Community database
log "Testing MongoDB Community database authentication..."
if mongosh --authenticationDatabase "${database_name}_community" -u "${formio_username}" -p "$FORMIO_PASSWORD" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
    log "MongoDB Community database authentication test successful"
else
    log "ERROR: MongoDB Community database authentication test failed"
    exit 1
fi

# Test authentication for Enterprise database
log "Testing MongoDB Enterprise database authentication..."
if mongosh --authenticationDatabase "${database_name}_enterprise" -u "${formio_username}" -p "$FORMIO_PASSWORD" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
    log "MongoDB Enterprise database authentication test successful"
else
    log "ERROR: MongoDB Enterprise database authentication test failed"
    exit 1
fi

# Clear password variables from memory for security
unset ADMIN_PASSWORD
unset FORMIO_PASSWORD
log "Cleared password variables from memory"

# Restart Ops Agent to pick up configuration
log "Restarting Google Cloud Ops Agent..."
systemctl restart google-cloud-ops-agent

# Set up log rotation for MongoDB
log "Configuring log rotation..."
cat > /etc/logrotate.d/mongodb << EOF
/var/log/mongodb/*.log {
    daily
    missingok
    rotate 52
    compress
    notifempty
    create 640 mongodb mongodb
    sharedscripts
    postrotate
        /bin/kill -SIGUSR1 \$(cat /var/run/mongodb/mongod.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

# Create backup script
log "Creating backup script..."
cat > /usr/local/bin/mongodb-backup.sh << 'EOF'
#!/bin/bash
# MongoDB backup script with Secret Manager integration

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb-backup-$DATE"
GCS_BUCKET="gs://${project_id}-mongodb-backups"

echo "Starting MongoDB backup: $DATE"

# Retrieve admin password from Secret Manager
ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret="${admin_password_secret}" --project="${project_id}")
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "ERROR: Failed to retrieve admin password from Secret Manager"
    exit 1
fi

# Create backup
echo "Creating MongoDB backup..."
mongodump --authenticationDatabase admin -u "${admin_username}" -p "$ADMIN_PASSWORD" --out "$BACKUP_DIR"

# Clear password from memory
unset ADMIN_PASSWORD

# Compress backup
echo "Compressing backup..."
tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"

# Upload to Cloud Storage
echo "Uploading backup to Cloud Storage..."
gsutil cp "$BACKUP_DIR.tar.gz" "$GCS_BUCKET/"

# Cleanup local files
rm -rf "$BACKUP_DIR" "$BACKUP_DIR.tar.gz"

echo "Backup completed successfully: $DATE"
EOF

chmod +x /usr/local/bin/mongodb-backup.sh

# Set up daily backup cron job
log "Setting up daily backup cron job..."
echo "0 2 * * * root /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" > /etc/cron.d/mongodb-backup

# Final status check
log "Performing final MongoDB status check..."
if systemctl is-active --quiet mongod; then
    log "MongoDB installation completed successfully!"
    log "MongoDB is running on port 27017"
    log "Admin user: ${admin_username}"
    log "Form.io database: ${database_name}"
    log "Form.io user: ${formio_username}"
    log "All passwords stored securely in Secret Manager"
else
    log "ERROR: MongoDB is not running after installation"
    exit 1
fi

# Display connection information
log "MongoDB installation summary:"
log "- Version: MongoDB Community ${mongodb_version}"
log "- Data directory: /mnt/mongodb-data"
log "- Log file: /var/log/mongodb/mongod.log"
log "- Configuration: /etc/mongod.conf"
log "- Service status: $(systemctl is-active mongod)"
log "- Replica set: rs0"
log "- Authentication: enabled"

log "Installation completed successfully at $(date)"