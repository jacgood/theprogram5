# Multi-stage Dockerfile for WebDNA Server
# Follows Docker best practices for security and optimization

# Build stage for downloading and preparing WebDNA
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and prepare WebDNA repository key
RUN curl -fsSL https://deb.webdna.us/ubuntu23/webdna.key | gpg --dearmor -o /tmp/webdna.gpg

# Production stage
FROM ubuntu:22.04

# Labels for better image management
LABEL maintainer="webmaster@localhost"
LABEL description="WebDNA Server v8.6.5 with Apache 2.4 on Ubuntu 22.04"
LABEL version="1.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2 \
    WEBDNA_VERSION=8.6.5

# Install runtime dependencies in a single layer
RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    ca-certificates \
    # PHP and extensions
    php \
    libapache2-mod-php \
    php-pgsql \
    php-mysql \
    # Security and monitoring tools
    htop \
    nano \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy WebDNA repository key from builder stage
COPY --from=builder /tmp/webdna.gpg /etc/apt/trusted.gpg.d/webdna.gpg

# Add WebDNA repository
RUN echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/webdna.gpg] https://deb.webdna.us/ubuntu23 lunar non-free" > /etc/apt/sources.list.d/webdna.list

# Create mock systemctl for WebDNA installer
RUN printf '#!/bin/bash\necho "Mock systemctl: $*"\nexit 0\n' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# Install WebDNA module with pinned version
RUN apt-get update && \
    apt-get install -y libapache2-mod-webdna=${WEBDNA_VERSION} && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Enable required Apache modules including PHP
RUN a2enmod rewrite headers webdna speling alias dir php8.1

# Create non-root user for application (if needed in the future)
RUN groupadd -r webdna && useradd -r -g webdna webdna

# Create necessary directories with proper permissions
RUN mkdir -p \
    /opt/webdna \
    /var/www/html \
    ${APACHE_RUN_DIR} \
    ${APACHE_LOCK_DIR} \
    && chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} \
        ${APACHE_RUN_DIR} \
        ${APACHE_LOCK_DIR} \
    && chmod 755 /var/www/html

# Copy configuration files
COPY config/webdna/corrected-webdna.conf /etc/apache2/mods-available/webdna.conf
COPY config/apache/webdna-site.conf /etc/apache2/sites-available/webdna-site.conf

# Copy startup script
COPY build/docker/scripts/start-webdna.sh /usr/local/bin/start-webdna.sh

# Set proper permissions for startup script
RUN chmod +x /usr/local/bin/start-webdna.sh

# Disable default Apache site and enable WebDNA site
RUN a2dissite 000-default && a2ensite webdna-site

# Create health check script
RUN printf '#!/bin/bash\ncurl -f http://localhost/WebCatalog/ || exit 1\n' > /usr/local/bin/health-check.sh && \
    chmod +x /usr/local/bin/health-check.sh

# Security: Remove unnecessary packages and files
RUN rm -f /usr/bin/systemctl

# Expose HTTP port
EXPOSE 80

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Set working directory
WORKDIR /var/www/html

# Use startup script as entrypoint
ENTRYPOINT ["/usr/local/bin/start-webdna.sh"]