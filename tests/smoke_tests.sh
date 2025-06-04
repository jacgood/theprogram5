#!/bin/bash
# WebDNA Docker Smoke Tests
# Quick tests to verify basic functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

BASE_URL="http://10.10.0.118:8080"

log() {
    echo -e "${GREEN}[SMOKE TEST] $1${NC}"
}

error() {
    echo -e "${RED}[SMOKE TEST] ERROR: $1${NC}"
}

# Quick smoke tests
log "Running smoke tests..."

# Test 1: Container is running
if ! docker compose ps | grep -q "webdna-server.*Up"; then
    error "Container is not running"
    exit 1
fi
log "✓ Container is running"

# Test 2: Basic HTTP response
if ! curl -s -f "$BASE_URL/" > /dev/null; then
    error "HTTP service not responding"
    exit 1
fi
log "✓ HTTP service responding"

# Test 3: WebCatalog accessible
if ! curl -s "$BASE_URL/WebCatalog/" | grep -q "WebDNA"; then
    error "WebCatalog not accessible"
    exit 1
fi
log "✓ WebCatalog accessible"

# Test 4: Main app accessible
if ! curl -s "$BASE_URL/theprogram/" | grep -q "Login"; then
    error "Main application not accessible"
    exit 1
fi
log "✓ Main application accessible"

log "🎉 All smoke tests passed!"