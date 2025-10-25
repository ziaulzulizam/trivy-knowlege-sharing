#!/bin/bash
echo "Running Trivy security scan..."

# Scan filesystem for vulnerabilities
trivy fs --exit-code 1 --severity HIGH,CRITICAL .

# Scan for secrets
trivy fs --scanners secret --exit-code 1 .

# If Docker files exist, scan them
if find . -name "Dockerfile*" -type f | grep -q .; then
    echo "Scanning Dockerfiles..."
    trivy config --exit-code 1 --severity HIGH,CRITICAL .
fi

echo "Trivy scan completed successfully!"