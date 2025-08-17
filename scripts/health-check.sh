#!/bin/bash
# MongoDB Atlas and Form.io Health Check Script
# Validates connectivity and security settings

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if required environment variables are set
check_environment() {
    print_header "ENVIRONMENT CHECK"
    
    local required_vars=(
        "MONGODB_ATLAS_PUBLIC_KEY"
        "MONGODB_ATLAS_PRIVATE_KEY"
        "TF_VAR_mongodb_atlas_org_id"
    )
    
    local all_set=true
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "$var is not set"
            all_set=false
        else
            print_success "$var is configured"
        fi
    done
    
    return $all_set
}

# Test MongoDB Atlas API connectivity
test_atlas_api() {
    print_header "MONGODB ATLAS API TEST"
    
    print_status "Testing Atlas API connectivity..."
    
    local response
    if response=$(curl -s --user "${MONGODB_ATLAS_PUBLIC_KEY}:${MONGODB_ATLAS_PRIVATE_KEY}" \
         "https://cloud.mongodb.com/api/atlas/v1.0/orgs/${TF_VAR_mongodb_atlas_org_id}" 2>&1); then
        print_success "Atlas API connectivity verified"
        
        # Extract organization name if possible
        if echo "$response" | grep -q '"name"'; then
            local org_name
            org_name=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/')
            print_success "Connected to organization: $org_name"
        fi
        return 0
    else
        print_error "Failed to connect to Atlas API"
        print_error "Response: $response"
        return 1
    fi
}

# Check Terraform Atlas cluster status
check_atlas_cluster() {
    print_header "ATLAS CLUSTER STATUS"
    
    if [[ ! -d "terraform/environments/dev" ]]; then
        print_error "Terraform directory not found"
        return 1
    fi
    
    cd terraform/environments/dev
    
    if [[ ! -f "terraform.tfstate" ]]; then
        print_warning "No Terraform state found - cluster may not be deployed yet"
        cd - > /dev/null
        return 1
    fi
    
    print_status "Checking Atlas cluster status from Terraform state..."
    
    local cluster_state
    if cluster_state=$(terraform output -raw mongodb_atlas_cluster_state 2>/dev/null); then
        print_status "Cluster state: $cluster_state"
        
        case "$cluster_state" in
            "IDLE")
                print_success "Atlas cluster is ready and operational"
                ;;
            "CREATING")
                print_warning "Atlas cluster is still being created"
                ;;
            "UPDATING")
                print_warning "Atlas cluster is being updated"
                ;;
            *)
                print_warning "Atlas cluster state: $cluster_state"
                ;;
        esac
    else
        print_warning "Could not retrieve cluster state from Terraform"
    fi
    
    local cluster_name
    if cluster_name=$(terraform output -raw mongodb_atlas_cluster_name 2>/dev/null); then
        print_success "Cluster name: $cluster_name"
    fi
    
    local project_id
    if project_id=$(terraform output -raw mongodb_atlas_project_id 2>/dev/null); then
        print_success "Atlas project ID: $project_id"
    fi
    
    cd - > /dev/null
}

# Test Form.io service connectivity
test_formio_services() {
    print_header "FORM.IO SERVICES TEST"
    
    local services=("dss-formio-api-com-dev" "dss-formio-api-ent-dev")
    local region="australia-southeast1"
    local project_id="erlich-dev"
    
    for service in "${services[@]}"; do
        print_status "Checking service: $service"
        
        local service_url
        if service_url=$(gcloud run services describe "$service" \
            --region="$region" \
            --project="$project_id" \
            --format='value(status.url)' 2>/dev/null); then
            
            print_success "Service URL: $service_url"
            
            # Test health endpoint
            print_status "Testing health endpoint..."
            if curl -s --max-time 10 "$service_url/health" > /dev/null; then
                print_success "$service is responding"
            else
                print_warning "$service health check failed (normal for new deployment)"
            fi
        else
            print_error "Could not get URL for service: $service"
        fi
    done
}

# Check GCP Secret Manager secrets
check_secrets() {
    print_header "SECRET MANAGER CHECK"
    
    local secrets=(
        "dss-formio-api-mongodb-community-connection-string-dev"
        "dss-formio-api-mongodb-enterprise-connection-string-dev"
        "dss-formio-api-formio-root-password-dev"
        "dss-formio-api-mongodb-admin-password-dev"
        "dss-formio-api-mongodb-formio-password-dev"
    )
    
    for secret in "${secrets[@]}"; do
        if gcloud secrets versions access latest --secret="$secret" --project="erlich-dev" > /dev/null 2>&1; then
            print_success "Secret exists: $secret"
        else
            print_warning "Secret not found or inaccessible: $secret"
        fi
    done
}

# Test database connectivity (if mongosh is available)
test_database_connectivity() {
    print_header "DATABASE CONNECTIVITY TEST"
    
    if ! command -v mongosh &> /dev/null; then
        print_warning "mongosh not installed - skipping database connectivity test"
        print_status "To install: https://docs.mongodb.com/mongodb-shell/"
        return 0
    fi
    
    cd terraform/environments/dev
    
    local connection_string
    if connection_string=$(terraform output -raw mongodb_connection_strings_srv 2>/dev/null); then
        print_status "Testing MongoDB connection..."
        
        # Test basic connectivity (timeout after 5 seconds)
        if timeout 5s mongosh "$connection_string" --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
            print_success "MongoDB connection successful"
        else
            print_warning "MongoDB connection failed (cluster may still be initializing)"
        fi
    else
        print_warning "Could not retrieve connection string"
    fi
    
    cd - > /dev/null
}

# Main health check
main() {
    print_header "MONGODB ATLAS & FORM.IO HEALTH CHECK"
    
    local errors=0
    
    # Load environment if .env exists
    if [[ -f ".env" ]]; then
        print_status "Loading environment variables from .env"
        source .env
    fi
    
    # Run all checks
    check_environment || ((errors++))
    test_atlas_api || ((errors++))
    check_atlas_cluster || ((errors++))
    test_formio_services || ((errors++))
    check_secrets || ((errors++))
    test_database_connectivity || ((errors++))
    
    print_header "HEALTH CHECK SUMMARY"
    
    if [[ $errors -eq 0 ]]; then
        print_success "All health checks passed!"
    else
        print_warning "$errors check(s) failed or showed warnings"
        print_status "This is normal for new deployments - services may need time to initialize"
    fi
    
    print_status "For detailed logs, run: make logs-com or make logs-ent"
    print_status "For service status, run: make status"
    print_status "For Atlas monitoring, visit: https://cloud.mongodb.com"
}

# Show usage if help is requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0"
    echo
    echo "Performs comprehensive health checks for MongoDB Atlas and Form.io services"
    echo
    echo "Checks:"
    echo "  - Environment variables"
    echo "  - MongoDB Atlas API connectivity"
    echo "  - Atlas cluster status"
    echo "  - Form.io service health"
    echo "  - GCP Secret Manager"
    echo "  - Database connectivity (if mongosh available)"
    echo
    echo "Prerequisites:"
    echo "  - .env file with Atlas credentials"
    echo "  - gcloud CLI configured"
    echo "  - Terraform state (for cluster info)"
    echo "  - mongosh (optional, for database tests)"
    echo
    exit 0
fi

# Run main function
main "$@"