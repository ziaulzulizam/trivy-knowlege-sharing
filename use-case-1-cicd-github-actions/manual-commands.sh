#!/bin/bash
# Manual Trivy commands for local development

echo "=== Developer Manual Scan Commands ==="

echo "1. Make changes to code"
echo "git add ."

echo ""
echo "2. Pre-commit hook runs automatically (or manually)"
echo "git commit -m 'Add new feature'"

echo ""
echo "3. Manual scan before push (optional)"
echo "trivy fs --severity HIGH,CRITICAL ."
echo "trivy fs --scanners secret ."

echo ""
echo "4. Push to trigger CI/CD"
echo "git push origin feature-branch"

echo ""
echo "5. Create PR - GitHub Actions runs automatically"

echo ""
echo "=== Additional useful commands ==="
echo "# Scan current directory for all vulnerabilities"
echo "trivy fs ."

echo ""
echo "# Scan with JSON output"
echo "trivy fs --format json --output scan-results.json ."

echo ""
echo "# Scan Docker image"
echo "trivy image nginx:latest"

echo ""
echo "# Scan with severity filtering"
echo "trivy image --severity CRITICAL,HIGH nginx:latest"