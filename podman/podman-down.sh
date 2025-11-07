#!/bin/bash
# Cleanup script for Podman deployment
# Stops and removes the devops-portfolio pod and containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping DevOps Portfolio Podman deployment...${NC}"

# Stop and remove containers
echo -e "${YELLOW}Removing containers...${NC}"
podman rm -f devops-backend devops-frontend devops-postgres 2>/dev/null || true

# Stop and remove pod
echo -e "${YELLOW}Removing pod...${NC}"
podman pod stop devops-portfolio 2>/dev/null || true
podman pod rm devops-portfolio 2>/dev/null || true

echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
echo "To remove the PostgreSQL volume (WARNING: This deletes all data):"
echo "  podman volume rm postgres-data"
echo ""
echo "To remove the NGINX config file:"
echo "  rm podman/nginx-pod.conf"
