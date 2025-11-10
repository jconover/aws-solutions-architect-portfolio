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
│   └── 04-rds.yaml           # PostgreSQL RDS database
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
./deploy-all.sh dev "YourSecurePassword123!"

# Deploy to production
./deploy-all.sh prod "ProductionPassword456!"
```

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

**Features:**
- Automated backups (configurable retention)
- Multi-AZ option for high availability
- Performance Insights (production)
- CloudWatch log exports
- Deletion protection (production)
- Encrypted storage
- Automatic snapshots on deletion

**Parameters:**
- `DBInstanceClass` - Default: db.t3.micro
- `DBAllocatedStorage` - Default: 20GB
- `DBUsername` - Default: dbadmin
- `DBPassword` - Required (NoEcho)
- `MultiAZ` - true/false

**CloudWatch Alarms:**
- High CPU utilization (> 80%)
- High connection count (> 80% of max)
- Low free storage (< 2GB)

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
5. ECS (depends on VPC, IAM, S3) - Future
   ↓
6. EKS (depends on VPC, IAM) - Future
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
  },
  {
    "ParameterKey": "DBPassword",
    "ParameterValue": "SecurePassword123!"
  }
]
```

Deploy with parameter file:
```bash
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://stacks/04-rds.yaml \
  --parameters file://parameters/dev-parameters.json
```

## Best Practices Implemented

### Security
- ✅ All passwords use `NoEcho: true`
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
| **Total** | **~$50/month** |

For `prod` with Multi-AZ and larger instances: ~$150-200/month

## Next Steps

1. **Create ECS/EKS stacks** for container orchestration
2. **Add WAF stack** for web application firewall
3. **Create Route 53 stack** for DNS management
4. **Add CloudFront stack** for CDN
5. **Implement nested stacks** for better organization
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
