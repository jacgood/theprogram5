#!/bin/bash

# GitHub Actions Self-Hosted Runner Installation Script
# This script installs and configures a GitHub Actions runner for your repository

set -e

# Configuration
RUNNER_DIR="/opt/actions-runner"
RUNNER_USER="runner"
RUNNER_GROUP="runner"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitHub Actions Self-Hosted Runner Installation${NC}"
echo "================================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Create runner user if it doesn't exist
if ! id "$RUNNER_USER" &>/dev/null; then
    echo -e "${YELLOW}Creating runner user...${NC}"
    useradd -m -s /bin/bash $RUNNER_USER
    usermod -aG docker $RUNNER_USER 2>/dev/null || true
fi

# Create runner directory
echo -e "${YELLOW}Creating runner directory...${NC}"
mkdir -p $RUNNER_DIR
chown -R $RUNNER_USER:$RUNNER_GROUP $RUNNER_DIR

# Download and extract runner
echo -e "${YELLOW}Downloading GitHub Actions runner...${NC}"
cd $RUNNER_DIR

# Get latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "Latest runner version: $RUNNER_VERSION"

# Download runner
sudo -u $RUNNER_USER curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract runner
echo -e "${YELLOW}Extracting runner...${NC}"
sudo -u $RUNNER_USER tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
./bin/installdependencies.sh

echo -e "${GREEN}Runner downloaded and extracted successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Go to your GitHub repository settings:"
echo "   Settings > Actions > Runners > New self-hosted runner"
echo ""
echo "2. Get your registration token from GitHub"
echo ""
echo "3. Configure the runner as $RUNNER_USER:"
echo "   sudo -u $RUNNER_USER bash -c 'cd $RUNNER_DIR && ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN'"
echo ""
echo "4. Install as a service:"
echo "   cd $RUNNER_DIR && sudo ./svc.sh install $RUNNER_USER"
echo "   sudo ./svc.sh start"
echo ""
echo "5. Check service status:"
echo "   sudo ./svc.sh status"