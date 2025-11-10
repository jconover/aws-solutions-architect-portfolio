# AWS ECR (Elastic Container Registry) Setup Guide

## Overview

AWS ECR is a fully managed Docker container registry that makes it easy to store, manage, share, and deploy container images. This guide covers the complete setup and usage for the CloudForge project.

## Table of Contents

- [Initial Setup](#initial-setup)
- [Pushing Images](#pushing-images)
- [Security Scanning](#security-scanning)
- [Lifecycle Policies](#lifecycle-policies)
- [IAM Permissions](#iam-permissions)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Initial Setup

### 1. Create ECR Repositories

```bash
# Set region
export AWS_REGION="us-east-1"

# Create backend repository
aws ecr create-repository \
  --repository-name cloudforge/backend \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region ${AWS_REGION}

# Create frontend repository
aws ecr create-repository \
  --repository-name cloudforge/frontend \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region ${AWS_REGION}
```

### 2. Verify Repository Creation

```bash
# List repositories
aws ecr describe-repositories \
  --repository-names cloudforge/backend cloudforge/frontend \
  --region ${AWS_REGION} \
  --query 'repositories[*].[repositoryName,repositoryUri,imageScanningConfiguration.scanOnPush]' \
  --output table
```

Expected output:
```
-------------------------------------------------------------------------------------
|                             DescribeRepositories                                  |
+---------------------+------------------------------------------------------------+
| cloudforge/backend  | 457780993905.dkr.ecr.us-east-1.amazonaws.com/cloudforge... | True |
| cloudforge/frontend | 457780993905.dkr.ecr.us-east-1.amazonaws.com/cloudforge... | True |
+---------------------+------------------------------------------------------------+
```

## Pushing Images

### Automated Push (Recommended)

Use the provided script for streamlined image pushing:

```bash
cd infrastructure/cloudformation/scripts
./push-to-ecr.sh
```

The script handles:
- ✅ ECR authentication
- ✅ Image detection
- ✅ Tagging with both `latest` and timestamp
- ✅ Pushing to appropriate repositories
- ✅ Automatic security scan triggering

### Manual Push Process

```bash
# 1. Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 2. Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# 3. Tag your images
docker tag docker-frontend:latest ${ECR_REGISTRY}/cloudforge/frontend:latest
docker tag docker-frontend:latest ${ECR_REGISTRY}/cloudforge/frontend:v1.0.0

docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:latest
docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:v1.0.0

# 4. Push images
docker push ${ECR_REGISTRY}/cloudforge/frontend:latest
docker push ${ECR_REGISTRY}/cloudforge/frontend:v1.0.0

docker push ${ECR_REGISTRY}/cloudforge/backend:latest
docker push ${ECR_REGISTRY}/cloudforge/backend:v1.0.0
```

### Tagging Strategy

**Recommended tagging approach:**

1. **`latest`** - Always points to the most recent build
2. **Semantic versioning** - `v1.0.0`, `v1.1.0`, etc.
3. **Timestamp** - `20251110-114720` for point-in-time reference
4. **Git commit** - `sha-abc123f` for traceability
5. **Environment** - `dev`, `staging`, `prod` for deployment tracking

Example multi-tag push:
```bash
IMAGE_TAG="v1.2.0"
GIT_SHA=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:latest
docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:${IMAGE_TAG}
docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:${GIT_SHA}
docker tag docker-backend:latest ${ECR_REGISTRY}/cloudforge/backend:${TIMESTAMP}

docker push ${ECR_REGISTRY}/cloudforge/backend --all-tags
```

## Security Scanning

### Automatic Scanning

When `scanOnPush=true`, ECR automatically scans images on push using AWS's managed CVE database.

### View Scan Results

```bash
# Summary of vulnerabilities
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --region ${AWS_REGION} \
  --query 'imageScanFindings.findingSeverityCounts'

# Output:
# {
#   "HIGH": 1,
#   "MEDIUM": 2
# }
```

### Detailed Vulnerability Report

```bash
# Get detailed findings for HIGH and CRITICAL
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --region ${AWS_REGION} \
  --query 'imageScanFindings.findings[?severity==`HIGH` || severity==`CRITICAL`].[name,severity,description]' \
  --output table
```

### Current Known Vulnerabilities (CloudForge)

As of the latest scan (November 2025), the backend image has the following findings:

#### CVE-2025-9230 (HIGH)
- **Component**: OpenSSL in Alpine Linux base image
- **Issue**: CMS password-based encryption out-of-bounds read/write
- **Impact**: Potential DoS or code execution
- **Risk Assessment**: LOW - CMS PWRI encryption is rarely used
- **Remediation**: Update to Alpine 3.20+ when available

#### CVE-2025-9231 (MEDIUM)
- **Component**: OpenSSL
- **Issue**: SM2 signature timing side-channel on ARM64
- **Impact**: Potential private key recovery
- **Risk Assessment**: LOW - Requires custom TLS provider and ARM64 platform
- **Remediation**: Update OpenSSL or avoid ARM64 if using SM2

#### CVE-2025-9232 (MEDIUM)
- **Component**: OpenSSL HTTP client
- **Issue**: no_proxy environment variable vulnerability
- **Impact**: Out-of-bounds read leading to DoS
- **Risk Assessment**: LOW - Requires specific environment configuration
- **Remediation**: Update to OpenSSL 3.0.17+, 3.1.9+, 3.2.5+, 3.3.4+, 3.4.1+, or 3.5.1+

### Remediation Steps

```bash
# 1. Check for updated base images
docker pull node:18-alpine
docker pull node:20-alpine
docker pull alpine:3.20

# 2. Update Dockerfile
# Edit docker/backend/Dockerfile
FROM node:20-alpine3.20  # or latest stable

# 3. Rebuild and test locally
cd /path/to/project
docker build -t docker-backend:latest -f docker/backend/Dockerfile .

# 4. Test locally
docker run -p 3000:3000 docker-backend:latest

# 5. Push to ECR and verify new scan
./infrastructure/cloudformation/scripts/push-to-ecr.sh

# 6. Wait for scan to complete and check results
aws ecr wait image-scan-complete \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest

aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findingSeverityCounts'
```

### Scan Triggers

```bash
# Manually trigger a scan
aws ecr start-image-scan \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest

# Check scan status
aws ecr describe-images \
  --repository-name cloudforge/backend \
  --image-ids imageTag=latest \
  --query 'imageDetails[0].imageScanStatus'
```

### Integration with CI/CD

Add to Jenkins pipeline after pushing images:

```groovy
stage('ECR Security Gate') {
    steps {
        script {
            // Wait for scan to complete
            sh """
                aws ecr wait image-scan-complete \
                  --repository-name cloudforge/backend \
                  --image-id imageTag=${IMAGE_TAG}
            """

            // Get vulnerability counts
            def scanResults = sh(
                script: """
                    aws ecr describe-image-scan-findings \
                      --repository-name cloudforge/backend \
                      --image-id imageTag=${IMAGE_TAG} \
                      --query 'imageScanFindings.findingSeverityCounts' \
                      --output json
                """,
                returnStdout: true
            ).trim()

            def findings = readJSON text: scanResults

            // Define thresholds
            def criticalCount = findings.CRITICAL ?: 0
            def highCount = findings.HIGH ?: 0

            echo "Security Scan Results: CRITICAL=${criticalCount}, HIGH=${highCount}"

            // Fail build if thresholds exceeded
            if (criticalCount > 0) {
                error("Build failed: ${criticalCount} CRITICAL vulnerabilities found")
            }
            if (highCount > 5) {
                unstable("Build unstable: ${highCount} HIGH vulnerabilities found")
            }
        }
    }
}
```

## Lifecycle Policies

Implement lifecycle policies to automatically remove old images and reduce storage costs.

### Example Policy: Keep Last 10 Images

```bash
cat > /tmp/lifecycle-policy.json <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

# Apply to backend repository
aws ecr put-lifecycle-policy \
  --repository-name cloudforge/backend \
  --lifecycle-policy-text file:///tmp/lifecycle-policy.json

# Apply to frontend repository
aws ecr put-lifecycle-policy \
  --repository-name cloudforge/frontend \
  --lifecycle-policy-text file:///tmp/lifecycle-policy.json
```

### Advanced Policy: Keep Tagged, Expire Untagged

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 20 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

## IAM Permissions

### For CI/CD (Jenkins/CodeBuild)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings",
        "ecr:StartImageScan"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:457780993905:repository/cloudforge/backend",
        "arn:aws:ecr:us-east-1:457780993905:repository/cloudforge/frontend"
      ]
    }
  ]
}
```

### For ECS/EKS Task Execution

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:457780993905:repository/cloudforge/*"
      ]
    }
  ]
}
```

## Best Practices

### 1. Image Tagging
- ✅ Always tag with semantic versions (`v1.0.0`)
- ✅ Use `latest` for the most recent stable build
- ✅ Include git commit SHA for traceability
- ✅ Tag with environment for deployment tracking
- ❌ Don't rely solely on `latest` in production

### 2. Security
- ✅ Enable scan-on-push for all repositories
- ✅ Review scan findings before deployment
- ✅ Set up alerts for CRITICAL/HIGH vulnerabilities
- ✅ Regularly update base images
- ✅ Use minimal base images (Alpine, Distroless)
- ❌ Don't ignore security findings

### 3. Cost Optimization
- ✅ Implement lifecycle policies
- ✅ Remove untagged images regularly
- ✅ Keep only necessary image versions
- ✅ Use image compression where possible
- ✅ Monitor storage costs in Cost Explorer

### 4. Operations
- ✅ Use consistent naming conventions
- ✅ Automate image builds and pushes
- ✅ Integrate with CI/CD pipelines
- ✅ Tag images with build metadata
- ✅ Maintain image inventory

## Troubleshooting

### Authentication Failed

```bash
# Error: no basic auth credentials
# Solution: Re-authenticate
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Note: ECR tokens expire after 12 hours
```

### Repository Does Not Exist

```bash
# Error: name unknown: The repository with name 'cloudforge/backend' does not exist
# Solution: Create the repository first
aws ecr create-repository --repository-name cloudforge/backend
```

### Scan Failed

```bash
# Check scan status
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --query 'imageScanStatus'

# If status is FAILED, try manual scan
aws ecr start-image-scan \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest
```

### Image Pull Errors in ECS/EKS

```bash
# Verify IAM role has ECR permissions
# Check CloudWatch logs for the task/pod
# Ensure image tag exists in ECR

# List available tags
aws ecr list-images \
  --repository-name cloudforge/backend \
  --query 'imageIds[*].imageTag'
```

## Cost Monitoring

```bash
# Check storage usage
aws ecr describe-repositories \
  --query 'repositories[*].[repositoryName,repositorySizeInBytes]' \
  --output table

# Pricing (us-east-1):
# Storage: $0.10 per GB/month
# Data transfer: Same as standard AWS data transfer rates
```

## Resources

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/best-practices.html)
- [ECR Lifecycle Policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
- [ECR Security Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/)

## Next Steps

1. **Create ECR CloudFormation Stack**: Automate repository creation
2. **Implement Enhanced Scanning**: Enable ECR Enhanced Scanning for deeper analysis
3. **Set up Security Hub**: Integrate findings with AWS Security Hub
4. **Create Alerts**: CloudWatch alarms for high-severity findings
5. **Automate Cleanup**: Lambda function for lifecycle management
