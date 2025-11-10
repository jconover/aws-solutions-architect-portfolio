# ECR CloudFormation Integration

## Overview

ECR repositories are now fully integrated into the CloudFormation deployment and deletion workflows.

## What Changed

### ✅ New CloudFormation Stack: `05-ecr.yaml`

Created a dedicated ECR stack that manages:
- **Backend Repository**: `cloudforge/backend`
- **Frontend Repository**: `cloudforge/frontend`

**Features**:
- ✅ Automatic security scanning on push (`scanOnPush: true`)
- ✅ AES256 encryption at rest
- ✅ Lifecycle policies to manage storage costs
- ✅ CloudWatch alarms for vulnerabilities (production only)
- ✅ Exports repository URIs for use in ECS/EKS stacks

**Lifecycle Policies**:
1. Delete untagged images after 1 day (configurable)
2. Keep last 10 images (configurable)

### ✅ Updated `deploy-all.sh`

Now deploys **5 stacks** instead of 4:

```bash
./deploy-all.sh dev "YourDBPassword"
```

**Deployment order**:
1. VPC (networking)
2. IAM (permissions)
3. S3 (storage)
4. RDS (database)
5. **ECR (container registry)** ← NEW

### ✅ Updated `delete-all.sh`

Now safely deletes ECR repositories:

```bash
./delete-all.sh dev
```

**Deletion process**:
1. Empties ECR repositories (deletes all images)
2. Empties S3 buckets
3. Deletes stacks in reverse order:
   - ECR
   - RDS
   - S3
   - IAM
   - VPC

## Important Notes

### ⚠️ Existing Manual ECR Repositories

If you already created ECR repositories manually (as we did earlier), you have two options:

**Option 1: Keep Manual Repositories (No Action Needed)**
- Continue using the manually created repositories
- Skip the ECR stack deployment
- Use `push-to-ecr.sh` as before

**Option 2: Migrate to CloudFormation (Recommended)**

```bash
# 1. Delete existing manual repositories (after backing up images if needed)
aws ecr delete-repository --repository-name cloudforge/backend --force --region us-east-1
aws ecr delete-repository --repository-name cloudforge/frontend --force --region us-east-1

# 2. Deploy the ECR stack
cd infrastructure/cloudformation/scripts
./deploy-all.sh dev "YourDBPassword"

# 3. Push images to new CloudFormation-managed repositories
./push-to-ecr.sh
```

### Stack Outputs

The ECR stack exports the following values for use in ECS/EKS stacks:

```yaml
Exports:
  - cloudforge-dev-BackendRepositoryUri
  - cloudforge-dev-BackendRepositoryArn
  - cloudforge-dev-BackendRepositoryName
  - cloudforge-dev-FrontendRepositoryUri
  - cloudforge-dev-FrontendRepositoryArn
  - cloudforge-dev-FrontendRepositoryName
```

**Example ECS/EKS Usage**:
```yaml
# In future ECS/EKS stack
TaskDefinition:
  Properties:
    ContainerDefinitions:
      - Name: backend
        Image: !Sub
          - '${RepoUri}:latest'
          - RepoUri: !ImportValue
              Fn::Sub: '${ProjectName}-${Environment}-BackendRepositoryUri'
```

## Parameters

The ECR stack accepts the following parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ProjectName` | cloudforge | Project name for resource naming |
| `Environment` | dev | Environment (dev/staging/prod) |
| `ImageRetentionCount` | 10 | Number of images to keep |
| `UntaggedImageRetentionDays` | 1 | Days to keep untagged images |

**Custom deployment**:
```bash
aws cloudformation create-stack \
  --stack-name cloudforge-dev-ecr \
  --template-body file://stacks/05-ecr.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=cloudforge \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=ImageRetentionCount,ParameterValue=20 \
    ParameterKey=UntaggedImageRetentionDays,ParameterValue=3
```

## Cost Impact

**ECR Costs** (us-east-1):
- Storage: $0.10 per GB/month
- Data transfer: Standard AWS rates
- Scanning: Free (basic scanning)

**Estimated monthly cost**:
- 10 images @ ~200MB each = 2GB storage = $0.20/month
- Minimal impact on overall infrastructure costs

**Lifecycle policies save costs** by automatically removing old images.

## Lifecycle Policy Details

### Default Policy

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
```

**How it works**:
1. Untagged images (from failed builds) are deleted after 1 day
2. Once you have more than 10 images total, the oldest ones are deleted
3. Tagged images like `v1.0.0` count toward the total

**To keep production releases longer**, use semantic versioning tags:
- `latest` - auto-updated
- `v1.0.0` - production release (kept)
- `dev-123` - development build (eventually expires)

## Security Features

### Scan on Push

All images are automatically scanned when pushed:

```bash
# Push triggers automatic scan
./push-to-ecr.sh

# View results
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest
```

### Encryption

All images are encrypted at rest using AES256 (managed by AWS).

### CloudWatch Alarms (Production Only)

In production environments, CloudWatch alarms trigger if vulnerabilities are found:

```yaml
BackendHighSeverityAlarm:
  Properties:
    AlarmName: cloudforge-prod-backend-high-vulnerabilities
    Threshold: 1  # Alert if any HIGH/CRITICAL vulnerabilities
```

**Note**: This requires publishing custom metrics from your CI/CD pipeline. See [ECR_SETUP.md](../../docs/ECR_SETUP.md) for integration examples.

## Troubleshooting

### Stack Already Exists Error

If you get "Stack already exists" after creating repositories manually:

```bash
# Option 1: Delete manual repos first (see Migration above)

# Option 2: Import existing repos into CloudFormation (advanced)
# See: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/resource-import.html
```

### Cannot Delete ECR Stack

Error: "Repository is not empty"

```bash
# Empty repositories first
cd infrastructure/cloudformation/scripts
./delete-all.sh dev  # This handles emptying automatically

# Or manually:
aws ecr batch-delete-image \
  --repository-name cloudforge/backend \
  --image-ids "$(aws ecr list-images --repository-name cloudforge/backend --query 'imageIds[*]' --output json)"
```

### Images Not Scanning

If scans aren't running automatically:

```bash
# Verify scan-on-push is enabled
aws ecr describe-repositories \
  --repository-names cloudforge/backend \
  --query 'repositories[0].imageScanningConfiguration'

# Manually trigger scan
aws ecr start-image-scan \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest
```

## Next Steps

1. **Deploy ECR Stack** (if migrating from manual repos)
2. **Push Images**: `./push-to-ecr.sh`
3. **Create ECS Stack**: Use ECR exports for task definitions
4. **Create EKS Stack**: Use ECR exports for deployments
5. **Set up CI/CD**: Integrate with Jenkins pipeline

## References

- [ECR Setup Guide](../../docs/ECR_SETUP.md) - Complete ECR documentation
- [CloudFormation Stack](stacks/05-ecr.yaml) - ECR template
- [Deploy Script](scripts/deploy-all.sh) - Automated deployment
- [Delete Script](scripts/delete-all.sh) - Automated cleanup
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
