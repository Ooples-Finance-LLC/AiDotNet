#!/bin/bash

# Batch Phase Runner - Runs master_fix_coordinator.sh phases within 2-minute limits
# Automatically manages execution to stay under timeout constraints

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         Batch Phase Runner - 2-Minute Compliance             ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

# Function to run a phase with timeout
run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local timeout_sec="${3:-110}" # Default 110 seconds (under 2 minutes)
    
    echo -e "\n${BOLD}${YELLOW}Running Phase $phase_num: $phase_name${NC}"
    echo -e "${CYAN}Timeout: ${timeout_sec}s${NC}"
    
    # Create a status file
    local status_file="$SCRIPT_DIR/state/.phase_${phase_num}_status"
    
    # Check if phase already completed
    if [[ -f "$status_file" ]] && grep -q "completed" "$status_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Phase $phase_num already completed${NC}"
        return 0
    fi
    
    # Run the phase with timeout
    if timeout ${timeout_sec}s bash "$SCRIPT_DIR/master_fix_coordinator.sh" "$phase_num"; then
        echo "completed" > "$status_file"
        echo -e "${GREEN}✓ Phase $phase_num completed successfully${NC}"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${YELLOW}⚠ Phase $phase_num timed out after ${timeout_sec}s${NC}"
            echo "timeout" > "$status_file"
        else
            echo -e "${RED}✗ Phase $phase_num failed with exit code $exit_code${NC}"
            echo "failed:$exit_code" > "$status_file"
        fi
    fi
    
    # Short pause between phases
    sleep 2
}

# Function to run fix phase in batches
run_fix_batches() {
    local max_batches="${1:-5}"
    
    echo -e "\n${BOLD}${CYAN}=== Running Fix Phase in Batches ===${NC}"
    
    for batch in $(seq 1 $max_batches); do
        local status_file="$SCRIPT_DIR/state/.phase_4_batch_${batch}_status"
        
        if [[ -f "$status_file" ]] && grep -q "completed" "$status_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Fix batch $batch already completed${NC}"
            continue
        fi
        
        echo -e "\n${YELLOW}Running Fix Batch $batch of $max_batches${NC}"
        
        if timeout 110s bash "$SCRIPT_DIR/master_fix_coordinator.sh" "fix" "$batch"; then
            echo "completed" > "$status_file"
            echo -e "${GREEN}✓ Fix batch $batch completed${NC}"
        else
            echo -e "${YELLOW}Fix batch $batch incomplete - will continue in next run${NC}"
            break
        fi
        
        sleep 2
    done
}

# Main execution
main() {
    # Ensure state directory exists
    mkdir -p "$SCRIPT_DIR/state"
    
    # Check for resume mode
    if [[ "${1:-}" == "--resume" ]]; then
        echo -e "${CYAN}Resuming from last checkpoint...${NC}"
    elif [[ "${1:-}" == "--reset" ]]; then
        echo -e "${YELLOW}Resetting all phase statuses...${NC}"
        rm -f "$SCRIPT_DIR/state/.phase_*_status"
    fi
    
    # Run each phase with appropriate timeout
    run_phase 1 "Analysis & Management Setup" 110
    run_phase 2 "Performance & Learning Analysis" 110
    run_phase 3 "Deploy Fix Agents" 110
    
    # Run fix phase in batches
    run_fix_batches 5
    
    # Continue with remaining phases
    run_phase 5 "Quality Assurance" 110
    run_phase 6 "System Testing" 110
    run_phase 7 "Generate Reports" 60
    
    # Final status
    echo -e "\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                  All Phases Complete!                          ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    # Show summary
    echo -e "\n${CYAN}Phase Summary:${NC}"
    for phase in {1..7}; do
        local status_file="$SCRIPT_DIR/state/.phase_${phase}_status"
        if [[ -f "$status_file" ]]; then
            local status=$(cat "$status_file")
            case "$status" in
                completed)
                    echo -e "  Phase $phase: ${GREEN}✓ Completed${NC}"
                    ;;
                timeout)
                    echo -e "  Phase $phase: ${YELLOW}⚠ Timed out${NC}"
                    ;;
                failed:*)
                    echo -e "  Phase $phase: ${RED}✗ Failed${NC}"
                    ;;
                *)
                    echo -e "  Phase $phase: ${YELLOW}? Unknown${NC}"
                    ;;
            esac
        else
            echo -e "  Phase $phase: ${YELLOW}- Not run${NC}"
        fi
    done
    
    echo -e "\n${CYAN}To resume incomplete phases, run:${NC}"
    echo -e "  ${YELLOW}$0 --resume${NC}"
}

# Run main with all arguments
main "$@"