#!/bin/bash

# Compliance & Audit Framework - Enterprise-grade audit trail and compliance checking
# Supports GDPR, HIPAA, SOC2, ISO 27001, and custom compliance standards

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_DIR="$AGENT_DIR/state/audit"
COMPLIANCE_DIR="$AGENT_DIR/state/compliance"
CONFIG_FILE="$AGENT_DIR/config/compliance.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create directories
mkdir -p "$AUDIT_DIR" "$COMPLIANCE_DIR" "$(dirname "$CONFIG_FILE")"

# Initialize compliance configuration
init_compliance_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Compliance & Audit Configuration
compliance:
  standards:
    - name: "GDPR"
      enabled: true
      checks:
        - personal_data_protection
        - data_retention_policy
        - user_consent_tracking
        
    - name: "HIPAA"
      enabled: false
      checks:
        - phi_encryption
        - access_controls
        - audit_logging
        
    - name: "SOC2"
      enabled: true
      checks:
        - security_controls
        - availability_monitoring
        - confidentiality_measures
        
    - name: "ISO27001"
      enabled: false
      checks:
        - risk_assessment
        - security_policies
        - incident_management

audit:
  retention_days: 365
  encrypt_logs: true
  sign_logs: true
  
  events_to_audit:
    - code_changes
    - error_fixes
    - security_scans
    - config_changes
    - user_actions
    - api_calls
    
approval_workflow:
  enabled: true
  required_for:
    - production_deployment
    - security_fixes
    - config_changes
    
  approvers:
    - role: "lead_developer"
      email: "lead@company.com"
    - role: "security_officer"
      email: "security@company.com"
EOF
        echo -e "${GREEN}Created default compliance config: $CONFIG_FILE${NC}"
    fi
}

# Audit trail functions
create_audit_entry() {
    local event_type="$1"
    local action="$2"
    local details="$3"
    local user="${4:-system}"
    local severity="${5:-info}"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    local audit_id=$(uuidgen 2>/dev/null || echo "$(date +%s)-$$-$RANDOM")
    local audit_file="$AUDIT_DIR/$(date +%Y/%m/%d)/audit_log.jsonl"
    
    mkdir -p "$(dirname "$audit_file")"
    
    # Create audit entry
    local audit_entry=$(jq -n \
        --arg id "$audit_id" \
        --arg timestamp "$timestamp" \
        --arg event "$event_type" \
        --arg action "$action" \
        --arg details "$details" \
        --arg user "$user" \
        --arg severity "$severity" \
        --arg host "$(hostname)" \
        --arg ip "$(hostname -I | awk '{print $1}')" \
        '{
            id: $id,
            timestamp: $timestamp,
            event_type: $event,
            action: $action,
            details: $details,
            user: $user,
            severity: $severity,
            environment: {
                host: $host,
                ip: $ip,
                pid: env.PPID,
                working_dir: env.PWD
            }
        }')
    
    # Sign the entry if enabled
    if grep -q "sign_logs: true" "$CONFIG_FILE" 2>/dev/null; then
        local signature=$(echo "$audit_entry" | sha256sum | cut -d' ' -f1)
        audit_entry=$(echo "$audit_entry" | jq --arg sig "$signature" '. + {signature: $sig}')
    fi
    
    # Append to audit log
    echo "$audit_entry" >> "$audit_file"
    
    # Also save to daily summary
    local summary_file="$AUDIT_DIR/$(date +%Y/%m/%d)/summary.json"
    if [[ ! -f "$summary_file" ]]; then
        echo '{"date":"'$(date +%Y-%m-%d)'","events":[]}' > "$summary_file"
    fi
    
    # Update summary
    jq --argjson entry "$audit_entry" '.events += [$entry]' "$summary_file" > "$summary_file.tmp" && \
        mv "$summary_file.tmp" "$summary_file"
    
    echo "$audit_id"
}

# Compliance checking functions
check_gdpr_compliance() {
    local report_file="$COMPLIANCE_DIR/gdpr_report_$(date +%Y%m%d_%H%M%S).json"
    local issues=()
    local passed=0
    local failed=0
    
    echo -e "${BLUE}Checking GDPR compliance...${NC}"
    
    # Check for personal data in code
    echo -e "  Checking for personal data exposure..."
    local pii_patterns="email|phone|ssn|social.?security|credit.?card|password"
    local pii_files=$(grep -r -i -E "$pii_patterns" "$PROJECT_DIR" --include="*.cs" --include="*.js" --include="*.py" 2>/dev/null | head -20)
    
    if [[ -n "$pii_files" ]]; then
        issues+=("Found potential PII in code files")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Check for encryption
    echo -e "  Checking encryption practices..."
    local unencrypted=$(grep -r -i "password\s*=\s*[\"'][^\"']+[\"']" "$PROJECT_DIR" --include="*.config" --include="*.json" 2>/dev/null || true)
    
    if [[ -n "$unencrypted" ]]; then
        issues+=("Found unencrypted passwords in configuration")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Check data retention
    echo -e "  Checking data retention policies..."
    if [[ ! -f "$PROJECT_DIR/data_retention_policy.md" ]]; then
        issues+=("Missing data retention policy documentation")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Generate report
    local compliance_status="PASS"
    [[ ${#issues[@]} -gt 0 ]] && compliance_status="FAIL"
    
    jq -n \
        --arg status "$compliance_status" \
        --arg standard "GDPR" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)" \
        '{
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            standard: $standard,
            status: $status,
            summary: {
                passed: $passed,
                failed: $failed,
                total: ($passed + $failed)
            },
            issues: $issues
        }' > "$report_file"
    
    echo -e "${CYAN}GDPR compliance check completed. Report: $report_file${NC}"
    echo "$compliance_status"
}

check_soc2_compliance() {
    local report_file="$COMPLIANCE_DIR/soc2_report_$(date +%Y%m%d_%H%M%S).json"
    local issues=()
    local passed=0
    local failed=0
    
    echo -e "${BLUE}Checking SOC2 compliance...${NC}"
    
    # Check security controls
    echo -e "  Checking security controls..."
    if [[ ! -f "$AGENT_DIR/security_agent.sh" ]] || [[ ! -x "$AGENT_DIR/security_agent.sh" ]]; then
        issues+=("Security scanning not properly configured")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Check audit logging
    echo -e "  Checking audit logging..."
    local audit_files=$(find "$AUDIT_DIR" -name "*.jsonl" -mtime -7 | wc -l)
    if [[ $audit_files -eq 0 ]]; then
        issues+=("No recent audit logs found")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Check access controls
    echo -e "  Checking access controls..."
    if [[ ! -f "$AGENT_DIR/config/access_control.yml" ]]; then
        issues+=("Missing access control configuration")
        ((failed++))
    else
        ((passed++))
    fi
    
    # Generate report
    local compliance_status="PASS"
    [[ ${#issues[@]} -gt 0 ]] && compliance_status="FAIL"
    
    jq -n \
        --arg status "$compliance_status" \
        --arg standard "SOC2" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)" \
        '{
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            standard: $standard,
            status: $status,
            summary: {
                passed: $passed,
                failed: $failed,
                total: ($passed + $failed)
            },
            issues: $issues
        }' > "$report_file"
    
    echo -e "${CYAN}SOC2 compliance check completed. Report: $report_file${NC}"
    echo "$compliance_status"
}

# Approval workflow
create_approval_request() {
    local change_type="$1"
    local description="$2"
    local requester="${3:-system}"
    
    local request_id=$(uuidgen 2>/dev/null || echo "$(date +%s)-$$-$RANDOM")
    local request_file="$COMPLIANCE_DIR/approvals/pending/${request_id}.json"
    
    mkdir -p "$(dirname "$request_file")"
    
    jq -n \
        --arg id "$request_id" \
        --arg type "$change_type" \
        --arg desc "$description" \
        --arg requester "$requester" \
        '{
            id: $id,
            type: $type,
            description: $desc,
            requester: $requester,
            status: "pending",
            created_at: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            approvals: [],
            required_approvals: 2
        }' > "$request_file"
    
    # Create audit entry
    create_audit_entry "approval_request" "create" "Created approval request for $change_type" "$requester" "info"
    
    echo -e "${GREEN}Created approval request: $request_id${NC}"
    echo "$request_id"
}

approve_request() {
    local request_id="$1"
    local approver="$2"
    local comments="${3:-}"
    
    local request_file="$COMPLIANCE_DIR/approvals/pending/${request_id}.json"
    
    if [[ ! -f "$request_file" ]]; then
        echo -e "${RED}Approval request not found: $request_id${NC}"
        return 1
    fi
    
    # Add approval
    local updated=$(jq \
        --arg approver "$approver" \
        --arg comments "$comments" \
        '.approvals += [{
            approver: $approver,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            comments: $comments
        }]' "$request_file")
    
    # Check if enough approvals
    local approval_count=$(echo "$updated" | jq '.approvals | length')
    local required=$(echo "$updated" | jq '.required_approvals')
    
    if [[ $approval_count -ge $required ]]; then
        updated=$(echo "$updated" | jq '.status = "approved"')
        echo "$updated" > "$request_file"
        
        # Move to approved
        mv "$request_file" "$COMPLIANCE_DIR/approvals/approved/${request_id}.json"
        
        echo -e "${GREEN}Request approved!${NC}"
        create_audit_entry "approval" "approve" "Request $request_id approved" "$approver" "info"
    else
        echo "$updated" > "$request_file"
        echo -e "${YELLOW}Approval recorded. Need $((required - approval_count)) more approvals.${NC}"
    fi
}

# Generate compliance report
generate_compliance_report() {
    local report_type="${1:-full}"
    local output_file="$COMPLIANCE_DIR/compliance_report_$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}Generating compliance report...${NC}"
    
    # Run all compliance checks
    local gdpr_status="N/A"
    local soc2_status="N/A"
    
    if grep -q "GDPR.*enabled: true" "$CONFIG_FILE" 2>/dev/null; then
        gdpr_status=$(check_gdpr_compliance | tail -1)
    fi
    
    if grep -q "SOC2.*enabled: true" "$CONFIG_FILE" 2>/dev/null; then
        soc2_status=$(check_soc2_compliance | tail -1)
    fi
    
    # Generate HTML report
    cat > "$output_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .status { padding: 5px 10px; border-radius: 4px; font-weight: bold; }
        .pass { background-color: #4CAF50; color: white; }
        .fail { background-color: #f44336; color: white; }
        .na { background-color: #9e9e9e; color: white; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .summary-card h3 { margin-top: 0; color: #555; }
        .summary-card .number { font-size: 36px; font-weight: bold; color: #4CAF50; }
        .issues { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 10px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Compliance & Audit Report</h1>
        <p>Generated: $(date)</p>
        <p>System: Build Fix Agent Enterprise</p>
        
        <h2>Compliance Summary</h2>
        <table>
            <tr>
                <th>Standard</th>
                <th>Status</th>
                <th>Last Checked</th>
            </tr>
            <tr>
                <td>GDPR</td>
                <td><span class="status $(echo $gdpr_status | tr '[:upper:]' '[:lower:]')">$gdpr_status</span></td>
                <td>$(date)</td>
            </tr>
            <tr>
                <td>SOC2</td>
                <td><span class="status $(echo $soc2_status | tr '[:upper:]' '[:lower:]')">$soc2_status</span></td>
                <td>$(date)</td>
            </tr>
            <tr>
                <td>HIPAA</td>
                <td><span class="status na">N/A</span></td>
                <td>Not enabled</td>
            </tr>
            <tr>
                <td>ISO 27001</td>
                <td><span class="status na">N/A</span></td>
                <td>Not enabled</td>
            </tr>
        </table>
        
        <h2>Audit Statistics</h2>
        <div class="summary-grid">
            <div class="summary-card">
                <h3>Total Audit Events</h3>
                <div class="number">$(find "$AUDIT_DIR" -name "*.jsonl" -exec wc -l {} + 2>/dev/null | awk '{sum += $1} END {print sum}' || echo 0)</div>
            </div>
            <div class="summary-card">
                <h3>Events Today</h3>
                <div class="number">$(find "$AUDIT_DIR/$(date +%Y/%m/%d)" -name "*.jsonl" -exec wc -l {} + 2>/dev/null | awk '{sum += $1} END {print sum}' || echo 0)</div>
            </div>
            <div class="summary-card">
                <h3>Pending Approvals</h3>
                <div class="number">$(find "$COMPLIANCE_DIR/approvals/pending" -name "*.json" 2>/dev/null | wc -l || echo 0)</div>
            </div>
        </div>
        
        <h2>Recent Compliance Issues</h2>
        <div class="issues">
            <p>Check individual compliance reports for detailed issues.</p>
        </div>
        
        <h2>Recent Audit Events</h2>
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Event Type</th>
                <th>Action</th>
                <th>User</th>
                <th>Severity</th>
            </tr>
EOF

    # Add recent audit events
    if [[ -f "$AUDIT_DIR/$(date +%Y/%m/%d)/audit_log.jsonl" ]]; then
        tail -10 "$AUDIT_DIR/$(date +%Y/%m/%d)/audit_log.jsonl" | while read -r line; do
            local timestamp=$(echo "$line" | jq -r '.timestamp')
            local event_type=$(echo "$line" | jq -r '.event_type')
            local action=$(echo "$line" | jq -r '.action')
            local user=$(echo "$line" | jq -r '.user')
            local severity=$(echo "$line" | jq -r '.severity')
            
            cat >> "$output_file" << EOF
            <tr>
                <td>$timestamp</td>
                <td>$event_type</td>
                <td>$action</td>
                <td>$user</td>
                <td>$severity</td>
            </tr>
EOF
        done
    fi
    
    cat >> "$output_file" << EOF
        </table>
        
        <div class="footer">
            <p>This report is confidential and should be handled according to your organization's data classification policies.</p>
            <p>Build Fix Agent Enterprise - Compliance & Audit Framework v1.0</p>
        </div>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}Compliance report generated: $output_file${NC}"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    init_compliance_config
    
    case "$command" in
        audit)
            local event_type="${2:-general}"
            local action="${3:-action}"
            local details="${4:-No details provided}"
            local user="${5:-system}"
            local severity="${6:-info}"
            
            local audit_id=$(create_audit_entry "$event_type" "$action" "$details" "$user" "$severity")
            echo -e "${GREEN}Audit entry created: $audit_id${NC}"
            ;;
            
        check)
            local standard="${2:-all}"
            case "$standard" in
                gdpr|GDPR)
                    check_gdpr_compliance
                    ;;
                soc2|SOC2)
                    check_soc2_compliance
                    ;;
                all)
                    check_gdpr_compliance
                    check_soc2_compliance
                    ;;
                *)
                    echo -e "${RED}Unknown compliance standard: $standard${NC}"
                    ;;
            esac
            ;;
            
        request)
            local change_type="${2:-change}"
            local description="${3:-No description}"
            local requester="${4:-system}"
            
            create_approval_request "$change_type" "$description" "$requester"
            ;;
            
        approve)
            local request_id="${2:-}"
            local approver="${3:-}"
            local comments="${4:-}"
            
            if [[ -z "$request_id" ]] || [[ -z "$approver" ]]; then
                echo "Usage: $0 approve <request_id> <approver> [comments]"
                exit 1
            fi
            
            approve_request "$request_id" "$approver" "$comments"
            ;;
            
        report)
            generate_compliance_report "${2:-full}"
            ;;
            
        search)
            local search_term="${2:-}"
            if [[ -z "$search_term" ]]; then
                echo "Usage: $0 search <term>"
                exit 1
            fi
            
            echo -e "${BLUE}Searching audit logs for: $search_term${NC}"
            grep -r "$search_term" "$AUDIT_DIR" --include="*.jsonl" || echo "No matches found"
            ;;
            
        config)
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
            
        *)
            cat << EOF
Compliance & Audit Framework - Enterprise compliance and audit trail management

Usage: $0 {command} [options]

Commands:
    audit       Create audit entry
                Usage: audit <event_type> <action> <details> [user] [severity]
                
    check       Run compliance checks
                Usage: check {gdpr|soc2|all}
                
    request     Create approval request
                Usage: request <change_type> <description> [requester]
                
    approve     Approve a request
                Usage: approve <request_id> <approver> [comments]
                
    report      Generate compliance report
                Usage: report [full|summary]
                
    search      Search audit logs
                Usage: search <term>
                
    config      Edit compliance configuration

Event Types:
    code_changes     Code modifications
    error_fixes      Error corrections
    security_scans   Security scan results
    config_changes   Configuration updates
    user_actions     User activities
    api_calls        API usage

Severity Levels:
    info        Informational
    warning     Warning condition
    error       Error condition
    critical    Critical security event

Examples:
    $0 audit code_changes "Fixed CS0101 error" "Fixed duplicate class" john.doe info
    $0 check gdpr
    $0 request production_deployment "Deploy version 2.0" john.doe
    $0 approve REQ-12345 jane.smith "Approved for production"
    $0 report full
EOF
            ;;
    esac
}

# Execute
main "$@"