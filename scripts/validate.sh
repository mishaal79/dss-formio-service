#!/bin/bash
# Pre-deploy validation gates for Continuous Delivery pipeline
# Implements 5 validation checks to prevent bad deployments
#
# Usage: ./scripts/validate.sh [environment]
# Example: ./scripts/validate.sh dev

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform/environments/$ENV"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Continuous Delivery Validation Gates${NC}"
echo -e "${BLUE}   Environment: $ENV${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Track overall status
VALIDATION_PASSED=true

# Gate 1: Git Clean Check
# Ensures all changes are committed before deployment
gate_1_git_clean() {
  echo -e "${BLUE}→ Validation Gate 1: Git Clean Check${NC}"
  echo "  Ensures no uncommitted changes exist"

  if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}❌ FAIL: Uncommitted changes detected${NC}"
    echo ""
    echo "  Uncommitted files:"
    git status --short | sed 's/^/    /'
    echo ""
    echo "  Resolution: Commit or stash changes before deployment"
    echo "    git add -A && git commit -m 'Your commit message'"
    echo ""
    return 1
  fi

  echo -e "${GREEN}✅ PASS: Git working directory is clean${NC}"
  echo ""
  return 0
}

# Gate 2: Terraform Format Check
# Ensures consistent Terraform code formatting
gate_2_terraform_fmt() {
  echo -e "${BLUE}→ Validation Gate 2: Terraform Format${NC}"
  echo "  Ensures canonical formatting (terraform fmt)"

  cd "$PROJECT_ROOT"

  # Check formatting without making changes
  if ! terraform fmt -check -recursive terraform/ > /dev/null 2>&1; then
    echo -e "${RED}❌ FAIL: Terraform files are not properly formatted${NC}"
    echo ""
    echo "  Files requiring formatting:"
    terraform fmt -check -recursive terraform/ 2>&1 | grep -v "Formatting" | sed 's/^/    /'
    echo ""
    echo "  Resolution: Run 'terraform fmt -recursive terraform/'"
    echo "    make format"
    echo ""
    return 1
  fi

  echo -e "${GREEN}✅ PASS: All Terraform files properly formatted${NC}"
  echo ""
  return 0
}

# Gate 3: Terraform Validate
# Checks for Terraform syntax and configuration errors
gate_3_terraform_validate() {
  echo -e "${BLUE}→ Validation Gate 3: Terraform Validate${NC}"
  echo "  Checks for syntax errors and invalid configuration"

  if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}❌ FAIL: Environment directory not found: $TF_DIR${NC}"
    echo ""
    echo "  Available environments:"
    ls -1 "$PROJECT_ROOT/terraform/environments/" | sed 's/^/    /'
    echo ""
    return 1
  fi

  cd "$TF_DIR"

  # Initialize if needed (quietly)
  if [ ! -d ".terraform" ]; then
    echo "  Initializing Terraform..."
    if ! terraform init -input=false > /dev/null 2>&1; then
      echo -e "${RED}❌ FAIL: Terraform initialization failed${NC}"
      echo ""
      echo "  Resolution: Fix initialization errors"
      echo "    cd $TF_DIR && terraform init"
      echo ""
      return 1
    fi
  fi

  # Validate configuration
  if ! terraform validate > /dev/null 2>&1; then
    echo -e "${RED}❌ FAIL: Terraform validation errors detected${NC}"
    echo ""
    echo "  Validation errors:"
    terraform validate 2>&1 | sed 's/^/    /'
    echo ""
    echo "  Resolution: Fix Terraform syntax/configuration errors"
    echo ""
    return 1
  fi

  echo -e "${GREEN}✅ PASS: Terraform configuration is valid${NC}"
  echo ""
  return 0
}

# Gate 4: TFLint Check
# Lints Terraform code for best practices and potential issues
gate_4_tflint() {
  echo -e "${BLUE}→ Validation Gate 4: TFLint${NC}"
  echo "  Checks for Terraform best practices and potential errors"

  if ! command -v tflint >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  SKIP: tflint not installed${NC}"
    echo "  Install: brew install tflint"
    echo ""
    return 0
  fi

  cd "$TF_DIR"

  # Run tflint
  if ! tflint --chdir="$TF_DIR" 2>&1 | tee /tmp/tflint-output.txt | grep -q "No issues found"; then
    if grep -q "Error" /tmp/tflint-output.txt || grep -q "Warning" /tmp/tflint-output.txt; then
      echo -e "${RED}❌ FAIL: TFLint detected issues${NC}"
      echo ""
      echo "  Issues found:"
      cat /tmp/tflint-output.txt | sed 's/^/    /'
      echo ""
      echo "  Resolution: Fix linting issues or update .tflint.hcl to ignore"
      echo ""
      rm -f /tmp/tflint-output.txt
      return 1
    fi
  fi

  rm -f /tmp/tflint-output.txt
  echo -e "${GREEN}✅ PASS: No TFLint issues found${NC}"
  echo ""
  return 0
}

# Gate 5: Checkov Security Scan
# Scans Terraform for security and compliance issues
gate_5_checkov() {
  echo -e "${BLUE}→ Validation Gate 5: Checkov Security Scan${NC}"
  echo "  Scans for security vulnerabilities and compliance issues"

  # Check for checkov or uvx (universal package runner)
  if command -v checkov >/dev/null 2>&1; then
    CHECKOV_CMD="checkov"
  elif command -v uvx >/dev/null 2>&1; then
    CHECKOV_CMD="uvx checkov"
  else
    echo -e "${YELLOW}⚠️  SKIP: checkov not installed${NC}"
    echo "  Install: pip install checkov OR install uvx"
    echo ""
    return 0
  fi

  cd "$PROJECT_ROOT"

  # Run security scan (compact output, fail on critical issues)
  if ! $CHECKOV_CMD -d "$TF_DIR" --framework terraform --compact --quiet > /tmp/checkov-output.txt 2>&1; then
    # Check if there are actual failures (not just warnings)
    if grep -q "Failed checks:" /tmp/checkov-output.txt; then
      echo -e "${RED}❌ FAIL: Security issues detected by Checkov${NC}"
      echo ""
      echo "  Security scan results:"
      cat /tmp/checkov-output.txt | sed 's/^/    /'
      echo ""
      echo "  Resolution: Fix security issues or add skip comments for exceptions"
      echo "    #checkov:skip=CKV_GCP_XXX:Reason for skip"
      echo ""
      rm -f /tmp/checkov-output.txt
      return 1
    fi
  fi

  rm -f /tmp/checkov-output.txt
  echo -e "${GREEN}✅ PASS: No critical security issues found${NC}"
  echo ""
  return 0
}

# Execute all validation gates
echo ""

# Run all gates (continue even if some fail to show all issues)
gate_1_git_clean || VALIDATION_PASSED=false
gate_2_terraform_fmt || VALIDATION_PASSED=false
gate_3_terraform_validate || VALIDATION_PASSED=false
gate_4_tflint || VALIDATION_PASSED=false
gate_5_checkov || VALIDATION_PASSED=false

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
if [ "$VALIDATION_PASSED" = true ]; then
  echo -e "${GREEN}✅ All validation gates passed${NC}"
  echo -e "${GREEN}   Deployment can proceed safely${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  exit 0
else
  echo -e "${RED}❌ Validation failed${NC}"
  echo -e "${RED}   Deployment blocked - fix issues above${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  exit 1
fi
