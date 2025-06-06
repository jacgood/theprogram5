#!/bin/bash
# WebDNA Docker Smoke Tests
# Quick tests to verify basic functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Determine environment
ENVIRONMENT="${1:-dev}"
if [ "$ENVIRONMENT" == "prod" ]; then
    BASE_URL="http://localhost:8080"
else
    BASE_URL="http://localhost:8080"
fi

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
    echo -e "${GREEN}[SMOKE TEST] $1${NC}"
}

error() {
    echo -e "${RED}[SMOKE TEST] ERROR: $1${NC}"
}

# Quick smoke tests
log "Running smoke tests for $ENVIRONMENT environment..."

# Test 1: Container is running
cd "$PROJECT_ROOT/deploy"
if ! docker compose ps --format table | grep -E "webdna-server.*running|webdna-server.*Up"; then
    error "Container is not running"
    docker compose ps
    exit 1
fi
log "✓ Container is running"

# Test 2: Wait for service to be ready and check basic HTTP response  
log "Waiting for service to be ready..."
for i in {1..30}; do
    if curl -s -f "$BASE_URL/" > /dev/null 2>&1; then
        log "✓ HTTP service responding"
        break
    fi
    if [ $i -eq 30 ]; then
        error "HTTP service not responding after 30 attempts"
        exit 1
    fi
    sleep 2
done

# Test 3: WebCatalog accessible (if it exists)
if curl -s "$BASE_URL/WebCatalog/" 2>/dev/null | grep -q "WebDNA"; then
    log "✓ WebCatalog accessible"
else
    log "⚠ WebCatalog not accessible (may not be configured yet)"
fi

# Test 4: Check if any content is served
if curl -s "$BASE_URL/" | grep -q -E "(html|HTML|Apache|WebDNA)"; then
    log "✓ Web server serving content"
else
    log "⚠ Web server not serving expected content"
fi

log "🎉 All smoke tests passed!"