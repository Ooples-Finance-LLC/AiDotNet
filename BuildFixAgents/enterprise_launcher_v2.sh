#!/bin/bash

# Enterprise Launcher v2 - Includes all Tier 1 enterprise features
# Manages multi-language support, integrations, compliance, and security

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Display banner
display_banner() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Build Fix Agent Enterprise v2.0                     ║${NC}"
    echo -e "${BLUE}║          with Tier 1 Enterprise Features                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    echo -e "${CYAN}Checking prerequisites...${NC}"
    
    local missing=()
    
    # Check for required tools
    command -v jq &> /dev/null || missing+=("jq")
    command -v curl &> /dev/null || missing+=("curl")
    command -v git &> /dev/null || missing+=("git")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        echo "Please install missing tools and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites satisfied${NC}"
}

# Initialize all components
initialize_components() {
    echo -e "\n${CYAN}Initializing enterprise components...${NC}"
    
    # Initialize configurations
    "$AGENT_DIR/config_manager.sh" init >/dev/null 2>&1 || true
    "$AGENT_DIR/integration_hub.sh" init >/dev/null 2>&1 || true
    "$AGENT_DIR/compliance_audit_framework.sh" config >/dev/null 2>&1 || true
    "$AGENT_DIR/advanced_security_suite.sh" config >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✓ Components initialized${NC}"
}

# Main menu
show_menu() {
    echo -e "\n${CYAN}Enterprise Features Menu:${NC}"
    echo "1. Run Multi-Language Build Fix"
    echo "2. Configure Integrations (JIRA, Slack, Teams)"
    echo "3. Run Security Scan (Secrets, SAST, Vulnerabilities)"
    echo "4. Run Compliance Check (GDPR, SOC2)"
    echo "5. View Audit Trail"
    echo "6. Generate Reports"
    echo "7. Run Full Enterprise Suite"
    echo "8. Test Tier 1 Features"
    echo "9. Quick Fix (Auto-detect language)"
    echo "0. Exit"
    echo
    read -p "Select option: " choice
}

# Run multi-language fix
run_multi_language_fix() {
    echo -e "\n${BLUE}Running Multi-Language Build Fix...${NC}"
    
    # Detect language
    local language=$("$AGENT_DIR/language_detector.sh" detect "$PROJECT_DIR" 2>&1 | tail -1)
    
    if [[ -n "$language" ]]; then
        echo -e "${GREEN}Detected language: $language${NC}"
        
        # Run appropriate fix
        case "$language" in
            csharp)
                "$AGENT_DIR/run_build_fix.sh"
                ;;
            typescript|javascript|python|java|go|rust)
                "$AGENT_DIR/multi_language_fix_agent.sh" "$PROJECT_DIR"
                ;;
            *)
                echo -e "${YELLOW}Unsupported language: $language${NC}"
                ;;
        esac
    else
        echo -e "${RED}Could not detect project language${NC}"
    fi
}

# Configure integrations
configure_integrations() {
    echo -e "\n${BLUE}Integration Configuration${NC}"
    echo "1. Configure JIRA"
    echo "2. Configure Slack"
    echo "3. Configure Teams"
    echo "4. Test integrations"
    echo "5. Back to main menu"
    
    read -p "Select option: " int_choice
    
    case "$int_choice" in
        1|2|3)
            "$AGENT_DIR/integration_hub.sh" config
            ;;
        4)
            "$AGENT_DIR/integration_hub.sh" test
            ;;
        5)
            return
            ;;
    esac
}

# Run security scan
run_security_scan() {
    echo -e "\n${BLUE}Security Scanning${NC}"
    echo "1. Scan for secrets"
    echo "2. Run SAST analysis"
    echo "3. Check vulnerabilities"
    echo "4. Run all security scans"
    echo "5. Back to main menu"
    
    read -p "Select option: " sec_choice
    
    case "$sec_choice" in
        1)
            "$AGENT_DIR/advanced_security_suite.sh" scan secrets "$PROJECT_DIR"
            ;;
        2)
            "$AGENT_DIR/advanced_security_suite.sh" scan sast "$PROJECT_DIR"
            ;;
        3)
            "$AGENT_DIR/advanced_security_suite.sh" scan vulnerabilities "$PROJECT_DIR"
            ;;
        4)
            "$AGENT_DIR/advanced_security_suite.sh" scan all "$PROJECT_DIR"
            ;;
        5)
            return
            ;;
    esac
}

# Run compliance check
run_compliance_check() {
    echo -e "\n${BLUE}Compliance Checking${NC}"
    echo "1. Check GDPR compliance"
    echo "2. Check SOC2 compliance"
    echo "3. Check all standards"
    echo "4. Create approval request"
    echo "5. Back to main menu"
    
    read -p "Select option: " comp_choice
    
    case "$comp_choice" in
        1)
            "$AGENT_DIR/compliance_audit_framework.sh" check gdpr
            ;;
        2)
            "$AGENT_DIR/compliance_audit_framework.sh" check soc2
            ;;
        3)
            "$AGENT_DIR/compliance_audit_framework.sh" check all
            ;;
        4)
            read -p "Change type: " change_type
            read -p "Description: " description
            "$AGENT_DIR/compliance_audit_framework.sh" request "$change_type" "$description"
            ;;
        5)
            return
            ;;
    esac
}

# View audit trail
view_audit_trail() {
    echo -e "\n${BLUE}Audit Trail${NC}"
    echo "1. View recent events"
    echo "2. Search audit logs"
    echo "3. Generate audit report"
    echo "4. Back to main menu"
    
    read -p "Select option: " audit_choice
    
    case "$audit_choice" in
        1)
            local today=$(date +%Y/%m/%d)
            local audit_file="$AGENT_DIR/state/audit/$today/audit_log.jsonl"
            if [[ -f "$audit_file" ]]; then
                echo -e "\n${CYAN}Recent audit events:${NC}"
                tail -10 "$audit_file" | jq -r '"[\(.timestamp)] \(.event_type) - \(.action) by \(.user)"'
            else
                echo -e "${YELLOW}No audit events today${NC}"
            fi
            ;;
        2)
            read -p "Search term: " search_term
            "$AGENT_DIR/compliance_audit_framework.sh" search "$search_term"
            ;;
        3)
            "$AGENT_DIR/compliance_audit_framework.sh" report
            ;;
        4)
            return
            ;;
    esac
}

# Generate reports
generate_reports() {
    echo -e "\n${BLUE}Report Generation${NC}"
    echo "1. Security report"
    echo "2. Compliance report"
    echo "3. Integration status"
    echo "4. All reports"
    echo "5. Back to main menu"
    
    read -p "Select option: " report_choice
    
    case "$report_choice" in
        1)
            "$AGENT_DIR/advanced_security_suite.sh" report
            ;;
        2)
            "$AGENT_DIR/compliance_audit_framework.sh" report
            ;;
        3)
            echo -e "\n${CYAN}Integration Status:${NC}"
            "$AGENT_DIR/integration_hub.sh" test
            ;;
        4)
            "$AGENT_DIR/advanced_security_suite.sh" report
            "$AGENT_DIR/compliance_audit_framework.sh" report
            ;;
        5)
            return
            ;;
    esac
}

# Run full enterprise suite
run_full_suite() {
    echo -e "\n${BLUE}Running Full Enterprise Suite...${NC}"
    
    # Create audit entry
    "$AGENT_DIR/compliance_audit_framework.sh" audit enterprise_scan start \
        "Starting full enterprise scan" "$USER" info >/dev/null 2>&1
    
    # 1. Language detection and build
    echo -e "\n${CYAN}Step 1: Language Detection${NC}"
    local language=$("$AGENT_DIR/language_detector.sh" detect "$PROJECT_DIR" 2>&1 | tail -1)
    echo -e "Detected: $language"
    
    # 2. Security scan
    echo -e "\n${CYAN}Step 2: Security Scanning${NC}"
    "$AGENT_DIR/advanced_security_suite.sh" scan all "$PROJECT_DIR"
    
    # 3. Compliance check
    echo -e "\n${CYAN}Step 3: Compliance Checking${NC}"
    "$AGENT_DIR/compliance_audit_framework.sh" check all
    
    # 4. Fix errors
    echo -e "\n${CYAN}Step 4: Fixing Errors${NC}"
    run_multi_language_fix
    
    # 5. Send notifications
    echo -e "\n${CYAN}Step 5: Sending Notifications${NC}"
    "$AGENT_DIR/integration_hub.sh" notify general "Enterprise Scan Complete" \
        "Full enterprise scan completed for $PROJECT_DIR" info
    
    # Create final audit entry
    "$AGENT_DIR/compliance_audit_framework.sh" audit enterprise_scan complete \
        "Completed full enterprise scan" "$USER" info >/dev/null 2>&1
    
    echo -e "\n${GREEN}✓ Full enterprise suite completed${NC}"
}

# Test features
test_features() {
    echo -e "\n${BLUE}Testing Tier 1 Features...${NC}"
    "$AGENT_DIR/tier1_features_test_suite.sh"
}

# Quick fix mode
quick_fix() {
    echo -e "\n${BLUE}Quick Fix Mode${NC}"
    run_multi_language_fix
}

# Main loop
main() {
    display_banner
    check_prerequisites
    initialize_components
    
    while true; do
        show_menu
        
        case "$choice" in
            1) run_multi_language_fix ;;
            2) configure_integrations ;;
            3) run_security_scan ;;
            4) run_compliance_check ;;
            5) view_audit_trail ;;
            6) generate_reports ;;
            7) run_full_suite ;;
            8) test_features ;;
            9) quick_fix ;;
            0) 
                echo -e "\n${GREEN}Thank you for using Build Fix Agent Enterprise!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Handle command line arguments
case "${1:-menu}" in
    fix)
        quick_fix
        ;;
    scan)
        "$AGENT_DIR/advanced_security_suite.sh" scan all "$PROJECT_DIR"
        ;;
    compliance)
        "$AGENT_DIR/compliance_audit_framework.sh" check all
        ;;
    test)
        test_features
        ;;
    menu|*)
        main
        ;;
esac