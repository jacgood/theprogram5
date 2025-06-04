#!/bin/bash
# WebDNA Performance Dashboard
# Generates real-time performance reports and visualizations

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="webdna-dashboard"
readonly METRICS_DIR="$(pwd)/logs/metrics"
readonly REPORTS_DIR="$(pwd)/logs/reports"
readonly DASHBOARD_PORT=${DASHBOARD_PORT:-8090}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ASCII art for charts
readonly BLOCK_CHARS=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

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

# Initialize dashboard
init_dashboard() {
    info "Initializing performance dashboard..."
    mkdir -p "$REPORTS_DIR"
    chmod 755 "$REPORTS_DIR"
}

# Create ASCII bar chart
create_bar_chart() {
    local values=("$@")
    local max_val=0
    local chart=""
    
    # Find maximum value
    for val in "${values[@]}"; do
        if (( $(echo "$val > $max_val" | bc -l) )); then
            max_val=$val
        fi
    done
    
    # Generate bars
    for val in "${values[@]}"; do
        if [ "$max_val" = "0" ]; then
            chart+="▁"
        else
            local ratio=$(echo "scale=2; $val / $max_val" | bc -l)
            local bar_height=$(echo "scale=0; $ratio * 7" | bc -l)
            chart+="${BLOCK_CHARS[$bar_height]}"
        fi
    done
    
    echo "$chart"
}

# Create sparkline from metrics
create_sparkline() {
    local metric_name=$1
    local metric_path=$2
    local count=${3:-20}
    
    local values=()
    
    # Extract recent values from JSON metrics
    if [ -f "$METRICS_DIR/$(ls -t $METRICS_DIR/metrics_*.json 2>/dev/null | head -1)" ]; then
        local latest_file="$METRICS_DIR/$(ls -t $METRICS_DIR/metrics_*.json | head -1)"
        values=($(grep -o "\"$metric_path\":[0-9.]*" "$latest_file" | tail -$count | cut -d: -f2 | tr '\n' ' '))
    fi
    
    if [ ${#values[@]} -eq 0 ]; then
        echo "No data available"
        return
    fi
    
    local chart=$(create_bar_chart "${values[@]}")
    printf "%-20s %s (latest: %.2f)\n" "$metric_name:" "$chart" "${values[-1]}"
}

# Generate system overview
show_system_overview() {
    echo -e "${BOLD}${CYAN}=== SYSTEM OVERVIEW ===${NC}"
    echo ""
    
    # Current system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    local memory_info=$(free -m)
    local memory_percent=$(echo "$memory_info" | awk 'NR==2{printf "%.1f", ($3/$2)*100}')
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    # Status indicators
    local cpu_status="🟢"
    if [ -n "$cpu_usage" ] && [ $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
        cpu_status="🔴"
    elif [ -n "$cpu_usage" ] && [ $(echo "$cpu_usage > 60" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
        cpu_status="🟡"
    fi
    
    local mem_status="🟢"
    if [ -n "$memory_percent" ] && [ $(echo "$memory_percent > 85" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
        mem_status="🔴"
    elif [ -n "$memory_percent" ] && [ $(echo "$memory_percent > 70" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
        mem_status="🟡"
    fi
    
    local disk_status="🟢"
    [ $disk_usage -gt 90 ] && disk_status="🔴"
    [ $disk_usage -gt 75 ] && disk_status="🟡"
    
    printf "%-15s %s %6s%%   Load Avg: %s\n" "CPU Usage" "$cpu_status" "$cpu_usage" "$load_avg"
    printf "%-15s %s %6s%%\n" "Memory Usage" "$mem_status" "$memory_percent"
    printf "%-15s %s %6s%%\n" "Disk Usage" "$disk_status" "$disk_usage"
    echo ""
}

# Generate application metrics
show_application_metrics() {
    echo -e "${BOLD}${CYAN}=== APPLICATION METRICS ===${NC}"
    echo ""
    
    # Container status
    local container_status="🔴 Down"
    local webdna_status="🔴 Down"
    local apache_status="🔴 Down"
    
    if docker ps | grep -q "webdna-server"; then
        container_status="🟢 Running"
        
        # Check WebDNA
        if docker exec webdna-server pgrep WebCatalog >/dev/null 2>&1; then
            webdna_status="🟢 Running"
        fi
        
        # Check Apache
        if docker exec webdna-server pgrep apache2 >/dev/null 2>&1; then
            apache_status="🟢 Running"
        fi
    fi
    
    printf "%-15s %s\n" "Container:" "$container_status"
    printf "%-15s %s\n" "WebDNA:" "$webdna_status"
    printf "%-15s %s\n" "Apache:" "$apache_status"
    echo ""
    
    # Response time tests
    echo -e "${BOLD}Response Times:${NC}"
    
    local main_app_time=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/theprogram/ 2>/dev/null || echo "timeout")
    local webcatalog_time=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/WebCatalog/ 2>/dev/null || echo "timeout")
    
    printf "%-15s %s seconds\n" "Main App:" "$main_app_time"
    printf "%-15s %s seconds\n" "WebCatalog:" "$webcatalog_time"
    echo ""
}

# Generate performance trends
show_performance_trends() {
    echo -e "${BOLD}${CYAN}=== PERFORMANCE TRENDS (Last 20 samples) ===${NC}"
    echo ""
    
    if [ ! -d "$METRICS_DIR" ] || [ -z "$(ls -A $METRICS_DIR 2>/dev/null)" ]; then
        echo "No metrics data available. Run monitoring first."
        return
    fi
    
    # Create sparklines for key metrics
    create_sparkline "CPU Usage" "cpu.usage_percent"
    create_sparkline "Memory Usage" "memory.usage_percent"
    create_sparkline "Container CPU" "cpu_percent"
    create_sparkline "Response Time" "response_time_seconds"
    echo ""
}

# Generate detailed report
generate_detailed_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$REPORTS_DIR/performance_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    info "Generating detailed performance report..."
    
    cat > "$report_file" << EOF
WebDNA Performance Report
Generated: $timestamp
========================

EXECUTIVE SUMMARY
-----------------
$(show_system_overview)

APPLICATION STATUS
------------------
$(show_application_metrics)

RECENT METRICS ANALYSIS
-----------------------
EOF
    
    # Add detailed metrics analysis
    if [ -d "$METRICS_DIR" ]; then
        echo "Recent metric files:" >> "$report_file"
        ls -la "$METRICS_DIR"/*.json 2>/dev/null | tail -5 >> "$report_file" || echo "No metric files found" >> "$report_file"
        echo "" >> "$report_file"
        
        # Add latest system metrics
        local latest_system=$(ls -t "$METRICS_DIR"/system_*.log 2>/dev/null | head -1)
        if [ -f "$latest_system" ]; then
            echo "Latest System Metrics:" >> "$report_file"
            tail -10 "$latest_system" >> "$report_file"
            echo "" >> "$report_file"
        fi
        
        # Add latest Apache metrics
        local latest_apache=$(ls -t "$METRICS_DIR"/apache_*.log 2>/dev/null | head -1)
        if [ -f "$latest_apache" ]; then
            echo "Latest Apache Metrics:" >> "$report_file"
            tail -10 "$latest_apache" >> "$report_file"
            echo "" >> "$report_file"
        fi
        
        # Add latest WebDNA metrics
        local latest_webdna=$(ls -t "$METRICS_DIR"/webdna_*.log 2>/dev/null | head -1)
        if [ -f "$latest_webdna" ]; then
            echo "Latest WebDNA Metrics:" >> "$report_file"
            tail -10 "$latest_webdna" >> "$report_file"
            echo "" >> "$report_file"
        fi
    fi
    
    echo "Report saved to: $report_file"
    return 0
}

# Performance alerts
check_performance_alerts() {
    echo -e "${BOLD}${CYAN}=== PERFORMANCE ALERTS ===${NC}"
    echo ""
    
    local alerts=()
    
    # CPU alert
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    if [ $(echo "$cpu_usage > 85" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🔴 HIGH CPU USAGE: ${cpu_usage}%")
    elif [ $(echo "$cpu_usage > 70" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🟡 ELEVATED CPU USAGE: ${cpu_usage}%")
    fi
    
    # Memory alert
    local memory_percent=$(free -m | awk 'NR==2{printf "%.1f", ($3/$2)*100}')
    if [ $(echo "$memory_percent > 90" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🔴 HIGH MEMORY USAGE: ${memory_percent}%")
    elif [ $(echo "$memory_percent > 75" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🟡 ELEVATED MEMORY USAGE: ${memory_percent}%")
    fi
    
    # Disk alert
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $disk_usage -gt 95 ]; then
        alerts+=("🔴 CRITICAL DISK USAGE: ${disk_usage}%")
    elif [ $disk_usage -gt 85 ]; then
        alerts+=("🟡 HIGH DISK USAGE: ${disk_usage}%")
    fi
    
    # Response time alert
    local response_time=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/theprogram/ 2>/dev/null || echo "999")
    if [ $(echo "$response_time > 5" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🔴 SLOW RESPONSE TIME: ${response_time}s")
    elif [ $(echo "$response_time > 2" | bc -l 2>/dev/null) -eq 1 ]; then
        alerts+=("🟡 ELEVATED RESPONSE TIME: ${response_time}s")
    fi
    
    # Container health
    if ! docker ps | grep -q "webdna-server"; then
        alerts+=("🔴 CONTAINER DOWN")
    else
        # Check WebDNA process
        if ! docker exec webdna-server pgrep WebCatalog >/dev/null 2>&1; then
            alerts+=("🔴 WEBDNA PROCESS DOWN")
        fi
        
        # Check Apache process
        if ! docker exec webdna-server pgrep apache2 >/dev/null 2>&1; then
            alerts+=("🔴 APACHE PROCESS DOWN")
        fi
    fi
    
    # Display alerts
    if [ ${#alerts[@]} -eq 0 ]; then
        echo "🟢 No performance alerts - System operating normally"
    else
        echo "⚠️  Active Performance Alerts:"
        for alert in "${alerts[@]}"; do
            echo "   $alert"
        done
    fi
    echo ""
}

# Real-time dashboard view
show_realtime_dashboard() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                           WebDNA Performance Dashboard                       ║"
        echo "║                              $(date '+%Y-%m-%d %H:%M:%S')                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        show_system_overview
        show_application_metrics
        check_performance_alerts
        show_performance_trends
        
        echo -e "${CYAN}Press Ctrl+C to exit${NC}"
        sleep 5
    done
}

# Show help
show_help() {
    cat << EOF
WebDNA Performance Dashboard

Usage: $0 [COMMAND]

Commands:
    overview        Show system overview
    metrics         Show application metrics
    trends          Show performance trends
    alerts          Check performance alerts
    report          Generate detailed report
    realtime        Start real-time dashboard
    help            Show this help

Examples:
    $0 overview     # Quick system overview
    $0 realtime     # Interactive dashboard
    $0 report       # Generate detailed report
EOF
}

# Main function
main() {
    init_dashboard
    
    case "${1:-overview}" in
        overview)
            show_system_overview
            ;;
        metrics)
            show_application_metrics
            ;;
        trends)
            show_performance_trends
            ;;
        alerts)
            check_performance_alerts
            ;;
        report)
            generate_detailed_report
            ;;
        realtime)
            show_realtime_dashboard
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