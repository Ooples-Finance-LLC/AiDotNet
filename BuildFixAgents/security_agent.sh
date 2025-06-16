#!/bin/bash

# Security Scanning Agent - Detects vulnerabilities, secrets, and security issues
# Scans code, dependencies, and configuration for security problems

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
SECURITY_REPORTS="$AGENT_DIR/state/security_reports"
VULNERABILITIES_DB="$AGENT_DIR/state/vulnerabilities.json"
SECRETS_PATTERNS="$AGENT_DIR/config/secrets_patterns.txt"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Agent ID
AGENT_ID="security_agent_$$"

# Initialize
mkdir -p "$SECURITY_REPORTS"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[$timestamp] SECURITY_AGENT${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/security_agent.log"
}

# Create secrets patterns file
create_secrets_patterns() {
    if [[ ! -f "$SECRETS_PATTERNS" ]]; then
        cat > "$SECRETS_PATTERNS" << 'EOF'
# API Keys and Tokens
(?i)(api[_-]?key|apikey|api[_-]?secret)[\s]*[:=][\s]*['\"]?([a-zA-Z0-9_\-]{20,})['\"]?
(?i)(access[_-]?token|auth[_-]?token|authentication[_-]?token)[\s]*[:=][\s]*['\"]?([a-zA-Z0-9_\-]{20,})['\"]?
(?i)bearer[\s]+([a-zA-Z0-9_\-\.]+)

# Passwords
(?i)(password|passwd|pwd)[\s]*[:=][\s]*['\"]?([^'\"]{8,})['\"]?
(?i)(db[_-]?password|database[_-]?password)[\s]*[:=][\s]*['\"]?([^'\"]+)['\"]?

# Connection Strings
(?i)(connection[_-]?string|conn[_-]?string|database[_-]?url|db[_-]?url)[\s]*[:=][\s]*['\"]?([^'\"]+)['\"]?
(Server|Data Source)=([^;]+);.*(Password|Pwd)=([^;]+)

# AWS
AKIA[0-9A-Z]{16}
(?i)aws[_-]?secret[_-]?access[_-]?key[\s]*[:=][\s]*['\"]?([a-zA-Z0-9/+=]{40})['\"]?

# Azure
(?i)azure[_-]?(storage[_-]?)?account[_-]?key[\s]*[:=][\s]*['\"]?([a-zA-Z0-9+/=]{88})['\"]?
DefaultEndpointsProtocol=https;AccountName=([^;]+);AccountKey=([^;]+);

# Private Keys
-----BEGIN[\s]+(?:RSA|DSA|EC|OPENSSH|PGP)[\s]+PRIVATE[\s]+KEY-----
(?i)private[_-]?key[\s]*[:=][\s]*['\"]?([^'\"]+)['\"]?

# Generic Secrets
(?i)(secret|client[_-]?secret)[\s]*[:=][\s]*['\"]?([a-zA-Z0-9_\-]{16,})['\"]?
(?i)(encryption[_-]?key|signing[_-]?key)[\s]*[:=][\s]*['\"]?([^'\"]+)['\"]?
EOF
    fi
}

# Scan for hardcoded secrets
scan_for_secrets() {
    log_message "Scanning for hardcoded secrets and sensitive data..."
    
    local secrets_found=0
    local report_file="$SECURITY_REPORTS/secrets_scan_$(date +%Y%m%d_%H%M%S).json"
    
    # Start JSON report
    echo "{" > "$report_file"
    echo "  \"scan_type\": \"secrets\"," >> "$report_file"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"findings\": [" >> "$report_file"
    
    local first_finding=true
    
    # Find all code files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Skip binary files
        if ! file "$file" | grep -q "text"; then
            continue
        fi
        
        # Check each pattern
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            [[ "$pattern" =~ ^# ]] && continue
            
            # Search for pattern in file
            if grep -Hn -E "$pattern" "$file" 2>/dev/null; then
                local line_numbers=$(grep -n -E "$pattern" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')
                line_numbers=${line_numbers%,}
                
                # Add to report
                if [[ "$first_finding" != "true" ]]; then
                    echo "," >> "$report_file"
                fi
                first_finding=false
                
                cat >> "$report_file" << EOF
    {
      "file": "$file",
      "type": "hardcoded_secret",
      "severity": "high",
      "lines": [$line_numbers],
      "pattern": "$(echo "$pattern" | head -1 | cut -c1-50)...",
      "recommendation": "Remove hardcoded secret and use environment variables or secure configuration"
    }
EOF
                
                ((secrets_found++))
                log_message "  ⚠️  Found potential secret in: $file" "WARN"
            fi
        done < "$SECRETS_PATTERNS"
    done < <(find "$PROJECT_DIR" -type f \( -name "*.cs" -o -name "*.config" -o -name "*.json" -o -name "*.xml" -o -name "*.yml" -o -name "*.yaml" \) ! -path "*/bin/*" ! -path "*/obj/*" ! -path "*/node_modules/*" ! -path "*/.git/*")
    
    # Close JSON
    echo "" >> "$report_file"
    echo "  ]," >> "$report_file"
    echo "  \"total_findings\": $secrets_found" >> "$report_file"
    echo "}" >> "$report_file"
    
    if [[ $secrets_found -gt 0 ]]; then
        log_message "Found $secrets_found potential secrets!" "ERROR"
    else
        log_message "No hardcoded secrets detected" "SUCCESS"
    fi
    
    return $secrets_found
}

# Scan dependencies for vulnerabilities
scan_dependencies() {
    log_message "Scanning dependencies for known vulnerabilities..."
    
    local vuln_count=0
    local report_file="$SECURITY_REPORTS/dependency_scan_$(date +%Y%m%d_%H%M%S).json"
    
    # Start report
    echo "{" > "$report_file"
    echo "  \"scan_type\": \"dependencies\"," >> "$report_file"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"vulnerabilities\": [" >> "$report_file"
    
    # Check for vulnerable NuGet packages
    local vulnerable_packages=(
        "Newtonsoft.Json:9.0.1:CVE-2021-42240:High"
        "System.Text.RegularExpressions:4.3.0:CVE-2019-0820:High"
        "System.Net.Http:4.3.0:CVE-2018-8292:Medium"
        "Microsoft.AspNetCore.All:2.0.0:CVE-2018-0784:High"
        "jQuery:1.9.0:CVE-2019-11358:Medium"
        "bootstrap:3.3.7:CVE-2019-8331:Medium"
        "log4net:1.2.10:CVE-2018-1285:Critical"
    )
    
    # Find all project files
    local first_vuln=true
    while IFS= read -r proj_file; do
        [[ -z "$proj_file" ]] && continue
        
        log_message "  Checking: $proj_file"
        
        for vuln_entry in "${vulnerable_packages[@]}"; do
            IFS=':' read -r package version cve severity <<< "$vuln_entry"
            
            # Check if vulnerable package is referenced
            if grep -i "$package" "$proj_file" | grep -E "Version=\"?$version\"?" >/dev/null 2>&1; then
                ((vuln_count++))
                
                if [[ "$first_vuln" != "true" ]]; then
                    echo "," >> "$report_file"
                fi
                first_vuln=false
                
                cat >> "$report_file" << EOF
    {
      "file": "$proj_file",
      "package": "$package",
      "version": "$version",
      "cve": "$cve",
      "severity": "$severity",
      "recommendation": "Update to latest secure version"
    }
EOF
                
                log_message "  ⚠️  Vulnerable package found: $package $version ($cve)" "WARN"
            fi
        done
    done < <(find "$PROJECT_DIR" -name "*.csproj" -o -name "packages.config")
    
    echo "" >> "$report_file"
    echo "  ]," >> "$report_file"
    echo "  \"total_vulnerabilities\": $vuln_count" >> "$report_file"
    echo "}" >> "$report_file"
    
    if [[ $vuln_count -gt 0 ]]; then
        log_message "Found $vuln_count vulnerable dependencies!" "ERROR"
    else
        log_message "No vulnerable dependencies detected" "SUCCESS"
    fi
    
    return $vuln_count
}

# Scan for insecure code patterns
scan_code_patterns() {
    log_message "Scanning for insecure code patterns..."
    
    local issues_found=0
    local report_file="$SECURITY_REPORTS/code_patterns_$(date +%Y%m%d_%H%M%S).json"
    
    # Define insecure patterns
    declare -A insecure_patterns=(
        ["SQL_INJECTION"]="(SqlCommand|SqlDataAdapter|SqlConnection).*\\+.*\\b(Request|QueryString|Form|Cookies|Session)\\b"
        ["COMMAND_INJECTION"]="Process\\.Start.*\\+.*\\b(Request|QueryString|Form|input)\\b"
        ["PATH_TRAVERSAL"]="\\.\\.\\\\\|\\.\\.\/"
        ["WEAK_CRYPTO"]="(MD5|SHA1|DES|RC2)CryptoServiceProvider"
        ["HARDCODED_CERT"]="X509Certificate.*\\(.*\".*\".*\\)"
        ["UNSAFE_DESERIALIZATION"]="BinaryFormatter|NetDataContractSerializer|SoapFormatter"
        ["MISSING_VALIDATION"]="Request\\.(QueryString|Form|Cookies)\\[[^]]+\\](?!.*Validate)"
        ["WEAK_RANDOM"]="Random\\(\\)|System\\.Random"
        ["CLEAR_TEXT_PASSWORD"]="[Pp]assword.*=.*\"[^\"]+\""
        ["NO_HTTPS"]="http://(?!localhost|127\\.0\\.0\\.1)"
    )
    
    # Start report
    echo "{" > "$report_file"
    echo "  \"scan_type\": \"code_patterns\"," >> "$report_file"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"findings\": [" >> "$report_file"
    
    local first_finding=true
    
    # Scan each C# file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        for pattern_name in "${!insecure_patterns[@]}"; do
            local pattern="${insecure_patterns[$pattern_name]}"
            
            if grep -Hn -E "$pattern" "$file" 2>/dev/null; then
                local line_numbers=$(grep -n -E "$pattern" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')
                line_numbers=${line_numbers%,}
                
                if [[ "$first_finding" != "true" ]]; then
                    echo "," >> "$report_file"
                fi
                first_finding=false
                
                local severity="high"
                [[ "$pattern_name" =~ WEAK_RANDOM|NO_HTTPS ]] && severity="medium"
                [[ "$pattern_name" =~ SQL_INJECTION|COMMAND_INJECTION|UNSAFE_DESERIALIZATION ]] && severity="critical"
                
                cat >> "$report_file" << EOF
    {
      "file": "$file",
      "issue": "$pattern_name",
      "severity": "$severity",
      "lines": [$line_numbers],
      "description": "$(get_issue_description "$pattern_name")",
      "recommendation": "$(get_issue_recommendation "$pattern_name")"
    }
EOF
                
                ((issues_found++))
                log_message "  ⚠️  Found $pattern_name in: $file" "WARN"
            fi
        done
    done < <(find "$PROJECT_DIR" -name "*.cs" ! -path "*/bin/*" ! -path "*/obj/*")
    
    echo "" >> "$report_file"
    echo "  ]," >> "$report_file"
    echo "  \"total_findings\": $issues_found" >> "$report_file"
    echo "}" >> "$report_file"
    
    if [[ $issues_found -gt 0 ]]; then
        log_message "Found $issues_found insecure code patterns!" "ERROR"
    else
        log_message "No insecure code patterns detected" "SUCCESS"
    fi
    
    return $issues_found
}

# Get issue description
get_issue_description() {
    local issue="$1"
    
    case "$issue" in
        "SQL_INJECTION") echo "Potential SQL injection vulnerability from string concatenation" ;;
        "COMMAND_INJECTION") echo "Potential command injection vulnerability" ;;
        "PATH_TRAVERSAL") echo "Potential path traversal vulnerability" ;;
        "WEAK_CRYPTO") echo "Use of weak cryptographic algorithm" ;;
        "HARDCODED_CERT") echo "Hardcoded certificate detected" ;;
        "UNSAFE_DESERIALIZATION") echo "Use of unsafe deserialization method" ;;
        "MISSING_VALIDATION") echo "User input used without validation" ;;
        "WEAK_RANDOM") echo "Use of weak random number generator" ;;
        "CLEAR_TEXT_PASSWORD") echo "Password stored in clear text" ;;
        "NO_HTTPS") echo "Use of unencrypted HTTP connection" ;;
        *) echo "Security issue detected" ;;
    esac
}

# Get issue recommendation
get_issue_recommendation() {
    local issue="$1"
    
    case "$issue" in
        "SQL_INJECTION") echo "Use parameterized queries or stored procedures" ;;
        "COMMAND_INJECTION") echo "Validate and sanitize all user input before use in system commands" ;;
        "PATH_TRAVERSAL") echo "Validate file paths and use Path.Combine() method" ;;
        "WEAK_CRYPTO") echo "Use SHA256 or stronger cryptographic algorithms" ;;
        "HARDCODED_CERT") echo "Load certificates from secure configuration or certificate store" ;;
        "UNSAFE_DESERIALIZATION") echo "Use safe serialization formats like JSON with type validation" ;;
        "MISSING_VALIDATION") echo "Always validate and sanitize user input" ;;
        "WEAK_RANDOM") echo "Use System.Security.Cryptography.RandomNumberGenerator for security-sensitive operations" ;;
        "CLEAR_TEXT_PASSWORD") echo "Hash passwords using bcrypt, scrypt, or Argon2" ;;
        "NO_HTTPS") echo "Use HTTPS for all external connections" ;;
        *) echo "Review and fix the security issue" ;;
    esac
}

# Check file permissions
check_file_permissions() {
    log_message "Checking file permissions..."
    
    local permission_issues=0
    local report_file="$SECURITY_REPORTS/permissions_$(date +%Y%m%d_%H%M%S).json"
    
    # Start report
    echo "{" > "$report_file"
    echo "  \"scan_type\": \"permissions\"," >> "$report_file"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"findings\": [" >> "$report_file"
    
    local first_finding=true
    
    # Check for world-writable files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        if [[ "$first_finding" != "true" ]]; then
            echo "," >> "$report_file"
        fi
        first_finding=false
        
        cat >> "$report_file" << EOF
    {
      "file": "$file",
      "issue": "WORLD_WRITABLE",
      "permissions": "$(stat -c %a "$file" 2>/dev/null || echo "unknown")",
      "severity": "medium",
      "recommendation": "Remove world-write permission: chmod o-w \"$file\""
    }
EOF
        
        ((permission_issues++))
        log_message "  ⚠️  World-writable file: $file" "WARN"
    done < <(find "$PROJECT_DIR" -type f -perm -002 ! -path "*/bin/*" ! -path "*/obj/*" ! -path "*/.git/*" 2>/dev/null)
    
    echo "" >> "$report_file"
    echo "  ]," >> "$report_file"
    echo "  \"total_findings\": $permission_issues" >> "$report_file"
    echo "}" >> "$report_file"
    
    return $permission_issues
}

# Scan configuration files
scan_configurations() {
    log_message "Scanning configuration files..."
    
    local config_issues=0
    local report_file="$SECURITY_REPORTS/config_scan_$(date +%Y%m%d_%H%M%S).json"
    
    # Start report
    echo "{" > "$report_file"
    echo "  \"scan_type\": \"configuration\"," >> "$report_file"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$report_file"
    echo "  \"findings\": [" >> "$report_file"
    
    local first_finding=true
    
    # Check web.config / app.config
    while IFS= read -r config_file; do
        [[ -z "$config_file" ]] && continue
        
        # Check for debug mode enabled
        if grep -i "debug=\"true\"" "$config_file" >/dev/null 2>&1; then
            if [[ "$first_finding" != "true" ]]; then
                echo "," >> "$report_file"
            fi
            first_finding=false
            
            cat >> "$report_file" << EOF
    {
      "file": "$config_file",
      "issue": "DEBUG_ENABLED",
      "severity": "medium",
      "description": "Debug mode is enabled in production configuration",
      "recommendation": "Set debug=\"false\" for production deployments"
    }
EOF
            
            ((config_issues++))
            log_message "  ⚠️  Debug mode enabled in: $config_file" "WARN"
        fi
        
        # Check for custom errors disabled
        if grep -i "customErrors.*mode=\"Off\"" "$config_file" >/dev/null 2>&1; then
            if [[ "$first_finding" != "true" ]]; then
                echo "," >> "$report_file"
            fi
            first_finding=false
            
            cat >> "$report_file" << EOF
    {
      "file": "$config_file",
      "issue": "CUSTOM_ERRORS_OFF",
      "severity": "medium",
      "description": "Custom errors are disabled, may expose sensitive information",
      "recommendation": "Set customErrors mode=\"On\" or \"RemoteOnly\""
    }
EOF
            
            ((config_issues++))
            log_message "  ⚠️  Custom errors disabled in: $config_file" "WARN"
        fi
        
        # Check for request validation disabled
        if grep -i "validateRequest=\"false\"" "$config_file" >/dev/null 2>&1; then
            if [[ "$first_finding" != "true" ]]; then
                echo "," >> "$report_file"
            fi
            first_finding=false
            
            cat >> "$report_file" << EOF
    {
      "file": "$config_file",
      "issue": "REQUEST_VALIDATION_OFF",
      "severity": "high",
      "description": "Request validation is disabled",
      "recommendation": "Enable request validation unless absolutely necessary"
    }
EOF
            
            ((config_issues++))
            log_message "  ⚠️  Request validation disabled in: $config_file" "WARN"
        fi
    done < <(find "$PROJECT_DIR" -name "web.config" -o -name "app.config" ! -path "*/bin/*" ! -path "*/obj/*")
    
    echo "" >> "$report_file"
    echo "  ]," >> "$report_file"
    echo "  \"total_findings\": $config_issues" >> "$report_file"
    echo "}" >> "$report_file"
    
    return $config_issues
}

# Generate security report
generate_security_report() {
    local total_issues="$1"
    local report_file="$SECURITY_REPORTS/security_summary_$(date +%Y%m%d_%H%M%S).md"
    
    log_message "Generating security summary report..."
    
    cat > "$report_file" << EOF
# Security Scan Report
Date: $(date)
Project: $PROJECT_DIR

## Summary
Total security issues found: **$total_issues**

## Scan Results

### 1. Secrets Detection
$(grep -h "total_findings" "$SECURITY_REPORTS"/secrets_scan_*.json 2>/dev/null | tail -1 || echo "Not scanned")

### 2. Dependency Vulnerabilities  
$(grep -h "total_vulnerabilities" "$SECURITY_REPORTS"/dependency_scan_*.json 2>/dev/null | tail -1 || echo "Not scanned")

### 3. Insecure Code Patterns
$(grep -h "total_findings" "$SECURITY_REPORTS"/code_patterns_*.json 2>/dev/null | tail -1 || echo "Not scanned")

### 4. File Permissions
$(grep -h "total_findings" "$SECURITY_REPORTS"/permissions_*.json 2>/dev/null | tail -1 || echo "Not scanned")

### 5. Configuration Issues
$(grep -h "total_findings" "$SECURITY_REPORTS"/config_scan_*.json 2>/dev/null | tail -1 || echo "Not scanned")

## Recommendations

### Immediate Actions Required
1. Remove all hardcoded secrets and use environment variables
2. Update vulnerable dependencies to secure versions
3. Fix SQL injection and command injection vulnerabilities
4. Enable HTTPS for all external connections
5. Disable debug mode in production configurations

### Best Practices
- Implement input validation for all user inputs
- Use parameterized queries for database operations
- Store passwords using strong hashing algorithms
- Regular security scans and dependency updates
- Security training for development team

## Compliance Status
- [ ] OWASP Top 10 compliance check
- [ ] CWE/SANS Top 25 review
- [ ] Industry-specific compliance (PCI-DSS, HIPAA, etc.)

---
*Generated by Security Agent v1.0*
EOF
    
    log_message "Security report generated: $report_file"
    
    # Also create a JSON summary
    local json_summary="$SECURITY_REPORTS/security_summary_$(date +%Y%m%d_%H%M%S).json"
    cat > "$json_summary" << EOF
{
  "scan_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "$PROJECT_DIR",
  "total_issues": $total_issues,
  "severity_breakdown": {
    "critical": $(grep -h "\"severity\": \"critical\"" "$SECURITY_REPORTS"/*.json 2>/dev/null | wc -l || echo 0),
    "high": $(grep -h "\"severity\": \"high\"" "$SECURITY_REPORTS"/*.json 2>/dev/null | wc -l || echo 0),
    "medium": $(grep -h "\"severity\": \"medium\"" "$SECURITY_REPORTS"/*.json 2>/dev/null | wc -l || echo 0),
    "low": $(grep -h "\"severity\": \"low\"" "$SECURITY_REPORTS"/*.json 2>/dev/null | wc -l || echo 0)
  },
  "scan_status": "completed",
  "reports": [
    $(ls -1 "$SECURITY_REPORTS"/*.json 2>/dev/null | sed 's/^/    "/' | sed 's/$/"/' | tr '\n' ',' | sed 's/,$//')
  ]
}
EOF
}

# Suggest fixes for common issues
suggest_fixes() {
    local issue_type="$1"
    local file="$2"
    
    case "$issue_type" in
        "SQL_INJECTION")
            cat << 'EOF'
// Instead of:
string query = "SELECT * FROM Users WHERE Id = " + userId;

// Use parameterized query:
string query = "SELECT * FROM Users WHERE Id = @UserId";
using (var command = new SqlCommand(query, connection))
{
    command.Parameters.AddWithValue("@UserId", userId);
    // Execute query
}
EOF
            ;;
            
        "WEAK_CRYPTO")
            cat << 'EOF'
// Instead of MD5 or SHA1:
// var hash = MD5.Create().ComputeHash(data);

// Use SHA256 or stronger:
using (var sha256 = SHA256.Create())
{
    var hash = sha256.ComputeHash(data);
}
EOF
            ;;
            
        "WEAK_RANDOM")
            cat << 'EOF'
// Instead of System.Random:
// var random = new Random();

// Use cryptographically secure random:
using (var rng = RandomNumberGenerator.Create())
{
    var bytes = new byte[32];
    rng.GetBytes(bytes);
}
EOF
            ;;
    esac
}

# Main security scan workflow
main() {
    log_message "=== SECURITY AGENT STARTING ==="
    
    # Initialize
    create_secrets_patterns
    
    # Track total issues
    local total_issues=0
    
    # Run all security scans
    log_message "Starting comprehensive security scan..."
    
    # 1. Scan for secrets
    if ! scan_for_secrets; then
        total_issues=$((total_issues + $?))
    fi
    
    # 2. Scan dependencies
    if ! scan_dependencies; then
        total_issues=$((total_issues + $?))
    fi
    
    # 3. Scan code patterns
    if ! scan_code_patterns; then
        total_issues=$((total_issues + $?))
    fi
    
    # 4. Check permissions (Unix/Linux only)
    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
        if ! check_file_permissions; then
            total_issues=$((total_issues + $?))
        fi
    fi
    
    # 5. Scan configurations
    if ! scan_configurations; then
        total_issues=$((total_issues + $?))
    fi
    
    # Generate summary report
    generate_security_report "$total_issues"
    
    # Display summary
    if [[ $total_issues -gt 0 ]]; then
        log_message "=== SECURITY SCAN COMPLETE ===" "WARN"
        log_message "Found $total_issues total security issues!" "ERROR"
        log_message "Review reports in: $SECURITY_REPORTS" "WARN"
        
        # Set exit code for CI/CD integration
        exit 1
    else
        log_message "=== SECURITY SCAN COMPLETE ===" "SUCCESS"
        log_message "No security issues found!" "SUCCESS"
        exit 0
    fi
}

# Execute
main "$@"