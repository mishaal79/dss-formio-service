#!/bin/sh
# Production wrapper script for Form.io Community Edition
# Assembles NODE_CONFIG from Secret Manager environment variables at runtime
# This prevents secrets from appearing in Terraform state files

set -e

echo "[$(date)] Starting Form.io Community wrapper script"

# Install jq if not available (Cloud Run containers should have this pre-installed)
if ! command -v jq >/dev/null 2>&1; then
    echo "[$(date)] Installing jq for JSON assembly..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache jq
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y jq
    else
        echo "[$(date)] ERROR: Cannot install jq - no supported package manager found"
        exit 1
    fi
fi

# Validate required environment variables
echo "[$(date)] Validating environment variables..."
for var in MONGO_URI JWT_SECRET DB_SECRET; do
    if [ -z "$(eval echo \$$var)" ]; then
        echo "[$(date)] ERROR: Required variable $var is not set"
        exit 1
    fi
done

# Build NODE_CONFIG using jq for safe JSON assembly
# jq's --arg flag properly escapes all special characters
echo "[$(date)] Assembling NODE_CONFIG..."
export NODE_CONFIG=$(jq -n \
    --arg mongo "$MONGO_URI" \
    --arg jwt "$JWT_SECRET" \
    --arg db "$DB_SECRET" \
    --arg host "$HOST" \
    --arg protocol "$PROTOCOL" \
    --argjson port "${PORT:-3001}" \
    --argjson trust "${TRUST_PROXY:-true}" \
    '{
        mongo: $mongo,
        port: $port,
        host: $host,
        protocol: $protocol,
        jwt: { secret: $jwt },
        db: { secret: $db },
        trust_proxy: $trust
    }')

# Validate JSON structure
if ! echo "$NODE_CONFIG" | jq empty 2>/dev/null; then
    echo "[$(date)] ERROR: Generated NODE_CONFIG is invalid JSON"
    exit 1
fi

echo "[$(date)] NODE_CONFIG assembled successfully"
echo "[$(date)] Configuration: $(echo "$NODE_CONFIG" | jq '{port: .port, trust_proxy: .trust_proxy, has_mongo: (.mongo != null), has_jwt: (.jwt.secret != null), has_db: (.db.secret != null)}')"

# Execute the original Form.io entrypoint
echo "[$(date)] Starting Form.io Community Edition..."
exec node main.js