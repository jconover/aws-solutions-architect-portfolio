#!/bin/bash
# Push Docker images to ECR
# Usage: ./push-to-ecr.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
PROJECT_NAME="cloudforge"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pushing Images to ECR${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Account: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Registry: ${ECR_REGISTRY}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Login to ECR
echo -e "${YELLOW}Step 1: Logging into ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}
echo -e "${GREEN}✓ Successfully logged into ECR${NC}"
echo ""

# Check if images exist locally
echo -e "${YELLOW}Step 2: Checking local images...${NC}"
if docker images | grep -q "docker-frontend"; then
    echo "Found docker-frontend image"
    FRONTEND_IMAGE="docker-frontend:latest"
elif docker images | grep -q "cloudforge-frontend"; then
    echo "Found cloudforge-frontend image"
    FRONTEND_IMAGE="cloudforge-frontend:latest"
else
    echo -e "${RED}Error: Frontend image not found${NC}"
    echo "Available images:"
    docker images | grep -E "frontend|cloudforge"
    exit 1
fi

if docker images | grep -q "docker-backend"; then
    echo "Found docker-backend image"
    BACKEND_IMAGE="docker-backend:latest"
elif docker images | grep -q "cloudforge-backend"; then
    echo "Found cloudforge-backend image"
    BACKEND_IMAGE="cloudforge-backend:latest"
else
    echo -e "${RED}Error: Backend image not found${NC}"
    echo "Available images:"
    docker images | grep -E "backend|cloudforge"
    exit 1
fi
echo -e "${GREEN}✓ Found both images${NC}"
echo ""

# Tag images
echo -e "${YELLOW}Step 3: Tagging images for ECR...${NC}"
docker tag ${FRONTEND_IMAGE} ${ECR_REGISTRY}/${PROJECT_NAME}/frontend:latest
docker tag ${FRONTEND_IMAGE} ${ECR_REGISTRY}/${PROJECT_NAME}/frontend:${TIMESTAMP}
docker tag ${BACKEND_IMAGE} ${ECR_REGISTRY}/${PROJECT_NAME}/backend:latest
docker tag ${BACKEND_IMAGE} ${ECR_REGISTRY}/${PROJECT_NAME}/backend:${TIMESTAMP}
echo -e "${GREEN}✓ Images tagged${NC}"
echo ""

# Push images
echo -e "${YELLOW}Step 4: Pushing frontend to ECR...${NC}"
docker push ${ECR_REGISTRY}/${PROJECT_NAME}/frontend:latest
docker push ${ECR_REGISTRY}/${PROJECT_NAME}/frontend:${TIMESTAMP}
echo -e "${GREEN}✓ Frontend pushed successfully${NC}"
echo ""

echo -e "${YELLOW}Step 5: Pushing backend to ECR...${NC}"
docker push ${ECR_REGISTRY}/${PROJECT_NAME}/backend:latest
docker push ${ECR_REGISTRY}/${PROJECT_NAME}/backend:${TIMESTAMP}
echo -e "${GREEN}✓ Backend pushed successfully${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Images pushed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Verify images in ECR:"
echo "  aws ecr list-images --repository-name ${PROJECT_NAME}/frontend --region ${AWS_REGION}"
echo "  aws ecr list-images --repository-name ${PROJECT_NAME}/backend --region ${AWS_REGION}"
echo ""
echo "View in AWS Console:"
echo "  https://console.aws.amazon.com/ecr/repositories?region=${AWS_REGION}"
