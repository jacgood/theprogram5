#!/bin/bash

# WebDNA Application Startup Script
# This script initializes and starts the WebDNA application with Apache

set -e

echo "Starting WebDNA Application Container..."

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Add www-data to the host group to access mounted files
if [ -n "$HOST_GID" ]; then
    log "Adding www-data to group $HOST_GID for file access..."
    groupadd -g $HOST_GID hostgroup 2>/dev/null || true
    usermod -a -G hostgroup www-data
    log "www-data added to group $HOST_GID"
fi

# Initialize WebDNA if not already done
if [ ! -f /opt/webdna/.initialized ]; then
    log "Initializing WebDNA for first run..."

    # Note: We don't change ownership of mounted volumes
    # The volumes are mounted with proper permissions from docker-compose
    log "Mounted volumes will retain host ownership"

    touch /opt/webdna/.initialized
    log "WebDNA initialization completed"
fi

# Configure Apache for WebDNA
log "Configuring Apache for WebDNA..."

# Enable WebDNA module if not already enabled
if [ ! -L /etc/apache2/mods-enabled/webdna.load ]; then
    a2enmod webdna
    log "WebDNA module enabled"
fi

# Enable the WebDNA site configuration
if [ -f /etc/apache2/sites-available/webdna-site.conf ]; then
    a2ensite webdna-site.conf
    log "WebDNA site configuration enabled"
else
    log "Warning: WebDNA site configuration not found, using default"
fi

# Disable default Apache site
a2dissite 000-default.conf || true

# Note: We don't change ownership of mounted volumes
# Apache runs as www-data and needs read access
log "Verifying Apache can access mounted volumes..."

# Test Apache configuration
log "Testing Apache configuration..."
if ! apache2ctl configtest; then
    log "ERROR: Apache configuration test failed"
    exit 1
fi

# Set Apache environment variables
export APACHE_RUN_USER=www-data
export APACHE_RUN_GROUP=www-data
export APACHE_RUN_DIR=/var/run/apache2
export APACHE_PID_FILE=/var/run/apache2/apache2.pid
export APACHE_LOCK_DIR=/var/lock/apache2
export APACHE_LOG_DIR=/var/log/apache2

# Create necessary directories
mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR
chown $APACHE_RUN_USER:$APACHE_RUN_GROUP $APACHE_RUN_DIR $APACHE_LOCK_DIR

# Start WebCatalog Engine
log "Starting WebCatalog Engine..."
if [ -x /usr/lib/cgi-bin/WebCatalogEngine/WebCatalog ]; then
    # Only set executable permissions, don't change ownership
    if [ -d /usr/lib/cgi-bin/WebCatalogEngine ]; then
        log "Setting executable permissions for WebCatalogEngine..."
        # Make WebCatalog executable without changing ownership
        chmod +x /usr/lib/cgi-bin/WebCatalogEngine/WebCatalog
        chmod +x /usr/lib/cgi-bin/WebCatalogEngine/WebDNAMonitor || true
    fi
    
    cd /usr/lib/cgi-bin/WebCatalogEngine
    ./WebCatalog &
    WEBDNA_PID=$!
    log "WebCatalog Engine started with PID: $WEBDNA_PID"
    sleep 2
    
    # Check if WebCatalog is running
    if ps -p $WEBDNA_PID > /dev/null; then
        log "WebCatalog Engine is running"
    else
        log "ERROR: WebCatalog Engine failed to start"
    fi
else
    log "ERROR: WebCatalog executable not found"
fi

# Start Apache in foreground
log "Starting Apache web server..."
log "Apache modules loaded:"
apache2ctl -M | grep -E "(webcatalog2|webdna|rewrite|headers)" || log "Note: Some modules may not be loaded yet"
log "Apache configuration test one more time:"
if ! apache2ctl configtest; then
    log "ERROR: Final Apache configuration test failed"
    exit 1
fi

log "WebDNA will be available at: http://localhost/WebCatalog"
log "Default credentials - User: admin, Password: admin"
log "Starting Apache in foreground mode..."

# Trap to ensure WebCatalog stops when container stops
trap "kill $WEBDNA_PID 2>/dev/null" EXIT

exec /usr/sbin/apache2 -D FOREGROUND 