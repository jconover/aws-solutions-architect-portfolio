# Architecture Documentation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.20.0.0/16)                      │ │
│  │                                                             │ │
│  │  ┌─────────────────────┐  ┌─────────────────────┐         │ │
│  │  │   Public Subnet      │  │   Public Subnet      │         │ │
│  │  │   (10.20.1.0/24)    │  │   (10.20.2.0/24)    │         │ │
│  │  │   AZ-1              │  │   AZ-2              │         │ │
│  │  │                     │  │                     │         │ │
│  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │         │ │
│  │  │  │     ALB       │◄─┼──┼──┤     ALB       │  │         │ │
│  │  │  └───────┬───────┘  │  │  └───────┬───────┘  │         │ │
│  │  │          │          │  │          │          │         │ │
│  │  │  ┌───────▼───────┐  │  │  ┌───────▼───────┐  │         │ │
│  │  │  │  NAT Gateway  │  │  │  │  NAT Gateway  │  │         │ │
│  │  │  └───────────────┘  │  │  └───────────────┘  │         │ │
│  │  └─────────┬───────────┘  └─────────┬───────────┘         │ │
│  │            │                         │                     │ │
│  │  ┌─────────▼───────────┐  ┌─────────▼───────────┐         │ │
│  │  │   Private Subnet     │  │   Private Subnet     │         │ │
│  │  │   (10.20.10.0/24)   │  │   (10.20.11.0/24)   │         │ │
│  │  │   AZ-1              │  │   AZ-2              │         │ │
│  │  │                     │  │                     │         │ │
│  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │         │ │
│  │  │  │  ECS Tasks    │  │  │  │  ECS Tasks    │  │         │ │
│  │  │  │  or           │  │  │  │  or           │  │         │ │
│  │  │  │  EKS Pods     │  │  │  │  EKS Pods     │  │         │ │
│  │  │  └───────────────┘  │  │  └───────────────┘  │         │ │
│  │  │                     │  │                     │         │ │
│  │  └─────────────────────┘  └─────────────────────┘         │ │
│  │                                                             │ │
│  │  ┌─────────────────────┐  ┌─────────────────────┐         │ │
│  │  │   Data Subnet        │  │   Data Subnet        │         │ │
│  │  │   (10.20.20.0/24)   │  │   (10.20.21.0/24)   │         │ │
│  │  │                     │  │                     │         │ │
│  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │         │ │
│  │  │  │  RDS Primary  │◄─┼──┼──┤  RDS Standby  │  │         │ │
│  │  │  └───────────────┘  │  │  └───────────────┘  │         │ │
│  │  └─────────────────────┘  └─────────────────────┘         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │      S3      │  │     IAM      │  │  CloudWatch  │           │
│  │   (Artifacts)│  │   (Roles)    │  │  (Monitoring)│           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└─────────────────────────────────────────────────────────────────┘

                              ▲
                              │
                    ┌─────────┴─────────┐
                    │  Jenkins Server   │
                    │  (CI/CD Pipeline) │
                    │  (Security Scans) │
                    └───────────────────┘
```

## Component Details

### Networking Layer

**VPC Configuration**
- CIDR: 10.20.0.0/16
- Multi-AZ deployment for high availability
- Three subnet tiers: Public, Private, Data

**Subnets**
- Public Subnets (10.20.1.0/24, 10.20.2.0/24): ALB, NAT Gateway, Bastion
- Private Subnets (10.20.10.0/24, 10.20.11.0/24): Application containers
- Data Subnets (10.20.20.0/24, 10.20.21.0/24): RDS instances

**Security Groups**
- ALB SG: Allow 80/443 from Internet
- App SG: Allow traffic from ALB only
- RDS SG: Allow 5432/3306 from App SG only
- Jenkins SG: Allow 8080, 50000, and SSH

### Compute Layer

#### Option 1: ECS Fargate

**Cluster Configuration**
- Fargate launch type (serverless)
- Service auto-scaling based on CPU/Memory
- Task definitions for frontend and backend

**Benefits**
- No server management
- Pay for what you use
- Automatic scaling
- Faster to set up

**Task Definition**
```yaml
Frontend Task:
  - CPU: 256
  - Memory: 512MB
  - Port: 80

Backend Task:
  - CPU: 512
  - Memory: 1024MB
  - Port: 3000
```

#### Option 2: EKS (Kubernetes)

**Cluster Configuration**
- Managed control plane
- Managed node groups (t3.medium)
- Auto-scaling with Cluster Autoscaler
- Kubernetes version 1.33

**Benefits**
- Industry standard
- Advanced orchestration features
- Multi-cloud portability
- Rich ecosystem

**Node Groups**
- Min: 2 nodes
- Max: 10 nodes
- Instance type: t3.medium
- Spot instances for cost optimization

### Application Layer

**Frontend Service**
- React/Vue.js SPA
- NGINX for serving static files
- Environment-based configuration
- CDN integration ready (CloudFront)

**Backend Service**
- RESTful API
- JWT authentication
- Connection pooling to database
- Health check endpoints (/health, /ready)

**Database**
- RDS PostgreSQL 17.4
- Multi-AZ deployment
- Automated backups (7-day retention)
- Read replicas for scaling

### Storage Layer

**S3 Buckets**
- Artifacts: Jenkins build artifacts and Docker images
- Static Assets: Frontend static files
- Logs: Application and access logs
- Backup: Database backups

**S3 Configuration**
- Versioning enabled
- Encryption at rest (AES-256)
- Lifecycle policies for cost optimization
- Bucket policies for least privilege access

### Security Layer

**IAM Roles and Policies**
- ECS Task Execution Role
- ECS Task Role (application permissions)
- EKS Node Role
- EKS Pod Service Accounts (IRSA)
- Jenkins EC2 Role

**Network Security**
- Security Groups for defense in depth
- Network ACLs for subnet-level control
- VPC Flow Logs for monitoring
- AWS WAF (optional) for application protection

**Data Security**
- Encryption in transit (TLS/SSL)
- Encryption at rest (RDS, S3)
- Secrets Manager for credentials
- Parameter Store for configuration

### Monitoring and Logging

**CloudWatch**
- Metrics: CPU, Memory, Request count, Latency
- Logs: Application logs, Access logs
- Alarms: Auto-scaling triggers, Error rate
- Dashboards: Real-time monitoring

**X-Ray (Optional)**
- Distributed tracing
- Performance bottleneck identification
- Service map visualization

## CI/CD Pipeline Flow

```
┌──────────────┐
│ Code Commit  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Jenkins      │
│ Webhook      │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Security Scanning Stage              │
├──────────────────────────────────────┤
│ 1. SAST (SonarQube)                 │
│ 2. Dependency Check (Snyk)          │
│ 3. IaC Scan (Checkov/tfsec)         │
│ 4. Container Scan (Trivy)           │
└──────┬───────────────────────────────┘
       │
       ▼ (All scans pass)
┌──────────────┐
│ Build        │
│ Docker Images│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Push to ECR  │
└──────┬───────┘
       │
       ├─────────────────────┐
       │                     │
       ▼                     ▼
┌──────────────┐    ┌──────────────┐
│ Deploy to    │    │ Deploy to    │
│ ECS          │    │ EKS          │
└──────┬───────┘    └──────┬───────┘
       │                     │
       └──────────┬──────────┘
                  │
                  ▼
         ┌──────────────┐
         │ DAST Scan    │
         │ (OWASP ZAP)  │
         └──────────────┘
```

## Deployment Strategies

### Blue-Green Deployment
- Maintain two identical environments
- Switch traffic using ALB target groups
- Quick rollback capability

### Rolling Update
- Gradually replace old containers with new
- ECS: Update service with deployment configuration
- EKS: RollingUpdate strategy in deployments

### Canary Deployment
- Route small percentage to new version
- Monitor metrics and errors
- Gradually increase traffic if successful

## High Availability and Disaster Recovery

**HA Configuration**
- Multi-AZ deployment for all components
- Load balancing across availability zones
- Auto-scaling for compute resources
- RDS Multi-AZ with automatic failover

**DR Strategy**
- RTO: < 1 hour
- RPO: < 5 minutes
- Automated backups to S3
- Cross-region replication (optional)
- Infrastructure as Code for quick rebuild

## Cost Optimization Strategies

1. **Compute**
   - Fargate Spot for non-prod environments
   - EKS Spot instances for batch workloads
   - Right-sizing based on CloudWatch metrics

2. **Storage**
   - S3 lifecycle policies
   - EBS snapshot lifecycle
   - Archive old logs to Glacier

3. **Network**
   - Single NAT Gateway for dev
   - VPC endpoints for S3/ECR to avoid NAT costs

4. **Database**
   - Reserved instances for production
   - Aurora Serverless for variable workloads
   - Read replicas only when needed

## Scaling Strategy

**Horizontal Scaling**
- ECS: Service auto-scaling based on CloudWatch metrics
- EKS: Horizontal Pod Autoscaler (HPA)
- RDS: Read replicas for read-heavy workloads

**Vertical Scaling**
- ECS: Update task definition with more resources
- EKS: Update deployment resource requests/limits
- RDS: Modify instance class (with downtime)

**Auto-Scaling Triggers**
- CPU utilization > 70%
- Memory utilization > 80%
- Request count per target > 1000
- Custom application metrics

## Comparison: ECS vs EKS

| Aspect | ECS Fargate | EKS |
|--------|-------------|-----|
| Setup Complexity | Low | Medium-High |
| Management Overhead | Minimal | Moderate |
| Cost (3 containers) | ~$50-80/month | ~$130-150/month |
| Portability | AWS-only | Multi-cloud |
| Ecosystem | AWS services | Kubernetes ecosystem |
| Learning Curve | Gentle | Steep |
| Best For | AWS-native apps | Complex orchestration |

## Security Best Practices Implemented

1. Least privilege IAM policies
2. Private subnets for compute and data
3. Security groups as virtual firewalls
4. Encryption in transit and at rest
5. Secrets in AWS Secrets Manager
6. VPC Flow Logs for network monitoring
7. CloudTrail for API auditing
8. Regular security scanning in pipeline
9. Container image scanning before deployment
10. Network segmentation with multiple subnet tiers
