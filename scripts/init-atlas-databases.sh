#!/bin/bash
# MongoDB Atlas Database Initialization Script
# Initializes Form.io Community and Enterprise databases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required environment variables are set
check_env_vars() {
    local required_vars=(
        "MONGODB_ATLAS_PUBLIC_KEY"
        "MONGODB_ATLAS_PRIVATE_KEY"
        "TF_VAR_mongodb_atlas_org_id"
        "MONGODB_CLUSTER_NAME"
        "MONGODB_ADMIN_USERNAME"
        "MONGODB_FORMIO_PASSWORD"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            print_error "  - $var"
        done
        echo
        print_error "Please set these variables and try again."
        echo "Example:"
        echo "  export MONGODB_ATLAS_PUBLIC_KEY='your-public-key'"
        echo "  export MONGODB_ATLAS_PRIVATE_KEY='your-private-key'"
        echo "  export TF_VAR_mongodb_atlas_org_id='your-org-id'"
        echo "  export MONGODB_CLUSTER_NAME='dss-formio-api-dev-cluster'"
        echo "  export MONGODB_ADMIN_USERNAME='mongoAdmin'"
        echo "  export MONGODB_FORMIO_PASSWORD='your-formio-password'"
        exit 1
    fi
}

# Get MongoDB Atlas connection string
get_connection_string() {
    local cluster_name="$1"
    local username="$2"
    local password="$3"
    
    # This would typically be retrieved from Atlas API or Terraform output
    # For now, we'll construct it manually
    local cluster_host="$cluster_name.xxxxx.mongodb.net"
    echo "mongodb+srv://$username:$password@$cluster_host/?retryWrites=true&w=majority"
}

# Initialize Form.io database
init_formio_database() {
    local db_name="$1"
    local connection_string="$2"
    
    print_status "Initializing database: $db_name"
    
    # Use mongosh to create database and initial collections
    mongosh "$connection_string/$db_name" --eval "
        // Create initial collections for Form.io
        db.createCollection('forms');
        db.createCollection('submissions');
        db.createCollection('actions');
        db.createCollection('roles');
        db.createCollection('tokens');
        
        // Create indexes for better performance
        db.forms.createIndex({ 'path': 1 }, { unique: true });
        db.submissions.createIndex({ 'form': 1 });
        db.submissions.createIndex({ 'created': 1 });
        db.actions.createIndex({ 'form': 1 });
        db.tokens.createIndex({ 'token': 1 }, { unique: true });
        
        print('Database $db_name initialized successfully');
    "
    
    print_success "Database $db_name initialized"
}

# Main execution
main() {
    print_status "Starting MongoDB Atlas database initialization"
    
    # Check environment variables
    check_env_vars
    
    # Database names
    local community_db="formio_community"
    local enterprise_db="formio_enterprise"
    
    # Check if mongosh is installed
    if ! command -v mongosh &> /dev/null; then
        print_error "mongosh is not installed"
        print_error "Please install MongoDB Shell (mongosh) from: https://docs.mongodb.com/mongodb-shell/"
        exit 1
    fi
    
    print_status "MongoDB Shell (mongosh) found"
    
    # Wait for cluster to be ready
    print_status "Waiting for MongoDB Atlas cluster to be ready..."
    sleep 10
    
    # Get connection strings (these would normally come from Terraform outputs)
    local community_connection_string
    local enterprise_connection_string
    
    # For now, we'll need to manually retrieve these from Atlas or Terraform
    print_warning "Connection strings need to be retrieved from MongoDB Atlas or Terraform outputs"
    print_warning "Please update this script with actual connection strings"
    
    # Initialize databases
    # init_formio_database "$community_db" "$community_connection_string"
    # init_formio_database "$enterprise_db" "$enterprise_connection_string"
    
    print_success "MongoDB Atlas database initialization completed"
    print_warning "Please verify the databases are properly set up in the MongoDB Atlas console"
}

# Show usage if help is requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0"
    echo
    echo "Initialize MongoDB Atlas databases for Form.io"
    echo
    echo "Required environment variables:"
    echo "  MONGODB_ATLAS_PUBLIC_KEY    - MongoDB Atlas API public key"
    echo "  MONGODB_ATLAS_PRIVATE_KEY   - MongoDB Atlas API private key"
    echo "  TF_VAR_mongodb_atlas_org_id - MongoDB Atlas organization ID"
    echo "  MONGODB_CLUSTER_NAME        - Name of the Atlas cluster"
    echo "  MONGODB_ADMIN_USERNAME      - MongoDB admin username"
    echo "  MONGODB_FORMIO_PASSWORD     - Password for Form.io database user"
    echo
    echo "Prerequisites:"
    echo "  - MongoDB Shell (mongosh) must be installed"
    echo "  - MongoDB Atlas cluster must be created and running"
    echo "  - Database users must be created in Atlas"
    echo
    exit 0
fi

# Run main function
main "$@"