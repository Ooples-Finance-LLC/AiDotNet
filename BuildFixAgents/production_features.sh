#!/bin/bash

# Production Features Integration Script
# Integrates all Phase 1 production features into the build fix workflow

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Source notification system
source "$AGENT_DIR/notification_system.sh"

# Logging
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] PRODUCTION${NC} [$level]: $message"
}

# Check if production features are configured
check_production_setup() {
    log_message "Checking production feature setup..."
    
    local setup_complete=true
    
    # Check configuration
    if [[ ! -f "$AGENT_DIR/config/project_config.yml" ]]; then
        echo -e "${YELLOW}⚠️  Configuration not initialized${NC}"
        setup_complete=false
    else
        echo -e "${GREEN}✓${NC} Configuration system ready"
    fi
    
    # Check git integration
    if ! "$AGENT_DIR/git_integration.sh" status >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Git integration not configured${NC}"
        setup_complete=false
    else
        echo -e "${GREEN}✓${NC} Git integration ready"
    fi
    
    # Check notification config
    if [[ ! -f "$AGENT_DIR/config/notifications.yml" ]]; then
        echo -e "${YELLOW}⚠️  Notifications not configured${NC}"
        setup_complete=false
    else
        echo -e "${GREEN}✓${NC} Notification system ready"
    fi
    
    # Check if architect agent has proposals
    if [[ ! -d "$AGENT_DIR/state/architectural_proposals" ]] || [[ -z "$(ls -A "$AGENT_DIR/state/architectural_proposals" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}⚠️  No architectural proposals found${NC}"
        echo "  Run: $AGENT_DIR/architect_agent.sh"
    else
        echo -e "${GREEN}✓${NC} Architectural proposals available"
    fi
    
    if [[ "$setup_complete" != "true" ]]; then
        echo -e "\n${YELLOW}Run the setup wizard to configure production features:${NC}"
        echo -e "${BLUE}$0 setup${NC}"
        return 1
    fi
    
    return 0
}

# Setup wizard for production features
setup_production_features() {
    log_message "Starting production features setup wizard..."
    
    echo -e "\n${BLUE}=== Production Features Setup ===${NC}\n"
    
    # 1. Configuration Management
    echo -e "${CYAN}1. Configuration Management${NC}"
    "$AGENT_DIR/config_manager.sh" init
    
    read -p "Run configuration wizard? (Y/n): " run_config
    if [[ "$run_config" != "n" ]]; then
        "$AGENT_DIR/config_manager.sh" wizard
    fi
    
    # 2. Git Integration
    echo -e "\n${CYAN}2. Git Integration${NC}"
    "$AGENT_DIR/git_integration.sh" setup
    
    # 3. Notification System
    echo -e "\n${CYAN}3. Notification System${NC}"
    "$AGENT_DIR/notification_system.sh" configure
    
    read -p "Test notifications? (Y/n): " test_notify
    if [[ "$test_notify" != "n" ]]; then
        "$AGENT_DIR/notification_system.sh" test
    fi
    
    # 4. Security Configuration
    echo -e "\n${CYAN}4. Security Scanning${NC}"
    read -p "Enable security scanning? (y/N): " enable_security
    if [[ "$enable_security" =~ ^[Yy]$ ]]; then
        "$AGENT_DIR/config_manager.sh" set security_enabled true
        echo -e "${GREEN}✓ Security scanning enabled${NC}"
    fi
    
    echo -e "\n${GREEN}✓ Production features setup complete!${NC}"
}

# Run enhanced build fix workflow with production features
run_production_workflow() {
    local mode="${1:-analyze}"
    
    log_message "Starting production-enhanced build fix workflow..."
    
    # Send start notification
    notify_build_progress "Initialization" 0 100 "Starting build fix process"
    
    # Load configuration
    "$AGENT_DIR/config_manager.sh" init
    local max_agents=$("$AGENT_DIR/config_manager.sh" get max_concurrent_agents || echo 3)
    local auto_commit=$("$AGENT_DIR/config_manager.sh" get auto_commit || echo false)
    local auto_pr=$("$AGENT_DIR/config_manager.sh" get auto_pr || echo false)
    
    # Phase 1: Run architect agent for analysis
    if [[ "$mode" == "full" ]] || [[ "$mode" == "architect" ]]; then
        log_message "Running architectural analysis..."
        notify_build_progress "Architecture Analysis" 10 100 "Analyzing codebase architecture"
        "$AGENT_DIR/architect_agent.sh"
    fi
    
    # Phase 2: Security scan
    local security_enabled=$("$AGENT_DIR/config_manager.sh" get security_enabled || echo false)
    if [[ "$security_enabled" == "true" ]]; then
        log_message "Running security scan..."
        notify_build_progress "Security Scan" 20 100 "Scanning for vulnerabilities"
        
        if ! "$AGENT_DIR/security_agent.sh"; then
            notify_security_alert "SCAN_FAILED" "high" "security_scan" "Security scan found issues"
        fi
    fi
    
    # Phase 3: Build fix
    log_message "Running build fix agents..."
    notify_build_progress "Build Fix" 30 100 "Fixing compilation errors"
    
    local start_time=$(date +%s)
    
    # Run the main build fix
    if "$AGENT_DIR/autofix.sh"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Get error count from state
        local errors_fixed=$(grep -c "FIXED" "$AGENT_DIR/state/agent_progress.txt" 2>/dev/null || echo 0)
        
        notify_build_complete "$errors_fixed" "$duration" true
        
        # Phase 4: Git integration
        if [[ "$auto_commit" == "true" ]]; then
            log_message "Creating automatic commit..."
            notify_build_progress "Git Commit" 80 100 "Committing changes"
            
            "$AGENT_DIR/git_integration.sh" commit "$errors_fixed" "Automated fix for $errors_fixed build errors" "$duration"
            
            if [[ "$auto_pr" == "true" ]]; then
                log_message "Creating pull request..."
                notify_build_progress "Pull Request" 90 100 "Creating pull request"
                "$AGENT_DIR/git_integration.sh" pr "$errors_fixed" "Automated build fixes"
            fi
        fi
    else
        notify_build_complete 0 0 false
        log_message "Build fix failed!" "ERROR"
        return 1
    fi
    
    # Phase 5: Code generation (if proposals exist)
    if [[ -f "$AGENT_DIR/state/ARCHITECT_TASKS.md" ]]; then
        read -p "Generate code for architectural proposals? (y/N): " generate_code
        if [[ "$generate_code" =~ ^[Yy]$ ]]; then
            log_message "Running code generation..."
            notify_build_progress "Code Generation" 95 100 "Generating code from proposals"
            "$AGENT_DIR/codegen_developer_agent.sh"
        fi
    fi
    
    # Phase 6: Summary
    notify_build_progress "Complete" 100 100 "Build fix workflow complete"
    
    # Generate reports
    "$AGENT_DIR/notification_system.sh" summary
    
    log_message "Production workflow complete!"
}

# Show production dashboard
show_production_dashboard() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Build Fix Agent - Production Dashboard        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    
    # Configuration Status
    echo -e "\n${CYAN}Configuration:${NC}"
    "$AGENT_DIR/config_manager.sh" show | grep -E "project_name|dotnet_version|auto_commit|auto_pr" | sed 's/^/  /'
    
    # Agent Status
    echo -e "\n${CYAN}Enabled Agents:${NC}"
    local agents=("error_fix" "tester" "performance" "architect" "security")
    for agent in "${agents[@]}"; do
        local config_key="${agent}_enabled"
        local enabled=$("$AGENT_DIR/config_manager.sh" get "$config_key" 2>/dev/null || echo "false")
        if [[ "$enabled" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $agent"
        else
            echo -e "  ${YELLOW}○${NC} $agent"
        fi
    done
    
    # Recent Activity
    echo -e "\n${CYAN}Recent Activity:${NC}"
    if [[ -f "$AGENT_DIR/state/commit_history.json" ]]; then
        echo "  Last commits:"
        tail -3 "$AGENT_DIR/state/commit_history.json" 2>/dev/null | grep timestamp | cut -d'"' -f4 | sed 's/^/    - /'
    else
        echo "  No recent commits"
    fi
    
    # Security Status
    if [[ -d "$AGENT_DIR/state/security_reports" ]]; then
        echo -e "\n${CYAN}Security Status:${NC}"
        local latest_scan=$(ls -t "$AGENT_DIR/state/security_reports"/security_summary_*.json 2>/dev/null | head -1)
        if [[ -f "$latest_scan" ]]; then
            local total_issues=$(grep "total_issues" "$latest_scan" | grep -o '[0-9]*' || echo 0)
            if [[ $total_issues -gt 0 ]]; then
                echo -e "  ${RED}⚠️  $total_issues security issues found${NC}"
            else
                echo -e "  ${GREEN}✓ No security issues${NC}"
            fi
        else
            echo "  No security scans performed"
        fi
    fi
    
    # Architectural Proposals
    if [[ -d "$AGENT_DIR/state/architectural_proposals" ]]; then
        echo -e "\n${CYAN}Architectural Proposals:${NC}"
        local proposal_count=$(ls "$AGENT_DIR/state/architectural_proposals"/*.md 2>/dev/null | wc -l)
        echo "  $proposal_count proposals available"
    fi
    
    echo -e "\n${YELLOW}────────────────────────────────────────────────────────${NC}"
}

# Main menu
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "setup")
            setup_production_features
            ;;
            
        "check")
            check_production_setup
            ;;
            
        "run")
            if check_production_setup; then
                run_production_workflow "$@"
            fi
            ;;
            
        "dashboard")
            show_production_dashboard
            ;;
            
        "full")
            # Full production workflow
            if check_production_setup; then
                run_production_workflow "full"
            fi
            ;;
            
        *)
            echo -e "${BLUE}Build Fix Agent - Production Features${NC}"
            echo -e "${YELLOW}====================================${NC}\n"
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  setup     - Configure production features"
            echo "  check     - Check production setup status"
            echo "  run       - Run build fix with production features"
            echo "  full      - Run full workflow (architect + fix + generate)"
            echo "  dashboard - Show production dashboard"
            echo ""
            echo "Examples:"
            echo "  $0 setup              # Initial setup"
            echo "  $0 run                # Run standard build fix"
            echo "  $0 full               # Run complete workflow"
            echo ""
            echo "Production Features:"
            echo "  ✓ Configuration Management"
            echo "  ✓ Git Integration & Auto-commit"
            echo "  ✓ Security Scanning"
            echo "  ✓ Notification System"
            echo "  ✓ Architect Agent"
            echo "  ✓ Code Generation"
            ;;
    esac
}

# Execute
main "$@"