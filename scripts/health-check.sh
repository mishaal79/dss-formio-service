#!/bin/bash
# Multi-level health check validation for Cloud Run services
# Implements retry logic and performance validation
#
# Usage: ./scripts/health-check.sh <service-name> [region] [project-id]
# Example: ./scripts/health-check.sh formio-custom-dev australia-southeast1 erlich-dev

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME=${1:-}
REGION=${2:-australia-southeast1}
PROJECT_ID=${3:-erlich-dev}

# Health check parameters
MAX_RETRIES=10
RETRY_DELAY=3
RESPONSE_TIME_THRESHOLD=0.5  # 500ms

if [ -z "$SERVICE_NAME" ]; then
  echo -e "${RED}Error: Service name required${NC}"
  echo "Usage: $0 <service-name> [region] [project-id]"
  echo "Example: $0 formio-custom-dev australia-southeast1 erlich-dev"
  exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Health Check Validation${NC}"
echo -e "${BLUE}   Service: $SERVICE_NAME${NC}"
echo -e "${BLUE}   Region: $REGION${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Get service URL from gcloud
echo -e "${BLUE}→ Retrieving service URL...${NC}"
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format='value(status.url)' 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
  echo -e "${RED}❌ FAIL: Service not found or not deployed${NC}"
  echo ""
  echo "  Service: $SERVICE_NAME"
  echo "  Region: $REGION"
  echo "  Project: $PROJECT_ID"
  echo ""
  echo "  Resolution: Verify service name and ensure it's deployed"
  echo "    gcloud run services list --region=$REGION --project=$PROJECT_ID"
  exit 1
fi

echo -e "${GREEN}  Service URL: $SERVICE_URL${NC}"
echo ""

# Health endpoint (try common paths)
HEALTH_ENDPOINTS=("/health" "/healthz" "/_health" "/api/health")
HEALTH_URL=""

# Find working health endpoint
echo -e "${BLUE}→ Detecting health endpoint...${NC}"
for endpoint in "${HEALTH_ENDPOINTS[@]}"; do
  TEST_URL="${SERVICE_URL}${endpoint}"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "204" ]; then
    HEALTH_URL="$TEST_URL"
    echo -e "${GREEN}  Found health endpoint: $endpoint${NC}"
    break
  fi
done

# Fallback to root if no health endpoint found
if [ -z "$HEALTH_URL" ]; then
  echo -e "${YELLOW}  No standard health endpoint found, using root URL${NC}"
  HEALTH_URL="$SERVICE_URL/"
fi

echo ""

# Level 2: HTTP Health Check with Retries
echo -e "${BLUE}→ Running health checks (${MAX_RETRIES} retries, ${RETRY_DELAY}s delay)...${NC}"
echo ""

for i in $(seq 1 $MAX_RETRIES); do
  # Perform health check
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
  RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null "$HEALTH_URL" 2>/dev/null || echo "999")

  # Check if request succeeded
  if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "204" ]; then
    # Check response time
    if (( $(echo "$RESPONSE_TIME < $RESPONSE_TIME_THRESHOLD" | bc -l) )); then
      echo -e "${GREEN}✅ PASS: Health check successful${NC}"
      echo ""
      echo "  HTTP Status: $HTTP_CODE"
      echo "  Response Time: ${RESPONSE_TIME}s (threshold: ${RESPONSE_TIME_THRESHOLD}s)"
      echo "  Retry Attempt: $i/$MAX_RETRIES"
      echo ""
      echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
      echo -e "${GREEN}   Service is healthy and ready for traffic${NC}"
      echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
      exit 0
    else
      echo -e "  ${YELLOW}Retry $i/$MAX_RETRIES: HTTP $HTTP_CODE, ${RESPONSE_TIME}s (too slow)${NC}"
    fi
  else
    echo -e "  ${YELLOW}Retry $i/$MAX_RETRIES: HTTP $HTTP_CODE${NC}"
  fi

  # Wait before retry (except on last attempt)
  if [ $i -lt $MAX_RETRIES ]; then
    sleep $RETRY_DELAY
  fi
done

# All retries exhausted
echo ""
echo -e "${RED}❌ FAIL: Health check failed after $MAX_RETRIES retries${NC}"
echo ""
echo "  Service URL: $HEALTH_URL"
echo "  Last HTTP Status: $HTTP_CODE"
echo "  Last Response Time: ${RESPONSE_TIME}s"
echo ""
echo "  Resolution: Check service logs for errors"
echo "    gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\" \\"
echo "      --project=$PROJECT_ID --limit=50"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
exit 1
