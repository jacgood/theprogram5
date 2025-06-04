#!/bin/bash
# WebDNA Docker Integration Tests
# Tests all critical functionality to ensure nothing breaks during refactoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
CONTAINER_NAME="webdna-server"
BASE_URL="http://10.10.0.118:8080"
TIMEOUT=30

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for service at $url to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "Service is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    error "Service at $url failed to become ready after $((max_attempts * 2)) seconds"
    return 1
}

# Test HTTP response
test_http_response() {
    local url=$1
    local expected_status=${2:-200}
    local description=$3
    
    log "Testing: $description"
    log "URL: $url"
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/response.txt "$url")
    
    if [ "$response" = "$expected_status" ]; then
        log "✓ PASS: Got expected status $expected_status"
        return 0
    else
        error "✗ FAIL: Expected $expected_status, got $response"
        if [ -f /tmp/response.txt ]; then
            echo "Response content:"
            head -10 /tmp/response.txt
        fi
        return 1
    fi
}

# Test content contains expected text
test_content_contains() {
    local url=$1
    local expected_text=$2
    local description=$3
    
    log "Testing content: $description"
    
    local content=$(curl -s "$url")
    
    if echo "$content" | grep -q "$expected_text"; then
        log "✓ PASS: Found expected content '$expected_text'"
        return 0
    else
        error "✗ FAIL: Expected content '$expected_text' not found"
        echo "Actual content preview:"
        echo "$content" | head -5
        return 1
    fi
}

# Test Docker container status
test_container_status() {
    log "Testing Docker container status..."
    
    if docker compose ps | grep -q "$CONTAINER_NAME.*Up"; then
        log "✓ PASS: Container is running"
        return 0
    else
        error "✗ FAIL: Container is not running"
        docker compose ps
        return 1
    fi
}

# Test WebDNA process
test_webdna_process() {
    log "Testing WebDNA process..."
    
    if docker compose exec webdna-server pgrep WebCatalog > /dev/null; then
        log "✓ PASS: WebCatalog process is running"
        return 0
    else
        error "✗ FAIL: WebCatalog process not found"
        return 1
    fi
}

# Main test suite
run_tests() {
    local failed=0
    
    log "Starting WebDNA Integration Tests"
    log "======================================="
    
    # Test 1: Container Status
    test_container_status || failed=$((failed + 1))
    
    # Test 2: Wait for services
    wait_for_service "$BASE_URL/WebCatalog/" || failed=$((failed + 1))
    
    # Test 3: WebDNA Process
    test_webdna_process || failed=$((failed + 1))
    
    # Test 4: Root URL
    test_http_response "$BASE_URL/" 200 "Root URL accessibility" || failed=$((failed + 1))
    
    # Test 5: WebCatalog Admin
    test_http_response "$BASE_URL/WebCatalog/" 200 "WebCatalog admin interface" || failed=$((failed + 1))
    test_content_contains "$BASE_URL/WebCatalog/" "WebDNA Administration" "WebCatalog admin page content" || failed=$((failed + 1))
    
    # Test 6: The Program (main application)
    test_http_response "$BASE_URL/theprogram/" 200 "Main application (/theprogram/)" || failed=$((failed + 1))
    test_content_contains "$BASE_URL/theprogram/" "Login - GVI WebApp" "Main application content" || failed=$((failed + 1))
    
    # Test 7: Application aliases
    test_http_response "$BASE_URL/client/" 200 "Client area alias" || failed=$((failed + 1))
    test_http_response "$BASE_URL/WebCatalog/" 200 "WebCatalog alias" || failed=$((failed + 1))
    
    # Test 8: WebDNA functionality test
    test_content_contains "$BASE_URL/" "2=2" "WebDNA math processing" || failed=$((failed + 1))
    
    # Test 9: File permissions (check if www-data can read files)
    if docker compose exec webdna-server test -r /var/www/html/AIS/I/C/IT.TPL; then
        log "✓ PASS: File permissions are correct"
    else
        error "✗ FAIL: File permission issues detected"
        failed=$((failed + 1))
    fi
    
    # Test 10: Apache modules
    if docker compose exec webdna-server apache2ctl -M | grep -q "webcatalog2_module"; then
        log "✓ PASS: WebDNA module is loaded"
    else
        error "✗ FAIL: WebDNA module not loaded"
        failed=$((failed + 1))
    fi
    
    log "======================================="
    
    if [ $failed -eq 0 ]; then
        log "🎉 ALL TESTS PASSED! ($failed failures)"
        return 0
    else
        error "❌ TESTS FAILED: $failed test(s) failed"
        return 1
    fi
}

# Cleanup function
cleanup() {
    rm -f /tmp/response.txt
}

# Trap cleanup
trap cleanup EXIT

# Run the tests
run_tests