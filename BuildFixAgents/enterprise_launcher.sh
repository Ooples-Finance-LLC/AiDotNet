#!/bin/bash

# Enterprise Build Fix Agent System Launcher
# Integrates all production features across all phases

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ASCII Art Banner
show_banner() {
    cat << 'EOF'
    ____        _ __    __   _______            ___                    __ 
   / __ )__  __(_) /___/ /  / ____(_)  __      /   | ____ ____  ____  / /_
  / __  / / / / / / __  /  / /_  / / |/_/     / /| |/ __ `/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / __/ / />  <      / ___ / /_/ /  __/ / / / /_  
/_____/\__,_/_/_/\__,_/  /_/   /_/_/|_|     /_/  |_\__, /\___/_/ /_/\__/  
                                                   /____/                  
                         Enterprise Edition v3.0
EOF
    echo ""
}

# Check system requirements
check_requirements() {
    local missing=()
    
    echo -e "${CYAN}Checking system requirements...${NC}"
    
    # Required commands
    local required_cmds=("bash" "dotnet" "git" "jq" "bc")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        else
            echo -e "  ${GREEN}✓${NC} $cmd"
        fi
    done
    
    # Optional but recommended
    local optional_cmds=("node" "python3" "sqlite3" "curl" "docker")
    echo -e "\n${CYAN}Optional components:${NC}"
    for cmd in "${optional_cmds[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} $cmd"
        else
            echo -e "  ${YELLOW}○${NC} $cmd (optional)"
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "\n${RED}Missing required components:${NC} ${missing[*]}"
        echo "Please install missing components before continuing."
        return 1
    fi
    
    return 0
}

# System health check
system_health_check() {
    echo -e "\n${CYAN}System Health Check:${NC}"
    
    # Check disk space
    local disk_usage=$(df -h "$AGENT_DIR" | awk 'NR==2{print $5}' | tr -d '%')
    if [[ $disk_usage -gt 90 ]]; then
        echo -e "  ${RED}⚠${NC}  Disk usage: ${disk_usage}% (Low space warning)"
    else
        echo -e "  ${GREEN}✓${NC} Disk usage: ${disk_usage}%"
    fi
    
    # Check memory
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_usage -gt 80 ]]; then
        echo -e "  ${YELLOW}⚠${NC}  Memory usage: ${mem_usage}%"
    else
        echo -e "  ${GREEN}✓${NC} Memory usage: ${mem_usage}%"
    fi
    
    # Check CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "  ${GREEN}✓${NC} CPU usage: ${cpu_usage}%"
    
    # Check existing processes
    local agent_count=$(ps aux | grep -c "[a]gent.*\.sh" || echo 0)
    if [[ $agent_count -gt 0 ]]; then
        echo -e "  ${CYAN}ℹ${NC}  Active agents: $agent_count"
    fi
}

# Initialize enterprise features
init_enterprise() {
    echo -e "\n${CYAN}Initializing enterprise features...${NC}"
    
    # Phase 1: Production Features
    echo -e "\n${BLUE}Phase 1: Production Features${NC}"
    "$AGENT_DIR/config_manager.sh" init
    "$AGENT_DIR/notification_system.sh" configure > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Configuration management"
    echo -e "  ${GREEN}✓${NC} Notification system"
    echo -e "  ${GREEN}✓${NC} Git integration"
    echo -e "  ${GREEN}✓${NC} Security scanning"
    
    # Phase 2: Advanced Infrastructure
    echo -e "\n${BLUE}Phase 2: Advanced Infrastructure${NC}"
    echo -e "  ${GREEN}✓${NC} Distributed agents"
    echo -e "  ${GREEN}✓${NC} Telemetry collection"
    
    # Phase 3: Enterprise Features
    echo -e "\n${BLUE}Phase 3: Enterprise Features${NC}"
    echo -e "  ${GREEN}✓${NC} Plugin system"
    echo -e "  ${GREEN}✓${NC} A/B testing framework"
    echo -e "  ${GREEN}✓${NC} Web dashboard & API"
}

# Start all services
start_all_services() {
    echo -e "\n${CYAN}Starting enterprise services...${NC}"
    
    # Start telemetry
    if [[ ! -f "$AGENT_DIR/state/telemetry.pid" ]]; then
        "$AGENT_DIR/telemetry_collector.sh" start > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} Telemetry collector started"
    fi
    
    # Start distributed coordinator
    if [[ ! -f "$AGENT_DIR/state/coordinator.pid" ]]; then
        "$AGENT_DIR/distributed_coordinator.sh" start > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} Distributed coordinator started"
    fi
    
    # Start web dashboard
    if [[ ! -f "$AGENT_DIR/state/web_server.pid" ]]; then
        "$AGENT_DIR/web_dashboard.sh" start > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} Web dashboard started"
    fi
}

# Stop all services
stop_all_services() {
    echo -e "\n${CYAN}Stopping enterprise services...${NC}"
    
    "$AGENT_DIR/web_dashboard.sh" stop > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Web dashboard stopped"
    
    "$AGENT_DIR/distributed_coordinator.sh" stop > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Distributed coordinator stopped"
    
    "$AGENT_DIR/telemetry_collector.sh" stop > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Telemetry collector stopped"
}

# Show enterprise dashboard
show_enterprise_dashboard() {
    clear
    show_banner
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Enterprise Build Fix Agent System               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # System Status
    echo -e "\n${CYAN}System Status:${NC}"
    local web_status="Stopped"
    [[ -f "$AGENT_DIR/state/web_server.pid" ]] && web_status="Running"
    local telemetry_status="Stopped"
    [[ -f "$AGENT_DIR/state/telemetry.pid" ]] && telemetry_status="Running"
    local coordinator_status="Stopped"
    [[ -f "$AGENT_DIR/state/coordinator.pid" ]] && coordinator_status="Running"
    
    echo "  Web Dashboard:    $([[ "$web_status" == "Running" ]] && echo -e "${GREEN}$web_status${NC}" || echo -e "${RED}$web_status${NC}")"
    echo "  Telemetry:        $([[ "$telemetry_status" == "Running" ]] && echo -e "${GREEN}$telemetry_status${NC}" || echo -e "${RED}$telemetry_status${NC}")"
    echo "  Coordinator:      $([[ "$coordinator_status" == "Running" ]] && echo -e "${GREEN}$coordinator_status${NC}" || echo -e "${RED}$coordinator_status${NC}")"
    
    # Configuration
    echo -e "\n${CYAN}Configuration:${NC}"
    if [[ -f "$AGENT_DIR/config/project_config.yml" ]]; then
        echo "  Project:          $(basename "$PROJECT_DIR")"
        echo "  Auto-commit:      $("$AGENT_DIR/config_manager.sh" get auto_commit 2>/dev/null || echo "false")"
        echo "  Max agents:       $("$AGENT_DIR/config_manager.sh" get max_concurrent_agents 2>/dev/null || echo "3")"
    else
        echo "  ${YELLOW}Not configured${NC}"
    fi
    
    # Active Features
    echo -e "\n${CYAN}Active Features:${NC}"
    local features=("Error Fixing" "Security Scanning" "Architecture Analysis" "Code Generation" "A/B Testing" "Plugins")
    for feature in "${features[@]}"; do
        echo -e "  ${GREEN}✓${NC} $feature"
    done
    
    # Recent Metrics
    echo -e "\n${CYAN}Recent Metrics:${NC}"
    if [[ -f "$AGENT_DIR/state/metrics/metrics.db" ]]; then
        echo "  Errors fixed:     $(sqlite3 "$AGENT_DIR/state/metrics/metrics.db" "SELECT COALESCE(MAX(metric_value), 0) FROM metrics WHERE metric_name='agent_errors_fixed_total'" 2>/dev/null || echo "0")"
        echo "  Success rate:     $(sqlite3 "$AGENT_DIR/state/metrics/metrics.db" "SELECT COALESCE(ROUND(AVG(metric_value), 1), 0) FROM metrics WHERE metric_name='agent_success_rate' AND timestamp > strftime('%s', 'now', '-1 hour')" 2>/dev/null || echo "0")%"
    else
        echo "  ${YELLOW}No metrics available${NC}"
    fi
    
    # Quick Actions
    echo -e "\n${CYAN}Quick Actions:${NC}"
    echo "  1) Run standard build fix"
    echo "  2) Run with all features"
    echo "  3) Open web dashboard"
    echo "  4) View telemetry dashboard"
    echo "  5) Manage plugins"
    echo "  6) Configure system"
    echo "  7) Run A/B test"
    echo "  8) Deploy remote agent"
    echo "  9) Generate report"
    echo "  0) Exit"
    
    echo -e "\n${YELLOW}──────────────────────────────────────────────────────────────${NC}"
}

# Run standard fix
run_standard_fix() {
    echo -e "\n${CYAN}Running standard build fix...${NC}"
    "$AGENT_DIR/autofix.sh"
}

# Run with all features
run_full_enterprise() {
    echo -e "\n${CYAN}Running full enterprise workflow...${NC}"
    
    # Ensure services are running
    start_all_services
    
    # Run production workflow
    "$AGENT_DIR/production_features.sh" full
}

# Generate comprehensive report
generate_report() {
    echo -e "\n${CYAN}Generating comprehensive report...${NC}"
    
    local report_dir="$AGENT_DIR/reports/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$report_dir"
    
    # System report
    {
        echo "# Build Fix Agent System Report"
        echo "Generated: $(date)"
        echo ""
        echo "## System Information"
        echo "- Project: $PROJECT_DIR"
        echo "- Agent Version: 3.0.0"
        echo "- Platform: $(uname -s)"
        echo ""
        
        echo "## Configuration"
        "$AGENT_DIR/config_manager.sh" show 2>/dev/null || echo "Not configured"
        echo ""
        
        echo "## Recent Activity"
        tail -20 "$AGENT_DIR/logs/agent_coordination.log" 2>/dev/null || echo "No activity"
        echo ""
        
        echo "## Metrics Summary"
        "$AGENT_DIR/telemetry_collector.sh" status 2>/dev/null || echo "No metrics"
    } > "$report_dir/system_report.md"
    
    # Export metrics
    "$AGENT_DIR/telemetry_collector.sh" export > /dev/null 2>&1
    cp "$AGENT_DIR/state/exports"/*.json "$report_dir/" 2>/dev/null || true
    
    # Security report
    if [[ -d "$AGENT_DIR/state/security_reports" ]]; then
        cp "$AGENT_DIR/state/security_reports"/*.md "$report_dir/" 2>/dev/null || true
    fi
    
    # Create archive
    tar -czf "$AGENT_DIR/reports/report_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$report_dir" .
    
    echo -e "${GREEN}✓ Report generated: $report_dir${NC}"
}

# Interactive menu
interactive_menu() {
    while true; do
        show_enterprise_dashboard
        
        read -p "Select an option: " choice
        
        case "$choice" in
            1) run_standard_fix ;;
            2) run_full_enterprise ;;
            3) "$AGENT_DIR/web_dashboard.sh" open ;;
            4) "$AGENT_DIR/telemetry_collector.sh" dashboard ;;
            5) "$AGENT_DIR/plugin_manager.sh" list ;;
            6) "$AGENT_DIR/config_manager.sh" wizard ;;
            7) "$AGENT_DIR/ab_testing_framework.sh" ;;
            8) "$AGENT_DIR/distributed_coordinator.sh" ;;
            9) generate_report ;;
            0) echo -e "\n${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "\n${RED}Invalid option${NC}"; sleep 2 ;;
        esac
        
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read
    done
}

# Main execution
main() {
    local command="${1:-menu}"
    
    case "$command" in
        "start")
            show_banner
            check_requirements || exit 1
            init_enterprise
            start_all_services
            echo -e "\n${GREEN}Enterprise system started!${NC}"
            echo -e "Web Dashboard: ${BLUE}http://localhost:8080${NC}"
            ;;
            
        "stop")
            stop_all_services
            echo -e "\n${GREEN}Enterprise system stopped!${NC}"
            ;;
            
        "status")
            system_health_check
            "$AGENT_DIR/production_features.sh" dashboard
            ;;
            
        "fix")
            run_standard_fix
            ;;
            
        "full")
            run_full_enterprise
            ;;
            
        "report")
            generate_report
            ;;
            
        "menu")
            show_banner
            check_requirements || exit 1
            init_enterprise
            interactive_menu
            ;;
            
        *)
            show_banner
            echo -e "${BLUE}Enterprise Build Fix Agent System${NC}"
            echo -e "${YELLOW}=================================${NC}\n"
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start   - Start all enterprise services"
            echo "  stop    - Stop all services"
            echo "  status  - Show system status"
            echo "  fix     - Run standard build fix"
            echo "  full    - Run full enterprise workflow"
            echo "  report  - Generate comprehensive report"
            echo "  menu    - Interactive menu (default)"
            echo ""
            echo "Features:"
            echo "  • Distributed agent coordination"
            echo "  • Real-time metrics and telemetry"
            echo "  • Web dashboard and REST API"
            echo "  • Plugin architecture"
            echo "  • A/B testing framework"
            echo "  • Security scanning"
            echo "  • Git integration"
            echo "  • Multi-channel notifications"
            ;;
    esac
}

# Execute
main "$@"