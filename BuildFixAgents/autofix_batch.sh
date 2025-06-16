#!/bin/bash

# Batch Mode Autofix - Works within 2-minute execution constraints
# Processes errors in small batches across multiple runs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Source debug utilities
if [[ -f "$SCRIPT_DIR/debug_utils.sh" ]]; then
    source "$SCRIPT_DIR/debug_utils.sh"
else
    # Fallback if debug_utils.sh not found
    DEBUG="${DEBUG:-false}"
    VERBOSE="${VERBOSE:-false}"
    TIMING="${TIMING:-false}"
    debug() { :; }
    verbose() { :; }
    start_timer() { :; }
    end_timer() { :; }
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Batch configuration
BATCH_SIZE="${BATCH_SIZE:-10}"
BATCH_STATE_FILE="$SCRIPT_DIR/state/.batch_state"
CACHED_COUNT_FILE="$SCRIPT_DIR/state/.error_count_cache"
MAX_TIME=90  # Leave 30s buffer before 2-minute limit

# Unicode characters
CHECK="✓"
CROSS="✗"
ARROW="→"

show_banner() {
    echo -e "${CYAN}
╔════════════════════════════════════════════════════════════════╗
║           🚀 Batch Mode Autofix - Fast & Efficient 🚀         ║
║         Processes $BATCH_SIZE errors per run (2-min limit)         ║
╚════════════════════════════════════════════════════════════════╝${NC}"
    show_debug_status
}

# Fast error counting - use cache if recent
get_error_count_fast() {
    source "$SCRIPT_DIR/state/state_management/error_count_manager.sh"
    get_error_count
}

# Load batch state
load_batch_state() {
    if [[ -f "$BATCH_STATE_FILE" ]]; then
        source "$BATCH_STATE_FILE"
    else
        BATCH_NUMBER=0
        TOTAL_FIXED=0
        LAST_ERROR_COUNT=0
    fi
}

# Save batch state
save_batch_state() {
    mkdir -p "$(dirname "$BATCH_STATE_FILE")"
    cat > "$BATCH_STATE_FILE" << EOF
BATCH_NUMBER=$BATCH_NUMBER
TOTAL_FIXED=$TOTAL_FIXED
LAST_ERROR_COUNT=$LAST_ERROR_COUNT
LAST_RUN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
}

# Clear all state
clear_state() {
    echo -e "${YELLOW}Clearing batch state...${NC}"
    rm -f "$BATCH_STATE_FILE" "$CACHED_COUNT_FILE"
    rm -f "$SCRIPT_DIR/state/.autofix_state"
    echo -e "${GREEN}$CHECK State cleared${NC}"
}

# Run one batch
run_batch() {
    local start_time=$(date +%s)
    
    # Get current error count
    local current_errors=$(get_error_count_fast)
    
    if [[ $current_errors -eq 0 ]]; then
        echo -e "${GREEN}$CHECK No errors found! Build is clean.${NC}"
        clear_state
        return 0
    fi
    
    # Calculate batches needed
    local batches_needed=$(( (current_errors + BATCH_SIZE - 1) / BATCH_SIZE ))
    BATCH_NUMBER=$((BATCH_NUMBER + 1))
    
    echo -e "${BOLD}Batch $BATCH_NUMBER of ~$batches_needed${NC}"
    echo -e "${BLUE}Errors remaining: $current_errors${NC}"
    
    # Check if we have time to run
    local elapsed=$(($(date +%s) - start_time))
    if [[ $elapsed -gt $MAX_TIME ]]; then
        echo -e "${YELLOW}⚠ Approaching time limit, saving progress...${NC}"
        save_batch_state
        return 1
    fi
    
    # Run quick analysis (skip full build analysis to save time)
    echo -e "${BLUE}$ARROW Analyzing next $BATCH_SIZE errors...${NC}"
    
    # Create minimal agent spec for batch
    mkdir -p "$SCRIPT_DIR/state"
    cat > "$SCRIPT_DIR/state/agent_specifications.json" << EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent_specifications": [
    {
      "agent_id": "batch_agent_1",
      "name": "batch_fixer",
      "specialization": "all",
      "target_errors": ["CS0101", "CS0111", "CS0462"],
      "priority": 1,
      "estimated_workload": $BATCH_SIZE,
      "batch_mode": true
    }
  ],
  "coordination_strategy": "batch",
  "max_concurrent_agents": 1,
  "batch_size": $BATCH_SIZE
}
EOF
    
    # Run coordinator with time limit
    local remaining_time=$((MAX_TIME - elapsed))
    echo -e "${BLUE}$ARROW Deploying batch fix agent (${remaining_time}s available)...${NC}"
    
    if timeout ${remaining_time}s bash "$SCRIPT_DIR/generic_agent_coordinator.sh" execute batch; then
        echo -e "${GREEN}$CHECK Batch completed${NC}"
    else
        echo -e "${YELLOW}⚠ Batch timed out${NC}"
    fi
    
    # Quick recount
    local new_count=$(get_error_count_fast)
    local fixed=$((current_errors - new_count))
    
    if [[ $fixed -gt 0 ]]; then
        TOTAL_FIXED=$((TOTAL_FIXED + fixed))
        echo -e "${GREEN}$CHECK Fixed $fixed errors in this batch${NC}"
        echo -e "${GREEN}Total fixed so far: $TOTAL_FIXED${NC}"
    else
        echo -e "${YELLOW}No errors fixed in this batch${NC}"
    fi
    
    LAST_ERROR_COUNT=$new_count
    save_batch_state
    
    if [[ $new_count -gt 0 ]]; then
        echo -e "\n${CYAN}Run again to process next batch${NC}"
        echo -e "${BLUE}Remaining errors: $new_count${NC}"
    fi
    
    return 0
}

# Cleanup on exit
cleanup() {
    debug_cleanup
}

trap cleanup EXIT

# Main execution
main() {
    case "${1:-run}" in
        "run"|"batch")
            show_banner
            load_batch_state
            run_batch
            ;;
        "status")
            load_batch_state
            echo -e "${CYAN}Batch Autofix Status${NC}"
            echo -e "Last run: ${LAST_RUN:-Never}"
            echo -e "Batches completed: $BATCH_NUMBER"
            echo -e "Total errors fixed: $TOTAL_FIXED"
            echo -e "Last error count: $LAST_ERROR_COUNT"
            
            # Get fresh count if requested
            if [[ "${2:-}" == "--fresh" ]]; then
                FORCE_FRESH=true
                local current=$(get_error_count_fast)
                echo -e "Current error count: $current"
            fi
            ;;
        "clear"|"reset")
            clear_state
            ;;
        "help"|"-h"|"--help")
            echo "Batch Mode Autofix - Processes errors in small batches"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  run/batch  - Run one batch of fixes (default)"
            echo "  status     - Show current progress"
            echo "  clear      - Clear state and start fresh"
            echo "  help       - Show this help"
            echo ""
            echo "Options:"
            echo "  BATCH_SIZE=N  - Set batch size (default: 10)"
            echo "  --fresh       - Force fresh error count (with status)"
            echo ""
            echo "Example:"
            echo "  BATCH_SIZE=20 $0 run"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"