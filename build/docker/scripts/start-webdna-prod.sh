#!/bin/bash
# WebDNA Production Startup Script
# Enhanced version for production deployment

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="webdna-startup-prod"
readonly LOG_FILE="/var/log/apache2/webdna-startup.log"
readonly PID_FILE="/var/run/webdna.pid"
readonly HEALTH_CHECK_URL="http://localhost/WebCatalog/"
readonly ENVIRONMENT="${ENVIRONMENT:-production}"

# Colors for console output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] [$ENVIRONMENT] $message" >> "$LOG_FILE"
    
    # Log to console with colors
    case $level in
        "INFO")  echo -e "${GREEN}[$timestamp] [INFO] $message${NC}" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" ;;
        "ERROR") echo -e "${RED}[$timestamp] [ERROR] $message${NC}" ;;
        "DEBUG") [ "${DEBUG:-false}" = "true" ] && echo -e "${BLUE}[$timestamp] [DEBUG] $message${NC}" ;;
        *)       echo "[$timestamp] [$level] $message" ;;
    esac
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }
debug() { log "DEBUG" "$@"; }

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    error "Script failed at line $line_number with exit code $exit_code"
    cleanup
    exit $exit_code
}

# Cleanup function
cleanup() {
    info "Performing cleanup..."
    
    # Stop WebCatalog if running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            warn "Stopping WebCatalog process (PID: $pid)"
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    
    # Stop Apache if running
    if pgrep apache2 > /dev/null; then
        warn "Stopping Apache processes"
        apache2ctl stop 2>/dev/null || true
    fi
}

# Trap errors and cleanup
trap 'handle_error $LINENO' ERR
trap 'cleanup' EXIT INT TERM

# Production environment checks
production_checks() {
    info "Performing production environment checks..."
    
    # Check if required environment variables are set
    local required_vars=("DB_HOST" "DB_PORT" "DB_NAME" "DB_USER" "DB_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required environment variable $var is not set"
            return 1
        fi
    done
    
    # Log configuration
    info "Production configuration:"
    info "  - Database Host: ${DB_HOST}"
    info "  - Database Port: ${DB_PORT}"
    info "  - Database Name: ${DB_NAME}"
    info "  - Database User: ${DB_USER}"
    info "  - Base URL: ${BASE_URL:-not set}"
    
    # Test database connection
    info "Testing database connection..."
    if command -v pg_isready >/dev/null 2>&1; then
        if pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
            info "Database connection successful"
        else
            warn "Database connection test failed - WebDNA will attempt to connect"
        fi
    fi
    
    info "Production checks completed"
}

# Setup permissions
setup_permissions() {
    info "Setting up permissions..."
    
    # Add www-data to host group if specified
    if [ -n "${HOST_GID:-}" ]; then
        info "Adding www-data to host group $HOST_GID for file access..."
        if ! getent group "$HOST_GID" > /dev/null; then
            groupadd -g "$HOST_GID" hostgroup 2>/dev/null || true
        fi
        usermod -a -G "$HOST_GID" www-data 2>/dev/null || true
        info "User permissions configured"
    fi
    
    # Set executable permissions for WebCatalog
    if [ -d "/usr/lib/cgi-bin/WebCatalogEngine" ]; then
        debug "Setting executable permissions for WebCatalogEngine..."
        chmod +x /usr/lib/cgi-bin/WebCatalogEngine/WebCatalog 2>/dev/null || true
        chmod +x /usr/lib/cgi-bin/WebCatalogEngine/WebDNAMonitor 2>/dev/null || true
    fi
    
    # Ensure log directory permissions
    chown -R www-data:www-data /var/log/apache2 || true
    
    info "Permissions setup completed"
}

# Configure Apache for production
configure_apache() {
    info "Configuring Apache for production..."
    
    # Enable WebDNA module if not already enabled
    if [ ! -L "/etc/apache2/mods-enabled/webdna.load" ]; then
        a2enmod webdna
        info "WebDNA module enabled"
    fi
    
    # Enable required modules for production
    a2enmod rewrite headers expires deflate || true
    
    # Select appropriate site configuration
    local site_config="webdna-site-prod.conf"
    if [ ! -f "/etc/apache2/sites-available/$site_config" ]; then
        warn "Production site config not found, using default"
        site_config="webdna-site.conf"
    fi
    
    # Enable the site configuration
    a2ensite "$site_config"
    info "Site configuration '$site_config' enabled"
    
    # Disable default Apache site
    a2dissite 000-default.conf 2>/dev/null || true
    
    # Test Apache configuration
    info "Testing Apache configuration..."
    if ! apache2ctl configtest; then
        error "Apache configuration test failed"
        return 1
    fi
    
    info "Apache configuration completed"
}

# Start WebCatalog Engine
start_webdna() {
    info "Starting WebCatalog Engine..."
    
    local webdna_executable="/usr/lib/cgi-bin/WebCatalogEngine/WebCatalog"
    
    if [ ! -x "$webdna_executable" ]; then
        error "WebCatalog executable not found or not executable: $webdna_executable"
        return 1
    fi
    
    cd "/usr/lib/cgi-bin/WebCatalogEngine"
    
    # Start WebCatalog in background
    "$webdna_executable" &
    local webdna_pid=$!
    
    # Save PID
    echo "$webdna_pid" > "$PID_FILE"
    
    info "WebCatalog Engine started with PID: $webdna_pid"
    
    # Wait for WebCatalog to be ready
    sleep 5
    
    # Verify process is still running
    if ! kill -0 "$webdna_pid" 2>/dev/null; then
        error "WebCatalog Engine failed to start or crashed immediately"
        return 1
    fi
    
    info "WebCatalog Engine is running successfully"
    return 0
}

# Start Apache
start_apache() {
    info "Starting Apache web server in production mode..."
    
    # Set Apache environment variables
    export APACHE_RUN_USER=${APACHE_RUN_USER:-www-data}
    export APACHE_RUN_GROUP=${APACHE_RUN_GROUP:-www-data}
    export APACHE_RUN_DIR=${APACHE_RUN_DIR:-/var/run/apache2}
    export APACHE_PID_FILE=${APACHE_PID_FILE:-/var/run/apache2/apache2.pid}
    export APACHE_LOCK_DIR=${APACHE_LOCK_DIR:-/var/lock/apache2}
    export APACHE_LOG_DIR=${APACHE_LOG_DIR:-/var/log/apache2}
    
    # Create necessary directories
    mkdir -p "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR"
    chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR"
    
    # Display loaded modules for debugging
    if [ "${DEBUG:-false}" = "true" ]; then
        debug "Apache modules loaded:"
        apache2ctl -M | grep -E "(webcatalog2|webdna|rewrite|headers|expires|deflate)" || warn "Some expected modules may not be loaded"
    fi
    
    # Final configuration test
    info "Performing final Apache configuration test..."
    if ! apache2ctl configtest; then
        error "Final Apache configuration test failed"
        return 1
    fi
    
    info "Starting Apache in foreground mode..."
    info "Environment: $ENVIRONMENT"
    info "WebDNA will be available at: http://localhost/WebCatalog"
    info "Main application available at: ${BASE_URL:-http://localhost/theprogram/}"
    
    # Start Apache in foreground
    exec apache2ctl -D FOREGROUND
}

# Main startup sequence
main() {
    info "=== WebDNA Production Container Startup ==="
    info "Environment: $ENVIRONMENT"
    info "Starting WebDNA Application Container..."
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Perform production checks
    production_checks || exit 1
    
    # Setup permissions
    setup_permissions || exit 1
    
    # Configure Apache
    configure_apache || exit 1
    
    # Start WebDNA
    start_webdna || exit 1
    
    # Start Apache (this will run in foreground)
    start_apache || exit 1
}

# Run main function
main "$@"