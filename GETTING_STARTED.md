# Getting Started Guide

This guide will help you deploy the AWS DevOps Portfolio project to your AWS account.

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** >= 1.5.0
   ```bash
   terraform --version
   ```
4. **Docker** and Docker Compose
   ```bash
   docker --version
   docker-compose --version
   ```
5. **kubectl** (for EKS deployment)
   ```bash
   kubectl version --client
   ```
6. **Git**
   ```bash
   git --version
   ```

## Quick Start

### Step 1: Clone and Configure

```bash
# Navigate to the project
cd aws-solutions-architect-portfolio

# Copy and edit Terraform variables
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

**Important variables to set:**
- `project_name`: Your project name
- `aws_region`: Your preferred AWS region
- `db_password`: Set via environment variable for security

### Step 2: Deploy Infrastructure with Terraform

```bash
# Set database password as environment variable
export TF_VAR_db_password="YourSecurePassword123!"

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Save the outputs
terraform output > outputs.txt
```

**Important outputs:**
- `alb_dns_name`: Your application URL
- `ecs_cluster_name`: ECS cluster name
- `frontend_ecr_url`: Frontend ECR repository
- `backend_ecr_url`: Backend ECR repository
- `rds_endpoint`: Database endpoint

### Step 3: Build and Push Docker Images

```bash
# Go back to project root
cd ../../../../

# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build images
cd docker
docker-compose build

# Tag and push images
docker tag devops-backend:latest \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/backend:latest

docker tag devops-frontend:latest \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/frontend:latest

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-portfolio/frontend:latest
```

### Step 4: Initialize Database

```bash
# Get RDS endpoint from Terraform outputs
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Connect to RDS and run init script
psql -h $RDS_ENDPOINT -U dbadmin -d appdb -f application/database/init.sql
# Enter the password you set in Step 2
```

### Step 5: Deploy to ECS

```bash
# Update task definitions with your account ID
cd jenkins
sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" ecs-task-definition-backend.json
sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" ecs-task-definition-frontend.json

# Update RDS endpoint in backend task definition
sed -i "s/RDS_ENDPOINT/${RDS_ENDPOINT}/g" ecs-task-definition-backend.json

# Register task definitions
aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition-backend.json

aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition-frontend.json

# Create ECS services (you'll need to get subnet IDs and security group IDs from Terraform outputs)
# See the detailed ECS deployment guide in docs/
```

### Step 6: Set Up Jenkins (Optional)

#### Option A: Run Jenkins on EC2

```bash
# Launch EC2 instance with Jenkins IAM role
# Use the jenkins_instance_profile from Terraform outputs

# SSH into the instance
ssh -i your-key.pem ec2-user@your-jenkins-instance

# Install Jenkins
sudo yum update -y
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum upgrade
sudo amazon-linux-extras install java-openjdk11 -y
sudo yum install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### Option B: Run Jenkins Locally with Docker

```bash
docker run -d \
    --name jenkins \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 7: Configure Jenkins Pipeline

1. Open Jenkins at `http://your-jenkins-url:8080`
2. Install required plugins:
   - AWS Credentials
   - Docker Pipeline
   - SonarQube Scanner
   - Pipeline
3. Add credentials:
   - AWS credentials (Access Key ID and Secret Access Key)
   - SonarQube token
   - Snyk token
4. Create a new Pipeline job
5. Point it to your Git repository
6. Set Jenkinsfile path to `jenkins/Jenkinsfile`
7. Run the pipeline

## Testing Locally

Before deploying to AWS, test locally:

```bash
# Run with Docker Compose
cd docker
docker-compose up -d

# Check services
docker-compose ps

# View logs
docker-compose logs -f

# Test backend API
curl http://localhost:3000/api/health
curl http://localhost:3000/api/items

# Test frontend
open http://localhost

# Stop services
docker-compose down
```

## Security Scans

Run security scans locally before pushing:

```bash
# IaC scanning
./jenkins/scripts/iac-scan.sh

# Container scanning (after building images)
export FRONTEND_IMAGE=devops-frontend:latest
export BACKEND_IMAGE=devops-backend:latest
export IMAGE_TAG=latest
./jenkins/scripts/container-scan.sh
```

## Troubleshooting

### Issue: ECR login fails
```bash
# Ensure AWS CLI is configured correctly
aws sts get-caller-identity

# Check ECR repository exists
aws ecr describe-repositories
```

### Issue: ECS tasks fail to start
```bash
# Check task logs in CloudWatch
aws logs tail /ecs/devops-portfolio --follow

# Check task definition
aws ecs describe-task-definition --task-definition devops-portfolio-backend
```

### Issue: Cannot connect to RDS
```bash
# Check security group allows traffic from ECS tasks
# Verify RDS endpoint is correct
# Check database credentials in Secrets Manager or environment variables
```

### Issue: Terraform apply fails
```bash
# Check AWS credentials
aws configure list

# Validate Terraform syntax
terraform validate

# Check for resource conflicts
terraform state list
```

## Cost Optimization Tips

For development/testing:

1. **Use Fargate Spot** (enabled by default in dev)
2. **Single NAT Gateway** (enabled by default in dev)
3. **Small RDS instance** (db.t3.micro)
4. **Stop resources when not in use**:
   ```bash
   # Stop ECS services
   aws ecs update-service --cluster devops-portfolio-cluster \
       --service backend-service --desired-count 0

   # Stop RDS instance
   aws rds stop-db-instance --db-instance-identifier devops-portfolio-db
   ```

## Cleanup

To delete all resources:

```bash
# Delete ECS services first
aws ecs delete-service --cluster devops-portfolio-cluster \
    --service backend-service --force
aws ecs delete-service --cluster devops-portfolio-cluster \
    --service frontend-service --force

# Destroy Terraform resources
cd infrastructure/terraform/environments/dev
terraform destroy

# Delete ECR images
aws ecr batch-delete-image \
    --repository-name devops-portfolio/backend \
    --image-ids imageTag=latest

aws ecr batch-delete-image \
    --repository-name devops-portfolio/frontend \
    --image-ids imageTag=latest
```

## Next Steps

1. **Set up CloudWatch dashboards** for monitoring
2. **Configure AWS WAF** for additional security
3. **Implement blue-green deployments**
4. **Add CloudFront** for CDN
5. **Set up Route 53** for custom domain
6. **Enable AWS X-Ray** for tracing
7. **Configure AWS Backup** for automated backups
8. **Deploy to EKS** for Kubernetes experience

## Resources

- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Security Tools Documentation](docs/security-scans.md)

## Support

For issues or questions:
1. Check the [docs/](docs/) directory
2. Review CloudWatch logs
3. Check security group and IAM policies
4. Verify resource limits in your AWS account

## Contributing

Feel free to customize this project for your portfolio needs. Add features, improve security, or optimize costs based on your requirements.
