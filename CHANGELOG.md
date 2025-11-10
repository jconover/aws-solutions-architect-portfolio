# Changelog

All notable changes to the CloudForge project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **CloudFormation ECR Stack** (`05-ecr.yaml`):
  - Managed ECR repositories for backend and frontend images
  - Automatic security scanning on push (scanOnPush enabled)
  - Lifecycle policies to manage storage costs (keep last 10 images, expire untagged after 1 day)
  - AES256 encryption at rest
  - CloudWatch alarms for high-severity vulnerabilities (production only)
  - Stack exports for ECR repository URIs (for use in ECS/EKS stacks)
- Automated `push-to-ecr.sh` script for building, tagging, and pushing Docker images
- Comprehensive ECR documentation:
  - `docs/ECR_SETUP.md` - Complete setup and usage guide
  - `docs/ECR_DEPLOYMENT_SUMMARY.md` - Deployment summary with security findings
  - `infrastructure/cloudformation/ECR_INTEGRATION.md` - CloudFormation integration guide
- ECR security scanning integration in `docs/security-scans.md`
- Security vulnerability tracking and remediation guidance

### Changed
- **Updated `deploy-all.sh`**: Now deploys 5 stacks (added ECR as step 5/5)
- **Updated `delete-all.sh`**: Automatically empties ECR repositories and deletes ECR stack
- Updated CloudFormation README with comprehensive ECR section
- Enhanced main README with ECR deployment workflow (step 2)
- Updated security scanning section to include ECR native scanning
- Renumbered Getting Started sections for better flow

### Fixed
- ECR repositories now properly cleaned up by `delete-all.sh` (deletes all images before stack deletion)
- Container images now managed by Infrastructure as Code (CloudFormation)

### Security
- **Identified vulnerabilities** in backend Docker image (node:18-alpine base):
  - CVE-2025-9230 (HIGH): OpenSSL CMS encryption vulnerability - Risk: LOW (feature not used)
  - CVE-2025-9231 (MEDIUM): OpenSSL SM2 timing side-channel - Risk: LOW (requires ARM64)
  - CVE-2025-9232 (MEDIUM): OpenSSL HTTP client no_proxy vulnerability - Risk: LOW (requires specific config)
- Documented remediation steps and risk assessment for each CVE
- Enabled automatic ECR security scanning on image push
- All vulnerabilities assessed as LOW actual risk to application

## [1.0.0] - 2025-11-10

### Added
- Initial CloudForge project structure
- Multi-tier application (React frontend, Node.js backend, PostgreSQL database)
- AWS CloudFormation templates for infrastructure deployment:
  - `01-vpc.yaml`: VPC with multi-AZ subnets, NAT Gateway, VPC Flow Logs
  - `02-iam.yaml`: IAM roles for ECS, EKS, Jenkins, and CI/CD
  - `03-s3.yaml`: S3 buckets for artifacts, logs, and backups
  - `04-rds.yaml`: PostgreSQL 17.4 RDS instance with CloudWatch alarms
- Terraform infrastructure modules (parallel implementation)
- Docker Compose configuration for local development
- Kubernetes manifests for local deployment (Rancher Desktop/k3s)
- Podman deployment configurations (pod YAML and native scripts)
- Jenkins CI/CD pipeline with security scanning:
  - SonarQube (SAST)
  - Snyk (dependency scanning)
  - Checkov and tfsec (IaC scanning)
  - Trivy (container scanning)
  - OWASP ZAP (DAST)
- Comprehensive documentation:
  - Main README with project overview
  - CloudFormation vs Terraform comparison
  - Security scanning guide
  - Getting started guide
- CloudFormation deployment scripts (`deploy-all.sh`, `delete-all.sh`)

### Changed
- Project renamed from "devops-portfolio" to "CloudForge" across all files
- VPC CIDR changed to 10.20.0.0/16 to avoid VLAN conflicts
- PostgreSQL version updated to 17.4 (latest)
- Kubernetes version target set to 1.33

### Fixed
- Docker build context issues (nginx.conf not found)
- npm SSL certificate validation errors in Rancher Desktop
- Port 80 conflict with Traefik (changed to port 8080)
- Kubernetes DNS resolution for backend service
- NGINX proxy_pass path stripping issue
- CloudFormation RDS Performance Insights configuration error
- CloudFormation IAM capability requirements (added CAPABILITY_IAM)

## Infrastructure Details

### AWS Resources Deployed

**VPC Stack (cloudforge-dev-vpc)**:
- VPC: 10.20.0.0/16
- 2 Public subnets (us-east-1a, us-east-1b)
- 2 Private subnets (us-east-1a, us-east-1b)
- 2 Data subnets for RDS (us-east-1a, us-east-1b)
- Internet Gateway
- NAT Gateway (single for dev, Multi-AZ for prod)
- VPC Flow Logs to S3

**IAM Stack (cloudforge-dev-iam)**:
- ECS Task Execution Role
- ECS Task Role
- Jenkins/CI Instance Role
- EKS Cluster Role
- EKS Node Group Role
- EKS Pod Execution Role (IRSA)
- Cluster Autoscaler Role

**S3 Stack (cloudforge-dev-s3)**:
- Artifacts bucket (versioned, 90-day lifecycle)
- Logs bucket (tiered storage: Standard → IA → Glacier)
- Backups bucket (versioned, Glacier after 30 days)
- All encrypted with AES-256
- Public access blocked on all buckets

**RDS Stack (cloudforge-dev-rds)**:
- PostgreSQL 17.4 (db.t3.micro for dev)
- 20GB gp3 storage (encrypted)
- Automated backups (1-day retention for dev, 7-day for prod)
- CloudWatch alarms: CPU, Connections, Storage
- Multi-AZ disabled for dev, enabled for prod
- Performance Insights disabled for dev, enabled for prod

**ECR Stack (cloudforge-dev-ecr)**:
- Backend repository: cloudforge/backend
- Frontend repository: cloudforge/frontend
- Automatic security scanning on push (scanOnPush enabled)
- AES256 encryption at rest
- Lifecycle policies:
  - Delete untagged images after 1 day
  - Keep last 10 images (configurable)
- Mutable tags allowed
- CloudWatch alarms for vulnerabilities (production only)
- Exports repository URIs for ECS/EKS integration

### Deployment Methods

The CloudForge application can be deployed using multiple methods:

1. **Docker Compose** (port 8080)
   - Best for: Local development and testing
   - Location: `docker/docker-compose.yml`

2. **Kubernetes/Rancher Desktop** (NodePort 30080)
   - Best for: Kubernetes learning and local orchestration
   - Location: `kubernetes/local/`

3. **Podman** (port 8081)
   - Best for: Rootless containers and OCI compatibility
   - Location: `podman/`

4. **AWS ECS** (planned)
   - Best for: Production AWS deployment with minimal Kubernetes overhead
   - Location: `infrastructure/cloudformation/` (future stack)

5. **AWS EKS** (planned)
   - Best for: Production Kubernetes on AWS
   - Location: `infrastructure/cloudformation/` (future stack)

## Security Posture

### Current Security Scanning

- **SAST**: SonarQube integration for code quality and security
- **SCA**: Snyk for dependency vulnerability detection
- **IaC**: Checkov and tfsec for infrastructure security
- **Container**: ECR native scanning + Trivy for local validation
- **DAST**: OWASP ZAP for runtime security testing

### Security Compliance

- ✅ All data encrypted at rest (S3, RDS, ECR)
- ✅ Secrets use NoEcho in CloudFormation
- ✅ IAM roles follow least privilege principle
- ✅ Security groups restrict access to VPC CIDR only
- ✅ S3 buckets block all public access
- ✅ VPC Flow Logs enabled for network monitoring
- ✅ CloudWatch alarms for anomaly detection
- ✅ Automated security scanning in CI/CD pipeline

### Known Issues & Mitigations

**HIGH Priority**:
- CVE-2025-9230: Update to patched Alpine/OpenSSL when available
  - Current Risk: LOW (CMS PWRI rarely used in this application)
  - Mitigation: Monitoring for Alpine security updates

**MEDIUM Priority**:
- CVE-2025-9231 & CVE-2025-9232: OpenSSL vulnerabilities
  - Current Risk: LOW (specific environment/platform requirements)
  - Mitigation: Scheduled base image updates, regular rescanning

## Cost Analysis

**Current AWS Monthly Costs (us-east-1, dev environment)**:
- VPC (NAT Gateway): $32/month
- RDS db.t3.micro: $15/month
- S3 Storage (~10GB): $0.23/month
- VPC Flow Logs: $1-5/month
- ECR Storage: $0.10/GB/month
- **Estimated Total**: ~$50-55/month for dev

**Production environment** (with Multi-AZ, larger instances): ~$150-200/month

## Development Setup

### Prerequisites Installed
- ✅ AWS CLI v2 (configured for us-east-1)
- ✅ Docker Desktop / Rancher Desktop
- ✅ kubectl
- ✅ Podman
- ✅ Node.js 18
- ✅ PostgreSQL client

### Local Endpoints
- Frontend (Docker Compose): http://localhost:8080
- Frontend (Kubernetes): http://localhost:30080
- Frontend (Podman): http://localhost:8081
- Backend API: http://localhost:3000/api/
- Health check: http://localhost:3000/api/health

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Solutions Architect Certification](https://aws.amazon.com/certification/certified-solutions-architect-associate/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

---

## Contributing

This is a portfolio project, but suggestions and improvements are welcome via issues.

## License

MIT License - See LICENSE file for details
