# AWS CloudForge Project with Jenkins & Security Scanning

A comprehensive DevOps portfolio project demonstrating AWS services, containerization, CI/CD with Jenkins, and security best practices.

## Project Overview

This project showcases a production-ready multi-tier application deployment on AWS using modern DevOps practices, including:

- **AWS Services**: IAM, EC2, S3, ECS, EKS
- **Infrastructure as Code**: Terraform and CloudFormation
- **CI/CD**: Jenkins with automated pipelines
- **Security**: Multiple security scanning tools integrated into the pipeline
- **Container Orchestration**: Both ECS (Fargate) and EKS (Kubernetes) for comparison

## Architecture

### Multi-Tier Application
- **Frontend**: React/Vue application served via NGINX
- **Backend**: REST API (Node.js/Express)
- **Database**: RDS PostgreSQL 17.4

### Deployment Options
1. **ECS Fargate**: Serverless container deployment
2. **EKS**: Kubernetes-based orchestration

### Infrastructure
- VPC with public/private subnets across multiple AZs
- Application Load Balancer for traffic distribution
- NAT Gateway for private subnet internet access
- S3 for artifact storage and static assets
- IAM roles following least privilege principle

## Security Scanning Pipeline

The Jenkins pipeline includes comprehensive security checks:

1. **SAST (Static Application Security Testing)**
   - SonarQube for code quality and security vulnerabilities
   - Snyk for dependency vulnerability scanning

2. **Container Scanning**
   - Trivy for Docker image vulnerability scanning
   - Reports CVEs and misconfigurations

3. **IaC Scanning**
   - Checkov for Terraform security analysis
   - tfsec for Terraform best practices
   - CloudFormation security validation

4. **DAST (Dynamic Application Security Testing)**
   - OWASP ZAP for runtime security testing
   - API security testing

## Project Structure

```
.
├── application/          # Multi-tier application code
│   ├── frontend/        # React/Vue frontend
│   ├── backend/         # API backend
│   └── database/        # Database migrations and seeds
├── infrastructure/      # Infrastructure as Code
│   ├── terraform/       # Terraform configurations
│   │   ├── modules/    # Reusable Terraform modules
│   │   └── environments/ # Environment-specific configs
│   └── cloudformation/  # CloudFormation templates
├── jenkins/            # Jenkins pipeline configurations
│   ├── Jenkinsfile     # Main pipeline
│   ├── Jenkinsfile.ecs # ECS deployment pipeline
│   ├── Jenkinsfile.eks # EKS deployment pipeline
│   └── scripts/        # Security scanning scripts
├── kubernetes/         # Kubernetes manifests for EKS
│   ├── deployments/
│   ├── services/
│   └── ingress/
└── docker/            # Docker configurations
    ├── frontend/
    ├── backend/
    └── docker-compose.yml
```

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.5.0
- Docker and Docker Compose
- kubectl (for EKS)
- Jenkins server (or use EC2 instance)
- Helm (for EKS add-ons)

## Getting Started

### 1. Infrastructure Setup

#### Using Terraform
```bash
cd infrastructure/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

#### Using CloudFormation
```bash
cd infrastructure/cloudformation
aws cloudformation create-stack \
  --stack-name cloudforge-vpc \
  --template-body file://vpc.yaml
```

### 2. Application Deployment

#### Deploy to ECS
```bash
# Build and push Docker images
docker-compose build
docker-compose push

# Deploy via Jenkins or manual
aws ecs update-service --cluster app-cluster --service app-service --force-new-deployment
```

#### Deploy to EKS
```bash
# Configure kubectl
aws eks update-kubeconfig --name app-cluster

# Apply Kubernetes manifests
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
```

### 3. Jenkins Setup

1. Launch Jenkins on EC2 or local
2. Install required plugins:
   - AWS Credentials
   - Docker Pipeline
   - Kubernetes
   - SonarQube Scanner
   - OWASP Dependency-Check

3. Configure credentials in Jenkins:
   - AWS credentials
   - Docker Hub credentials
   - SonarQube token

4. Create pipeline jobs using the Jenkinsfiles

## Security Scanning

### Running Security Scans Locally

```bash
# SAST with SonarQube
./jenkins/scripts/sast-scan.sh

# Container scanning with Trivy
./jenkins/scripts/container-scan.sh

# IaC scanning
./jenkins/scripts/iac-scan.sh

# DAST with OWASP ZAP
./jenkins/scripts/dast-scan.sh
```

## Cost Optimization

- ECS Fargate Spot for non-production environments
- Auto-scaling based on CloudWatch metrics
- S3 lifecycle policies for artifact retention
- NAT Gateway in single AZ for dev environment

## Learning Outcomes

This project demonstrates knowledge of:

- AWS core services and best practices
- Infrastructure as Code with multiple tools
- Container orchestration (ECS vs EKS trade-offs)
- CI/CD pipeline design and implementation
- Security scanning and DevSecOps practices
- Multi-tier application architecture
- High availability and fault tolerance
- IAM security and least privilege

## AWS Solutions Architect Exam Alignment

This project covers key SA exam topics:

- **Design Resilient Architectures**: Multi-AZ, Auto-scaling, Load Balancing
- **Design High-Performing Architectures**: ECS, EKS, caching strategies
- **Design Secure Applications**: IAM, Security Groups, encryption
- **Design Cost-Optimized Architectures**: Spot instances, right-sizing
- **Design Operationally Excellent Architectures**: IaC, CI/CD, monitoring

## Next Steps

- [ ] Add CloudWatch monitoring and alerting
- [ ] Implement AWS Secrets Manager for secrets
- [ ] Add AWS WAF for application protection
- [ ] Implement blue-green deployments
- [ ] Add cost tracking with AWS Cost Explorer tags
- [ ] Implement backup and disaster recovery

## License

MIT License - Feel free to use for your portfolio

## Contact

[Your Name]
[LinkedIn/GitHub links]
