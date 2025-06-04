#!/bin/bash
# Script to fix ownership of directories for development

echo "This script will fix ownership of project directories"
echo "You may be prompted for your sudo password"
echo ""

# Change ownership to current user
sudo chown -R $(whoami):$(whoami) html WebCatalogEngine logs

# Set appropriate permissions
chmod -R 755 html WebCatalogEngine
chmod -R 755 logs

echo "Ownership fixed. Directories are now owned by: $(whoami)"
ls -la | grep -E "(html|WebCatalogEngine|logs)"