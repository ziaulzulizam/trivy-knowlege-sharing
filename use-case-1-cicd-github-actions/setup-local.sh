#!/bin/bash

echo "Setting up Trivy for local development..."

# Check if Trivy is installed
if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    # For Ubuntu/Debian
    sudo apt-get install wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy
else
    echo "Trivy is already installed: $(trivy --version)"
fi

# Set up pre-commit hook
echo "Setting up pre-commit hook..."
mkdir -p .git/hooks

cat > .git/hooks/pre-commit << 'EOF'
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
EOF

chmod +x .git/hooks/pre-commit

echo "Setup completed successfully!"
echo "You can now run 'git commit' and the pre-commit hook will automatically scan for vulnerabilities."