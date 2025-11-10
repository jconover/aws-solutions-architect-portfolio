#!/bin/bash
# Podman deployment script for CloudForge
# This script starts the application using Podman Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting CloudForge with Podman Compose${NC}"

# Check if podman-compose is installed
if ! command -v podman-compose &> /dev/null; then
    echo -e "${YELLOW}podman-compose not found. Install it with:${NC}"
    echo "  pip3 install podman-compose"
    echo ""
    echo -e "${YELLOW}Or use Podman directly with the pod YAML:${NC}"
    echo "  ./podman-play.sh"
    exit 1
fi

# Navigate to the podman directory
cd "$(dirname "$0")"

# Stop any running containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
podman-compose down 2>/dev/null || true

# Build and start containers
echo -e "${GREEN}Building and starting containers...${NC}"
podman-compose up -d --build

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Check status
echo -e "${GREEN}Checking container status...${NC}"
podman-compose ps

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Access the application at:"
echo -e "  ${GREEN}Frontend:${NC} http://localhost:8081"
echo -e "  ${GREEN}Backend API:${NC} http://localhost:3001/api/health"
echo -e "  ${GREEN}PostgreSQL:${NC} localhost:5433"
echo ""
echo "Useful commands:"
echo "  podman-compose logs -f          # View logs"
echo "  podman-compose ps               # Check status"
echo "  podman-compose down             # Stop all containers"
echo "  podman-compose restart          # Restart all containers"
