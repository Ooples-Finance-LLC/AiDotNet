#!/bin/bash

# Enterprise Launcher v3 - Includes Tier 1 and Tier 2 enterprise features
# Complete enterprise solution with ML, analytics, cost optimization, and DR

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
    echo -e "${BLUE}║          Build Fix Agent Enterprise v3.0                     ║${NC}"
    echo -e "${BLUE}║          Complete Enterprise Solution                        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Main menu
show_main_menu() {
    echo -e "\n${CYAN}Main Menu:${NC}"
    echo "1. Build Fix Operations"
    echo "2. ML/AI Features"
    echo "3. Analytics & Reporting"
    echo "4. Cost Management"
    echo "5. Disaster Recovery"
    echo "6. Integration & Compliance"
    echo "7. Quick Actions"
    echo "8. System Administration"
    echo "0. Exit"
    echo
    read -p "Select option: " main_choice
}

# Build Fix menu
show_build_fix_menu() {
    echo -e "\n${CYAN}Build Fix Operations:${NC}"
    echo "1. Auto-detect and fix errors"
    echo "2. Multi-language build fix"
    echo "3. Run specific language fix"
    echo "4. View error analysis"
    echo "5. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            echo -e "\n${BLUE}Running auto-detect and fix...${NC}"
            "$AGENT_DIR/run_build_fix.sh" fix
            ;;
        2)
            "$AGENT_DIR/multi_language_fix_agent.sh" "$PROJECT_DIR"
            ;;
        3)
            read -p "Enter language (csharp/typescript/python/java): " lang
            "$AGENT_DIR/language_detector.sh" build "$PROJECT_DIR" "$lang"
            ;;
        4)
            if [[ -f "$AGENT_DIR/state/error_analysis.json" ]]; then
                jq . "$AGENT_DIR/state/error_analysis.json"
            else
                echo -e "${YELLOW}No error analysis available${NC}"
            fi
            ;;
    esac
}

# ML/AI menu
show_ml_menu() {
    echo -e "\n${CYAN}ML/AI Features:${NC}"
    echo "1. Train ML models"
    echo "2. Predict errors"
    echo "3. Get fix suggestions"
    echo "4. Detect anomalies"
    echo "5. View ML insights"
    echo "6. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            "$AGENT_DIR/ml_integration_layer.sh" train all
            ;;
        2)
            "$AGENT_DIR/ml_integration_layer.sh" predict "$PROJECT_DIR"
            ;;
        3)
            read -p "Enter error code: " error_code
            "$AGENT_DIR/ml_integration_layer.sh" suggest "$error_code"
            ;;
        4)
            if [[ -f "$AGENT_DIR/state/error_analysis.json" ]]; then
                "$AGENT_DIR/ml_integration_layer.sh" anomaly "$AGENT_DIR/state/error_analysis.json"
            else
                echo -e "${YELLOW}No error data for anomaly detection${NC}"
            fi
            ;;
        5)
            "$AGENT_DIR/ml_integration_layer.sh" report
            ;;
    esac
}

# Analytics menu
show_analytics_menu() {
    echo -e "\n${CYAN}Analytics & Reporting:${NC}"
    echo "1. Executive dashboard"
    echo "2. Team performance report"
    echo "3. Error trends analysis"
    echo "4. Calculate KPIs"
    echo "5. Generate all reports"
    echo "6. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            "$AGENT_DIR/advanced_analytics.sh" executive
            ;;
        2)
            "$AGENT_DIR/advanced_analytics.sh" team
            ;;
        3)
            read -p "Enter lookback days (default 30): " days
            "$AGENT_DIR/advanced_analytics.sh" trends "${days:-30}"
            ;;
        4)
            read -p "Enter lookback days (default 7): " days
            "$AGENT_DIR/advanced_analytics.sh" kpi "${days:-7}"
            ;;
        5)
            "$AGENT_DIR/advanced_analytics.sh" all
            ;;
    esac
}

# Cost management menu
show_cost_menu() {
    echo -e "\n${CYAN}Cost Management:${NC}"
    echo "1. View cost dashboard"
    echo "2. Track resource usage"
    echo "3. Calculate costs"
    echo "4. Predict future costs"
    echo "5. Get optimization recommendations"
    echo "6. Start cost monitoring"
    echo "7. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            "$AGENT_DIR/cost_optimization_engine.sh" dashboard
            ;;
        2)
            "$AGENT_DIR/cost_optimization_engine.sh" track
            ;;
        3)
            "$AGENT_DIR/cost_optimization_engine.sh" calculate
            ;;
        4)
            read -p "Enter prediction days (default 7): " days
            "$AGENT_DIR/cost_optimization_engine.sh" predict "${days:-7}"
            ;;
        5)
            "$AGENT_DIR/cost_optimization_engine.sh" optimize
            ;;
        6)
            echo -e "${YELLOW}Starting cost monitoring (Ctrl+C to stop)...${NC}"
            "$AGENT_DIR/cost_optimization_engine.sh" monitor
            ;;
    esac
}

# Disaster recovery menu
show_dr_menu() {
    echo -e "\n${CYAN}Disaster Recovery:${NC}"
    echo "1. Create backup (full)"
    echo "2. Create backup (incremental)"
    echo "3. List backups"
    echo "4. Restore from backup"
    echo "5. Test recovery procedure"
    echo "6. Check backup health"
    echo "7. Generate DR report"
    echo "8. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            "$AGENT_DIR/disaster_recovery.sh" backup full
            ;;
        2)
            "$AGENT_DIR/disaster_recovery.sh" backup incremental
            ;;
        3)
            "$AGENT_DIR/disaster_recovery.sh" list
            ;;
        4)
            "$AGENT_DIR/disaster_recovery.sh" list
            read -p "Enter backup ID to restore: " backup_id
            "$AGENT_DIR/disaster_recovery.sh" restore "$backup_id"
            ;;
        5)
            "$AGENT_DIR/disaster_recovery.sh" test
            ;;
        6)
            "$AGENT_DIR/disaster_recovery.sh" health
            ;;
        7)
            "$AGENT_DIR/disaster_recovery.sh" report
            ;;
    esac
}

# Integration & Compliance menu
show_integration_menu() {
    echo -e "\n${CYAN}Integration & Compliance:${NC}"
    echo "1. Configure integrations (JIRA, Slack, Teams)"
    echo "2. Run security scan"
    echo "3. Check compliance (GDPR, SOC2)"
    echo "4. View audit trail"
    echo "5. Generate compliance report"
    echo "6. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            "$AGENT_DIR/integration_hub.sh" config
            ;;
        2)
            "$AGENT_DIR/advanced_security_suite.sh" scan all "$PROJECT_DIR"
            ;;
        3)
            "$AGENT_DIR/compliance_audit_framework.sh" check all
            ;;
        4)
            read -p "Search audit logs (leave empty for recent): " search
            if [[ -n "$search" ]]; then
                "$AGENT_DIR/compliance_audit_framework.sh" search "$search"
            else
                local today=$(date +%Y/%m/%d)
                local audit_file="$AGENT_DIR/state/audit/$today/audit_log.jsonl"
                if [[ -f "$audit_file" ]]; then
                    tail -20 "$audit_file" | jq -r '"[\(.timestamp)] \(.event_type) - \(.action) by \(.user)"'
                fi
            fi
            ;;
        5)
            "$AGENT_DIR/compliance_audit_framework.sh" report
            ;;
    esac
}

# Quick actions menu
show_quick_actions() {
    echo -e "\n${CYAN}Quick Actions:${NC}"
    echo "1. Full enterprise scan (all features)"
    echo "2. Generate all reports"
    echo "3. Run all tests"
    echo "4. Emergency backup"
    echo "5. System health check"
    echo "6. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            run_full_enterprise_scan
            ;;
        2)
            generate_all_reports
            ;;
        3)
            run_all_tests
            ;;
        4)
            echo -e "${RED}Creating emergency backup...${NC}"
            "$AGENT_DIR/disaster_recovery.sh" backup full
            ;;
        5)
            system_health_check
            ;;
    esac
}

# System administration menu
show_admin_menu() {
    echo -e "\n${CYAN}System Administration:${NC}"
    echo "1. Initialize all components"
    echo "2. Setup automated schedules"
    echo "3. Clean old data"
    echo "4. Export configuration"
    echo "5. View system logs"
    echo "6. Back to main menu"
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            initialize_all_components
            ;;
        2)
            setup_schedules
            ;;
        3)
            cleanup_old_data
            ;;
        4)
            export_configuration
            ;;
        5)
            view_system_logs
            ;;
    esac
}

# Full enterprise scan
run_full_enterprise_scan() {
    echo -e "\n${BLUE}Running Full Enterprise Scan...${NC}"
    
    # Create audit entry
    "$AGENT_DIR/compliance_audit_framework.sh" audit enterprise_scan start \
        "Full enterprise scan initiated" "$USER" info >/dev/null 2>&1
    
    # 1. Language detection and ML prediction
    echo -e "\n${CYAN}Step 1: ML-Powered Analysis${NC}"
    local language=$("$AGENT_DIR/language_detector.sh" detect "$PROJECT_DIR" 2>&1 | tail -1)
    "$AGENT_DIR/ml_integration_layer.sh" predict "$PROJECT_DIR"
    
    # 2. Security scanning
    echo -e "\n${CYAN}Step 2: Security Analysis${NC}"
    "$AGENT_DIR/advanced_security_suite.sh" scan all "$PROJECT_DIR"
    
    # 3. Cost tracking
    echo -e "\n${CYAN}Step 3: Cost Analysis${NC}"
    "$AGENT_DIR/cost_optimization_engine.sh" track
    "$AGENT_DIR/cost_optimization_engine.sh" calculate
    
    # 4. Fix errors with ML assistance
    echo -e "\n${CYAN}Step 4: Intelligent Error Fixing${NC}"
    "$AGENT_DIR/multi_language_fix_agent.sh" "$PROJECT_DIR"
    
    # 5. Generate reports
    echo -e "\n${CYAN}Step 5: Report Generation${NC}"
    "$AGENT_DIR/advanced_analytics.sh" executive
    
    # 6. Create backup
    echo -e "\n${CYAN}Step 6: Backup Creation${NC}"
    "$AGENT_DIR/disaster_recovery.sh" backup incremental
    
    echo -e "\n${GREEN}✓ Full enterprise scan completed${NC}"
}

# Generate all reports
generate_all_reports() {
    echo -e "\n${BLUE}Generating all reports...${NC}"
    
    "$AGENT_DIR/ml_integration_layer.sh" report
    "$AGENT_DIR/advanced_analytics.sh" all
    "$AGENT_DIR/cost_optimization_engine.sh" dashboard
    "$AGENT_DIR/disaster_recovery.sh" report
    "$AGENT_DIR/advanced_security_suite.sh" report
    "$AGENT_DIR/compliance_audit_framework.sh" report
    
    echo -e "\n${GREEN}All reports generated${NC}"
}

# Run all tests
run_all_tests() {
    echo -e "\n${BLUE}Running all test suites...${NC}"
    
    echo -e "\n${CYAN}Tier 1 Tests:${NC}"
    "$AGENT_DIR/tier1_features_test_suite.sh"
    
    echo -e "\n${CYAN}Tier 2 Tests:${NC}"
    "$AGENT_DIR/tier2_features_test_suite.sh"
    
    echo -e "\n${GREEN}All tests completed${NC}"
}

# System health check
system_health_check() {
    echo -e "\n${BLUE}System Health Check${NC}"
    
    echo -e "\n${CYAN}Component Status:${NC}"
    
    # Check each component
    local components=(
        "ML Integration:ml_integration_layer.sh:status"
        "Analytics:advanced_analytics.sh:api"
        "Cost Engine:cost_optimization_engine.sh:track"
        "Disaster Recovery:disaster_recovery.sh:health"
        "Security:advanced_security_suite.sh:config"
        "Compliance:compliance_audit_framework.sh:config"
    )
    
    for component in "${components[@]}"; do
        IFS=: read -r name script command <<< "$component"
        if [[ -f "$AGENT_DIR/$script" ]]; then
            echo -e "  $name: ${GREEN}✓ Installed${NC}"
        else
            echo -e "  $name: ${RED}✗ Missing${NC}"
        fi
    done
    
    # Check disk space
    echo -e "\n${CYAN}Disk Usage:${NC}"
    df -h "$AGENT_DIR" | tail -1
    
    # Check recent activity
    echo -e "\n${CYAN}Recent Activity:${NC}"
    local recent_fixes=$(find "$AGENT_DIR/logs" -name "*.log" -mtime -1 2>/dev/null | wc -l)
    echo -e "  Logs in last 24h: $recent_fixes"
    
    local recent_backups=$(find "$AGENT_DIR/backups" -name "*.tar.gz" -mtime -7 2>/dev/null | wc -l)
    echo -e "  Backups in last 7d: $recent_backups"
}

# Initialize all components
initialize_all_components() {
    echo -e "\n${BLUE}Initializing all components...${NC}"
    
    # Tier 1
    "$AGENT_DIR/config_manager.sh" init >/dev/null 2>&1
    "$AGENT_DIR/integration_hub.sh" init >/dev/null 2>&1
    "$AGENT_DIR/compliance_audit_framework.sh" config >/dev/null 2>&1
    "$AGENT_DIR/advanced_security_suite.sh" config >/dev/null 2>&1
    
    # Tier 2
    "$AGENT_DIR/ml_integration_layer.sh" status >/dev/null 2>&1
    "$AGENT_DIR/advanced_analytics.sh" collect >/dev/null 2>&1
    "$AGENT_DIR/cost_optimization_engine.sh" track >/dev/null 2>&1
    "$AGENT_DIR/disaster_recovery.sh" health >/dev/null 2>&1
    
    echo -e "${GREEN}✓ All components initialized${NC}"
}

# Setup automated schedules
setup_schedules() {
    echo -e "\n${BLUE}Setting up automated schedules...${NC}"
    
    cat > "$AGENT_DIR/enterprise_schedule.cron" << EOF
# Build Fix Agent Enterprise - Automated Schedule

# Hourly tasks
0 * * * * $AGENT_DIR/disaster_recovery.sh backup incremental
0 * * * * $AGENT_DIR/cost_optimization_engine.sh track

# Daily tasks
0 2 * * * $AGENT_DIR/disaster_recovery.sh backup full
0 6 * * * $AGENT_DIR/advanced_analytics.sh all
0 7 * * * $AGENT_DIR/ml_integration_layer.sh train all

# Weekly tasks
0 3 * * 0 $AGENT_DIR/disaster_recovery.sh cleanup
0 4 * * 6 $AGENT_DIR/disaster_recovery.sh test
0 5 * * 1 $AGENT_DIR/compliance_audit_framework.sh report

# Every 5 minutes
*/5 * * * * $AGENT_DIR/advanced_analytics.sh api
*/5 * * * * $AGENT_DIR/cost_optimization_engine.sh track
EOF
    
    echo -e "${GREEN}Schedule created: $AGENT_DIR/enterprise_schedule.cron${NC}"
    echo -e "To activate: crontab $AGENT_DIR/enterprise_schedule.cron"
}

# Cleanup old data
cleanup_old_data() {
    echo -e "\n${BLUE}Cleaning up old data...${NC}"
    
    read -p "Remove data older than how many days? (default 30): " days
    days="${days:-30}"
    
    # Clean old logs
    find "$AGENT_DIR/logs" -name "*.log" -mtime +$days -delete 2>/dev/null
    
    # Clean old backups
    "$AGENT_DIR/disaster_recovery.sh" cleanup $days
    
    # Clean old reports
    find "$AGENT_DIR/state" -name "*.html" -mtime +$days -delete 2>/dev/null
    find "$AGENT_DIR/state" -name "*.json" -mtime +$days -delete 2>/dev/null
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Export configuration
export_configuration() {
    local export_file="$AGENT_DIR/enterprise_config_export_$(date +%Y%m%d).tar.gz"
    
    echo -e "\n${BLUE}Exporting configuration...${NC}"
    
    tar czf "$export_file" \
        "$AGENT_DIR/config" \
        "$AGENT_DIR/state/runtime_config.json" \
        "$AGENT_DIR/state/plugin_registry.json" \
        2>/dev/null
    
    echo -e "${GREEN}Configuration exported to: $export_file${NC}"
}

# View system logs
view_system_logs() {
    echo -e "\n${CYAN}System Logs:${NC}"
    echo "1. Agent coordination log"
    echo "2. Build output log"
    echo "3. Web dashboard log"
    echo "4. All recent logs"
    
    read -p "Select log: " log_choice
    
    case "$log_choice" in
        1)
            tail -50 "$AGENT_DIR/logs/agent_coordination.log" 2>/dev/null || echo "No log found"
            ;;
        2)
            tail -50 "$AGENT_DIR/logs/build_output.txt" 2>/dev/null || echo "No log found"
            ;;
        3)
            tail -50 "$AGENT_DIR/logs/web_dashboard.log" 2>/dev/null || echo "No log found"
            ;;
        4)
            find "$AGENT_DIR/logs" -name "*.log" -mtime -1 -exec tail -20 {} \; 2>/dev/null
            ;;
    esac
}

# Main loop
main() {
    display_banner
    
    # Initialize on first run
    if [[ ! -f "$AGENT_DIR/state/.initialized_v3" ]]; then
        echo -e "${YELLOW}First run detected. Initializing...${NC}"
        initialize_all_components
        touch "$AGENT_DIR/state/.initialized_v3"
    fi
    
    while true; do
        show_main_menu
        
        case "$main_choice" in
            1) show_build_fix_menu ;;
            2) show_ml_menu ;;
            3) show_analytics_menu ;;
            4) show_cost_menu ;;
            5) show_dr_menu ;;
            6) show_integration_menu ;;
            7) show_quick_actions ;;
            8) show_admin_menu ;;
            0) 
                echo -e "\n${GREEN}Thank you for using Build Fix Agent Enterprise v3!${NC}"
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
        "$AGENT_DIR/multi_language_fix_agent.sh" "$PROJECT_DIR"
        ;;
    scan)
        run_full_enterprise_scan
        ;;
    report)
        generate_all_reports
        ;;
    test)
        run_all_tests
        ;;
    health)
        system_health_check
        ;;
    menu|*)
        main
        ;;
esac