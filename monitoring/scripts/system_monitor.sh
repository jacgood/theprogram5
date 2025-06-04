#!/bin/bash
# WebDNA System Performance Monitor
# Collects comprehensive system and application metrics

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="webdna-monitor"
readonly METRICS_DIR="$(pwd)/logs/metrics"
readonly CONTAINER_NAME="webdna-server"
readonly INTERVAL=${MONITOR_INTERVAL:-30}
readonly RETENTION_DAYS=${MONITOR_RETENTION:-7}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
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

# Initialize monitoring
init_monitoring() {
    info "Initializing performance monitoring..."
    
    # Create metrics directory
    mkdir -p "$METRICS_DIR"
    chmod 755 "$METRICS_DIR"
    
    # Create metric files
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    export METRICS_FILE="$METRICS_DIR/metrics_${timestamp}.json"
    export SYSTEM_FILE="$METRICS_DIR/system_${timestamp}.log"
    export APACHE_FILE="$METRICS_DIR/apache_${timestamp}.log"
    export WEBDNA_FILE="$METRICS_DIR/webdna_${timestamp}.log"
    
    info "Metrics will be stored in: $METRICS_DIR"
}

# Collect system metrics
collect_system_metrics() {
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # CPU metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs)
    
    # Memory metrics
    local memory_info=$(free -m)
    local memory_total=$(echo "$memory_info" | awk 'NR==2{print $2}')
    local memory_used=$(echo "$memory_info" | awk 'NR==2{print $3}')
    local memory_free=$(echo "$memory_info" | awk 'NR==2{print $4}')
    local memory_percent=$(awk "BEGIN {printf \"%.2f\", ($memory_used/$memory_total)*100}")
    
    # Disk metrics
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_free=$(df -h / | awk 'NR==2 {print $4}')
    
    # Network metrics
    local network_stats=$(cat /proc/net/dev | grep -E "(eth0|ens|enp)" | head -1)
    local rx_bytes=$(echo "$network_stats" | awk '{print $2}')
    local tx_bytes=$(echo "$network_stats" | awk '{print $10}')
    
    # Create JSON metric entry
    cat << EOF >> "$METRICS_FILE"
{
  "timestamp": "$timestamp",
  "type": "system",
  "metrics": {
    "cpu": {
      "usage_percent": $cpu_usage,
      "load_average": "$load_avg"
    },
    "memory": {
      "total_mb": $memory_total,
      "used_mb": $memory_used,
      "free_mb": $memory_free,
      "usage_percent": $memory_percent
    },
    "disk": {
      "usage_percent": $disk_usage,
      "free": "$disk_free"
    },
    "network": {
      "rx_bytes": $rx_bytes,
      "tx_bytes": $tx_bytes
    }
  }
},
EOF
    
    # Log to system file
    echo "[$timestamp] CPU: ${cpu_usage}% | Memory: ${memory_percent}% | Disk: ${disk_usage}% | Load: $load_avg" >> "$SYSTEM_FILE"
}

# Collect container metrics
collect_container_metrics() {
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Check if container is running
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        warn "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    # Container resource usage
    local container_stats=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}")
    local cpu_percent=$(echo "$container_stats" | tail -1 | awk '{print $1}' | sed 's/%//')
    local memory_usage=$(echo "$container_stats" | tail -1 | awk '{print $2}')
    local memory_percent=$(echo "$container_stats" | tail -1 | awk '{print $3}' | sed 's/%//' | sed 's/^$/0/')
    local network_io=$(echo "$container_stats" | tail -1 | awk '{print $4}')
    local block_io=$(echo "$container_stats" | tail -1 | awk '{print $5}')
    
    # Container process count
    local process_count=$(docker exec "$CONTAINER_NAME" ps aux | wc -l)
    
    # Create JSON metric entry
    cat << EOF >> "$METRICS_FILE"
{
  "timestamp": "$timestamp",
  "type": "container",
  "metrics": {
    "cpu_percent": $cpu_percent,
    "memory_usage": "$memory_usage",
    "memory_percent": $memory_percent,
    "network_io": "$network_io",
    "block_io": "$block_io",
    "process_count": $process_count
  }
},
EOF
    
    debug "Container metrics: CPU: ${cpu_percent}% | Memory: ${memory_percent}% | Processes: $process_count"
}

# Collect Apache metrics
collect_apache_metrics() {
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Apache status (if mod_status is enabled)
    local apache_status=""
    if curl -s http://localhost/server-status 2>/dev/null; then
        apache_status=$(curl -s http://localhost/server-status?auto 2>/dev/null || echo "unavailable")
    fi
    
    # Apache process count
    local apache_processes=$(docker exec "$CONTAINER_NAME" pgrep apache2 | wc -l 2>/dev/null || echo "0")
    
    # Recent log analysis
    local error_count=$(docker exec "$CONTAINER_NAME" tail -1000 /var/log/apache2/error.log 2>/dev/null | grep "$(date '+%Y-%m-%d %H:')" | wc -l || echo "0")
    local access_count=$(docker exec "$CONTAINER_NAME" tail -1000 /var/log/apache2/access.log 2>/dev/null | grep "$(date '+%d/%b/%Y:%H:')" | wc -l || echo "0")
    
    # Response time test
    local response_time=$(curl -w "@-" -o /dev/null -s http://localhost:8080/theprogram/ << 'EOF' || echo "0"
     time_total:  %{time_total}\n
EOF
)
    response_time=$(echo "$response_time" | grep "time_total" | awk '{print $2}' || echo "0")
    
    # Create JSON metric entry
    cat << EOF >> "$METRICS_FILE"
{
  "timestamp": "$timestamp",
  "type": "apache",
  "metrics": {
    "process_count": $apache_processes,
    "error_count_last_hour": $error_count,
    "access_count_last_hour": $access_count,
    "response_time_seconds": $response_time
  }
},
EOF
    
    echo "[$timestamp] Apache processes: $apache_processes | Errors/hour: $error_count | Requests/hour: $access_count | Response time: ${response_time}s" >> "$APACHE_FILE"
}

# Collect WebDNA specific metrics
collect_webdna_metrics() {
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # WebDNA process status
    local webdna_processes=$(docker exec "$CONTAINER_NAME" pgrep WebCatalog | wc -l 2>/dev/null || echo "0")
    
    # WebDNA memory usage
    local webdna_memory=$(docker exec "$CONTAINER_NAME" ps aux | grep WebCatalog | grep -v grep | awk '{sum+=$6} END {print sum+0}' 2>/dev/null || echo "0")
    
    # WebDNA response test
    local webdna_response=""
    local webdna_status="down"
    if curl -s http://localhost:8080/WebCatalog/ | grep -q "WebDNA"; then
        webdna_status="up"
        webdna_response=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/WebCatalog/ 2>/dev/null || echo "0")
    fi
    
    # Database access test
    local db_test_time=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/theprogram/ 2>/dev/null || echo "0")
    
    # Create JSON metric entry
    cat << EOF >> "$METRICS_FILE"
{
  "timestamp": "$timestamp",
  "type": "webdna",
  "metrics": {
    "process_count": $webdna_processes,
    "memory_kb": $webdna_memory,
    "status": "$webdna_status",
    "webcatalog_response_time": $webdna_response,
    "app_response_time": $db_test_time
  }
},
EOF
    
    echo "[$timestamp] WebDNA processes: $webdna_processes | Memory: ${webdna_memory}KB | Status: $webdna_status | WebCatalog response: ${webdna_response}s | App response: ${db_test_time}s" >> "$WEBDNA_FILE"
}

# Generate performance summary
generate_summary() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    info "=== Performance Summary at $timestamp ==="
    
    # Latest metrics from files
    if [ -f "$SYSTEM_FILE" ]; then
        echo -e "${BLUE}System:${NC}"
        tail -1 "$SYSTEM_FILE" 2>/dev/null || echo "No system metrics available"
    fi
    
    if [ -f "$APACHE_FILE" ]; then
        echo -e "${BLUE}Apache:${NC}"
        tail -1 "$APACHE_FILE" 2>/dev/null || echo "No Apache metrics available"
    fi
    
    if [ -f "$WEBDNA_FILE" ]; then
        echo -e "${BLUE}WebDNA:${NC}"
        tail -1 "$WEBDNA_FILE" 2>/dev/null || echo "No WebDNA metrics available"
    fi
    
    echo "=================================="
}

# Clean old metrics
cleanup_old_metrics() {
    info "Cleaning up metrics older than $RETENTION_DAYS days..."
    find "$METRICS_DIR" -name "*.json" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$METRICS_DIR" -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
}

# Main monitoring loop
monitor_continuous() {
    info "Starting continuous monitoring (interval: ${INTERVAL}s)"
    
    while true; do
        collect_system_metrics
        collect_container_metrics
        collect_apache_metrics
        collect_webdna_metrics
        
        generate_summary
        sleep "$INTERVAL"
    done
}

# Single collection run
monitor_once() {
    info "Running single monitoring collection..."
    
    collect_system_metrics
    collect_container_metrics
    collect_apache_metrics
    collect_webdna_metrics
    
    generate_summary
}

# Show help
show_help() {
    cat << EOF
WebDNA Performance Monitor

Usage: $0 [OPTIONS] COMMAND

Commands:
    once        Run monitoring collection once
    continuous  Run continuous monitoring
    summary     Show latest performance summary
    cleanup     Clean old metric files

Options:
    -i, --interval SECONDS    Monitoring interval (default: 30)
    -r, --retention DAYS      Metric retention days (default: 7)
    -h, --help               Show this help

Examples:
    $0 once                   # Single collection
    $0 continuous             # Continuous monitoring
    $0 -i 60 continuous       # Monitor every 60 seconds
    $0 cleanup                # Clean old metrics
EOF
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            once)
                init_monitoring
                monitor_once
                exit 0
                ;;
            continuous)
                init_monitoring
                monitor_continuous
                exit 0
                ;;
            summary)
                generate_summary
                exit 0
                ;;
            cleanup)
                cleanup_old_metrics
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action
    show_help
}

# Run main function
main "$@"