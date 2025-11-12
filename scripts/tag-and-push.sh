#!/bin/bash
# =============================================================================
# Form.io Custom Image - Build, Tag, and Push Script
# =============================================================================
# This script builds the Form.io custom Docker image with proper tagging
# strategy for CI/CD deployments.
#
# Usage:
#   ./scripts/tag-and-push.sh [strategy] [custom-tag]
#
# Strategies:
#   git-sha     - Use Git commit SHA (default, recommended for CI/CD)
#   semver      - Use semantic version (requires VERSION file or argument)
#   timestamp   - Use timestamp + Git SHA
#   latest      - Use "latest" tag (not recommended for production)
#
# Examples:
#   ./scripts/tag-and-push.sh                  # Uses git-sha strategy
#   ./scripts/tag-and-push.sh git-sha          # Explicit git-sha
#   ./scripts/tag-and-push.sh semver v1.2.3    # Custom semantic version
#   ./scripts/tag-and-push.sh timestamp        # Timestamp + SHA
#   ./scripts/tag-and-push.sh latest           # Latest tag
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

PROJECT_ID="${GCP_PROJECT_ID:-erlich-dev}"
IMAGE_NAME="formio-custom"
DOCKERFILE_PATH="formio/Dockerfile"
BUILD_CONTEXT="."
PLATFORM="linux/amd64"

# -----------------------------------------------------------------------------
# Color Output
# -----------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

log_error() {
    echo -e "${RED}✗ ${NC}$1"
}

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

get_git_sha() {
    git rev-parse --short=7 HEAD
}

get_timestamp() {
    date +%Y%m%d-%H%M%S
}

get_semver() {
    local custom_version="$1"

    if [[ -n "$custom_version" ]]; then
        echo "$custom_version"
    elif [[ -f "VERSION" ]]; then
        cat VERSION
    else
        log_error "No semantic version provided and VERSION file not found"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Image Tagging Strategies
# -----------------------------------------------------------------------------

tag_git_sha() {
    local sha=$(get_git_sha)
    echo "git-${sha}"
}

tag_semver() {
    local version=$(get_semver "$1")
    # Remove 'v' prefix if present
    version="${version#v}"
    echo "v${version}"
}

tag_timestamp() {
    local timestamp=$(get_timestamp)
    local sha=$(get_git_sha)
    echo "${timestamp}-${sha}"
}

tag_latest() {
    echo "latest"
}

# -----------------------------------------------------------------------------
# Main Logic
# -----------------------------------------------------------------------------

main() {
    local strategy="${1:-git-sha}"
    local custom_tag="${2:-}"

    log_info "Starting Form.io Custom Docker image build"
    log_info "Strategy: ${strategy}"

    # Generate tag based on strategy
    case "$strategy" in
        git-sha)
            IMAGE_TAG=$(tag_git_sha)
            ;;
        semver)
            IMAGE_TAG=$(tag_semver "$custom_tag")
            ;;
        timestamp)
            IMAGE_TAG=$(tag_timestamp)
            ;;
        latest)
            IMAGE_TAG=$(tag_latest)
            log_warning "Using 'latest' tag - not recommended for production"
            ;;
        *)
            log_error "Unknown strategy: $strategy"
            echo "Valid strategies: git-sha, semver, timestamp, latest"
            exit 1
            ;;
    esac

    local FULL_IMAGE_PATH="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

    log_info "Image tag: ${IMAGE_TAG}"
    log_info "Full path: ${FULL_IMAGE_PATH}"

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Build image
    log_info "Building Docker image..."
    docker buildx build \
        --platform "${PLATFORM}" \
        -t "${FULL_IMAGE_PATH}" \
        -f "${DOCKERFILE_PATH}" \
        "${BUILD_CONTEXT}"

    log_success "Image built successfully"

    # Tag with 'latest' if not already using it
    if [[ "$IMAGE_TAG" != "latest" ]]; then
        local LATEST_PATH="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest"
        log_info "Tagging as latest: ${LATEST_PATH}"
        docker tag "${FULL_IMAGE_PATH}" "${LATEST_PATH}"
    fi

    # Push to GCR
    log_info "Pushing image to Google Container Registry..."
    docker push "${FULL_IMAGE_PATH}"

    if [[ "$IMAGE_TAG" != "latest" ]]; then
        docker push "gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest"
    fi

    log_success "Image pushed successfully"

    # Output Terraform variable
    echo ""
    log_success "Deployment complete!"
    echo ""
    echo "Update your Terraform configuration with:"
    echo ""
    echo "  custom_image_tag = \"${IMAGE_TAG}\""
    echo ""
    echo "Or set environment variable:"
    echo ""
    echo "  export TF_VAR_custom_image_tag=\"${IMAGE_TAG}\""
    echo ""
}

# -----------------------------------------------------------------------------
# Script Entry Point
# -----------------------------------------------------------------------------

main "$@"
