#!/bin/bash
# Container Security Scanning Script
# Uses Trivy to scan Docker images for vulnerabilities

set -e

echo "========================================="
echo "Container Security Scanning with Trivy"
echo "========================================="

# Create reports directory
mkdir -p reports

# Install Trivy if not present
if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install -y trivy
fi

# Update Trivy database
echo "Updating Trivy vulnerability database..."
trivy image --download-db-only

# Scan frontend image
echo ""
echo "=== Scanning Frontend Image ==="
trivy image --severity HIGH,CRITICAL \
    --format table \
    ${FRONTEND_IMAGE}:${IMAGE_TAG}

trivy image --severity HIGH,CRITICAL \
    --format json \
    --output reports/trivy-frontend-report.json \
    ${FRONTEND_IMAGE}:${IMAGE_TAG}

# Scan backend image
echo ""
echo "=== Scanning Backend Image ==="
trivy image --severity HIGH,CRITICAL \
    --format table \
    ${BACKEND_IMAGE}:${IMAGE_TAG}

trivy image --severity HIGH,CRITICAL \
    --format json \
    --output reports/trivy-backend-report.json \
    ${BACKEND_IMAGE}:${IMAGE_TAG}

# Generate summary
echo ""
echo "=== Container Scan Results Summary ==="

if [ -f reports/trivy-frontend-report.json ]; then
    FRONTEND_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' reports/trivy-frontend-report.json)
    echo "Frontend: $FRONTEND_VULNS HIGH/CRITICAL vulnerabilities"
fi

if [ -f reports/trivy-backend-report.json ]; then
    BACKEND_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' reports/trivy-backend-report.json)
    echo "Backend: $BACKEND_VULNS HIGH/CRITICAL vulnerabilities"
fi

# Check for critical vulnerabilities with available fixes
echo ""
echo "Checking for fixable critical vulnerabilities..."
FRONTEND_FIXABLE=$(trivy image --severity CRITICAL --format json ${FRONTEND_IMAGE}:${IMAGE_TAG} | \
    jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" and .FixedVersion != "")] | length')

BACKEND_FIXABLE=$(trivy image --severity CRITICAL --format json ${BACKEND_IMAGE}:${IMAGE_TAG} | \
    jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" and .FixedVersion != "")] | length')

echo "Frontend: $FRONTEND_FIXABLE fixable CRITICAL vulnerabilities"
echo "Backend: $BACKEND_FIXABLE fixable CRITICAL vulnerabilities"

# Fail if fixable critical vulnerabilities found
if [ "$FRONTEND_FIXABLE" -gt 0 ] || [ "$BACKEND_FIXABLE" -gt 0 ]; then
    echo ""
    echo "FAIL: Fixable CRITICAL vulnerabilities found. Please update dependencies."
    exit 1
fi

echo ""
echo "SUCCESS: Container security scan passed (no fixable critical vulnerabilities)"
exit 0
