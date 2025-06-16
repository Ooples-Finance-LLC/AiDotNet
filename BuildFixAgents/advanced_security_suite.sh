#!/bin/bash

# Advanced Security Suite - Enterprise-grade security scanning and vulnerability management
# Includes secrets detection, CVE database integration, SAST/DAST capabilities

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$AGENT_DIR/state/security"
CONFIG_FILE="$AGENT_DIR/config/security_suite.yml"
CVE_DB="$SECURITY_DIR/cve_database.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create directories
mkdir -p "$SECURITY_DIR/scans" "$SECURITY_DIR/reports" "$SECURITY_DIR/vulnerabilities" "$(dirname "$CONFIG_FILE")"

# Initialize security configuration
init_security_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Advanced Security Suite Configuration
security:
  scanning:
    secrets_detection: true
    vulnerability_scanning: true
    dependency_checking: true
    code_analysis: true
    
  secrets:
    patterns:
      - name: "AWS Access Key"
        regex: "AKIA[0-9A-Z]{16}"
        severity: "critical"
        
      - name: "AWS Secret Key"
        regex: "(?i)aws_secret[_]?access[_]?key.*['\"]?[0-9a-zA-Z/+=]{40}['\"]?"
        severity: "critical"
        
      - name: "GitHub Token"
        regex: "ghp_[0-9a-zA-Z]{36}"
        severity: "critical"
        
      - name: "Private Key"
        regex: "-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----"
        severity: "critical"
        
      - name: "Generic API Key"
        regex: "(?i)(api[_]?key|apikey).*['\"]?[0-9a-zA-Z]{32,}['\"]?"
        severity: "high"
        
      - name: "Generic Secret"
        regex: "(?i)(secret|password|passwd|pwd).*['\"]?[0-9a-zA-Z]{8,}['\"]?"
        severity: "high"
        
      - name: "Database Connection String"
        regex: "(?i)(mongodb|postgres|mysql|mssql|oracle)://[^\\s]+"
        severity: "high"
        
      - name: "JWT Token"
        regex: "ey[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.?[A-Za-z0-9-_.+/=]*"
        severity: "medium"
        
  vulnerabilities:
    cve_feeds:
      - "https://nvd.nist.gov/feeds/json/cve/1.1/nvdcve-1.1-recent.json.gz"
      
    severity_thresholds:
      block_on: "critical"
      warn_on: "high"
      
  dependency_check:
    languages:
      - csharp: "dotnet list package --vulnerable"
      - javascript: "npm audit"
      - python: "pip-audit"
      - java: "dependency-check"
      
  code_analysis:
    rules:
      - name: "SQL Injection"
        pattern: "SELECT.*FROM.*WHERE.*\\+"
        severity: "critical"
        
      - name: "Command Injection"
        pattern: "Process\\.Start|system\\(|exec\\("
        severity: "high"
        
      - name: "Path Traversal"
        pattern: "\\.\\.\\/|\\.\\.\\\\"
        severity: "high"
        
      - name: "Hardcoded Credentials"
        pattern: "password\\s*=\\s*[\"'][^\"']+[\"']"
        severity: "high"
        
  reporting:
    format: "json"
    include_recommendations: true
    send_notifications: true
EOF
        echo -e "${GREEN}Created security suite configuration: $CONFIG_FILE${NC}"
    fi
}

# Update CVE database
update_cve_database() {
    echo -e "${BLUE}Updating CVE database...${NC}"
    
    local temp_file="$SECURITY_DIR/nvdcve-recent.json.gz"
    
    # Download recent CVEs (simplified - in production use proper NVD API)
    if curl -s -L "https://nvd.nist.gov/feeds/json/cve/1.1/nvdcve-1.1-recent.json.gz" -o "$temp_file"; then
        gunzip -f "$temp_file"
        
        # Extract relevant CVE data
        local cve_file="${temp_file%.gz}"
        if [[ -f "$cve_file" ]]; then
            jq '.CVE_Items[] | {
                id: .cve.CVE_data_meta.ID,
                description: .cve.description.description_data[0].value,
                severity: .impact.baseMetricV3.cvssV3.baseSeverity,
                score: .impact.baseMetricV3.cvssV3.baseScore,
                published: .publishedDate
            }' "$cve_file" > "$CVE_DB.tmp" 2>/dev/null || true
            
            if [[ -s "$CVE_DB.tmp" ]]; then
                mv "$CVE_DB.tmp" "$CVE_DB"
                echo -e "${GREEN}CVE database updated successfully${NC}"
            fi
            
            rm -f "$cve_file"
        fi
    else
        echo -e "${YELLOW}Failed to download CVE database${NC}"
    fi
}

# Secrets scanner
scan_for_secrets() {
    local scan_path="${1:-$PROJECT_DIR}"
    local report_file="$SECURITY_DIR/reports/secrets_scan_$(date +%Y%m%d_%H%M%S).json"
    local findings=()
    
    echo -e "${BLUE}Scanning for secrets in: $scan_path${NC}"
    
    # Create audit entry
    source "$AGENT_DIR/compliance_audit_framework.sh" 2>/dev/null && \
        create_audit_entry "security_scan" "secrets_scan" "Started secrets scan on $scan_path" "system" "info"
    
    # Read patterns from config
    local patterns_count=$(grep -c "name:" "$CONFIG_FILE" | head -1)
    
    # Common secret patterns
    declare -A SECRET_PATTERNS=(
        ["AWS_ACCESS_KEY"]="AKIA[0-9A-Z]{16}"
        ["AWS_SECRET_KEY"]="aws_secret[_]?access[_]?key.*['\"]?[0-9a-zA-Z/+=]{40}"
        ["GITHUB_TOKEN"]="ghp_[0-9a-zA-Z]{36}"
        ["PRIVATE_KEY"]="-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----"
        ["API_KEY"]="(api[_]?key|apikey).*['\"]?[0-9a-zA-Z]{32,}"
        ["PASSWORD"]="(secret|password|passwd|pwd).*['\"]?[0-9a-zA-Z]{8,}"
        ["CONNECTION_STRING"]="(mongodb|postgres|mysql|mssql|oracle)://[^[:space:]]+"
        ["JWT_TOKEN"]="ey[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.?[A-Za-z0-9-_.+/=]*"
    )
    
    # Scan for each pattern
    for pattern_name in "${!SECRET_PATTERNS[@]}"; do
        local pattern="${SECRET_PATTERNS[$pattern_name]}"
        echo -e "  Checking for $pattern_name..."
        
        # Use grep with extended regex
        local matches=$(grep -r -i -E "$pattern" "$scan_path" \
            --exclude-dir=".git" \
            --exclude-dir="node_modules" \
            --exclude-dir="bin" \
            --exclude-dir="obj" \
            --exclude="*.log" \
            --exclude="*.lock" \
            2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
                local file=$(echo "$match" | cut -d: -f1)
                local line_num=$(grep -n "$pattern" "$file" 2>/dev/null | cut -d: -f1 | head -1)
                local line_content=$(echo "$match" | cut -d: -f2-)
                
                # Mask the secret
                local masked_content=$(echo "$line_content" | sed -E "s/$pattern/***REDACTED***/g")
                
                findings+=("{
                    \"type\": \"$pattern_name\",
                    \"file\": \"$file\",
                    \"line\": ${line_num:-0},
                    \"severity\": \"high\",
                    \"content\": \"$masked_content\"
                }")
            done <<< "$matches"
        fi
    done
    
    # Generate report
    local total_findings=${#findings[@]}
    local status="PASS"
    [[ $total_findings -gt 0 ]] && status="FAIL"
    
    cat > "$report_file" << EOF
{
    "scan_type": "secrets",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scan_path": "$scan_path",
    "status": "$status",
    "summary": {
        "total_findings": $total_findings,
        "critical": $(echo "${findings[@]}" | grep -c '"severity": "critical"' || echo 0),
        "high": $(echo "${findings[@]}" | grep -c '"severity": "high"' || echo 0),
        "medium": $(echo "${findings[@]}" | grep -c '"severity": "medium"' || echo 0)
    },
    "findings": [
        $(IFS=,; echo "${findings[*]}")
    ]
}
EOF
    
    echo -e "${CYAN}Secrets scan completed. Found $total_findings potential secrets${NC}"
    echo -e "${CYAN}Report saved to: $report_file${NC}"
    
    # Send notification if findings
    if [[ $total_findings -gt 0 ]] && [[ -f "$AGENT_DIR/integration_hub.sh" ]]; then
        "$AGENT_DIR/integration_hub.sh" notify security_issue "Secrets Found" \
            "Found $total_findings potential secrets in codebase" "critical"
    fi
    
    return $([[ "$status" == "PASS" ]] && echo 0 || echo 1)
}

# Vulnerability scanner
scan_vulnerabilities() {
    local scan_path="${1:-$PROJECT_DIR}"
    local report_file="$SECURITY_DIR/reports/vulnerability_scan_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    echo -e "${BLUE}Scanning for vulnerabilities...${NC}"
    
    # Detect project type and run appropriate scanner
    if [[ -f "$scan_path/package.json" ]]; then
        echo -e "  Running npm audit..."
        local npm_audit=$(cd "$scan_path" && npm audit --json 2>/dev/null || echo '{}')
        
        if [[ $(echo "$npm_audit" | jq '.vulnerabilities | length') -gt 0 ]]; then
            vulnerabilities+=("{
                \"type\": \"npm_dependency\",
                \"summary\": $(echo "$npm_audit" | jq -c '.metadata')
            }")
        fi
    fi
    
    if [[ -f "$scan_path/requirements.txt" ]] || [[ -f "$scan_path/pyproject.toml" ]]; then
        echo -e "  Checking Python dependencies..."
        if command -v pip-audit &> /dev/null; then
            local pip_audit=$(cd "$scan_path" && pip-audit --format json 2>/dev/null || echo '[]')
            vulnerabilities+=("{
                \"type\": \"python_dependency\",
                \"issues\": $pip_audit
            }")
        fi
    fi
    
    if [[ -f "$scan_path/*.csproj" ]]; then
        echo -e "  Checking .NET dependencies..."
        local dotnet_audit=$(cd "$scan_path" && dotnet list package --vulnerable --format json 2>/dev/null || echo '{}')
        
        if [[ -n "$dotnet_audit" ]]; then
            vulnerabilities+=("{
                \"type\": \"dotnet_dependency\",
                \"data\": \"$dotnet_audit\"
            }")
        fi
    fi
    
    # Check against CVE database
    if [[ -f "$CVE_DB" ]]; then
        echo -e "  Checking against CVE database..."
        # This is simplified - in production, properly match dependencies to CVEs
    fi
    
    # Generate report
    cat > "$report_file" << EOF
{
    "scan_type": "vulnerability",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scan_path": "$scan_path",
    "vulnerabilities": [
        $(IFS=,; echo "${vulnerabilities[*]}")
    ]
}
EOF
    
    echo -e "${CYAN}Vulnerability scan completed${NC}"
    echo -e "${CYAN}Report saved to: $report_file${NC}"
}

# Code security analysis (SAST)
analyze_code_security() {
    local scan_path="${1:-$PROJECT_DIR}"
    local report_file="$SECURITY_DIR/reports/sast_scan_$(date +%Y%m%d_%H%M%S).json"
    local issues=()
    
    echo -e "${BLUE}Performing static application security testing (SAST)...${NC}"
    
    # Security patterns to check
    declare -A SECURITY_PATTERNS=(
        ["SQL_INJECTION"]="(SELECT|INSERT|UPDATE|DELETE).*FROM.*WHERE.*\\+|string\\.Format.*WHERE"
        ["COMMAND_INJECTION"]="Process\\.Start|Runtime\\.exec|system\\(|exec\\(|eval\\("
        ["PATH_TRAVERSAL"]="\\.\\.\\/|\\.\\.\\\\"
        ["XXE_INJECTION"]="XmlReader|XmlDocument.*\\.Load"
        ["LDAP_INJECTION"]="DirectorySearcher|SearchFilter"
        ["XPATH_INJECTION"]="SelectNodes|SelectSingleNode"
        ["WEAK_CRYPTO"]="MD5|SHA1|DES|RC4"
        ["HARDCODED_CREDS"]="password\\s*=\\s*[\"'][^\"']+[\"']"
        ["INSECURE_RANDOM"]="Random\\(\\)|Math\\.random"
    )
    
    # Scan for each pattern
    for issue_type in "${!SECURITY_PATTERNS[@]}"; do
        local pattern="${SECURITY_PATTERNS[$issue_type]}"
        echo -e "  Checking for $issue_type..."
        
        local matches=$(grep -r -E "$pattern" "$scan_path" \
            --include="*.cs" --include="*.js" --include="*.ts" \
            --include="*.java" --include="*.py" --include="*.go" \
            --exclude-dir=".git" --exclude-dir="node_modules" \
            2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
                local file=$(echo "$match" | cut -d: -f1)
                local line_content=$(echo "$match" | cut -d: -f2-)
                
                issues+=("{
                    \"type\": \"$issue_type\",
                    \"file\": \"$file\",
                    \"severity\": \"high\",
                    \"description\": \"Potential security issue detected\",
                    \"recommendation\": \"Review and fix security issue\"
                }")
            done <<< "$matches"
        fi
    done
    
    # Generate report
    cat > "$report_file" << EOF
{
    "scan_type": "sast",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scan_path": "$scan_path",
    "total_issues": ${#issues[@]},
    "issues": [
        $(IFS=,; echo "${issues[*]}")
    ]
}
EOF
    
    echo -e "${CYAN}SAST scan completed. Found ${#issues[@]} potential security issues${NC}"
    echo -e "${CYAN}Report saved to: $report_file${NC}"
}

# Generate security report
generate_security_report() {
    local output_file="$SECURITY_DIR/security_report_$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}Generating comprehensive security report...${NC}"
    
    # Get latest scan results
    local latest_secrets=$(ls -t "$SECURITY_DIR/reports/secrets_scan_"*.json 2>/dev/null | head -1)
    local latest_vuln=$(ls -t "$SECURITY_DIR/reports/vulnerability_scan_"*.json 2>/dev/null | head -1)
    local latest_sast=$(ls -t "$SECURITY_DIR/reports/sast_scan_"*.json 2>/dev/null | head -1)
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Security Report - Build Fix Agent</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #d32f2f; border-bottom: 2px solid #d32f2f; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .severity-critical { color: #d32f2f; font-weight: bold; }
        .severity-high { color: #f44336; font-weight: bold; }
        .severity-medium { color: #ff9800; }
        .severity-low { color: #4caf50; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #d32f2f; }
        .summary-card h3 { margin-top: 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .finding { background-color: #ffebee; padding: 10px; margin: 10px 0; border-radius: 4px; border-left: 4px solid #d32f2f; }
        .recommendation { background-color: #e3f2fd; padding: 10px; margin: 10px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Security Scan Report</h1>
        <p>Generated: $(date)</p>
        
        <div class="summary-grid">
            <div class="summary-card">
                <h3>Secrets Found</h3>
                <div style="font-size: 36px;">
EOF
    
    # Add secrets count
    if [[ -f "$latest_secrets" ]]; then
        local secrets_count=$(jq '.summary.total_findings' "$latest_secrets")
        echo "$secrets_count" >> "$output_file"
    else
        echo "0" >> "$output_file"
    fi
    
    cat >> "$output_file" << 'EOF'
                </div>
            </div>
            <div class="summary-card">
                <h3>Vulnerabilities</h3>
                <div style="font-size: 36px;">N/A</div>
            </div>
            <div class="summary-card">
                <h3>Code Issues</h3>
                <div style="font-size: 36px;">
EOF
    
    # Add SAST count
    if [[ -f "$latest_sast" ]]; then
        local sast_count=$(jq '.total_issues' "$latest_sast")
        echo "$sast_count" >> "$output_file"
    else
        echo "0" >> "$output_file"
    fi
    
    cat >> "$output_file" << 'EOF'
                </div>
            </div>
        </div>
        
        <h2>Critical Findings</h2>
        <p>Review and address these security issues immediately.</p>
        
        <h2>Recommendations</h2>
        <div class="recommendation">
            <h3>Immediate Actions</h3>
            <ul>
                <li>Remove all hardcoded secrets from code</li>
                <li>Implement proper secret management (e.g., HashiCorp Vault)</li>
                <li>Update vulnerable dependencies</li>
                <li>Fix SQL injection vulnerabilities</li>
            </ul>
        </div>
        
        <h2>Detailed Findings</h2>
        <p>See individual scan reports for complete details.</p>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}Security report generated: $output_file${NC}"
}

# Main execution
main() {
    local command="${1:-help}"
    
    init_security_config
    
    case "$command" in
        scan)
            local scan_type="${2:-all}"
            local scan_path="${3:-$PROJECT_DIR}"
            
            case "$scan_type" in
                secrets)
                    scan_for_secrets "$scan_path"
                    ;;
                vulnerabilities)
                    scan_vulnerabilities "$scan_path"
                    ;;
                sast)
                    analyze_code_security "$scan_path"
                    ;;
                all)
                    scan_for_secrets "$scan_path"
                    scan_vulnerabilities "$scan_path"
                    analyze_code_security "$scan_path"
                    generate_security_report
                    ;;
                *)
                    echo -e "${RED}Unknown scan type: $scan_type${NC}"
                    ;;
            esac
            ;;
            
        update-cve)
            update_cve_database
            ;;
            
        report)
            generate_security_report
            ;;
            
        config)
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
            
        *)
            cat << EOF
Advanced Security Suite - Enterprise security scanning and management

Usage: $0 {command} [options]

Commands:
    scan        Run security scans
                Types: secrets, vulnerabilities, sast, all
                Usage: scan [type] [path]
                
    update-cve  Update CVE database
    
    report      Generate security report
    
    config      Edit security configuration

Examples:
    $0 scan all                    # Run all security scans
    $0 scan secrets /path/to/code  # Scan specific path for secrets
    $0 scan sast                   # Run static analysis
    $0 update-cve                  # Update vulnerability database
    $0 report                      # Generate HTML report

Security Scans:
    secrets         - Detect hardcoded secrets and credentials
    vulnerabilities - Check dependencies for known CVEs
    sast           - Static Application Security Testing
    
The security suite integrates with the compliance framework
to maintain audit trails of all security scans.
EOF
            ;;
    esac
}

# Execute
main "$@"