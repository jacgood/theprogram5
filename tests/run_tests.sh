#!/bin/bash
# WebDNA Test Runner
# Runs all test suites and reports results

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log() {
    echo -e "${BLUE}[TEST RUNNER] $1${NC}"
}

success() {
    echo -e "${GREEN}[TEST RUNNER] $1${NC}"
}

error() {
    echo -e "${RED}[TEST RUNNER] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[TEST RUNNER] $1${NC}"
}

# Function to run a test suite
run_test_suite() {
    local test_name=$1
    local test_script=$2
    
    log "Running $test_name..."
    echo "=================================================="
    
    if [ ! -f "$test_script" ]; then
        error "Test script not found: $test_script"
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        error "Test script not executable: $test_script"
        return 1
    fi
    
    if "$test_script"; then
        success "✓ $test_name PASSED"
        return 0
    else
        error "✗ $test_name FAILED"
        return 1
    fi
}

# Main test runner
main() {
    local failed=0
    local total=0
    
    log "WebDNA Test Suite Runner"
    log "Project root: $PROJECT_ROOT"
    log "Test directory: $SCRIPT_DIR"
    
    # Change to project root  
    cd "$PROJECT_ROOT"
    
    # Ensure we have a working container before testing
    log "Ensuring container is running with new configuration..."
    echo "Stopping WebDNA services..."
    cd "$PROJECT_ROOT/deploy" && docker compose down
    echo "Building WebDNA Docker image..."
    cd "$PROJECT_ROOT/deploy" && docker compose build
    echo "Starting WebDNA services..."
    cd "$PROJECT_ROOT/deploy" && docker compose up -d
    
    echo ""
    log "Starting test execution..."
    echo ""
    
    # Run smoke tests first
    total=$((total + 1))
    if ! run_test_suite "Smoke Tests" "$SCRIPT_DIR/smoke_tests.sh"; then
        failed=$((failed + 1))
        error "Smoke tests failed - stopping execution"
        exit 1
    fi
    
    echo ""
    
    # Run integration tests
    total=$((total + 1))
    if ! run_test_suite "Integration Tests" "$SCRIPT_DIR/integration_tests.sh"; then
        failed=$((failed + 1))
    fi
    
    echo ""
    echo "=================================================="
    
    # Final report
    if [ $failed -eq 0 ]; then
        success "🎉 ALL TEST SUITES PASSED ($total/$total)"
        success "System is ready for refactoring!"
        exit 0
    else
        error "❌ TEST FAILURES: $failed/$total test suites failed"
        error "Please fix issues before proceeding with refactoring"
        exit 1
    fi
}

# Run with error handling
if ! main "$@"; then
    error "Test execution failed"
    exit 1
fi