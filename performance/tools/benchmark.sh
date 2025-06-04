#!/bin/bash
# WebDNA Performance Benchmarking Tool
# Tests application performance under various load conditions

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="webdna-benchmark"
readonly RESULTS_DIR="$(pwd)/logs/benchmarks"
readonly BASE_URL="http://localhost:8080"
readonly USER_AGENT="WebDNA-Benchmark/1.0"

# Test configuration
readonly DEFAULT_REQUESTS=100
readonly DEFAULT_CONCURRENCY=10
readonly DEFAULT_DURATION=60

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[$timestamp] [INFO] $message${NC}" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" ;;
        "ERROR") echo -e "${RED}[$timestamp] [ERROR] $message${NC}" ;;
        "DEBUG") echo -e "${BLUE}[$timestamp] [DEBUG] $message${NC}" ;;
    esac
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }
debug() { log "DEBUG" "$@"; }

# Initialize benchmarking
init_benchmark() {
    info "Initializing performance benchmarking..."
    mkdir -p "$RESULTS_DIR"
    chmod 755 "$RESULTS_DIR"
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required for benchmarking"
        exit 1
    fi
    
    if ! command -v ab >/dev/null 2>&1; then
        warn "Apache Bench (ab) not available - installing..."
        docker exec webdna-server apt-get update >/dev/null 2>&1 || true
        docker exec webdna-server apt-get install -y apache2-utils >/dev/null 2>&1 || warn "Could not install apache2-utils"
    fi
}

# Single request performance test
test_single_request() {
    local url=$1
    local test_name=$2
    
    info "Testing single request performance: $test_name"
    
    local result=$(curl -w "@-" -o /dev/null -s "$url" << 'EOF'
{
  "url": "%{url_effective}",
  "http_code": %{http_code},
  "time_namelookup": %{time_namelookup},
  "time_connect": %{time_connect},
  "time_appconnect": %{time_appconnect},
  "time_pretransfer": %{time_pretransfer},
  "time_redirect": %{time_redirect},
  "time_starttransfer": %{time_starttransfer},
  "time_total": %{time_total},
  "speed_download": %{speed_download},
  "speed_upload": %{speed_upload},
  "size_download": %{size_download},
  "size_upload": %{size_upload}
}
EOF
)
    
    echo "$result" | jq . 2>/dev/null || echo "$result"
    return 0
}

# Load testing with Apache Bench
test_load_ab() {
    local url=$1
    local requests=$2
    local concurrency=$3
    local test_name=$4
    local output_file="$RESULTS_DIR/ab_${test_name}_$(date '+%Y%m%d_%H%M%S').txt"
    
    info "Running Apache Bench load test: $test_name ($requests requests, $concurrency concurrent)"
    
    if command -v ab >/dev/null 2>&1; then
        ab -n "$requests" -c "$concurrency" -g "$output_file.gnuplot" "$url" > "$output_file" 2>&1
        
        # Parse results
        local rps=$(grep "Requests per second" "$output_file" | awk '{print $4}')
        local time_per_request=$(grep "Time per request.*mean" "$output_file" | head -1 | awk '{print $4}')
        local transfer_rate=$(grep "Transfer rate" "$output_file" | awk '{print $3}')
        local failed_requests=$(grep "Failed requests" "$output_file" | awk '{print $3}')
        
        info "Results: ${rps} req/sec, ${time_per_request}ms avg, ${failed_requests} failed"
        
        echo "{\"test\":\"$test_name\",\"requests_per_second\":$rps,\"avg_time_ms\":$time_per_request,\"failed_requests\":$failed_requests,\"transfer_rate\":\"$transfer_rate\"}" >> "$RESULTS_DIR/benchmark_results.json"
    else
        warn "Apache Bench not available, using curl-based test"
        test_load_curl "$url" "$requests" "$concurrency" "$test_name"
    fi
}

# Load testing with curl (fallback)
test_load_curl() {
    local url=$1
    local requests=$2
    local concurrency=$3
    local test_name=$4
    
    info "Running curl-based load test: $test_name"
    
    local start_time=$(date +%s.%N)
    local success_count=0
    local total_time=0
    local failed_count=0
    
    # Sequential requests (simplified version)
    for ((i=1; i<=requests; i++)); do
        local request_start=$(date +%s.%N)
        
        if curl -s -f "$url" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        
        local request_end=$(date +%s.%N)
        local request_time=$(echo "$request_end - $request_start" | bc -l)
        total_time=$(echo "$total_time + $request_time" | bc -l)
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            printf "."
        fi
    done
    echo ""
    
    local end_time=$(date +%s.%N)
    local test_duration=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $total_time / $requests * 1000" | bc -l)
    local rps=$(echo "scale=2; $requests / $test_duration" | bc -l)
    
    info "Results: ${rps} req/sec, ${avg_time}ms avg, ${failed_count} failed"
    
    echo "{\"test\":\"$test_name\",\"requests_per_second\":$rps,\"avg_time_ms\":$avg_time,\"failed_requests\":$failed_count}" >> "$RESULTS_DIR/benchmark_results.json"
}

# Database performance test
test_database_performance() {
    info "Testing database performance..."
    
    # Test various WebDNA database operations
    local db_urls=(
        "$BASE_URL/theprogram/"
        "$BASE_URL/client/"
        "$BASE_URL/WebCatalog/"
    )
    
    for url in "${db_urls[@]}"; do
        local name=$(basename "$url")
        test_single_request "$url" "db_$name"
    done
}

# Memory stress test
test_memory_stress() {
    local duration=${1:-30}
    
    info "Running memory stress test for ${duration} seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Make rapid requests to stress memory
        curl -s "$BASE_URL/theprogram/" >/dev/null 2>&1 &
        curl -s "$BASE_URL/WebCatalog/" >/dev/null 2>&1 &
        
        request_count=$((request_count + 2))
        sleep 0.1
        
        # Check memory usage every 5 seconds
        if [ $((request_count % 50)) -eq 0 ]; then
            local memory_usage=$(free -m | awk 'NR==2{printf "%.1f", ($3/$2)*100}')
            debug "Memory usage: ${memory_usage}%"
        fi
    done
    
    # Wait for background jobs to complete
    wait
    
    info "Memory stress test completed: $request_count requests sent"
}

# Response time consistency test
test_response_consistency() {
    local url=$1
    local samples=${2:-50}
    local test_name=$3
    
    info "Testing response time consistency: $test_name ($samples samples)"
    
    local times=()
    local failures=0
    
    for ((i=1; i<=samples; i++)); do
        local response_time=$(curl -w "%{time_total}" -o /dev/null -s "$url" 2>/dev/null || echo "999")
        
        if [ "$response_time" = "999" ]; then
            failures=$((failures + 1))
        else
            times+=("$response_time")
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    # Calculate statistics
    if [ ${#times[@]} -gt 0 ]; then
        local sum=0
        local min=${times[0]}
        local max=${times[0]}
        
        for time in "${times[@]}"; do
            sum=$(echo "$sum + $time" | bc -l)
            
            if [ $(echo "$time < $min" | bc -l) -eq 1 ]; then
                min=$time
            fi
            
            if [ $(echo "$time > $max" | bc -l) -eq 1 ]; then
                max=$time
            fi
        done
        
        local avg=$(echo "scale=3; $sum / ${#times[@]}" | bc -l)
        local range=$(echo "scale=3; $max - $min" | bc -l)
        
        info "Response time stats: avg=${avg}s, min=${min}s, max=${max}s, range=${range}s, failures=${failures}"
        
        echo "{\"test\":\"consistency_$test_name\",\"avg_time\":$avg,\"min_time\":$min,\"max_time\":$max,\"range\":$range,\"failures\":$failures}" >> "$RESULTS_DIR/benchmark_results.json"
    else
        error "All requests failed for $test_name"
    fi
}

# WebDNA specific performance tests
test_webdna_specific() {
    info "Running WebDNA-specific performance tests..."
    
    # Test WebDNA processing
    test_response_consistency "$BASE_URL/" 20 "webdna_root"
    test_response_consistency "$BASE_URL/theprogram/" 20 "webdna_main_app"
    test_response_consistency "$BASE_URL/WebCatalog/" 20 "webdna_admin"
    
    # Test different WebDNA features if available
    local webdna_features=(
        "/theprogram/index.tpl"
        "/WebCatalog/index.html"
    )
    
    for feature in "${webdna_features[@]}"; do
        if curl -s -f "$BASE_URL$feature" >/dev/null 2>&1; then
            local name=$(echo "$feature" | tr '/' '_' | sed 's/^_//')
            test_single_request "$BASE_URL$feature" "feature_$name"
        fi
    done
}

# Comprehensive benchmark suite
run_full_benchmark() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local report_file="$RESULTS_DIR/full_benchmark_$timestamp.txt"
    
    info "Running comprehensive benchmark suite..."
    
    # Initialize results file
    echo "WebDNA Performance Benchmark Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "========================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Clear previous results
    echo "[]" > "$RESULTS_DIR/benchmark_results.json"
    
    # Test 1: Single request performance
    echo "=== Single Request Tests ===" >> "$report_file"
    test_single_request "$BASE_URL/" "root_page" | tee -a "$report_file"
    test_single_request "$BASE_URL/theprogram/" "main_app" | tee -a "$report_file"
    test_single_request "$BASE_URL/WebCatalog/" "admin_panel" | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 2: Light load
    echo "=== Light Load Test ===" >> "$report_file"
    test_load_ab "$BASE_URL/theprogram/" 50 5 "light_load" 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 3: Medium load
    echo "=== Medium Load Test ===" >> "$report_file"
    test_load_ab "$BASE_URL/theprogram/" 100 10 "medium_load" 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 4: Heavy load
    echo "=== Heavy Load Test ===" >> "$report_file"
    test_load_ab "$BASE_URL/theprogram/" 200 20 "heavy_load" 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 5: Consistency tests
    echo "=== Response Time Consistency ===" >> "$report_file"
    test_response_consistency "$BASE_URL/theprogram/" 30 "main_app" 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 6: WebDNA specific tests
    echo "=== WebDNA Specific Tests ===" >> "$report_file"
    test_webdna_specific 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    # Test 7: Database performance
    echo "=== Database Performance ===" >> "$report_file"
    test_database_performance 2>&1 | tee -a "$report_file"
    echo "" >> "$report_file"
    
    info "Full benchmark completed. Report saved to: $report_file"
    
    # Generate summary
    generate_benchmark_summary "$report_file"
}

# Generate benchmark summary
generate_benchmark_summary() {
    local report_file=$1
    
    echo ""
    echo -e "${BOLD}${BLUE}=== BENCHMARK SUMMARY ===${NC}"
    
    if [ -f "$RESULTS_DIR/benchmark_results.json" ]; then
        echo "Performance Test Results:"
        echo "------------------------"
        
        # Parse JSON results if jq is available
        if command -v jq >/dev/null 2>&1; then
            cat "$RESULTS_DIR/benchmark_results.json" | jq -r '.[] | "\(.test): \(.requests_per_second // "N/A") req/sec, \(.avg_time_ms // .avg_time // "N/A")ms avg"' 2>/dev/null || cat "$RESULTS_DIR/benchmark_results.json"
        else
            cat "$RESULTS_DIR/benchmark_results.json"
        fi
    fi
    
    echo ""
    echo "Detailed report available at: $report_file"
}

# Show help
show_help() {
    cat << EOF
WebDNA Performance Benchmarking Tool

Usage: $0 [OPTIONS] COMMAND

Commands:
    single URL          Test single request performance
    load URL R C        Load test (R=requests, C=concurrency)
    consistency URL N   Response time consistency (N=samples)
    webdna             WebDNA-specific performance tests
    memory [DURATION]   Memory stress test
    full               Run comprehensive benchmark suite

Options:
    -h, --help         Show this help

Examples:
    $0 single http://localhost:8080/theprogram/
    $0 load http://localhost:8080/theprogram/ 100 10
    $0 consistency http://localhost:8080/theprogram/ 50
    $0 webdna
    $0 memory 60
    $0 full
EOF
}

# Main function
main() {
    init_benchmark
    
    case "${1:-help}" in
        single)
            if [ -z "${2:-}" ]; then
                error "URL required for single test"
                exit 1
            fi
            test_single_request "$2" "single_test"
            ;;
        load)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                error "URL, requests, and concurrency required for load test"
                exit 1
            fi
            test_load_ab "$2" "$3" "$4" "custom_load"
            ;;
        consistency)
            if [ -z "${2:-}" ]; then
                error "URL required for consistency test"
                exit 1
            fi
            test_response_consistency "$2" "${3:-30}" "custom_consistency"
            ;;
        webdna)
            test_webdna_specific
            ;;
        memory)
            test_memory_stress "${2:-30}"
            ;;
        full)
            run_full_benchmark
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"