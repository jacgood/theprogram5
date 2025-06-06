# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dockerized WebDNA Server v8.6.5 setup running on Ubuntu 22.04 with Apache 2.4. WebDNA is a server-side scripting language and database system for web applications.

## Common Commands

### Docker Operations
```bash
# Build and start the container
docker compose up --build -d

# Stop the container
docker compose down

# View logs
docker compose logs -f

# Restart the container
docker compose restart

# Access container shell
docker compose exec webdna-server bash

# Check container health
docker compose ps
```

### Development Commands
```bash
# Test Apache configuration (inside container)
docker compose exec webdna-server apache2ctl configtest

# Reload Apache configuration (inside container)
docker compose exec webdna-server apache2ctl graceful

# View Apache error logs
tail -f logs/error.log

# View Apache access logs
tail -f logs/access.log
```

## Architecture & Key Components

### Container Architecture
- **Base**: Ubuntu 22.04 LTS with Apache 2.4
- **WebDNA Module**: libapache2-mod-webdna v8.6.5
- **Port Mapping**: Host 8080 → Container 80
- **Health Check**: GET request to /WebCatalog endpoint

### Volume Mounts
- `./webdna-files` → `/var/www/html/webdna-files` - WebDNA application files
- `./logs` → `/var/log/apache2` - Apache logs for debugging

### Configuration Files
- **corrected-webdna.conf**: WebDNA Apache module configuration with security rules blocking access to .db, .hdr files and admin directories
- **webdna-site.conf**: Apache virtual host configuration setting document root and WebCatalog permissions
- **start-webdna.sh**: Container initialization script that handles first-run setup, permissions, and Apache startup

### Security Configuration
The setup includes security measures to protect sensitive WebDNA files:
- Blocks access to database files (.db, .hdr)
- Protects WebDNA admin directories (WebCatalogPrefs, WebCatalogCtl)
- Secures WebMerchant directories (Orders, StockRoom, etc.)

### Access Information
- WebCatalog URL: http://localhost:8080/WebCatalog
- Default credentials: admin/admin

## Important Notes

- WebDNA files should be placed in the `webdna-files/` directory for persistence
- The container runs Apache as the `www-data` user
- WebDNA templates use .tpl, .tmpl, or .dna extensions
- The container includes automatic restart on failure (unless-stopped policy)
- First run initialization is handled automatically by start-webdna.sh