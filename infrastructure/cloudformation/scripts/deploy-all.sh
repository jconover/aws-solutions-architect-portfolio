#!/bin/bash
# Deploy all CloudFormation stacks in correct order
# Usage: ./deploy-all.sh <environment> <db-password>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_NAME="cloudforge"
ENVIRONMENT="${1:-dev}"
DB_PASSWORD="${2}"
AWS_REGION="${AWS_REGION:-us-east-1}"
STACKS_DIR="../stacks"

# Validate inputs
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: DB password is required${NC}"
    echo "Usage: $0 <environment> <db-password>"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CloudFormation Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to deploy stack
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters=$3

    echo -e "${YELLOW}Deploying stack: ${stack_name}${NC}"

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "Stack exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://${template_file}" \
            --parameters $parameters \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION" || {
                error_msg=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" --query 'Stacks[0].StackStatusReason' --output text 2>&1)
                if [[ "$error_msg" == *"No updates are to be performed"* ]]; then
                    echo -e "${GREEN}No updates needed for $stack_name${NC}"
                    return 0
                fi
                echo -e "${RED}Failed to update stack $stack_name${NC}"
                return 1
            }

        echo "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$stack_name" \
            --region "$AWS_REGION"
    else
        echo "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://${template_file}" \
            --parameters $parameters \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION" --tags \
            Key=Project,Value=$PROJECT_NAME \
            Key=Environment,Value=$ENVIRONMENT \
            Key=ManagedBy,Value=CloudFormation

        echo "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete \
            --stack-name "$stack_name" \
            --region "$AWS_REGION"
    fi

    echo -e "${GREEN}✓ Stack ${stack_name} deployed successfully${NC}"
    echo ""
}

# Deploy stacks in order
echo -e "${YELLOW}Step 1/4: Deploying VPC Stack${NC}"
deploy_stack \
    "${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
    "${STACKS_DIR}/01-vpc.yaml" \
    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT"

echo -e "${YELLOW}Step 2/4: Deploying IAM Stack${NC}"
deploy_stack \
    "${PROJECT_NAME}-${ENVIRONMENT}-iam" \
    "${STACKS_DIR}/02-iam.yaml" \
    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT"

echo -e "${YELLOW}Step 3/4: Deploying S3 Stack${NC}"
deploy_stack \
    "${PROJECT_NAME}-${ENVIRONMENT}-s3" \
    "${STACKS_DIR}/03-s3.yaml" \
    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT"

echo -e "${YELLOW}Step 4/4: Deploying RDS Stack${NC}"
deploy_stack \
    "${PROJECT_NAME}-${ENVIRONMENT}-rds" \
    "${STACKS_DIR}/04-rds.yaml" \
    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All stacks deployed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Stack Outputs:"
echo "-------------"

# Get outputs from stacks
aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-${ENVIRONMENT}-rds" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo "Next Steps:"
echo "1. Build and push Docker images to ECR (create ECS/EKS stacks first)"
echo "2. Deploy ECS services: ./deploy-ecs.sh $ENVIRONMENT"
echo "3. Deploy EKS cluster: ./deploy-eks.sh $ENVIRONMENT"
echo ""
echo "To view all stack resources:"
echo "  aws cloudformation describe-stack-resources --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-vpc"
