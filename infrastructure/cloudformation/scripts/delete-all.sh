#!/bin/bash
# Delete all CloudFormation stacks
# Usage: ./delete-all.sh <environment>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_NAME="cloudforge"
ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${RED}========================================${NC}"
echo -e "${RED}CloudFormation Stack Deletion${NC}"
echo -e "${RED}========================================${NC}"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will delete all resources!${NC}"
echo "This includes:"
echo "  - ECS cluster, services, and task definitions"
echo "  - Application Load Balancer"
echo "  - VPC and all networking resources"
echo "  - RDS database (a snapshot will be created)"
echo "  - S3 buckets (must be empty first)"
echo "  - ECR repositories and all container images"
echo "  - IAM roles and policies"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# Function to delete stack
delete_stack() {
    local stack_name=$1

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo -e "${YELLOW}Deleting stack: ${stack_name}${NC}"

        aws cloudformation delete-stack \
            --stack-name "$stack_name" \
            --region "$AWS_REGION"

        echo "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete \
            --stack-name "$stack_name" \
            --region "$AWS_REGION"

        echo -e "${GREEN}✓ Stack ${stack_name} deleted successfully${NC}"
    else
        echo -e "${YELLOW}Stack ${stack_name} does not exist, skipping${NC}"
    fi
    echo ""
}

# Get Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Empty ECR repositories first
echo -e "${YELLOW}Emptying ECR repositories...${NC}"
for repo in "backend" "frontend"; do
    REPO_NAME="${PROJECT_NAME}/${repo}"
    if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "Deleting images from repository: $REPO_NAME"
        # Get all image IDs
        IMAGE_IDS=$(aws ecr list-images --repository-name "$REPO_NAME" --region "$AWS_REGION" --query 'imageIds[*]' --output json)
        if [ "$IMAGE_IDS" != "[]" ]; then
            aws ecr batch-delete-image \
                --repository-name "$REPO_NAME" \
                --region "$AWS_REGION" \
                --image-ids "$IMAGE_IDS" || true
            echo "  Deleted all images from $REPO_NAME"
        else
            echo "  No images found in $REPO_NAME"
        fi
    else
        echo "Repository $REPO_NAME does not exist, skipping"
    fi
done
echo ""

# Empty S3 buckets
echo -e "${YELLOW}Emptying S3 buckets...${NC}"
for bucket in "artifacts" "logs" "backups"; do
    BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${bucket}-${ACCOUNT_ID}"
    if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
        echo "Emptying bucket: $BUCKET_NAME"
        aws s3 rm "s3://$BUCKET_NAME" --recursive || true
        # Remove all versions if versioning is enabled
        aws s3api delete-objects --bucket "$BUCKET_NAME" \
            --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" \
            --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --max-items 1000)" 2>/dev/null || true
    fi
done
echo ""

# Delete stacks in reverse order (ECS first since it depends on other stacks)
echo -e "${YELLOW}Deleting stacks in reverse order...${NC}"
echo ""

delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-ecs"
delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-ecr"
delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-rds"
delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-s3"
delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-iam"
delete_stack "${PROJECT_NAME}-${ENVIRONMENT}-vpc"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All stacks deleted successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Note: RDS snapshots may still exist. To view them:"
echo "  aws rds describe-db-snapshots --query 'DBSnapshots[?contains(DBSnapshotIdentifier, \`${PROJECT_NAME}\`)]'"
echo ""
echo "To delete a snapshot:"
echo "  aws rds delete-db-snapshot --db-snapshot-identifier <snapshot-id>"
