#!/bin/bash
# Test Runner Script for DSS Form.io Service
# Following Qrius GCP Methodology - Terraform Native Testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_VERSION_MIN="1.6.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Terraform version
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    if ! [[ "$tf_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Unable to determine Terraform version"
        exit 1
    fi
    
    # Simple version comparison (assumes semantic versioning)
    if [[ "$(printf '%s\n' "$TERRAFORM_VERSION_MIN" "$tf_version" | sort -V | head -n1)" != "$TERRAFORM_VERSION_MIN" ]]; then
        log_error "Terraform version $tf_version is below minimum required $TERRAFORM_VERSION_MIN"
        exit 1
    fi
    
    log_success "Terraform version $tf_version meets requirements"
    
    # Check TFLint
    if ! command -v tflint &> /dev/null; then
        log_warning "TFLint is not installed. Quality checks will be limited."
    fi
    
    # Check TFSec
    if ! command -v tfsec &> /dev/null; then
        log_warning "TFSec is not installed. Security checks will be limited."
    fi
}

run_mock_tests() {
    log_info "Running mock tests (cost-free validation)..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Format check
    if ! terraform fmt -check -recursive .; then
        log_error "Terraform formatting issues found. Run 'terraform fmt -recursive .' to fix."
        return 1
    fi
    log_success "Terraform formatting is correct"
    
    # Validation check
    find . -name "*.tf" -path "./environments/*" -execdir terraform init -backend=false \; -execdir terraform validate \; 2>/dev/null || {
        log_error "Terraform validation failed"
        return 1
    }
    log_success "Terraform validation passed"
    
    # TFLint check (if available)
    if command -v tflint &> /dev/null; then
        if ! tflint --config="$PROJECT_ROOT/.tflint.hcl" --recursive; then
            log_error "TFLint checks failed"
            return 1
        fi
        log_success "TFLint checks passed"
    fi
    
    # TFSec check (if available)
    if command -v tfsec &> /dev/null; then
        if ! tfsec --config-file="$PROJECT_ROOT/.tfsec.yml" .; then
            log_error "TFSec security checks failed"
            return 1
        fi
        log_success "TFSec security checks passed"
    fi
    
    log_success "Mock tests completed successfully"
}

run_unit_tests() {
    log_info "Running unit tests (Terraform native testing)..."
    
    cd "$PROJECT_ROOT"
    
    # Find and run .tftest.hcl files
    local test_files
    test_files=$(find . -name "*.tftest.hcl" -not -path "./.terraform/*")
    
    if [ -z "$test_files" ]; then
        log_warning "No .tftest.hcl files found. Skipping unit tests."
        return 0
    fi
    
    local test_count=0
    local passed_count=0
    
    while IFS= read -r test_file; do
        test_count=$((test_count + 1))
        log_info "Running test: $test_file"
        
        # Navigate to test directory and run test
        local test_dir
        test_dir=$(dirname "$test_file")
        
        if (cd "$test_dir" && terraform test "$(basename "$test_file")"); then
            log_success "Test passed: $test_file"
            passed_count=$((passed_count + 1))
        else
            log_error "Test failed: $test_file"
        fi
    done <<< "$test_files"
    
    log_info "Unit test results: $passed_count/$test_count passed"
    
    if [ $passed_count -eq $test_count ]; then
        log_success "All unit tests passed"
        return 0
    else
        log_error "Some unit tests failed"
        return 1
    fi
}

run_integration_tests() {
    log_info "Running integration tests..."
    log_warning "Integration tests require actual GCP resources and will incur costs."
    
    # This would typically run terraform plan/apply in test environments
    # For now, we'll simulate with plan-only operations
    
    local environments=("dev" "staging")
    
    for env in "${environments[@]}"; do
        log_info "Testing environment: $env"
        
        local env_dir="$PROJECT_ROOT/terraform/environments/$env"
        if [ ! -d "$env_dir" ]; then
            log_warning "Environment directory not found: $env_dir"
            continue
        fi
        
        cd "$env_dir"
        
        # Initialize (without backend for testing)
        if ! terraform init -backend=false; then
            log_error "Failed to initialize $env environment"
            return 1
        fi
        
        # Plan (dry run)
        if ! terraform plan -var-file=terraform.tfvars -out="$env.tfplan"; then
            log_error "Planning failed for $env environment"
            return 1
        fi
        
        log_success "Integration test passed for $env environment"
        
        # Cleanup plan file
        rm -f "$env.tfplan"
    done
    
    log_success "Integration tests completed"
}

# Main execution
main() {
    local mode="${1:-all}"
    
    echo "🚀 DSS Form.io Service Test Runner"
    echo "Mode: $mode"
    echo "Project: $PROJECT_ROOT"
    echo ""
    
    check_prerequisites
    
    case "$mode" in
        "mock")
            run_mock_tests
            ;;
        "unit")
            run_unit_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "all")
            run_mock_tests && run_unit_tests && run_integration_tests
            ;;
        *)
            echo "Usage: $0 [mock|unit|integration|all]"
            echo ""
            echo "Test modes:"
            echo "  mock        - Cost-free validation (fmt, validate, lint, security)"
            echo "  unit        - Terraform native unit tests (.tftest.hcl files)"
            echo "  integration - Environment-specific testing (plan validation)"
            echo "  all         - Run all test modes (default)"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_success "All tests completed successfully! 🎉"
    else
        log_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"