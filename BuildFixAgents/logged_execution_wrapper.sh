#!/bin/bash
# Wrapper script that adds comprehensive logging to any BuildFixAgents execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the enhanced logging system
source "$SCRIPT_DIR/enhanced_logging_system.sh"

# Track execution time
EXECUTION_START=$(date +%s)

# Log system initialization
log_event "INFO" "SYSTEM" "BuildFixAgents/ZeroDev starting with enhanced logging"
log_event "INFO" "SYSTEM" "Command: $*"

# Trap to ensure summary is generated
cleanup() {
    local exit_code=$?
    EXECUTION_END=$(date +%s)
    EXECUTION_DURATION=$((EXECUTION_END - EXECUTION_START))
    
    log_event "INFO" "SYSTEM" "Execution completed" "Duration: ${EXECUTION_DURATION}s, Exit code: $exit_code"
    
    # Generate summary report
    generate_execution_summary
    
    # Show summary locations
    echo -e "\n${BOLD}${GREEN}Execution Complete!${NC}"
    echo -e "${CYAN}Logs available at:${NC}"
    echo -e "  📄 Master Log: $MASTER_LOG"
    echo -e "  📊 Agent Status: $AGENT_STATUS_LOG"
    echo -e "  📋 Task Tracking: $TASK_TRACKING_LOG"
    echo -e "  🔍 Debug Log: $DEBUG_LOG"
    echo -e "  📈 Summary: $HUMAN_LOG_DIR/execution_summary_*.md"
}
trap cleanup EXIT

# Example of how to wrap agent execution with logging
run_agent_with_logging() {
    local agent_script="$1"
    local agent_name="$(basename "$agent_script" .sh)"
    shift
    
    log_agent_start "$agent_name" "$*"
    
    # Run the agent and capture output
    local start_time=$(date +%s.%N)
    local exit_code=0
    
    if bash "$agent_script" "$@" 2>&1 | while IFS= read -r line; do
        # Parse agent output for important events
        if [[ "$line" =~ "Task:" ]]; then
            local task_id=$(create_task "$agent_name" "$line" "NORMAL")
            start_task "$task_id" "$agent_name"
        elif [[ "$line" =~ "✓" ]] || [[ "$line" =~ "Success" ]]; then
            log_event "SUCCESS" "$agent_name" "$line"
        elif [[ "$line" =~ "Error" ]] || [[ "$line" =~ "Failed" ]]; then
            log_event "ERROR" "$agent_name" "$line"
        else
            log_event "DEBUG" "$agent_name" "$line"
        fi
        echo "$line"  # Pass through original output
    done; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if [[ $exit_code -eq 0 ]]; then
        log_agent_complete "$agent_name" "Execution time: ${duration}s"
    else
        log_agent_error "$agent_name" "Exit code: $exit_code"
    fi
    
    return $exit_code
}

# Main execution
case "${1:-help}" in
    autofix)
        log_event "INFO" "SYSTEM" "Running autofix with comprehensive logging"
        run_agent_with_logging "$SCRIPT_DIR/autofix.sh" "${@:2}"
        ;;
    zerodev)
        log_event "INFO" "SYSTEM" "Running ZeroDev with comprehensive logging"
        shift
        # For ZeroDev, we need to handle the main script differently
        source "$SCRIPT_DIR/enhanced_logging_system.sh"
        bash "$SCRIPT_DIR/../zerodev.sh" "$@" 2>&1 | while IFS= read -r line; do
            # Parse ZeroDev output
            if [[ "$line" =~ "Creating new project" ]]; then
                log_event "TASK" "ZERODEV" "$line"
            elif [[ "$line" =~ "✓" ]]; then
                log_event "SUCCESS" "ZERODEV" "$line"
            else
                log_event "INFO" "ZERODEV" "$line"
            fi
            echo "$line"
        done
        ;;
    orchestrate)
        log_event "INFO" "SYSTEM" "Running full orchestration with logging"
        # Run enhanced coordinator with integrated logging
        source "$SCRIPT_DIR/enhanced_logging_system.sh"
        bash "$SCRIPT_DIR/enhanced_coordinator_v2.sh" orchestrate
        ;;
    test)
        # Test the logging system
        log_event "INFO" "TEST" "Testing logging system"
        
        # Simulate agent lifecycle
        log_agent_start "test_agent" "testing"
        sleep 0.5
        
        # Create and process tasks
        task1=$(create_task "test_agent" "Compile project" "HIGH")
        assign_task "$task1" "compiler_agent"
        start_task "$task1" "compiler_agent"
        sleep 0.5
        complete_task "$task1" "compiler_agent" "Compiled successfully"
        
        task2=$(create_task "test_agent" "Run tests" "NORMAL")
        start_task "$task2" "test_agent"
        sleep 0.5
        fail_task "$task2" "test_agent" "Test suite failed: 2 tests failed"
        
        # Log some decisions
        log_decision "test_agent" "Skip optional features" "Time constraints"
        log_communication "test_agent" "coordinator" "STATUS_UPDATE" "Ready for next phase"
        
        log_agent_complete "test_agent" "Test completed with 1 failure"
        ;;
    *)
        echo "Usage: $0 {autofix|zerodev|orchestrate|test} [options]"
        echo ""
        echo "This wrapper adds comprehensive logging to BuildFixAgents execution."
        echo "All agent activities, tasks, and decisions are logged for debugging."
        exit 1
        ;;
esac