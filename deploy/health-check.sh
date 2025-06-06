#!/bin/bash
# Production health check script

set -e

# Configuration
WEBDNA_URL="http://localhost:8081/WebCatalog"
NGINX_URL="https://dev.goodvaluation.com/theprogram"
APP_URL="http://localhost:8081/theprogram/"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Production Health Check ==="
echo ""

# Check if containers are running
echo "Checking container status..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "Running health checks..."

# Check WebDNA directly
echo -n "WebDNA Engine: "
if curl -f -s "$WEBDNA_URL" > /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi

# Check Apache/App directly
echo -n "Application (local): "
if curl -f -s "$APP_URL" > /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi

# Check Nginx
echo -n "Nginx proxy: "
if docker-compose -f docker-compose.prod.yml exec nginx nginx -t 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi

# Check database
echo -n "PostgreSQL: "
if docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U webdna_user > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi

# Check logs for errors
echo ""
echo "Recent errors (if any):"
docker-compose -f docker-compose.prod.yml logs --tail=10 webdna-server | grep -i error || echo "No recent errors"

echo ""
echo -e "${GREEN}All health checks passed!${NC}"
echo ""
echo "Application should be accessible at:"
echo "  - Local: http://localhost:8081/theprogram/"
echo "  - Production: https://dev.goodvaluation.com/theprogram"