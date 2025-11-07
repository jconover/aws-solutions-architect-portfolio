#!/bin/bash
# Podman play kube script for DevOps Portfolio
# This script deploys the application using Podman's Kubernetes YAML support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting DevOps Portfolio with Podman Play Kube${NC}"

# Navigate to the podman directory
cd "$(dirname "$0")"

# Check if images exist
echo -e "${YELLOW}Checking for required images...${NC}"
if ! podman image exists localhost/docker-backend:latest; then
    echo -e "${RED}Backend image not found. Building...${NC}"
    podman build -t localhost/docker-backend:latest -f ../docker/backend/Dockerfile ..
fi

if ! podman image exists localhost/docker-frontend:latest; then
    echo -e "${RED}Frontend image not found. Building...${NC}"
    podman build -t localhost/docker-frontend:latest -f ../docker/frontend/Dockerfile ..
fi

# Stop and remove existing pod
echo -e "${YELLOW}Stopping existing pod if running...${NC}"
podman pod stop devops-portfolio 2>/dev/null || true
podman pod rm devops-portfolio 2>/dev/null || true
podman kube down devops-portfolio-pod.yaml 2>/dev/null || true

# Deploy using play kube
echo -e "${GREEN}Deploying pod with play kube...${NC}"
podman play kube devops-portfolio-pod.yaml

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 15

# Check pod status
echo -e "${GREEN}Checking pod status...${NC}"
podman pod ps
echo ""
podman ps --filter pod=devops-portfolio

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Access the application at:"
echo -e "  ${GREEN}Frontend:${NC} http://localhost:8081"
echo -e "  ${GREEN}Backend API:${NC} http://localhost:3001/api/health"
echo -e "  ${GREEN}PostgreSQL:${NC} localhost:5433"
echo ""
echo "Useful commands:"
echo "  podman pod logs devops-portfolio                    # View all pod logs"
echo "  podman logs devops-portfolio-frontend               # View frontend logs"
echo "  podman logs devops-portfolio-backend                # View backend logs"
echo "  podman logs devops-portfolio-postgres               # View database logs"
echo "  podman pod stop devops-portfolio                    # Stop the pod"
echo "  podman pod start devops-portfolio                   # Start the pod"
echo "  podman kube down devops-portfolio-pod.yaml          # Remove the pod"
