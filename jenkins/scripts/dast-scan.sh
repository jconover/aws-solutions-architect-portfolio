#!/bin/bash
# Dynamic Application Security Testing Script
# Uses OWASP ZAP to scan running application

set -e

echo "========================================="
echo "DAST with OWASP ZAP"
echo "========================================="

# Create reports directory
mkdir -p reports

# Check if APP_URL is set
if [ -z "$APP_URL" ]; then
    echo "ERROR: APP_URL environment variable not set"
    exit 1
fi

echo "Target URL: $APP_URL"

# Run ZAP Baseline Scan
echo ""
echo "=== Running OWASP ZAP Baseline Scan ==="
docker run --rm \
    -v $(pwd)/reports:/zap/wrk/:rw \
    -t owasp/zap2docker-stable \
    zap-baseline.py \
    -t $APP_URL \
    -r zap-report.html \
    -J zap-report.json \
    -w zap-report.md \
    || ZAP_EXIT_CODE=$?

# ZAP returns different exit codes:
# 0 = success (no alerts)
# 1 = warning (some alerts found)
# 2 = failure (high alerts found)

echo ""
echo "=== ZAP Scan Results Summary ==="

if [ -f reports/zap-report.json ]; then
    # Count alerts by risk level
    HIGH_ALERTS=$(jq '[.site[0].alerts[] | select(.riskcode == "3")] | length' reports/zap-report.json)
    MEDIUM_ALERTS=$(jq '[.site[0].alerts[] | select(.riskcode == "2")] | length' reports/zap-report.json)
    LOW_ALERTS=$(jq '[.site[0].alerts[] | select(.riskcode == "1")] | length' reports/zap-report.json)
    INFO_ALERTS=$(jq '[.site[0].alerts[] | select(.riskcode == "0")] | length' reports/zap-report.json)

    echo "High Risk Alerts: $HIGH_ALERTS"
    echo "Medium Risk Alerts: $MEDIUM_ALERTS"
    echo "Low Risk Alerts: $LOW_ALERTS"
    echo "Informational Alerts: $INFO_ALERTS"

    # Print high risk alerts details
    if [ "$HIGH_ALERTS" -gt 0 ]; then
        echo ""
        echo "High Risk Issues Found:"
        jq -r '.site[0].alerts[] | select(.riskcode == "3") | "  - \(.alert) (\(.count) instances)"' reports/zap-report.json
    fi
fi

# Fail pipeline if high risk alerts found
if [ "${ZAP_EXIT_CODE:-0}" -eq 2 ]; then
    echo ""
    echo "FAIL: High risk security issues found"
    echo "Review the ZAP report for details"
    exit 1
fi

if [ "${ZAP_EXIT_CODE:-0}" -eq 1 ]; then
    echo ""
    echo "WARNING: Some security alerts found, but not blocking deployment"
fi

echo ""
echo "SUCCESS: DAST scan completed"
exit 0
