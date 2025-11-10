# Security Scanning Documentation

## Overview

This project implements a comprehensive DevSecOps approach with multiple security scanning tools integrated into the CI/CD pipeline. Security checks are automated and run on every build.

## Pipeline Security Gates

```
Code Commit → SAST → Dependency Check → IaC Scan → Build → Container Scan → Deploy → DAST
                ↓         ↓               ↓                      ↓              ↓
            SonarQube    Snyk         Checkov/tfsec           Trivy        OWASP ZAP
```

## 1. SAST (Static Application Security Testing)

### SonarQube

**Purpose**: Analyze source code for security vulnerabilities, code smells, and technical debt.

**What it Detects**:
- SQL Injection vulnerabilities
- Cross-Site Scripting (XSS)
- Path traversal issues
- Hardcoded credentials
- Insecure cryptography
- Authentication/Authorization flaws
- Code quality issues

**Configuration**:
```properties
# sonar-project.properties
sonar.projectKey=aws-cloudforge
sonar.sources=./application
sonar.exclusions=**/node_modules/**,**/*.test.js
sonar.javascript.lcov.reportPaths=coverage/lcov.info
```

**Jenkins Integration**:
```groovy
stage('SAST - SonarQube') {
    steps {
        script {
            def scannerHome = tool 'SonarQube Scanner'
            withSonarQubeEnv('SonarQube') {
                sh "${scannerHome}/bin/sonar-scanner"
            }
        }
    }
}

stage('Quality Gate') {
    steps {
        timeout(time: 5, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

**Quality Gates**:
- Security Rating: A
- Reliability Rating: A
- Maintainability Rating: A
- Code Coverage: > 80%
- Duplicated Lines: < 3%

### Snyk (Dependency Scanning)

**Purpose**: Scan dependencies for known vulnerabilities.

**What it Detects**:
- Vulnerable npm/pip/maven packages
- License compliance issues
- Outdated dependencies with known CVEs
- Transitive dependency vulnerabilities

**Jenkins Integration**:
```groovy
stage('Dependency Check - Snyk') {
    steps {
        script {
            snykSecurity(
                snykInstallation: 'Snyk',
                snykTokenId: 'snyk-api-token',
                severity: 'high',
                failOnIssues: true
            )
        }
    }
}
```

**Command Line Usage**:
```bash
# Scan Node.js dependencies
snyk test --severity-threshold=high

# Scan and fix vulnerabilities
snyk fix

# Monitor project
snyk monitor
```

## 2. Infrastructure as Code Scanning

### Checkov (Multi-IaC Scanner)

**Purpose**: Scan Terraform, CloudFormation, and Kubernetes manifests for security misconfigurations.

**What it Detects**:
- Unencrypted storage
- Public S3 buckets
- Open security groups
- Missing logging
- Insecure IAM policies
- Unencrypted RDS instances
- Missing backup configurations

**Jenkins Integration**:
```groovy
stage('IaC Scan - Checkov') {
    steps {
        sh '''
            pip3 install checkov
            checkov -d infrastructure/terraform \
                --framework terraform \
                --output junitxml \
                --soft-fail-on MEDIUM \
                --hard-fail-on HIGH,CRITICAL
        '''
    }
}
```

**Example Checks**:
```python
# Check if S3 bucket has encryption
CKV_AWS_19: "Ensure all data stored in the S3 bucket is securely encrypted at rest"

# Check if RDS has backup retention
CKV_AWS_133: "Ensure that RDS instances have backup policy"

# Check if security group is not open to 0.0.0.0/0
CKV_AWS_24: "Ensure no security groups allow ingress from 0.0.0.0:0 to port 22"
```

**Configuration**:
```yaml
# .checkov.yml
framework:
  - terraform
  - cloudformation
  - kubernetes

skip-check:
  - CKV_AWS_20  # Skip specific check with justification

hard-fail-on:
  - HIGH
  - CRITICAL

soft-fail-on:
  - MEDIUM
```

### tfsec (Terraform-specific Scanner)

**Purpose**: Specialized security scanner for Terraform with deep AWS knowledge.

**Jenkins Integration**:
```groovy
stage('IaC Scan - tfsec') {
    steps {
        sh '''
            curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
            tfsec infrastructure/terraform \
                --minimum-severity HIGH \
                --format junit > tfsec-report.xml
        '''
        junit 'tfsec-report.xml'
    }
}
```

**Example Findings**:
- AWS001: S3 Bucket has an ACL defined which allows public access
- AWS002: Resource 'aws_s3_bucket.example' does not have logging enabled
- AWS018: Resource 'aws_security_group.example' should include a description
- AWS079: Resource 'aws_instance.example' is missing `metadata_options`

## 3. Container Image Scanning

### AWS ECR Image Scanning (Native)

**Purpose**: AWS-native container vulnerability scanning integrated with ECR.

**What it Detects**:
- OS package vulnerabilities (using CVE database)
- Known security vulnerabilities in base images
- Updated daily from public CVE databases
- Integration with AWS Security Hub

**Setup**:
```bash
# Create ECR repository with scan-on-push enabled
aws ecr create-repository \
  --repository-name cloudforge/backend \
  --image-scanning-configuration scanOnPush=true \
  --region us-east-1

# Enable scanning for existing repository
aws ecr put-image-scanning-configuration \
  --repository-name cloudforge/backend \
  --image-scanning-configuration scanOnPush=true
```

**Usage**:
```bash
# Scans automatically on push when scanOnPush=true
docker push ${ECR_REGISTRY}/cloudforge/backend:latest

# Or manually trigger scan
aws ecr start-image-scan \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest

# View scan results summary
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findingSeverityCounts'

# View detailed findings
aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findings[?severity==`HIGH` || severity==`CRITICAL`].[name,severity,description]' \
  --output table

# List all images with scan status
aws ecr describe-images \
  --repository-name cloudforge/backend \
  --query 'imageDetails[*].[imageTags[0],imageScanStatus.status,imageScanFindingsSummary.findingSeverityCounts]' \
  --output table
```

**Real-World Example - CloudForge Backend Scan Results:**

After pushing images to ECR, the following vulnerabilities were detected in the Alpine-based Node.js image:

```json
{
  "HIGH": 1,
  "MEDIUM": 2
}
```

**Detailed Findings:**

1. **CVE-2025-9230 (HIGH)**
   - Component: OpenSSL
   - Description: CMS password-based encryption out-of-bounds read/write
   - Impact: Potential DoS or code execution
   - Severity Rationale: While technically severe, CMS PWRI encryption is rarely used
   - Remediation: Update Alpine base image when patch available

2. **CVE-2025-9231 (MEDIUM)**
   - Component: OpenSSL
   - Description: SM2 signature timing side-channel on ARM64 platforms
   - Impact: Potential private key recovery
   - Severity Rationale: Requires custom TLS provider and ARM64 platform
   - Remediation: Update OpenSSL or use non-ARM platforms

3. **CVE-2025-9232 (MEDIUM)**
   - Component: OpenSSL
   - Description: HTTP client no_proxy environment variable vulnerability
   - Impact: Out-of-bounds read leading to DoS
   - Severity Rationale: Requires specific no_proxy configuration
   - Remediation: Update to OpenSSL 3.0.17+, 3.1.9+, 3.2.5+, 3.3.4+, 3.4.1+, or 3.5.1+

**Remediation Workflow:**

```bash
# 1. Check for updated base image
docker pull node:18-alpine
docker pull alpine:3.20

# 2. Update Dockerfile
cat > docker/backend/Dockerfile <<'EOF'
FROM node:18-alpine3.20
# ... rest of Dockerfile
EOF

# 3. Rebuild and push
docker build -t backend:latest -f docker/backend/Dockerfile .
docker tag backend:latest ${ECR_REGISTRY}/cloudforge/backend:latest
docker push ${ECR_REGISTRY}/cloudforge/backend:latest

# 4. Verify new scan results
aws ecr wait image-scan-complete \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest

aws ecr describe-image-scan-findings \
  --repository-name cloudforge/backend \
  --image-id imageTag=latest
```

**Integration with CI/CD:**

```groovy
// Add to Jenkinsfile after pushing to ECR
stage('ECR Security Scan') {
    steps {
        script {
            // Wait for scan to complete
            sh '''
                aws ecr wait image-scan-complete \
                  --repository-name cloudforge/backend \
                  --image-id imageTag=${IMAGE_TAG}
            '''

            // Get scan results
            def scanResults = sh(
                script: '''
                    aws ecr describe-image-scan-findings \
                      --repository-name cloudforge/backend \
                      --image-id imageTag=${IMAGE_TAG} \
                      --query 'imageScanFindings.findingSeverityCounts'
                ''',
                returnStdout: true
            ).trim()

            // Parse and evaluate
            def findings = readJSON text: scanResults
            if (findings.CRITICAL > 0 || findings.HIGH > 5) {
                error("Security vulnerabilities found: ${findings}")
            }
        }
    }
}
```

**Comparison: ECR vs Trivy:**

| Feature | AWS ECR Scan | Trivy |
|---------|-------------|-------|
| Cost | Free (included) | Free |
| Database | AWS-managed CVE | Trivy database |
| Update Frequency | Daily | Hourly |
| OS Coverage | Amazon Linux, Alpine, Debian, Ubuntu, etc. | Comprehensive |
| Speed | Moderate (cloud-based) | Fast (local) |
| Integration | Native AWS | CLI/Docker |
| Reports | AWS Console/CLI | JSON/HTML/SARIF |
| CI/CD | Easy (AWS native) | Easy (any platform) |

**Recommendation**: Use **both** for defense-in-depth:
- ECR scanning for AWS-native integration and compliance
- Trivy for pre-push validation and broader coverage

### Trivy (Container Vulnerability Scanner)

**Purpose**: Scan Docker images for OS and application vulnerabilities before deployment.

**What it Detects**:
- OS package vulnerabilities (Alpine, Ubuntu, etc.)
- Application dependency vulnerabilities
- IaC misconfigurations in Dockerfiles
- Secrets in container images
- License issues

**Jenkins Integration**:
```groovy
stage('Container Scan - Trivy') {
    steps {
        sh '''
            # Install Trivy
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install trivy

            # Scan images
            trivy image --severity HIGH,CRITICAL \
                --exit-code 1 \
                --format json \
                --output trivy-report.json \
                ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
        '''
    }
}
```

**Scan Modes**:
```bash
# Scan image before push
trivy image myapp:latest

# Scan with specific severity
trivy image --severity HIGH,CRITICAL myapp:latest

# Scan filesystem (useful for build context)
trivy fs --security-checks vuln,config .

# Scan and ignore unfixed vulnerabilities
trivy image --ignore-unfixed myapp:latest

# Generate report
trivy image --format json --output report.json myapp:latest
```

**Example Output**:
```
myapp:latest (alpine 3.18)
==========================
Total: 15 (HIGH: 8, CRITICAL: 7)

┌────────────────┬────────────────┬──────────┬────────────────┬───────────────────┐
│   Library      │ Vulnerability  │ Severity │ Installed Ver. │   Fixed Version   │
├────────────────┼────────────────┼──────────┼────────────────┼───────────────────┤
│ openssl        │ CVE-2023-12345 │ CRITICAL │ 1.1.1k         │ 1.1.1t            │
│ nginx          │ CVE-2023-67890 │ HIGH     │ 1.20.1         │ 1.22.0            │
└────────────────┴────────────────┴──────────┴────────────────┴───────────────────┘
```

## 4. DAST (Dynamic Application Security Testing)

### OWASP ZAP (Zed Attack Proxy)

**Purpose**: Test running application for vulnerabilities through active scanning.

**What it Detects**:
- SQL Injection
- Cross-Site Scripting (XSS)
- Cross-Site Request Forgery (CSRF)
- Security misconfigurations
- Sensitive data exposure
- Broken authentication
- XML External Entities (XXE)
- Insecure deserialization

**Jenkins Integration**:
```groovy
stage('DAST - OWASP ZAP') {
    steps {
        sh '''
            docker run -v $(pwd):/zap/wrk/:rw \
                -t owasp/zap2docker-stable \
                zap-baseline.py \
                -t ${APP_URL} \
                -g gen.conf \
                -r zap-report.html \
                -J zap-report.json \
                || true
        '''
        publishHTML([
            reportName: 'ZAP Scan',
            reportDir: '.',
            reportFiles: 'zap-report.html'
        ])
    }
}
```

**Scan Modes**:

1. **Baseline Scan** (Passive)
```bash
docker run -t owasp/zap2docker-stable \
    zap-baseline.py -t https://myapp.com
```

2. **Full Scan** (Active - use carefully)
```bash
docker run -t owasp/zap2docker-stable \
    zap-full-scan.py -t https://myapp.com
```

3. **API Scan**
```bash
docker run -t owasp/zap2docker-stable \
    zap-api-scan.py -t https://api.myapp.com/openapi.json \
        -f openapi
```

**ZAP Configuration**:
```conf
# gen.conf
# Passive scan rules
10010 # Cookie No HttpOnly Flag
10011 # Cookie Without Secure Flag
10015 # Incomplete or No Cache-control
10017 # Cross-Domain JavaScript Source File Inclusion
10019 # Content-Type Header Missing
10020 # X-Frame-Options Header Not Set
10021 # X-Content-Type-Options Header Missing
```

## Pipeline Configuration

### Complete Security Pipeline (Jenkinsfile)

```groovy
pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        SNYK_TOKEN = credentials('snyk-token')
        ECR_REGISTRY = '123456789012.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_NAME = 'devops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Security Scans') {
            parallel {
                stage('SAST - SonarQube') {
                    steps {
                        script {
                            def scannerHome = tool 'SonarQube Scanner'
                            withSonarQubeEnv('SonarQube') {
                                sh "${scannerHome}/bin/sonar-scanner"
                            }
                        }
                    }
                }

                stage('Dependency Check - Snyk') {
                    steps {
                        sh '''
                            snyk test \
                                --severity-threshold=high \
                                --json > snyk-report.json || true
                        '''
                    }
                }

                stage('IaC Scan') {
                    steps {
                        sh './jenkins/scripts/iac-scan.sh'
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    docker-compose build
                '''
            }
        }

        stage('Container Scan - Trivy') {
            steps {
                sh './jenkins/scripts/container-scan.sh'
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region us-east-1 | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker tag frontend:latest ${ECR_REGISTRY}/frontend:${IMAGE_TAG}
                    docker tag backend:latest ${ECR_REGISTRY}/backend:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/frontend:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/backend:${IMAGE_TAG}
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh './jenkins/scripts/deploy.sh'
            }
        }

        stage('DAST - OWASP ZAP') {
            steps {
                sh './jenkins/scripts/dast-scan.sh'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
            archiveArtifacts artifacts: '**/reports/*', allowEmptyArchive: true
        }
        failure {
            emailext (
                subject: "Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: "team@example.com"
            )
        }
    }
}
```

## Security Scan Results Dashboard

### Recommended Metrics to Track

1. **Vulnerability Trends**
   - Total vulnerabilities over time
   - Critical/High/Medium/Low breakdown
   - Time to remediation

2. **Code Quality Metrics**
   - Code coverage percentage
   - Technical debt ratio
   - Code duplication

3. **Compliance Metrics**
   - Failed security checks
   - Policy violations
   - License compliance issues

4. **Container Security**
   - Vulnerable images count
   - Average CVE score
   - Outdated base images

## Remediation Workflow

1. **Scan Failure** → Pipeline stops
2. **Review Report** → Analyze findings in Jenkins/SonarQube
3. **Triage** → Determine severity and impact
4. **Fix** → Apply security patches or code changes
5. **Verify** → Re-run scans
6. **Deploy** → Continue pipeline

## Best Practices

1. **Fail Fast**: Run quick scans (SAST, IaC) before expensive builds
2. **Parallel Scanning**: Run independent scans in parallel
3. **Incremental Scanning**: Only scan changed files when possible
4. **Threshold Management**: Set appropriate failure thresholds
5. **Regular Updates**: Keep scanning tools updated
6. **False Positive Management**: Maintain suppression lists
7. **Developer Training**: Educate team on secure coding
8. **Shift Left**: Run scans locally before commit

## Tool Comparison

| Tool | Type | Speed | Accuracy | False Positives | Cost | Best For |
|------|------|-------|----------|-----------------|------|----------|
| SonarQube | SAST | Medium | High | Low | Free (CE) | Code quality & security |
| Snyk | SCA | Fast | Very High | Very Low | Freemium | Dependency vulnerabilities |
| Checkov | IaC | Fast | High | Low | Free | Multi-cloud IaC scanning |
| tfsec | IaC | Very Fast | High | Low | Free | Terraform-specific checks |
| ECR Scan | Container | Medium | High | Low | Free | AWS-native integration |
| Trivy | Container | Fast | High | Low | Free | Pre-push validation |
| OWASP ZAP | DAST | Slow | Medium | Medium | Free | Runtime testing |

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [DevSecOps Manifesto](https://www.devsecops.org/)
