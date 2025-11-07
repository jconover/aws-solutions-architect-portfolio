# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AWS DevOps portfolio project demonstrating a production-ready multi-tier application with:
- Infrastructure as Code (both Terraform and CloudFormation)
- Multi-tier application (Node.js backend, NGINX frontend, PostgreSQL database)
- Jenkins CI/CD pipeline with comprehensive security scanning
- Dual deployment strategies (ECS Fargate and EKS)

**Purpose**: Demonstrate AWS Solutions Architect knowledge and DevSecOps practices for portfolio/interview purposes.

## Architecture

### Three-Tier Infrastructure Design

1. **Network Layer**: Multi-AZ VPC (10.20.0.0/16) with three subnet tiers
   - Public subnets (10.20.1.0/24, 10.20.2.0/24): ALB, NAT Gateway
   - Private subnets (10.20.10.0/24, 10.20.11.0/24): Application containers
   - Data subnets (10.20.20.0/24, 10.20.21.0/24): RDS PostgreSQL 17.4 instances

2. **Application Layer**:
   - Frontend: NGINX serving static files, proxying `/api/*` to backend
   - Backend: Express.js REST API with PostgreSQL connection pool
   - Database: RDS PostgreSQL with init scripts in `application/database/`

3. **Security Layer**: Five-stage security pipeline (SAST → Dependency → IaC → Container → DAST)

### Terraform Module Architecture

Modules are designed for reusability and follow AWS best practices:
- **vpc module**: Creates full network topology with NAT, IGW, route tables
- **ecs module**: Creates cluster, ALB, target groups, ECR repos, security groups
- **eks module**: Creates EKS cluster (v1.33), managed node groups, IRSA, autoscaler
- **ec2 module**: Creates Jenkins server and optional bastion host with user data
- **s3 module**: Creates artifacts/logs/backups buckets with lifecycle policies
- **iam module**: Creates least-privilege roles for ECS tasks, EKS, Jenkins

The `infrastructure/terraform/environments/dev/main.tf` composes these modules together and adds RDS instance.

### Security Scanning Pipeline Flow

Jenkins pipeline (`jenkins/Jenkinsfile`) runs security checks in this order:
1. **Parallel Static Analysis**: SonarQube (SAST) + Snyk (dependencies) + Checkov/tfsec (IaC)
2. **Quality Gate**: Blocks on SonarQube failures
3. **Build**: Docker images for frontend/backend
4. **Container Scan**: Trivy checks for CVEs in images
5. **Deploy**: To ECS and/or EKS
6. **DAST**: OWASP ZAP scans running application

Each scan has a dedicated script in `jenkins/scripts/` that can be run independently.

## Common Commands

### Infrastructure Deployment

```bash
# Deploy infrastructure (from project root)
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_db_password="SecurePassword123!"
terraform init
terraform plan
terraform apply

# Get outputs for later use
terraform output -json > outputs.json
```

### Local Development

```bash
# Run full stack locally
cd docker
docker-compose up -d

# View logs
docker-compose logs -f [service]  # service: frontend, backend, database

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build [service]
```

### Docker Image Management

```bash
# Build images for AWS deployment
cd docker
docker-compose build

# Login to ECR (requires AWS CLI configured)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Tag and push (replace ACCOUNT_ID)
docker tag devops-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/backend:latest
```

### Security Scanning (Local)

```bash
# All scripts must be run from project root

# IaC security scan (Checkov + tfsec)
./jenkins/scripts/iac-scan.sh

# Container vulnerability scan (requires images built)
export FRONTEND_IMAGE=devops-frontend:latest
export BACKEND_IMAGE=devops-backend:latest
export IMAGE_TAG=latest
./jenkins/scripts/container-scan.sh

# DAST scan (requires running application)
export APP_URL=http://localhost
./jenkins/scripts/dast-scan.sh
```

### Database Operations

```bash
# Connect to local database
docker exec -it devops-db psql -U dbadmin -d appdb

# Connect to RDS (get endpoint from terraform output)
psql -h <rds-endpoint> -U dbadmin -d appdb

# Run init script on RDS
psql -h <rds-endpoint> -U dbadmin -d appdb -f application/database/init.sql
```

### Kubernetes/EKS Deployment

```bash
# Configure kubectl for EKS cluster
aws eks update-kubeconfig --name devops-portfolio-cluster --region us-east-1

# Update image references in manifests (replace ACCOUNT_ID)
find kubernetes/ -name "*.yaml" -exec sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" {} \;

# Deploy to EKS
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/

# Check status
kubectl get pods
kubectl get services
kubectl logs -f deployment/backend
```

### Jenkins Server Management

```bash
# Deploy Jenkins EC2 instance (add to main.tf and uncomment)
# See infrastructure/terraform/modules/ec2/README.md for full configuration

# After deployment, get Jenkins URL
terraform output jenkins_url

# SSH to Jenkins server
ssh -i your-key.pem ec2-user@<jenkins-ip>

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# Or use helper command
jenkins-password

# Check Jenkins service status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f
```

## Important Implementation Details

### Environment Variables and Secrets

- **Database password**: Never commit to code. Use `TF_VAR_db_password` environment variable for Terraform, or AWS Secrets Manager for production.
- **ECS Task Definitions**: Reference secrets from AWS Secrets Manager using the `secrets` array (see `jenkins/ecs-task-definition-*.json`)
- **Local Development**: Uses hardcoded password in `docker-compose.yml` for convenience (acceptable for local-only)

### Security Scan Thresholds

All security scripts in `jenkins/scripts/` are configured to fail the pipeline on HIGH/CRITICAL issues:
- **Checkov/tfsec**: Hard fail on HIGH/CRITICAL, soft fail on MEDIUM
- **Trivy**: Only fails if CRITICAL vulnerabilities have available fixes
- **OWASP ZAP**: Fails on high-risk alerts (exit code 2)

Thresholds can be adjusted in the individual scripts.

### ECS vs EKS Deployment Patterns

- **ECS**: Uses JSON task definitions that reference IAM roles created by Terraform. Update `ACCOUNT_ID` and `RDS_ENDPOINT` placeholders before registering.
- **EKS**: Uses standard Kubernetes manifests. Backend uses IRSA (IAM Roles for Service Accounts) pattern with `eks.amazonaws.com/role-arn` annotation.

### Cost Optimization Configurations

Development environment is configured for cost savings:
- Single NAT Gateway instead of one per AZ (`single_nat_gateway = true`)
- Fargate Spot enabled with 50% weight (`enable_fargate_spot = true`)
- Small RDS instance (`db.t3.micro`)
- S3 lifecycle policies move logs to Glacier after 30 days
- ECR lifecycle keeps only 10 most recent images

## Modifying Infrastructure

### Adding a New Terraform Module

1. Create module directory: `infrastructure/terraform/modules/your-module/`
2. Create `main.tf`, `variables.tf`, `outputs.tf`
3. Add module call in `infrastructure/terraform/environments/dev/main.tf`
4. Pass outputs to dependent modules via module references

### Updating Security Group Rules

Security groups are defined in:
- ALB SG: `infrastructure/terraform/modules/ecs/main.tf` (allows 80/443 from internet)
- ECS Tasks SG: Same file (allows traffic from ALB only)
- RDS SG: `infrastructure/terraform/environments/dev/main.tf` (allows 5432 from ECS tasks)

### Changing Application Ports

If changing backend port from 3000:
1. Update `application/backend/server.js` PORT constant
2. Update `docker/frontend/nginx.conf` proxy_pass directive
3. Update ECS task definition `jenkins/ecs-task-definition-backend.json`
4. Update Kubernetes deployment `kubernetes/deployments/backend-deployment.yaml`
5. Update security group ingress rules in Terraform

## Jenkins Configuration Requirements

When setting up Jenkins, configure these credentials (ID must match Jenkinsfile):
- `aws-account-id`: AWS Account ID (secret text)
- `sonar-token`: SonarQube authentication token
- `snyk-token`: Snyk API token

Required Jenkins plugins:
- AWS Credentials Plugin
- Docker Pipeline Plugin
- SonarQube Scanner Plugin
- Pipeline Plugin

## Common Troubleshooting

### ECS Tasks Fail to Start
- Check CloudWatch logs: `aws logs tail /ecs/devops-portfolio --follow`
- Verify task execution role has permissions for ECR, Secrets Manager, CloudWatch
- Ensure security groups allow traffic between ALB and tasks

### Database Connection Fails
- Verify RDS security group allows inbound 5432 from ECS task security group
- Check DB_HOST environment variable matches RDS endpoint
- Ensure DB_PASSWORD secret exists in Secrets Manager (for production) or is set in environment

### Terraform State Conflicts
- This project doesn't use remote state by default
- For team use, uncomment the S3 backend block in `infrastructure/terraform/environments/dev/main.tf`
- Create S3 bucket and DynamoDB table for state locking first

### Security Scan False Positives
- Add exclusions to `.checkov.yml` for Checkov
- Use `# nosec` comments for specific lines
- Update `jenkins/scripts/*-scan.sh` to adjust severity thresholds

## Project Context

This project is designed as a portfolio piece for AWS Solutions Architect certification and DevSecOps demonstration. Key design decisions:

- **Both Terraform and CloudFormation**: Shows proficiency with multiple IaC tools
- **Both ECS and EKS**: Demonstrates understanding of trade-offs between managed container services
- **Multiple security tools**: Comprehensive coverage of SAST, SCA, DAST, IaC scanning
- **Multi-AZ architecture**: Follows AWS Well-Architected Framework for high availability
- **Cost-optimized dev environment**: Shows understanding of AWS cost management

When making changes, maintain this educational/demonstrative purpose rather than optimizing purely for production use.
