#!/bin/bash

# MongoDB Atlas Database Initialization Script for Form.io
# Simple version that works with our current setup

set -e

echo "🚀 Initializing MongoDB Atlas databases for Form.io..."

# Get MongoDB Atlas connection details
cd /Users/mishal/code/work/dss-formio-service/terraform/environments/dev
source ../../../.env

# Extract hostname from connection string
ATLAS_CONNECTION=$(terraform output -raw mongodb_connection_strings_srv)
ATLAS_HOST=$(echo $ATLAS_CONNECTION | sed 's|mongodb+srv://||')

# Get passwords from Secret Manager
ADMIN_PASSWORD_RAW=$(gcloud secrets versions access latest --secret=dss-formio-api-mongodb-admin-password-dev)
# URL encode the password for use in connection strings
ADMIN_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ADMIN_PASSWORD_RAW', safe=''))")

echo "📡 Connecting to Atlas cluster: $ATLAS_HOST"
echo "👤 Admin user: mongoAdmin"

# Test connection first
echo "🔍 Testing Atlas connection..."
if mongosh "mongodb+srv://mongoAdmin:${ADMIN_PASSWORD}@${ATLAS_HOST}/admin?retryWrites=true&w=majority" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
    echo "✅ Atlas connection successful!"
else
    echo "❌ Failed to connect to Atlas"
    exit 1
fi

# Initialize Form.io Community Database
echo "🏘️  Initializing Form.io Community database..."
mongosh "mongodb+srv://mongoAdmin:${ADMIN_PASSWORD}@${ATLAS_HOST}/formio_community?retryWrites=true&w=majority" <<EOF
print('Creating formio_community database...');

// Create basic collections
db.createCollection('forms');
db.createCollection('submissions'); 
db.createCollection('actions');
db.createCollection('roles');

// Create a basic form to initialize the database
db.forms.insertOne({
  title: 'Welcome Form',
  name: 'welcome',
  path: 'welcome',
  type: 'form',
  display: 'form',
  components: [
    {
      type: 'textfield',
      key: 'firstName',
      label: 'First Name',
      input: true
    }
  ],
  created: new Date(),
  modified: new Date()
});

// Create default role
db.roles.insertOne({
  title: 'Anonymous',
  name: 'anonymous',
  default: true,
  admin: false,
  created: new Date(),
  modified: new Date()
});

print('✅ Community database initialized');
EOF

# Initialize Form.io Enterprise Database  
echo "🏢 Initializing Form.io Enterprise database..."
mongosh "mongodb+srv://mongoAdmin:${ADMIN_PASSWORD}@${ATLAS_HOST}/formio_enterprise?retryWrites=true&w=majority" <<EOF
print('Creating formio_enterprise database...');

// Create basic collections
db.createCollection('forms');
db.createCollection('submissions');
db.createCollection('actions');
db.createCollection('roles');

// Create a basic form to initialize the database
db.forms.insertOne({
  title: 'Enterprise Welcome Form',
  name: 'enterprise-welcome',
  path: 'enterprise-welcome',
  type: 'form',
  display: 'form',
  components: [
    {
      type: 'textfield',
      key: 'companyName',
      label: 'Company Name',
      input: true
    }
  ],
  created: new Date(),
  modified: new Date()
});

// Create default role
db.roles.insertOne({
  title: 'Anonymous',
  name: 'anonymous', 
  default: true,
  admin: false,
  created: new Date(),
  modified: new Date()
});

print('✅ Enterprise database initialized');
EOF

echo ""
echo "🎉 Database initialization complete!"
echo "📊 Community DB: formio_community" 
echo "📊 Enterprise DB: formio_enterprise"
echo "🔗 Atlas Cluster: $ATLAS_HOST"
echo ""
echo "Next steps:"
echo "1. Restart Form.io services to connect to initialized databases"
echo "2. Test Form.io Community: https://dss-formio-api-com-dev-240287924786.australia-southeast1.run.app"
echo "3. Test Form.io Enterprise: https://dss-formio-api-ent-dev-240287924786.australia-southeast1.run.app"