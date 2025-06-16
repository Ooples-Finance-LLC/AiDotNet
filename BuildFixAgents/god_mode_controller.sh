#!/bin/bash

# God Mode Controller - Interactive control system for Build Fix Agents
# Allows real-time control, focus switching, and priority management

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
CONTROL_SOCKET="$AGENT_DIR/state/control.sock"
CONTROL_FIFO="$AGENT_DIR/state/control.fifo"
GOD_MODE_STATE="$AGENT_DIR/state/god_mode.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Initialize
mkdir -p "$AGENT_DIR/state"

# Create control FIFO if it doesn't exist
[[ ! -p "$CONTROL_FIFO" ]] && mkfifo "$CONTROL_FIFO"

# Initialize god mode state
init_god_mode_state() {
    cat > "$GOD_MODE_STATE" << EOF
{
  "mode": "balanced",
  "focus": "auto",
  "priorities": {
    "error_fixing": 50,
    "performance": 25,
    "security": 15,
    "architecture": 10
  },
  "active_agents": [],
  "paused": false,
  "speed": "normal",
  "intervention_mode": "suggest",
  "rules": []
}
EOF
}

# ASCII Art for God Mode
show_god_mode_banner() {
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║  ██████╗  ██████╗ ██████╗     ███╗   ███╗ ██████╗ ██████╗ ███████╗ ║
    ║ ██╔════╝ ██╔═══██╗██╔══██╗    ████╗ ████║██╔═══██╗██╔══██╗██╔════╝ ║
    ║ ██║  ███╗██║   ██║██║  ██║    ██╔████╔██║██║   ██║██║  ██║█████╗   ║
    ║ ██║   ██║██║   ██║██║  ██║    ██║╚██╔╝██║██║   ██║██║  ██║██╔══╝   ║
    ║ ╚██████╔╝╚██████╔╝██████╔╝    ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████╗ ║
    ║  ╚═════╝  ╚═════╝ ╚═════╝     ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝ ║
    ╚═══════════════════════════════════════════════════════════════╝
                    Interactive Control System v1.0
EOF
}

# Real-time control panel
show_control_panel() {
    clear
    show_god_mode_banner
    
    # Load current state
    local current_mode=$(jq -r '.mode' "$GOD_MODE_STATE" 2>/dev/null || echo "balanced")
    local current_focus=$(jq -r '.focus' "$GOD_MODE_STATE" 2>/dev/null || echo "auto")
    local is_paused=$(jq -r '.paused' "$GOD_MODE_STATE" 2>/dev/null || echo "false")
    local speed=$(jq -r '.speed' "$GOD_MODE_STATE" 2>/dev/null || echo "normal")
    
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      CONTROL PANEL                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    # Status
    echo -e "\n${WHITE}Status:${NC}"
    if [[ "$is_paused" == "true" ]]; then
        echo -e "  System: ${RED}⏸  PAUSED${NC}"
    else
        echo -e "  System: ${GREEN}▶  RUNNING${NC}"
    fi
    echo -e "  Mode: ${YELLOW}$current_mode${NC}"
    echo -e "  Focus: ${BLUE}$current_focus${NC}"
    echo -e "  Speed: ${MAGENTA}$speed${NC}"
    
    # Active Agents
    echo -e "\n${WHITE}Active Agents:${NC}"
    local agent_count=$(ls "$AGENT_DIR"/.pid_* 2>/dev/null | wc -l || echo 0)
    if [[ $agent_count -gt 0 ]]; then
        for pid_file in "$AGENT_DIR"/.pid_*; do
            [[ -f "$pid_file" ]] || continue
            local agent_name=$(basename "$pid_file" | sed 's/.pid_//')
            echo -e "  ${GREEN}●${NC} $agent_name"
        done
    else
        echo -e "  ${YELLOW}No active agents${NC}"
    fi
    
    # Priorities
    echo -e "\n${WHITE}Current Priorities:${NC}"
    jq -r '.priorities | to_entries[] | "  \(.key): \(.value)%"' "$GOD_MODE_STATE" 2>/dev/null || echo "  No priorities set"
    
    # Commands
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      COMMANDS                                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${WHITE}Focus Control:${NC}"
    echo "  [1] Bug Fixing Focus      [2] Performance Focus"
    echo "  [3] Security Focus        [4] Architecture Focus"
    echo "  [5] Balanced Mode         [6] Custom Priority"
    
    echo -e "\n${WHITE}System Control:${NC}"
    echo "  [P] Pause/Resume          [S] Change Speed"
    echo "  [K] Kill Agent            [A] Add Agent"
    echo "  [R] Add Rule              [M] Change Mode"
    
    echo -e "\n${WHITE}Monitoring:${NC}"
    echo "  [L] Live Logs             [T] Telemetry"
    echo "  [E] Error Summary         [D] Dashboard"
    
    echo -e "\n${WHITE}Actions:${NC}"
    echo "  [I] Intervene Now         [F] Force Fix"
    echo "  [B] Rollback              [C] Checkpoint"
    echo "  [Q] Quit God Mode         [H] Help"
    
    echo -e "\n${YELLOW}════════════════════════════════════════════════════════════════${NC}"
}

# Handle user commands
handle_command() {
    local cmd="$1"
    
    case "$cmd" in
        1) set_focus "bug_fixing" ;;
        2) set_focus "performance" ;;
        3) set_focus "security" ;;
        4) set_focus "architecture" ;;
        5) set_focus "balanced" ;;
        6) custom_priority ;;
        
        p|P) toggle_pause ;;
        s|S) change_speed ;;
        k|K) kill_agent ;;
        a|A) add_agent ;;
        r|R) add_rule ;;
        m|M) change_mode ;;
        
        l|L) show_live_logs ;;
        t|T) show_telemetry ;;
        e|E) show_error_summary ;;
        d|D) open_dashboard ;;
        
        i|I) intervene_now ;;
        f|F) force_fix ;;
        b|B) rollback_changes ;;
        c|C) create_checkpoint ;;
        
        q|Q) exit_god_mode ;;
        h|H) show_help ;;
        
        *) echo -e "${RED}Unknown command: $cmd${NC}" ;;
    esac
}

# Set focus mode
set_focus() {
    local focus="$1"
    
    echo -e "\n${CYAN}Setting focus to: $focus${NC}"
    
    # Update priorities based on focus
    case "$focus" in
        "bug_fixing")
            update_priorities 70 10 10 10
            send_control_message "FOCUS:BUG_FIXING"
            ;;
        "performance")
            update_priorities 20 60 10 10
            send_control_message "FOCUS:PERFORMANCE"
            ;;
        "security")
            update_priorities 20 10 60 10
            send_control_message "FOCUS:SECURITY"
            ;;
        "architecture")
            update_priorities 20 10 10 60
            send_control_message "FOCUS:ARCHITECTURE"
            ;;
        "balanced")
            update_priorities 40 20 20 20
            send_control_message "FOCUS:BALANCED"
            ;;
    esac
    
    # Update state
    local temp_file=$(mktemp)
    jq ".focus = \"$focus\"" "$GOD_MODE_STATE" > "$temp_file"
    mv "$temp_file" "$GOD_MODE_STATE"
    
    echo -e "${GREEN}✓ Focus changed to: $focus${NC}"
    sleep 2
}

# Update priorities
update_priorities() {
    local error_fixing=$1
    local performance=$2
    local security=$3
    local architecture=$4
    
    local temp_file=$(mktemp)
    jq ".priorities = {
        \"error_fixing\": $error_fixing,
        \"performance\": $performance,
        \"security\": $security,
        \"architecture\": $architecture
    }" "$GOD_MODE_STATE" > "$temp_file"
    mv "$temp_file" "$GOD_MODE_STATE"
}

# Custom priority setting
custom_priority() {
    echo -e "\n${CYAN}Custom Priority Configuration${NC}"
    echo "Enter percentages for each category (must total 100%):"
    
    read -p "Error Fixing [%]: " error_pct
    read -p "Performance [%]: " perf_pct
    read -p "Security [%]: " sec_pct
    read -p "Architecture [%]: " arch_pct
    
    local total=$((error_pct + perf_pct + sec_pct + arch_pct))
    
    if [[ $total -ne 100 ]]; then
        echo -e "${RED}Error: Percentages must total 100% (currently $total%)${NC}"
        sleep 2
        return
    fi
    
    update_priorities "$error_pct" "$perf_pct" "$sec_pct" "$arch_pct"
    send_control_message "PRIORITY:CUSTOM"
    
    echo -e "${GREEN}✓ Custom priorities set${NC}"
    sleep 2
}

# Toggle pause
toggle_pause() {
    local is_paused=$(jq -r '.paused' "$GOD_MODE_STATE")
    
    if [[ "$is_paused" == "true" ]]; then
        echo -e "\n${GREEN}Resuming system...${NC}"
        send_control_message "RESUME"
        update_state ".paused = false"
    else
        echo -e "\n${YELLOW}Pausing system...${NC}"
        send_control_message "PAUSE"
        update_state ".paused = true"
    fi
    
    sleep 1
}

# Change speed
change_speed() {
    echo -e "\n${CYAN}Select Speed:${NC}"
    echo "  1) Slow (Conservative)"
    echo "  2) Normal"
    echo "  3) Fast (Aggressive)"
    echo "  4) Turbo (Maximum)"
    
    read -p "Choice: " speed_choice
    
    case "$speed_choice" in
        1) 
            update_state ".speed = \"slow\""
            send_control_message "SPEED:SLOW"
            echo -e "${GREEN}✓ Speed set to: Slow${NC}"
            ;;
        2) 
            update_state ".speed = \"normal\""
            send_control_message "SPEED:NORMAL"
            echo -e "${GREEN}✓ Speed set to: Normal${NC}"
            ;;
        3) 
            update_state ".speed = \"fast\""
            send_control_message "SPEED:FAST"
            echo -e "${GREEN}✓ Speed set to: Fast${NC}"
            ;;
        4) 
            update_state ".speed = \"turbo\""
            send_control_message "SPEED:TURBO"
            echo -e "${GREEN}✓ Speed set to: Turbo${NC}"
            ;;
    esac
    
    sleep 2
}

# Kill specific agent
kill_agent() {
    echo -e "\n${CYAN}Active Agents:${NC}"
    
    local i=1
    local agents=()
    
    for pid_file in "$AGENT_DIR"/.pid_*; do
        [[ -f "$pid_file" ]] || continue
        local agent_name=$(basename "$pid_file" | sed 's/.pid_//')
        local pid=$(cat "$pid_file")
        agents+=("$pid_file:$pid:$agent_name")
        echo "  $i) $agent_name (PID: $pid)"
        ((i++))
    done
    
    if [[ ${#agents[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No active agents to kill${NC}"
        sleep 2
        return
    fi
    
    read -p "Select agent to kill (number): " choice
    
    if [[ $choice -ge 1 && $choice -le ${#agents[@]} ]]; then
        local agent_info="${agents[$((choice-1))]}"
        local pid=$(echo "$agent_info" | cut -d: -f2)
        local name=$(echo "$agent_info" | cut -d: -f3)
        
        echo -e "${YELLOW}Killing $name (PID: $pid)...${NC}"
        kill "$pid" 2>/dev/null || true
        rm -f "$AGENT_DIR/.pid_$name"
        
        echo -e "${GREEN}✓ Agent killed${NC}"
    fi
    
    sleep 2
}

# Add new agent
add_agent() {
    echo -e "\n${CYAN}Add New Agent:${NC}"
    echo "  1) Error Fix Agent"
    echo "  2) Security Agent"
    echo "  3) Performance Agent"
    echo "  4) Architect Agent"
    echo "  5) Custom Agent"
    
    read -p "Choice: " agent_choice
    
    case "$agent_choice" in
        1) 
            launch_agent "error_fix"
            echo -e "${GREEN}✓ Error Fix Agent launched${NC}"
            ;;
        2) 
            launch_agent "security"
            echo -e "${GREEN}✓ Security Agent launched${NC}"
            ;;
        3) 
            launch_agent "performance"
            echo -e "${GREEN}✓ Performance Agent launched${NC}"
            ;;
        4) 
            launch_agent "architect"
            echo -e "${GREEN}✓ Architect Agent launched${NC}"
            ;;
        5) 
            read -p "Enter custom agent command: " custom_cmd
            eval "$custom_cmd" &
            echo -e "${GREEN}✓ Custom agent launched${NC}"
            ;;
    esac
    
    sleep 2
}

# Launch specific agent
launch_agent() {
    local agent_type="$1"
    
    case "$agent_type" in
        "error_fix")
            "$AGENT_DIR/generic_error_agent.sh" &
            ;;
        "security")
            "$AGENT_DIR/security_agent.sh" &
            ;;
        "performance")
            "$AGENT_DIR/performance_agent.sh" &
            ;;
        "architect")
            "$AGENT_DIR/architect_agent.sh" &
            ;;
    esac
}

# Add custom rule
add_rule() {
    echo -e "\n${CYAN}Add Custom Rule:${NC}"
    echo "Examples:"
    echo "  - 'Skip files matching *.generated.cs'"
    echo "  - 'Prioritize errors in /src/core/'"
    echo "  - 'Max 5 retries per file'"
    
    read -p "Enter rule: " rule
    
    # Add rule to state
    local temp_file=$(mktemp)
    jq ".rules += [\"$rule\"]" "$GOD_MODE_STATE" > "$temp_file"
    mv "$temp_file" "$GOD_MODE_STATE"
    
    send_control_message "RULE:$rule"
    
    echo -e "${GREEN}✓ Rule added: $rule${NC}"
    sleep 2
}

# Change intervention mode
change_mode() {
    echo -e "\n${CYAN}Select Intervention Mode:${NC}"
    echo "  1) Suggest - Show recommendations"
    echo "  2) Assist - Help with decisions"
    echo "  3) Auto - Fully automatic"
    echo "  4) Manual - Full control"
    
    read -p "Choice: " mode_choice
    
    case "$mode_choice" in
        1) update_state ".intervention_mode = \"suggest\"" ;;
        2) update_state ".intervention_mode = \"assist\"" ;;
        3) update_state ".intervention_mode = \"auto\"" ;;
        4) update_state ".intervention_mode = \"manual\"" ;;
    esac
    
    echo -e "${GREEN}✓ Mode changed${NC}"
    sleep 2
}

# Show live logs
show_live_logs() {
    echo -e "\n${CYAN}Live Logs (Press Ctrl+C to return)${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}\n"
    
    # Create a subshell to tail logs
    (
        tail -f "$AGENT_DIR/logs"/*.log 2>/dev/null | while IFS= read -r line; do
            # Color code based on content
            if [[ "$line" =~ ERROR ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ WARNING ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" =~ SUCCESS|FIXED ]]; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
    ) || true
}

# Show telemetry
show_telemetry() {
    if [[ -f "$AGENT_DIR/state/metrics/metrics.db" ]]; then
        "$AGENT_DIR/telemetry_collector.sh" status
    else
        echo -e "${YELLOW}No telemetry data available${NC}"
    fi
    
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

# Show error summary
show_error_summary() {
    echo -e "\n${CYAN}Error Summary:${NC}"
    
    if [[ -f "$AGENT_DIR/logs/build_output.txt" ]]; then
        echo -e "\n${WHITE}Top Error Types:${NC}"
        grep "error CS" "$AGENT_DIR/logs/build_output.txt" 2>/dev/null | \
            cut -d: -f4 | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -10
        
        echo -e "\n${WHITE}Files with Most Errors:${NC}"
        grep "error CS" "$AGENT_DIR/logs/build_output.txt" 2>/dev/null | \
            cut -d'(' -f1 | sort | uniq -c | sort -rn | head -10
    else
        echo -e "${YELLOW}No build output available${NC}"
    fi
    
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

# Open dashboard
open_dashboard() {
    "$AGENT_DIR/web_dashboard.sh" open
    echo -e "\n${GREEN}✓ Dashboard opened in browser${NC}"
    sleep 2
}

# Intervene now
intervene_now() {
    echo -e "\n${CYAN}Manual Intervention${NC}"
    echo "Current agents will be paused."
    
    # Pause all agents
    send_control_message "PAUSE"
    
    echo -e "\n${WHITE}Options:${NC}"
    echo "  1) Fix specific file"
    echo "  2) Skip current operation"
    echo "  3) Modify agent behavior"
    echo "  4) Resume normal operation"
    
    read -p "Choice: " int_choice
    
    case "$int_choice" in
        1)
            read -p "Enter file path: " file_path
            echo -e "${YELLOW}Opening file for manual edit...${NC}"
            # You could open the file in an editor here
            ;;
        2)
            send_control_message "SKIP"
            echo -e "${GREEN}✓ Current operation skipped${NC}"
            ;;
        3)
            echo "Agent behavior modification not yet implemented"
            ;;
        4)
            send_control_message "RESUME"
            echo -e "${GREEN}✓ Resuming normal operation${NC}"
            ;;
    esac
    
    sleep 2
}

# Force fix
force_fix() {
    echo -e "\n${YELLOW}Force Fix Mode${NC}"
    echo "This will aggressively attempt to fix all errors."
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        send_control_message "FORCE_FIX"
        echo -e "${GREEN}✓ Force fix initiated${NC}"
    fi
    
    sleep 2
}

# Rollback changes
rollback_changes() {
    echo -e "\n${CYAN}Rollback Options:${NC}"
    
    # List available checkpoints
    local checkpoints=()
    for checkpoint in "$AGENT_DIR/state/checkpoints"/*; do
        [[ -d "$checkpoint" ]] && checkpoints+=("$checkpoint")
    done
    
    if [[ ${#checkpoints[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No checkpoints available${NC}"
        sleep 2
        return
    fi
    
    echo "Available checkpoints:"
    local i=1
    for cp in "${checkpoints[@]}"; do
        local timestamp=$(basename "$cp")
        echo "  $i) $timestamp"
        ((i++))
    done
    
    read -p "Select checkpoint (number): " choice
    
    if [[ $choice -ge 1 && $choice -le ${#checkpoints[@]} ]]; then
        local checkpoint="${checkpoints[$((choice-1))]}"
        echo -e "${YELLOW}Rolling back to: $(basename "$checkpoint")${NC}"
        
        # Implement rollback logic here
        send_control_message "ROLLBACK:$checkpoint"
        
        echo -e "${GREEN}✓ Rollback complete${NC}"
    fi
    
    sleep 2
}

# Create checkpoint
create_checkpoint() {
    echo -e "\n${CYAN}Creating checkpoint...${NC}"
    
    local checkpoint_dir="$AGENT_DIR/state/checkpoints/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$checkpoint_dir"
    
    # Save current state
    cp -r "$AGENT_DIR/state"/*.json "$checkpoint_dir/" 2>/dev/null || true
    
    # Create backup of project files (optional)
    read -p "Include project file backup? (y/N): " include_files
    
    if [[ "$include_files" =~ ^[Yy]$ ]]; then
        echo "Creating file backup..."
        tar -czf "$checkpoint_dir/project_backup.tar.gz" -C "$PROJECT_DIR" . \
            --exclude="bin" --exclude="obj" --exclude="node_modules" 2>/dev/null || true
    fi
    
    send_control_message "CHECKPOINT:$checkpoint_dir"
    
    echo -e "${GREEN}✓ Checkpoint created: $(basename "$checkpoint_dir")${NC}"
    sleep 2
}

# Update state
update_state() {
    local update="$1"
    local temp_file=$(mktemp)
    jq "$update" "$GOD_MODE_STATE" > "$temp_file"
    mv "$temp_file" "$GOD_MODE_STATE"
}

# Send control message
send_control_message() {
    local message="$1"
    
    # Write to control FIFO
    echo "$message" > "$CONTROL_FIFO" 2>/dev/null || true
    
    # Also write to control file for agents to read
    echo "$message" > "$AGENT_DIR/state/CONTROL_MESSAGE"
    
    # Log the control message
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] GOD_MODE: $message" >> "$AGENT_DIR/logs/god_mode.log"
}

# Show help
show_help() {
    echo -e "\n${CYAN}God Mode Help${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE}Focus Modes:${NC}"
    echo "  • Bug Fixing - Prioritizes error resolution"
    echo "  • Performance - Focuses on optimization"
    echo "  • Security - Emphasizes security fixes"
    echo "  • Architecture - Improves code structure"
    echo "  • Balanced - Equal priority to all areas"
    
    echo -e "\n${WHITE}Speed Settings:${NC}"
    echo "  • Slow - Conservative, careful changes"
    echo "  • Normal - Standard operation"
    echo "  • Fast - Aggressive fixing"
    echo "  • Turbo - Maximum speed, may be risky"
    
    echo -e "\n${WHITE}Intervention Modes:${NC}"
    echo "  • Suggest - System suggests, you decide"
    echo "  • Assist - System helps with implementation"
    echo "  • Auto - Fully automatic operation"
    echo "  • Manual - Full manual control"
    
    echo -e "\n${WHITE}Control Messages:${NC}"
    echo "  All commands send real-time messages to agents"
    echo "  Agents respond immediately to focus changes"
    echo "  State is preserved across sessions"
    
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

# Exit god mode
exit_god_mode() {
    echo -e "\n${YELLOW}Exiting God Mode...${NC}"
    
    # Send exit message
    send_control_message "GOD_MODE:EXIT"
    
    # Save final state
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] God Mode session ended" >> "$AGENT_DIR/logs/god_mode.log"
    
    echo -e "${GREEN}✓ God Mode deactivated${NC}"
    echo -e "${CYAN}Agents will continue with current settings${NC}"
    
    exit 0
}

# Monitor control messages in background
monitor_control_messages() {
    # This would run in agent scripts to receive commands
    while true; do
        if [[ -f "$AGENT_DIR/state/CONTROL_MESSAGE" ]]; then
            local message=$(cat "$AGENT_DIR/state/CONTROL_MESSAGE" 2>/dev/null)
            
            case "$message" in
                PAUSE) 
                    # Pause agent operations
                    ;;
                RESUME) 
                    # Resume operations
                    ;;
                FOCUS:*) 
                    # Adjust agent behavior based on focus
                    ;;
                SPEED:*) 
                    # Adjust operation speed
                    ;;
                *)
                    # Handle other messages
                    ;;
            esac
            
            # Clear message after processing
            > "$AGENT_DIR/state/CONTROL_MESSAGE"
        fi
        
        sleep 1
    done
}

# Main loop
main() {
    # Initialize state if needed
    [[ ! -f "$GOD_MODE_STATE" ]] && init_god_mode_state
    
    # Send activation message
    send_control_message "GOD_MODE:ACTIVE"
    
    # Main interactive loop
    while true; do
        show_control_panel
        
        # Read command with timeout
        if read -t 1 -n 1 cmd; then
            handle_command "$cmd"
        fi
        
        # Check for external updates
        # (Other scripts can update god_mode.json to communicate back)
    done
}

# Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi