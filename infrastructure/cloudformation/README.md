# CloudFormation Infrastructure

This directory contains AWS CloudFormation templates for deploying the CloudForge infrastructure. CloudFormation is AWS's native Infrastructure as Code (IaC) service.

## Why Both Terraform and CloudFormation?

This project includes **both Terraform and CloudFormation** implementations to demonstrate:
1. **Multi-tool proficiency** - Understanding both major IaC approaches
2. **AWS Solutions Architect knowledge** - CloudFormation is AWS-native and often required
3. **Comparative analysis** - Real-world experience with trade-offs between tools
4. **Flexibility** - Choose the right tool for your organization

See [TERRAFORM_VS_CLOUDFORMATION.md](./TERRAFORM_VS_CLOUDFORMATION.md) for detailed comparison.

## Directory Structure

```
cloudformation/
├── stacks/
│   ├── 01-vpc.yaml           # VPC, subnets, NAT, IGW, Flow Logs
│   ├── 02-iam.yaml           # IAM roles for ECS, EKS, Jenkins
│   ├── 03-s3.yaml            # S3 buckets for artifacts, logs, backups
│   ├── 04-rds.yaml           # PostgreSQL RDS database
│   ├── 05-ecr.yaml           # ECR repositories for container images
│   └── 06-ecs.yaml           # ECS Fargate cluster, ALB, services
├── parameters/
│   └── dev-parameters.json   # Parameter files for each environment
├── scripts/
│   ├── deploy-all.sh         # Deploy all stacks
│   └── delete-all.sh         # Clean up all resources
└── README.md                 # This file
```

## Prerequisites

- **AWS CLI** v2.x configured with appropriate credentials
- **AWS Account** with permissions to create CloudFormation stacks
- **Bash** for running deployment scripts
- **jq** (optional) for JSON processing

```bash
# Install AWS CLI
brew install awscli  # macOS
# or
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
```

## Quick Start

### 1. Deploy All Infrastructure

```bash
cd infrastructure/cloudformation/scripts

# Deploy to dev environment
./deploy-all.sh dev

# Deploy to production
./deploy-all.sh prod
```

> **Note:** Database credentials are automatically generated and stored in AWS Secrets Manager. No password input required.

### 2. View Stack Status

```bash
# List all stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Describe specific stack
aws cloudformation describe-stacks --stack-name cloudforge-dev-vpc

# View stack outputs
aws cloudformation describe-stacks \
  --stack-name cloudforge-dev-vpc \
  --query 'Stacks[0].Outputs' \
  --output table
```

### 3. Update a Stack

```bash
# Modify the template file, then update
aws cloudformation update-stack \
  --stack-name cloudforge-dev-vpc \
  --template-body file://stacks/01-vpc.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=cloudforge \
               ParameterKey=Environment,ParameterValue=dev
```

### 4. Delete All Resources

```bash
cd infrastructure/cloudformation/scripts
./delete-all.sh dev
```

## Detailed Stack Information

### 01-vpc.yaml - Network Infrastructure

**Creates:**
- VPC with CIDR 10.20.0.0/16
- 2 Public subnets (10.20.1.0/24, 10.20.2.0/24)
- 2 Private subnets (10.20.10.0/24, 10.20.11.0/24)
- 2 Data subnets for databases (10.20.20.0/24, 10.20.21.0/24)
- Internet Gateway
- NAT Gateway (optional)
- Route tables for each subnet tier
- VPC Flow Logs (optional)
- S3 VPC Endpoint

**Parameters:**
- `ProjectName` - Default: cloudforge
- `Environment` - dev/staging/prod
- `VpcCIDR` - Default: 10.20.0.0/16
- `EnableVpcFlowLogs` - true/false
- `EnableNatGateway` - true/false

**Exports:**
- VpcId, VpcCIDR
- PublicSubnet1Id, PublicSubnet2Id
- PrivateSubnet1Id, PrivateSubnet2Id
- DataSubnet1Id, DataSubnet2Id

### 02-iam.yaml - Identity and Access Management

**Creates:**
- ECS Task Execution Role (pulls images, accesses secrets)
- ECS Task Role (application permissions)
- Jenkins/CI Instance Role (deploy to ECS/EKS)
- EKS Cluster Role
- EKS Node Group Role
- EKS Pod Execution Role (IRSA)
- Cluster Autoscaler Role

**Permissions:**
- ECR pull/push
- Secrets Manager access
- S3 bucket access
- CloudWatch Logs
- ECS/EKS deployment

**Exports:**
- All role ARNs for cross-stack references

### 03-s3.yaml - Storage Buckets

**Creates:**
- **Artifacts Bucket**
  - Build artifacts and deployment packages
  - Versioning enabled
  - 90-day retention
  - Encrypted at rest

- **Logs Bucket**
  - Application and access logs
  - Lifecycle: STANDARD → IA (30d) → Glacier (90d)
  - 365-day retention
  - Encrypted at rest

- **Backups Bucket**
  - Database and configuration backups
  - Versioning enabled
  - Lifecycle: STANDARD → Glacier (30d)
  - 90-day retention
  - Encrypted at rest

**Features:**
- Public access blocked
- Encryption at rest (AES-256)
- Lifecycle policies for cost optimization
- Cross-stack exports for bucket names and ARNs

### 04-rds.yaml - PostgreSQL Database

**Creates:**
- RDS PostgreSQL 17.4 instance
- DB Subnet Group (spans data subnets)
- Security Group (allows PostgreSQL from VPC)
- CloudWatch Alarms (CPU, connections, storage)
- **Secrets Manager Secret** for database credentials

**Features:**
- **AWS Secrets Manager integration** - Auto-generated 32-character password, no manual password input required
- Automated backups (configurable retention)
- Multi-AZ option for high availability
- Performance Insights (production)
- CloudWatch log exports
- Deletion protection (production)
- Encrypted storage
- Automatic snapshots on deletion

**Secrets Manager Integration:**

The RDS stack uses AWS Secrets Manager for secure credential management:

1. **Auto-generated password** - A 32-character password is generated automatically (excludes `"@/\` characters)
2. **Secret structure** - Stores `username`, `password`, plus connection info (`host`, `port`, `dbname`, `engine`) after attachment
3. **No manual password input** - The `DBPassword` parameter has been removed; credentials are fully managed by Secrets Manager

**Retrieving Database Credentials:**

```bash
# Get the secret ARN
SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name cloudforge-dev-rds \
  --query 'Stacks[0].Outputs[?OutputKey==`DBSecretArn`].OutputValue' \
  --output text)

# Retrieve the secret value
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query 'SecretString' \
  --output text | jq .
```

**Using in ECS Task Definitions:**

```json
{
  "containerDefinitions": [{
    "secrets": [
      {
        "name": "DB_PASSWORD",
        "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:cloudforge-dev-db-credentials:password::"
      },
      {
        "name": "DB_USERNAME",
        "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:cloudforge-dev-db-credentials:username::"
      }
    ]
  }]
}
```

**Using in Application Code (Node.js example):**

```javascript
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

async function getDbCredentials() {
  const client = new SecretsManagerClient({ region: 'us-east-1' });
  const response = await client.send(new GetSecretValueCommand({
    SecretId: process.env.DB_SECRET_ARN
  }));
  return JSON.parse(response.SecretString);
}
```

**Parameters:**
- `DBInstanceClass` - Default: db.t3.micro
- `DBAllocatedStorage` - Default: 20GB
- `DBUsername` - Default: dbadmin
- `MultiAZ` - true/false

**Exports:**
- `DBSecretArn` - ARN of the Secrets Manager secret (use for ECS/EKS integration)
- `DBSecretName` - Name of the secret (`cloudforge-{env}-db-credentials`)
- `DBEndpoint`, `DBPort`, `DBName`, `DBSecurityGroupId`

**CloudWatch Alarms:**
- High CPU utilization (> 80%)
- High connection count (> 80% of max)
- Low free storage (< 2GB)

### 05-ecr.yaml - Container Registry

**Creates:**
- **Backend ECR Repository**
  - Image scanning on push
  - AES256 encryption
  - Lifecycle policy (keep last 10 images)
  - Untagged image cleanup

- **Frontend ECR Repository**
  - Same features as backend
  - Separate lifecycle management

- **CloudWatch Alarms** (production only)
  - High severity vulnerability alerts

**Parameters:**
- `ImageRetentionCount` - Number of images to retain (default: 10)
- `UntaggedImageRetentionDays` - Days before untagged images expire (default: 1)

**Exports:**
- BackendRepositoryUri, BackendRepositoryArn, BackendRepositoryName
- FrontendRepositoryUri, FrontendRepositoryArn, FrontendRepositoryName

**Push Docker Images to ECR:**

```bash
cd infrastructure/cloudformation/scripts
./push-to-ecr.sh
```

**Manual Push Process:**

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Tag and push
docker tag docker-frontend:latest ${ECR_REGISTRY}/cloudforge/frontend:latest
docker push ${ECR_REGISTRY}/cloudforge/frontend:latest

docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:latest
docker push ${ECR_REGISTRY}/cloudforge/backend:latest
```

### 06-ecs.yaml - Container Orchestration

**Creates:**
- **Application Load Balancer**
  - Internet-facing, HTTP/HTTPS enabled
  - Cross-zone load balancing
  - Deletion protection (production)

- **Target Groups**
  - Frontend (port 80, /health)
  - Backend (port 3000, /api/health)

- **ECS Cluster**
  - Fargate and Fargate Spot capacity providers
  - Container Insights (optional)

- **ECS Services**
  - Frontend service with Nginx
  - Backend service with Node.js
  - Deployment circuit breaker with rollback

- **Task Definitions**
  - Fargate-compatible (awsvpc networking)
  - CloudWatch logging
  - Secrets Manager integration for DB password

- **Auto Scaling** (production only)
  - CPU-based target tracking (70% threshold)
  - 2-10 task scaling range

- **Security Groups**
  - ALB SG: HTTP/HTTPS from internet
  - ECS Tasks SG: Traffic only from ALB

- **CloudWatch Alarms** (production only)
  - High CPU utilization
  - ALB 5XX errors

**Parameters:**
- `EnableContainerInsights` - Enable CloudWatch Container Insights (default: true)
- `EnableFargateSpot` - Use Fargate Spot for cost savings (default: false)
- `FrontendDesiredCount` - Number of frontend tasks (default: 2)
- `BackendDesiredCount` - Number of backend tasks (default: 2)
- `FrontendCPU/Memory` - Task resource allocation
- `BackendCPU/Memory` - Task resource allocation
- `LogRetentionDays` - CloudWatch log retention (default: 7)

**Exports:**
- ClusterName, ClusterArn
- ALBDNSName, ALBArn, ALBHostedZoneId
- FrontendTargetGroupArn, BackendTargetGroupArn
- ALBSecurityGroupId, ECSTasksSecurityGroupId
- FrontendServiceName, BackendServiceName
- ECSLogGroupName, ApplicationURL

**View Application:**

After deployment, access the application at:
```bash
# Get the ALB DNS name
aws cloudformation describe-stacks \
  --stack-name cloudforge-dev-ecs \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text
```

**Monitor Services:**

```bash
# View service status
aws ecs describe-services \
  --cluster cloudforge-dev-cluster \
  --services cloudforge-dev-frontend cloudforge-dev-backend

# View running tasks
aws ecs list-tasks --cluster cloudforge-dev-cluster

# View logs
aws logs tail /ecs/cloudforge-dev --follow
```

## Stack Dependencies

Stacks must be deployed in this order due to dependencies:

```
1. VPC (no dependencies)
   ↓
2. IAM (no dependencies)
   ↓
3. S3 (no dependencies)
   ↓
4. RDS (depends on VPC)
   ↓
5. ECR (no dependencies)
   ↓
6. ECS (depends on VPC, IAM, RDS, ECR)
   ↓
7. EKS (depends on VPC, IAM) - Future
```

Cross-stack references use CloudFormation Exports and Fn::ImportValue.

## Parameter Files

Create parameter files for each environment:

```json
// parameters/dev-parameters.json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "cloudforge"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  }
]
```

> **Note:** Database credentials are now managed by AWS Secrets Manager automatically. No password parameter is required for the RDS stack.

Deploy with parameter file:
```bash
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://stacks/04-rds.yaml \
  --parameters file://parameters/dev-parameters.json
```

## Best Practices Implemented

### Security
- ✅ **Secrets Manager integration** for RDS credentials (auto-generated, auto-rotated)
- ✅ IAM roles follow least privilege principle
- ✅ S3 buckets block public access
- ✅ Encryption at rest enabled for RDS and S3
- ✅ Security groups restrict access to VPC CIDR
- ✅ Deletion protection on production databases

### Cost Optimization
- ✅ S3 lifecycle policies (IA, Glacier transitions)
- ✅ Optional NAT Gateway (single gateway in dev)
- ✅ Right-sized instance types (t3.micro for dev)
- ✅ S3 VPC Endpoint (no data transfer costs)
- ✅ Automated resource cleanup scripts

### Reliability
- ✅ Multi-AZ option for RDS
- ✅ Automated database backups
- ✅ CloudWatch alarms for key metrics
- ✅ Snapshot on deletion for RDS
- ✅ VPC Flow Logs for troubleshooting

### Operational Excellence
- ✅ Comprehensive tagging strategy
- ✅ Stack exports for modularity
- ✅ Conditional resources (prod vs dev)
- ✅ Automated deployment scripts
- ✅ Change sets for safe updates

## CloudFormation Commands Reference

### Stack Operations

```bash
# Create stack
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters ParameterKey=Key1,ParameterValue=Value1 \
  --capabilities CAPABILITY_NAMED_IAM

# Update stack
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://template.yaml

# Delete stack
aws cloudformation delete-stack --stack-name my-stack

# Describe stack
aws cloudformation describe-stacks --stack-name my-stack

# List stacks
aws cloudformation list-stacks

# Get stack events
aws cloudformation describe-stack-events --stack-name my-stack

# Get stack resources
aws cloudformation describe-stack-resources --stack-name my-stack
```

### Change Sets

```bash
# Create change set
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-changes \
  --template-body file://template.yaml

# Describe change set
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# Execute change set
aws cloudformation execute-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# Delete change set
aws cloudformation delete-change-set \
  --stack-name my-stack \
  --change-set-name my-changes
```

### Validation and Linting

```bash
# Validate template
aws cloudformation validate-template \
  --template-body file://stacks/01-vpc.yaml

# Use cfn-lint for advanced validation
pip install cfn-lint
cfn-lint stacks/*.yaml
```

## Troubleshooting

### Stack Creation Failed

```bash
# View events to see what failed
aws cloudformation describe-stack-events \
  --stack-name cloudforge-dev-vpc \
  --max-items 50

# Common issues:
# 1. Parameter validation errors
# 2. Resource limit exceeded
# 3. IAM permission denied
# 4. Resource name conflicts
```

### Stack is in UPDATE_ROLLBACK_COMPLETE

```bash
# View why rollback occurred
aws cloudformation describe-stack-events --stack-name my-stack

# Continue with rollback
aws cloudformation continue-update-rollback --stack-name my-stack
```

### Cannot Delete Stack

```bash
# Force delete (use with caution)
aws cloudformation delete-stack \
  --stack-name my-stack \
  --role-arn arn:aws:iam::ACCOUNT:role/CloudFormationRole

# Check for dependencies
# - Exported values used by other stacks
# - Resources created outside CloudFormation
# - Deletion protection enabled
```

### Debugging Template Errors

```bash
# Validate syntax
aws cloudformation validate-template --template-body file://template.yaml

# Use cfn-lint for best practices
cfn-lint template.yaml

# Test in CloudFormation Designer (visual)
# Console → CloudFormation → Design template
```

## Cost Estimation

Approximate monthly costs for `dev` environment (us-east-1):

| Resource | Cost |
|----------|------|
| VPC (NAT Gateway) | $32/month |
| RDS db.t3.micro | $15/month |
| S3 Storage (10GB) | $0.23/month |
| VPC Flow Logs | $1-5/month |
| ALB | $16/month + $0.008/LCU-hour |
| ECS Fargate (2x 0.25vCPU/0.5GB) | ~$15/month |
| ECR Storage | $0.10/GB/month |
| **Total** | **~$80-100/month** |

For `prod` with Multi-AZ, auto-scaling, and larger instances: ~$200-400/month

## Next Steps

1. **Create EKS stack** for Kubernetes orchestration
2. **Add WAF stack** for web application firewall
3. **Create Route 53 stack** for DNS management
4. **Add CloudFront stack** for CDN
5. **Add HTTPS/TLS** with ACM certificates
6. **Add CI/CD pipeline** with CodePipeline/CodeBuild

## Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) - Template linting
- [CloudFormation Registry](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/registry.html)
- [Comparison: Terraform vs CloudFormation](./TERRAFORM_VS_CLOUDFORMATION.md)

## Support

For issues with CloudFormation templates:
1. Validate template syntax first
2. Check CloudFormation events for errors
3. Review IAM permissions
4. Verify parameter values
5. Check for resource limits in your account
