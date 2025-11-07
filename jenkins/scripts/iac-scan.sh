#!/bin/bash
# Infrastructure as Code Security Scanning Script
# Runs Checkov and tfsec on Terraform configurations

set -e

echo "========================================="
echo "Infrastructure Security Scanning"
echo "========================================="

# Create reports directory
mkdir -p reports

# Install Checkov if not present
if ! command -v checkov &> /dev/null; then
    echo "Installing Checkov..."
    pip3 install checkov
fi

# Install tfsec if not present
if ! command -v tfsec &> /dev/null; then
    echo "Installing tfsec..."
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    sudo mv tfsec /usr/local/bin/
fi

echo ""
echo "=== Running Checkov on Terraform ==="
checkov -d infrastructure/terraform \
    --framework terraform \
    --output cli \
    --output json \
    --output-file-path reports/checkov-terraform-report.json \
    --soft-fail-on MEDIUM \
    --hard-fail-on HIGH,CRITICAL || CHECKOV_TERRAFORM_EXIT_CODE=$?

echo ""
echo "=== Running Checkov on CloudFormation ==="
checkov -d infrastructure/cloudformation \
    --framework cloudformation \
    --output cli \
    --output json \
    --output-file-path reports/checkov-cfn-report.json \
    --soft-fail-on MEDIUM \
    --hard-fail-on HIGH,CRITICAL || CHECKOV_CFN_EXIT_CODE=$?

echo ""
echo "=== Running tfsec on Terraform ==="
tfsec infrastructure/terraform \
    --format json \
    --out reports/tfsec-report.json \
    --minimum-severity HIGH || TFSEC_EXIT_CODE=$?

tfsec infrastructure/terraform \
    --format default \
    --minimum-severity MEDIUM

echo ""
echo "=== IaC Scan Results Summary ==="

if [ -f reports/checkov-terraform-report.json ]; then
    CHECKOV_FAILED=$(jq '.summary.failed' reports/checkov-terraform-report.json)
    CHECKOV_PASSED=$(jq '.summary.passed' reports/checkov-terraform-report.json)
    echo "Checkov Terraform: $CHECKOV_PASSED passed, $CHECKOV_FAILED failed"
fi

if [ -f reports/tfsec-report.json ]; then
    TFSEC_ISSUES=$(jq '.results | length' reports/tfsec-report.json)
    echo "tfsec: $TFSEC_ISSUES issues found"
fi

# Fail pipeline if high/critical issues found
if [ "${CHECKOV_TERRAFORM_EXIT_CODE:-0}" -ne 0 ] || [ "${TFSEC_EXIT_CODE:-0}" -ne 0 ]; then
    echo ""
    echo "FAIL: Critical security issues found in Infrastructure as Code"
    exit 1
fi

echo ""
echo "SUCCESS: IaC security scan passed"
exit 0
