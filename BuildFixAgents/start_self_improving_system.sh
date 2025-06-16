#!/bin/bash

# Start Self-Improving BuildFixAgents System
# Initializes and runs the complete multi-agent architecture

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
GOLD='\033[0;33m'

# Banner
echo -e "${BOLD}${GOLD}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     BuildFixAgents - Self-Improving Multi-Agent System      ║
║                                                              ║
║     🤖 Autonomous | 🧠 Learning | 🚀 Production Ready        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Ensure all scripts are executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Create required directories
mkdir -p "$SCRIPT_DIR/state" "$SCRIPT_DIR/logs" "$SCRIPT_DIR/patterns"

# Check if .NET is available
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}⚠ Warning: .NET SDK not found. Some features may not work.${NC}"
fi

# Initialize system
echo -e "\n${CYAN}=== Initializing Self-Improving System ===${NC}"

# Step 1: Initialize Enhanced Coordinator
echo -e "\n${YELLOW}Step 1: Initializing Enhanced Coordinator...${NC}"
bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" init

# Step 2: Deploy Agent Network
echo -e "\n${YELLOW}Step 2: Deploying Multi-Agent Network...${NC}"
bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" deploy

# Step 3: Remove any blockers
echo -e "\n${YELLOW}Step 3: Removing System Blockers...${NC}"
if [[ -f "$SCRIPT_DIR/scrum_master_agent.sh" ]]; then
    bash "$SCRIPT_DIR/scrum_master_agent.sh" remove-blockers
fi

# Step 4: Start Metrics Collection
echo -e "\n${YELLOW}Step 4: Starting Metrics Collection...${NC}"
if [[ -f "$SCRIPT_DIR/metrics_collector_agent.sh" ]]; then
    bash "$SCRIPT_DIR/metrics_collector_agent.sh" collect
fi

# Step 5: Run Initial Analysis
echo -e "\n${YELLOW}Step 5: Running System Analysis...${NC}"
if [[ -f "$SCRIPT_DIR/learning_agent.sh" ]]; then
    bash "$SCRIPT_DIR/learning_agent.sh" analyze
fi

# Main menu
show_menu() {
    echo -e "\n${BOLD}${CYAN}=== BuildFixAgents Control Panel ===${NC}"
    echo -e "${GREEN}1)${NC} Run Full Orchestration (Fix all errors)"
    echo -e "${GREEN}2)${NC} View System Status"
    echo -e "${GREEN}3)${NC} Launch Metrics Dashboard"
    echo -e "${GREEN}4)${NC} Run Scrum Standup"
    echo -e "${GREEN}5)${NC} Generate Reports"
    echo -e "${GREEN}6)${NC} Apply Learning & Improvements"
    echo -e "${GREEN}7)${NC} Run in Debug Mode"
    echo -e "${GREEN}8)${NC} Start Continuous Mode (Background)"
    echo -e "${GREEN}9)${NC} View Executive Summary"
    echo -e "${RED}0)${NC} Exit"
    echo
}

# Handle user choice
handle_choice() {
    local choice=$1
    
    case $choice in
        1)
            echo -e "\n${BOLD}${GREEN}Starting Full Orchestration...${NC}"
            bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" orchestrate
            ;;
        2)
            echo -e "\n${BOLD}${CYAN}System Status:${NC}"
            bash "$SCRIPT_DIR/architect_agent_v2.sh" monitor
            ;;
        3)
            echo -e "\n${BOLD}${BLUE}Launching Metrics Dashboard...${NC}"
            bash "$SCRIPT_DIR/metrics_collector_agent.sh" dashboard
            ;;
        4)
            echo -e "\n${BOLD}${MAGENTA}Running Scrum Standup...${NC}"
            bash "$SCRIPT_DIR/scrum_master_agent.sh" standup
            ;;
        5)
            echo -e "\n${BOLD}${YELLOW}Generating Reports...${NC}"
            bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" report
            echo -e "\n${GREEN}Reports generated in state/ subdirectories${NC}"
            ;;
        6)
            echo -e "\n${BOLD}${GOLD}Applying Improvements...${NC}"
            bash "$SCRIPT_DIR/learning_agent.sh" learn
            bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" improve
            ;;
        7)
            echo -e "\n${BOLD}${YELLOW}Running in Debug Mode...${NC}"
            DEBUG=true VERBOSE=true bash "$SCRIPT_DIR/autofix_batch.sh" run
            ;;
        8)
            echo -e "\n${BOLD}${GREEN}Starting Continuous Mode...${NC}"
            echo "The system will run in background and fix errors automatically."
            nohup bash -c 'while true; do 
                bash "'"$SCRIPT_DIR"'/enhanced_coordinator_v2.sh" orchestrate
                sleep 300
            done' > "$SCRIPT_DIR/logs/continuous_mode.log" 2>&1 &
            echo -e "${GREEN}✓ Continuous mode started (PID: $!)${NC}"
            echo "Check logs/continuous_mode.log for output"
            ;;
        9)
            echo -e "\n${BOLD}${GOLD}Executive Summary:${NC}"
            if [[ -f "$SCRIPT_DIR/state/coordinator/EXECUTIVE_SUMMARY.md" ]]; then
                cat "$SCRIPT_DIR/state/coordinator/EXECUTIVE_SUMMARY.md"
            else
                bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" report
                cat "$SCRIPT_DIR/state/coordinator/EXECUTIVE_SUMMARY.md"
            fi
            ;;
        0)
            echo -e "\n${GREEN}Thank you for using BuildFixAgents!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
}

# Quick start options
if [[ $# -gt 0 ]]; then
    case "$1" in
        "auto")
            echo -e "\n${BOLD}${GREEN}Running in Automatic Mode...${NC}"
            bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" orchestrate
            exit 0
            ;;
        "status")
            bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" status
            exit 0
            ;;
        "help")
            echo "Usage: $0 [auto|status|help]"
            echo "  auto   - Run automatic orchestration"
            echo "  status - Show system status"
            echo "  help   - Show this help"
            echo ""
            echo "Or run without arguments for interactive mode"
            exit 0
            ;;
    esac
fi

# Interactive mode
echo -e "\n${GREEN}✓ Self-Improving System Ready!${NC}"
echo -e "${CYAN}The system can now learn from its actions and improve over time.${NC}"

while true; do
    show_menu
    read -p "Enter your choice: " choice
    handle_choice "$choice"
    
    echo
    read -p "Press Enter to continue..."
done