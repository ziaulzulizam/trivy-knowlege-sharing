# AquaSec Trivy - Complete Use Case Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Installation Setup](#installation-setup)
3. [Practical Use Cases](#practical-use-cases)
4. [Knowledge Discussion Topics](#knowledge-discussion-topics)
5. [Demo Scenarios](#demo-scenarios)

---

## Introduction

### What is Trivy?
Trivy is a comprehensive, easy-to-use open-source vulnerability scanner developed by Aqua Security. It can scan:
- Container images
- Filesystem
- Git repositories
- Kubernetes clusters
- Cloud infrastructure (IaC)
- Software Bill of Materials (SBOM)

### Key Features
- Detects vulnerabilities in OS packages and application dependencies
- Simple installation and usage
- Fast scanning performance
- CI/CD integration support
- Multiple output formats (JSON, SARIF, Table, etc.)
- Offline operation capability

---

## Installation Setup

### For Linux (Ubuntu/Debian)
```bash
# Add Trivy repository
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

# Install Trivy
sudo apt-get update
sudo apt-get install trivy
```

### For macOS
```bash
# Using Homebrew
brew install trivy
```

### For Windows
```powershell
# Using Chocolatey
choco install trivy

# Or download binary from GitHub releases
# https://github.com/aquasecurity/trivy/releases
```

### Verify Installation
```bash
trivy --version
```

---

## Practical Use Cases

### Use Case 1: CI/CD using GitHub Actions with Trivy on Local Machine

#### Scenario: Local Development with GitHub Actions Integration
Set up a complete CI/CD workflow using GitHub Actions that runs Trivy scans both locally and in the pipeline.

**Local Machine Setup:**
```bash
# Install Trivy locally
# For Ubuntu/Debian
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Verify installation
trivy --version
```

**Local Pre-commit Setup:**
```bash
# Create pre-commit hook
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
```

**GitHub Actions Workflow:**
```yaml
# .github/workflows/trivy-security.yml
name: Trivy Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    name: Trivy Security Scan
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner in repo mode
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '0'  # Don't fail build, just report

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Trivy vulnerability scanner (fail on high/critical)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'table'
          severity: 'CRITICAL'
          exit-code: '1'  # Fail build on critical vulnerabilities

      - name: Generate HTML report
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'template'
          template: '@/contrib/html.tpl'
          output: 'trivy-report.html'

      - name: Upload HTML report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: trivy-security-report
          path: trivy-report.html

  build-and-scan-image:
    runs-on: ubuntu-latest
    needs: trivy-scan
    if: github.event_name == 'push'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t myapp:${{ github.sha }} .
          
      - name: Scan Docker image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          
      - name: Upload image scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-image-results.sarif'
```

**Local Development Workflow:**
```bash
# Developer workflow
# 1. Make changes to code
git add .

# 2. Pre-commit hook runs automatically (or manually)
git commit -m "Add new feature"

# 3. Manual scan before push (optional)
trivy fs --severity HIGH,CRITICAL .
trivy fs --scanners secret .

# 4. Push to trigger CI/CD
git push origin feature-branch

# 5. Create PR - GitHub Actions runs automatically
```

**Expected Outputs:**
- Pre-commit hook prevents commits with critical vulnerabilities
- GitHub Security tab shows detailed vulnerability reports
- HTML reports available as artifacts
- Build fails on critical vulnerabilities in main branch
- Automated scanning of both source code and built Docker images

---

### Use Case 2: PHP Application Vulnerability Management Workflow

#### Scenario: Complete PHP Application Security Pipeline
A developer creates a PHP application with vulnerable and outdated dependencies, containerizes it, and implements a comprehensive vulnerability management workflow with Trivy.

**Step 1: Create Vulnerable PHP Application**

**Dockerfile with Vulnerable PHP Version:**
```dockerfile
# Vulnerable Dockerfile - Using outdated PHP version
FROM php:7.4-apache

# Install vulnerable packages
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Install Composer
COPY --from=composer:1.10 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files first for better caching
COPY composer.json composer.lock ./

# Install PHP dependencies (with known vulnerabilities)
RUN composer install --no-dev --optimize-autoloader

# Copy application code
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 80

CMD ["apache2-foreground"]
```

**composer.json with Vulnerable Dependencies:**
```json
{
    "name": "vulnerable-php-app",
    "description": "Sample PHP application with security vulnerabilities",
    "type": "project",
    "require": {
        "php": "^7.4",
        "guzzlehttp/guzzle": "6.3.0",
        "symfony/console": "4.4.0",
        "doctrine/orm": "2.6.0",
        "monolog/monolog": "1.24.0",
        "twig/twig": "2.12.0",
        "swiftmailer/swiftmailer": "6.1.0"
    },
    "require-dev": {
        "phpunit/phpunit": "8.5.0",
        "symfony/var-dumper": "4.4.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

**Step 2: Build and Push Docker Image**
```bash
# Build the vulnerable image
docker build -t vulnerable-php-app:latest .

# Tag for registry
docker tag vulnerable-php-app:latest myregistry/vulnerable-php-app:v1.0.0

# Push to registry
docker push myregistry/vulnerable-php-app:v1.0.0
```

**Step 3: Comprehensive Trivy Vulnerability Assessment**

**Initial Vulnerability Scan:**
```bash
# Scan the Docker image
trivy image myregistry/vulnerable-php-app:v1.0.0

# Detailed scan with JSON output
trivy image --format json --output vulnerability-report.json myregistry/vulnerable-php-app:v1.0.0

# Scan with severity filtering
trivy image --severity CRITICAL,HIGH myregistry/vulnerable-php-app:v1.0.0

# Scan for secrets in the image
trivy image --scanners secret myregistry/vulnerable-php-app:v1.0.0
```

**Step 4: CVE Assessment and Prioritization**

**CVSS Score Analysis Script:**
```bash
#!/bin/bash
# cvss-analysis.sh - Analyze CVSS scores and prioritize vulnerabilities

echo "=== TRIVY VULNERABILITY ASSESSMENT AND PRIORITIZATION ==="

# Generate comprehensive JSON report
trivy image --format json --output detailed-report.json myregistry/vulnerable-php-app:v1.0.0

# Extract and analyze CVSS scores
echo "=== CRITICAL VULNERABILITIES (CVSS >= 9.0) ==="
cat detailed-report.json | jq -r '
  .Results[]? | 
  select(.Vulnerabilities) | 
  .Vulnerabilities[] | 
  select(.CVSS.nvd.V3Score >= 9.0) | 
  "CVE: \(.VulnerabilityID) | CVSS: \(.CVSS.nvd.V3Score) | Package: \(.PkgName) | Severity: \(.Severity)"'

echo ""
echo "=== HIGH VULNERABILITIES (CVSS 7.0-8.9) ==="
cat detailed-report.json | jq -r '
  .Results[]? | 
  select(.Vulnerabilities) | 
  .Vulnerabilities[] | 
  select(.CVSS.nvd.V3Score >= 7.0 and .CVSS.nvd.V3Score < 9.0) | 
  "CVE: \(.VulnerabilityID) | CVSS: \(.CVSS.nvd.V3Score) | Package: \(.PkgName) | Severity: \(.Severity)"'

echo ""
echo "=== EXPLOITABILITY ANALYSIS ==="
# Check for known exploited vulnerabilities (would need EPSS database integration)
cat detailed-report.json | jq -r '
  .Results[]? | 
  select(.Vulnerabilities) | 
  .Vulnerabilities[] | 
  select(.VulnerabilityID) | 
  "CVE: \(.VulnerabilityID) | Title: \(.Title) | Package: \(.PkgName)"'

echo ""
echo "=== VULNERABILITY SUMMARY ==="
cat detailed-report.json | jq -r '
  [.Results[]?.Vulnerabilities[]? | .Severity] | 
  group_by(.) | 
  map({severity: .[0], count: length}) | 
  .[] | 
  "Severity: \(.severity) | Count: \(.count)"'
```

**Severity Filtering and Priority Matrix:**
```bash
# Create priority-based scans
echo "=== IMMEDIATE ACTION REQUIRED (CRITICAL) ==="
trivy image --severity CRITICAL --format table myregistry/vulnerable-php-app:v1.0.0

echo "=== SCHEDULE FOR NEXT RELEASE (HIGH) ==="
trivy image --severity HIGH --format table myregistry/vulnerable-php-app:v1.0.0

echo "=== BACKLOG ITEMS (MEDIUM) ==="
trivy image --severity MEDIUM --format table myregistry/vulnerable-php-app:v1.0.0
```

**Step 5: Generate Multiple Report Formats**

**SARIF Report for GitHub Security:**
```bash
# Generate SARIF report for GitHub Security tab
trivy image --format sarif --output trivy-results.sarif myregistry/vulnerable-php-app:v1.0.0

# GitHub Actions workflow to upload SARIF
cat > .github/workflows/trivy-scan.yml << 'EOF'
name: Trivy Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Build image
      run: docker build -t ${{ github.repository }}:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: '${{ github.repository }}:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'
EOF
```

**HTML Report for Human-Readable Analysis:**
```bash
# Generate comprehensive HTML report
trivy image --format template --template '@/contrib/html.tpl' --output vulnerability-report.html myregistry/vulnerable-php-app:v1.0.0

# Custom HTML template for detailed reporting
cat > custom-report.tpl << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Vulnerability Assessment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .critical { background-color: #ff4444; color: white; }
        .high { background-color: #ff8800; color: white; }
        .medium { background-color: #ffaa00; }
        .low { background-color: #88cc88; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background-color: #f9f9f9; padding: 20px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Security Vulnerability Assessment Report</h1>
    <div class="summary">
        <h2>Executive Summary</h2>
        <p><strong>Scan Target:</strong> {{ range . }}{{ .Target }}{{ end }}</p>
        <p><strong>Scan Date:</strong> {{ now.Format "2006-01-02 15:04:05" }}</p>
        <p><strong>Total Vulnerabilities:</strong> 
        {{ $critical := 0 }}{{ $high := 0 }}{{ $medium := 0 }}{{ $low := 0 }}
        {{ range . }}{{ range .Vulnerabilities }}
            {{ if eq .Severity "CRITICAL" }}{{ $critical = add $critical 1 }}{{ end }}
            {{ if eq .Severity "HIGH" }}{{ $high = add $high 1 }}{{ end }}
            {{ if eq .Severity "MEDIUM" }}{{ $medium = add $medium 1 }}{{ end }}
            {{ if eq .Severity "LOW" }}{{ $low = add $low 1 }}{{ end }}
        {{ end }}{{ end }}
        Critical: {{ $critical }}, High: {{ $high }}, Medium: {{ $medium }}, Low: {{ $low }}
        </p>
    </div>

    {{ range . }}
    <h2>{{ .Target }}</h2>
    {{ if .Vulnerabilities }}
    <table>
        <tr>
            <th>CVE ID</th>
            <th>Severity</th>
            <th>Package</th>
            <th>Installed Version</th>
            <th>Fixed Version</th>
            <th>CVSS Score</th>
            <th>Description</th>
        </tr>
        {{ range .Vulnerabilities }}
        <tr class="{{ .Severity | lower }}">
            <td><a href="{{ .PrimaryURL }}" target="_blank">{{ .VulnerabilityID }}</a></td>
            <td>{{ .Severity }}</td>
            <td>{{ .PkgName }}</td>
            <td>{{ .InstalledVersion }}</td>
            <td>{{ .FixedVersion }}</td>
            <td>{{ if .CVSS.nvd.V3Score }}{{ .CVSS.nvd.V3Score }}{{ else }}N/A{{ end }}</td>
            <td>{{ .Title }}</td>
        </tr>
        {{ end }}
    </table>
    {{ else }}
    <p>No vulnerabilities found.</p>
    {{ end }}
    {{ end }}
</body>
</html>
EOF

# Generate report with custom template
trivy image --format template --template ./custom-report.tpl --output detailed-vulnerability-report.html myregistry/vulnerable-php-app:v1.0.0
```

**Step 6: Automated Reporting Pipeline**
```bash
#!/bin/bash
# automated-security-pipeline.sh

IMAGE_NAME="myregistry/vulnerable-php-app:v1.0.0"
REPORT_DIR="./security-reports"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $REPORT_DIR

echo "Starting comprehensive security assessment for $IMAGE_NAME"

# 1. Generate JSON report for programmatic analysis
echo "Generating JSON report..."
trivy image --format json --output "$REPORT_DIR/vulnerability-report-$DATE.json" $IMAGE_NAME

# 2. Generate SARIF for GitHub Security
echo "Generating SARIF report for GitHub..."
trivy image --format sarif --output "$REPORT_DIR/trivy-results-$DATE.sarif" $IMAGE_NAME

# 3. Generate HTML report for stakeholders
echo "Generating HTML report for stakeholders..."
trivy image --format template --template '@/contrib/html.tpl' --output "$REPORT_DIR/security-report-$DATE.html" $IMAGE_NAME

# 4. Generate executive summary
echo "Generating executive summary..."
cat > "$REPORT_DIR/executive-summary-$DATE.txt" << EOF
SECURITY ASSESSMENT EXECUTIVE SUMMARY
=====================================
Scan Date: $(date)
Image: $IMAGE_NAME

VULNERABILITY SUMMARY:
$(trivy image --format json $IMAGE_NAME | jq -r '[.Results[]?.Vulnerabilities[]? | .Severity] | group_by(.) | map({severity: .[0], count: length}) | .[] | "- \(.severity): \(.count) vulnerabilities"')

CRITICAL ISSUES REQUIRING IMMEDIATE ATTENTION:
$(trivy image --severity CRITICAL --format table $IMAGE_NAME)

RECOMMENDATIONS:
1. Update base image to latest stable version
2. Update all packages to fixed versions
3. Implement security scanning in CI/CD pipeline
4. Schedule regular vulnerability assessments
EOF

echo "Reports generated in $REPORT_DIR/"
echo "Summary: $(trivy image --format json $IMAGE_NAME | jq -r '[.Results[]?.Vulnerabilities[]? | .Severity] | group_by(.) | map({severity: .[0], count: length}) | map("\(.severity): \(.count)") | join(", ")')"
```

**Expected Workflow Outputs:**
- **JSON Report**: Machine-readable vulnerability data for automation
- **SARIF Report**: Integrated with GitHub Security tab showing vulnerabilities in code context
- **HTML Report**: Human-readable comprehensive report for security teams
- **Executive Summary**: High-level overview for management
- **Prioritization Matrix**: Vulnerabilities categorized by severity and exploitability
- **Remediation Roadmap**: Actionable steps for vulnerability resolution

**Key Benefits of This Workflow:**
- Complete visibility into application security posture
- Multiple report formats for different stakeholders
- Automated integration with development workflows
- Risk-based prioritization for efficient remediation
- Compliance-ready documentation and audit trails

---

## Knowledge Discussion Topics

### 1. Vulnerability Management Strategy

**Discussion Points:**
- **Risk-Based Prioritization**: How to prioritize vulnerabilities based on:
  - Severity (CVSS scores)
  - Exploitability
  - Asset criticality
  - Exposure to internet
  
- **Remediation Workflows**:
  - Immediate patching for CRITICAL vulnerabilities
  - Scheduled updates for HIGH severity
  - Risk acceptance process for LOW/MEDIUM

- **Metrics to Track**:
  - Mean Time to Detect (MTTD)
  - Mean Time to Remediate (MTTR)
  - Vulnerability density per application
  - Trend analysis over time

---

### 2. Container Security Best Practices

**Key Topics:**

**Image Selection:**
- Use minimal base images (Alpine, Distroless)
- Official images from trusted registries
- Regular base image updates

**Build Security:**
- Multi-stage builds to reduce attack surface
- Non-root user execution
- Minimize installed packages
- Copy only necessary files

**Runtime Security:**
- Read-only root filesystem
- Drop unnecessary capabilities
- Resource limits (CPU, memory)
- Network policies
- Pod security policies/standards

**Supply Chain Security:**
- Image signing and verification
- Private registry usage
- Dependency pinning
- Regular scanning schedules

---

### 3. DevSecOps Integration

**Discussion Areas:**

**Shift-Left Security:**
- Early vulnerability detection in development
- Developer education and tooling
- Pre-commit hooks with Trivy
- IDE integration possibilities

**CI/CD Security Gates:**
- Fail builds on critical vulnerabilities
- Exception/waiver processes
- Automated ticket creation
- Security dashboard integration

**Continuous Monitoring:**
- Regular re-scanning of deployed images
- Runtime threat detection
- Compliance reporting
- Audit trail maintenance

---

### 4. Compliance and Regulatory Requirements

**Relevant Standards:**

**PCI-DSS:**
- Requirement 6.2: Protect against vulnerabilities
- Regular vulnerability scanning
- Patch management processes

**SOC 2:**
- System monitoring controls
- Vulnerability management
- Change management

**ISO 27001:**
- Technical vulnerability management
- Information security risk management

**HIPAA:**
- Security management process
- Information system activity review

---

### 5. Trivy Architecture and How It Works

**Technical Deep Dive:**

**Scanning Process:**
1. **Database Update**: Downloads latest vulnerability database
2. **Artifact Analysis**: Analyzes OS packages, language-specific dependencies
3. **Vulnerability Matching**: Matches found packages against CVE database
4. **Report Generation**: Produces formatted output

**Data Sources:**
- National Vulnerability Database (NVD)
- GitHub Security Advisories
- Operating system vendors (RHEL, Debian, Alpine, etc.)
- Language-specific advisories (npm, PyPI, RubyGems)

**Detection Methods:**
- OS package managers (dpkg, rpm, apk)
- Application dependency files (package.json, requirements.txt, go.mod)
- License detection
- Secret scanning patterns

---

### 6. Comparison with Other Security Tools

**Trivy vs. Alternatives:**

| Feature | Trivy | Clair | Anchore | Snyk |
|---------|-------|-------|---------|------|
| **Ease of Use** | Excellent | Moderate | Moderate | Excellent |
| **Speed** | Very Fast | Moderate | Slow | Fast |
| **Offline Mode** | Yes | Partial | Yes | Limited |
| **Cost** | Free (OSS) | Free (OSS) | Free/Commercial | Commercial/Free Tier |
| **IaC Scanning** | Yes | No | Limited | Yes |
| **SBOM Support** | Yes | No | Yes | Yes |
| **K8s Scanning** | Yes | No | Yes | Yes |

**When to Use Trivy:**
- Need comprehensive, fast scanning
- Budget constraints (open-source)
- Multiple scan targets (images, IaC, repos)
- CI/CD integration requirements
- Offline environments

---

### 7. False Positives and Vulnerability Context

**Managing False Positives:**

**Common Scenarios:**
- Unused dependencies or code paths
- Vulnerabilities in test dependencies
- Fixed in custom patches
- Not applicable to specific use case

**Mitigation Strategies:**
```yaml
# .trivyignore file example
# Ignore specific CVE
CVE-2021-12345

# Ignore CVE until fixed version available
CVE-2021-67890 exp:2024-12-31

# Ignore with reason
CVE-2021-11111 # Not exploitable in our configuration
```

**Contextual Analysis:**
- Reachability analysis
- EPSS scores (Exploit Prediction Scoring System)
- Known exploits in the wild (KEV catalog)
- Application-specific context

---

### 8. Advanced Trivy Features

**Custom Policies:**
```rego
# Custom OPA policy for Trivy
package trivy

deny[msg] {
    input.Vulnerabilities[_].Severity == "CRITICAL"
    msg = "Critical vulnerabilities are not allowed"
}

deny[msg] {
    input.Vulnerabilities[_].PkgName == "log4j"
    msg = "Log4j is not allowed due to security concerns"
}
```

**Database Customization:**
- Air-gapped environments setup
- Custom vulnerability database
- Private registry integration

**Plugin System:**
- Extend functionality
- Custom reporters
- Integration with other tools

---

## Demo Scenarios

### Demo 1: Simple Image Scan (10 minutes)

**Objective:** Show basic vulnerability detection

**Steps:**
1. Pull a known vulnerable image
   ```bash
   docker pull vulnerables/web-dvwa:latest
   ```

2. Scan the image
   ```bash
   trivy image vulnerables/web-dvwa:latest
   ```

3. Explain the output:
   - Severity distribution
   - CVE details
   - Fixed versions
   - Total vulnerability count

4. Show filtering
   ```bash
   trivy image --severity CRITICAL vulnerables/web-dvwa:latest
   ```

**Key Talking Points:**
- Number of vulnerabilities doesn't always indicate risk
- Severity classification importance
- Remediation guidance

---

### Demo 2: Before and After Patching (15 minutes)

**Objective:** Demonstrate remediation effectiveness

**Steps:**
1. Scan vulnerable version
   ```bash
   trivy image node:14.15.0
   ```

2. Document findings
   ```bash
   trivy image --format json -o before.json node:14.15.0
   ```

3. Scan patched version
   ```bash
   trivy image node:14.21.3
   ```

4. Compare results
   ```bash
   trivy image --format json -o after.json node:14.21.3
   ```

**Key Talking Points:**
- Importance of keeping base images updated
- Cost vs. benefit of updates
- Breaking changes consideration

---

### Demo 3: Misconfiguration Detection (15 minutes)

**Objective:** Show IaC security issues

**Setup - Create insecure Kubernetes manifest:**
```yaml
# insecure-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure
  template:
    metadata:
      labels:
        app: insecure
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        securityContext:
          runAsUser: 0  # Running as root
          privileged: true  # Privileged mode
        resources: {}  # No resource limits
        ports:
        - containerPort: 80
          hostPort: 80  # Host port binding
```

**Scan:**
```bash
trivy config insecure-deployment.yaml
```

**Expected Findings:**
- Running as root user
- Privileged container
- Missing resource limits
- Host port binding
- No security context

**Fix and re-scan:**
```yaml
# secure-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: nginx
        image: nginx:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
              - ALL
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        ports:
        - containerPort: 80
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

---

### Demo 4: CI/CD Integration (20 minutes)

**Objective:** Show automated security in pipeline

**Setup:**
1. Create sample repository
2. Add Trivy GitHub Action
3. Trigger scan on PR
4. Show failed/passed builds
5. Demonstrate security tab integration

**Key Points:**
- Automated security checks
- Developer feedback loops
- Security gate policies
- Exception handling

---

### Demo 5: Secret Scanning (10 minutes)

**Objective:** Detect hardcoded secrets

**Setup - Create file with secrets:**
```bash
# Create test file
cat > config.yaml << EOF
database:
  host: localhost
  username: admin
  password: SuperSecret123!
  
aws:
  access_key: AKIAIOSFODNN7EXAMPLE
  secret_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

github:
  token: ghp_1234567890abcdefghijklmnopqrstuvwxyz
EOF
```

**Scan:**
```bash
trivy fs --scanners secret .
```

**Key Talking Points:**
- Types of secrets detected
- Secret management best practices
- Integration with secret managers
- Remediation steps

---

## Practical Exercises for Audience

### Exercise 1: Basic Image Scanning
**Task:** Scan 3 different images and compare vulnerability counts
```bash
trivy image alpine:3.14
trivy image ubuntu:20.04
trivy image nginx:alpine
```

**Questions:**
- Which image has the least vulnerabilities?
- Why do minimal images tend to be more secure?
- What's the trade-off between features and security?

---

### Exercise 2: Create Secure Dockerfile
**Task:** Write a secure Dockerfile that passes Trivy scan

**Requirements:**
- Use minimal base image
- Non-root user
- No critical/high vulnerabilities
- Resource limits defined
- Health checks implemented

---

### Exercise 3: Set Up CI/CD Integration
**Task:** Integrate Trivy into your CI/CD pipeline

**Deliverables:**
- Working pipeline configuration
- Failed build on critical vulnerabilities
- JSON report artifact
- Security dashboard integration

---

## Additional Resources

### Official Documentation
- Trivy GitHub: https://github.com/aquasecurity/trivy
- Official Docs: https://aquasecurity.github.io/trivy/
- Trivy Action: https://github.com/aquasecurity/trivy-action

### Vulnerability Databases
- NVD: https://nvd.nist.gov/
- GitHub Advisory: https://github.com/advisories
- CISA KEV: https://www.cisa.gov/known-exploited-vulnerabilities

### Learning Resources
- Container Security Best Practices
- OWASP Container Security
- CIS Benchmarks
- Kubernetes Security Hardening Guide

---

## Conclusion

Trivy is a powerful, versatile security scanning tool that should be part of every DevSecOps toolkit. Its ease of use, comprehensive scanning capabilities, and CI/CD integration make it ideal for implementing shift-left security practices.

**Key Takeaways:**
1. Security scanning should be automated and continuous
2. Vulnerability management requires context and prioritization
3. Configuration scanning is as important as vulnerability scanning
4. Integration into development workflows is crucial
5. Regular updates and monitoring are essential

**Next Steps:**
- Implement Trivy in your development environment
- Create security policies and thresholds
- Train teams on using and interpreting results
- Establish remediation processes
- Monitor and improve over time
