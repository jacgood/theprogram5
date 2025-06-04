FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Update system and install required packages
RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    gnupg \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install WebDNA public key
RUN curl https://deb.webdna.us/ubuntu23/webdna.key | gpg --dearmor > webdna.gpg && \
    install -o root -g root -m 644 webdna.gpg /etc/apt/trusted.gpg.d/

# Add WebDNA repository to sources list
RUN echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/webdna.gpg] https://deb.webdna.us/ubuntu23 lunar non-free" | tee -a /etc/apt/sources.list

# Create a mock systemctl for the installation since WebDNA installer expects it
RUN echo '#!/bin/bash\necho "Mock systemctl called with: $@"\nexit 0' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# Update apt and install WebDNA apache module
RUN apt-get update && \
    apt-get install -y libapache2-mod-webdna=8.6.5 && \
    rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY corrected-webdna.conf /etc/apache2/mods-available/webdna.conf
COPY webdna-site.conf /etc/apache2/sites-available/webdna-site.conf
COPY start-webdna.sh /usr/local/bin/start-webdna.sh

# Make startup script executable
RUN chmod +x /usr/local/bin/start-webdna.sh

# Enable Apache modules including WebDNA
RUN a2enmod rewrite && \
    a2enmod headers && \
    a2enmod webdna && \
    a2enmod speling && \
    a2enmod alias && \
    a2enmod dir

# Configure Apache environment variables
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_LOG_DIR=/var/log/apache2

# Create initialization directory for the script
RUN mkdir -p /opt/webdna

# Create empty html directory (will be replaced by mount)
RUN mkdir -p /var/www/html && \
    chmod 755 /var/www/html

# Expose port 80 for Apache
EXPOSE 80

# Set working directory
WORKDIR /var/www/html

# Use the startup script
CMD ["/usr/local/bin/start-webdna.sh"]