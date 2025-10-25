# Use Case 1: CI/CD using GitHub Actions with Trivy on Local Machine

## Scenario: Local Development with GitHub Actions Integration
Set up a complete CI/CD workflow using GitHub Actions that runs Trivy scans both locally and in the pipeline.

## Local Machine Setup

### Install Trivy locally
```bash
# For Ubuntu/Debian
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Verify installation
trivy --version
```

## Files in this directory:
- `setup-local.sh` - Script to set up Trivy locally and configure pre-commit hooks
- `trivy-security.yml` - GitHub Actions workflow file
- `pre-commit-hook.sh` - Pre-commit hook script for local development
- `Dockerfile` - Example Dockerfile for testing

## Local Development Workflow:
1. Make changes to code
2. Pre-commit hook runs automatically (or manually)
3. Manual scan before push (optional)
4. Push to trigger CI/CD
5. Create PR - GitHub Actions runs automatically

## Expected Outputs:
- Pre-commit hook prevents commits with critical vulnerabilities
- GitHub Security tab shows detailed vulnerability reports
- HTML reports available as artifacts
- Build fails on critical vulnerabilities in main branch
- Automated scanning of both source code and built Docker images