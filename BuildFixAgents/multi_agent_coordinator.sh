#!/bin/bash

# Multi-Agent Build Error Fix Coordinator
# Orchestrates the 4-agent system for systematic build error resolution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
COORDINATION_FILE="$SCRIPT_DIR/AGENT_COORDINATION.md"
BUILD_CHECKER="$SCRIPT_DIR/build_checker_agent.sh"
AGENT1="$SCRIPT_DIR/agent1_duplicate_resolver.sh"
AGENT2="$SCRIPT_DIR/agent2_constraints_specialist.sh"
AGENT3="$SCRIPT_DIR/agent3_inheritance_specialist.sh"

# Configuration
MAX_ITERATIONS=10
SIMULATION_MODE=false
EMERGENCY_STOP=false

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] COORDINATOR: $message" | tee -a "$LOG_FILE"
}

# Display banner
show_banner() {
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║           MULTI-AGENT BUILD ERROR FIX COORDINATOR             ║
║                                                                ║
║  🤖 Build Checker Agent (Supervisor)                          ║
║  🔧 Agent 1: Duplicate Resolution Specialist                   ║
║  ⚙️  Agent 2: Constraints & Compatibility Specialist          ║
║  🔗 Agent 3: Inheritance & Override Specialist                ║
║                                                                ║
║  Target: AiDotNet C# Project (.NET Framework 4.6.2+)         ║
╚════════════════════════════════════════════════════════════════╝
EOF
}

# Check system dependencies
check_dependencies() {
    log_message "Checking system dependencies..."
    
    # Check if all agent scripts exist and are executable
    local agents=("$BUILD_CHECKER" "$AGENT1" "$AGENT2" "$AGENT3")
    
    for agent in "${agents[@]}"; do
        if [[ ! -f "$agent" ]]; then
            log_message "ERROR: Agent script not found: $agent"
            return 1
        fi
        
        if [[ ! -x "$agent" ]]; then
            log_message "ERROR: Agent script not executable: $agent"
            return 1
        fi
    done
    
    # Check if dotnet is available
    if ! command -v dotnet &> /dev/null; then
        log_message "ERROR: dotnet CLI not found"
        return 1
    fi
    
    # Check if coordination file exists
    if [[ ! -f "$COORDINATION_FILE" ]]; then
        log_message "ERROR: Coordination file not found: $COORDINATION_FILE"
        return 1
    fi
    
    log_message "All dependencies checked successfully"
    return 0
}

# Clean up file locks
cleanup_locks() {
    log_message "Cleaning up file locks..."
    rm -f "$SCRIPT_DIR"/.lock_*
    log_message "File locks cleared"
}

# Emergency stop handler
emergency_stop() {
    log_message "EMERGENCY STOP TRIGGERED"
    EMERGENCY_STOP=true
    cleanup_locks
    
    # Stop any running agents (they should check EMERGENCY_STOP flag)
    log_message "Emergency stop complete"
    exit 1
}

# Set up signal handlers
setup_signal_handlers() {
    trap emergency_stop SIGINT SIGTERM
}

# Run build checker to establish baseline
run_build_checker() {
    log_message "Phase 1: Running Build Checker Agent to establish baseline..."
    
    if [[ "$SIMULATION_MODE" == "true" ]]; then
        log_message "SIMULATION: Would run build checker"
        return 0
    fi
    
    if "$BUILD_CHECKER" main; then
        log_message "Build checker completed successfully"
        return 0
    else
        log_message "Build checker failed or found errors to fix"
        return 1
    fi
}

# Deploy worker agents sequentially
deploy_worker_agents() {
    local iteration="$1"
    log_message "Phase 2: Deploying worker agents for iteration $iteration..."
    
    local agents_success=0
    local total_agents=3
    
    # Agent 1: Duplicate Resolution
    log_message "Deploying Agent 1 - Duplicate Resolution Specialist..."
    if [[ "$SIMULATION_MODE" == "true" ]]; then
        log_message "SIMULATION: Would run Agent 1"
        agents_success=$((agents_success + 1))
    else
        if "$AGENT1" main; then
            log_message "Agent 1 completed successfully"
            agents_success=$((agents_success + 1))
        else
            log_message "Agent 1 failed or encountered issues"
        fi
    fi
    
    # Agent 2: Constraints Specialist
    log_message "Deploying Agent 2 - Constraints & Compatibility Specialist..."
    if [[ "$SIMULATION_MODE" == "true" ]]; then
        log_message "SIMULATION: Would run Agent 2"
        agents_success=$((agents_success + 1))
    else
        if "$AGENT2" main; then
            log_message "Agent 2 completed successfully"
            agents_success=$((agents_success + 1))
        else
            log_message "Agent 2 failed or encountered issues"
        fi
    fi
    
    # Agent 3: Inheritance Specialist
    log_message "Deploying Agent 3 - Inheritance & Override Specialist..."
    if [[ "$SIMULATION_MODE" == "true" ]]; then
        log_message "SIMULATION: Would run Agent 3"
        agents_success=$((agents_success + 1))
    else
        if "$AGENT3" main; then
            log_message "Agent 3 completed successfully"
            agents_success=$((agents_success + 1))
        else
            log_message "Agent 3 failed or encountered issues"
        fi
    fi
    
    log_message "Worker agent deployment complete: $agents_success/$total_agents agents successful"
    return 0
}

# Validate iteration results
validate_iteration() {
    local iteration="$1"
    log_message "Phase 3: Validating iteration $iteration results..."
    
    if [[ "$SIMULATION_MODE" == "true" ]]; then
        log_message "SIMULATION: Would validate results"
        return 0
    fi
    
    # Run build checker again to see if errors were reduced
    if "$BUILD_CHECKER" build; then
        log_message "Final build validation completed"
        return 0
    else
        log_message "Build validation found remaining issues"
        return 1
    fi
}

# Main coordination loop
run_coordination_loop() {
    log_message "Starting multi-agent coordination loop..."
    
    local iteration=1
    local initial_errors=0
    local current_errors=0
    
    while [[ $iteration -le $MAX_ITERATIONS ]]; do
        if [[ "$EMERGENCY_STOP" == "true" ]]; then
            log_message "Emergency stop detected, terminating coordination loop"
            break
        fi
        
        log_message "=== ITERATION $iteration/$MAX_ITERATIONS ==="
        local start_time=$(date +%s)
        
        # Phase 1: Build Checker
        if ! run_build_checker; then
            log_message "Build checker indicates work needed"
        fi
        
        # Get current error count
        if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
            current_errors=$(cat "$SCRIPT_DIR/build_error_count.txt")
            if [[ $iteration -eq 1 ]]; then
                initial_errors=$current_errors
            fi
            log_message "Current error count: $current_errors"
        fi
        
        # Check if we're done
        if [[ $current_errors -eq 0 ]]; then
            log_message "🎉 SUCCESS: All errors resolved!"
            break
        fi
        
        # Phase 2: Deploy Worker Agents
        deploy_worker_agents $iteration
        
        # Phase 3: Validate Results
        validate_iteration $iteration
        
        # Check progress
        if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
            local new_errors=$(cat "$SCRIPT_DIR/build_error_count.txt")
            if [[ $new_errors -lt $current_errors ]]; then
                local reduction=$((current_errors - new_errors))
                log_message "✅ Progress: Reduced errors by $reduction (${current_errors}→${new_errors})"
            elif [[ $new_errors -eq $current_errors ]]; then
                log_message "⚠️  No progress: Error count unchanged"
            else
                log_message "❌ Regression: Error count increased"
            fi
        fi
        
        iteration=$((iteration + 1))
        
        # Brief pause between iterations
        if [[ $iteration -le $MAX_ITERATIONS ]]; then
            log_message "Waiting 5 seconds before next iteration..."
            sleep 5
        fi
    done
    
    # Final summary
    log_message "=== COORDINATION COMPLETE ==="
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        local final_errors=$(cat "$SCRIPT_DIR/build_error_count.txt")
        local total_reduction=$((initial_errors - final_errors))
        log_message "Final Results: $initial_errors → $final_errors errors (-$total_reduction)"
        
        if [[ $final_errors -eq 0 ]]; then
            log_message "🎉 SUCCESS: All build errors resolved!"
        elif [[ $total_reduction -gt 0 ]]; then
            log_message "📈 PROGRESS: Reduced errors by $total_reduction"
        else
            log_message "⚠️  LIMITED PROGRESS: Manual intervention may be required"
        fi
    fi
}

# Main function
main() {
    show_banner
    log_message "Multi-Agent Build Error Fix Coordinator starting..."
    
    # Setup
    setup_signal_handlers
    
    # Check dependencies
    if ! check_dependencies; then
        log_message "Dependency check failed"
        exit 1
    fi
    
    # Clean up any existing locks
    cleanup_locks
    
    # Run the coordination loop
    run_coordination_loop
    
    # Final cleanup
    cleanup_locks
    
    log_message "Multi-Agent Coordinator complete"
}

# Parse command line arguments
case "${1:-execute}" in
    "simulation")
        SIMULATION_MODE=true
        log_message "Running in SIMULATION mode"
        main
        ;;
    "execute")
        SIMULATION_MODE=false
        log_message "Running in EXECUTION mode"
        main
        ;;
    "resume")
        SIMULATION_MODE=false
        log_message "Resuming from previous state"
        # Could add logic to restore previous state here
        main
        ;;
    "status")
        if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
            echo "Current error count: $(cat "$SCRIPT_DIR/build_error_count.txt")"
        else
            echo "No error count available"
        fi
        
        if [[ -f "$LOG_FILE" ]]; then
            echo "Last 10 log entries:"
            tail -10 "$LOG_FILE"
        fi
        ;;
    "cleanup")
        cleanup_locks
        echo "File locks cleaned up"
        ;;
    *)
        echo "Usage: $0 {simulation|execute|resume|status|cleanup}"
        echo ""
        echo "  simulation  - Test the system without making actual changes"
        echo "  execute     - Run the system and make actual changes"
        echo "  resume      - Resume from previous state"
        echo "  status      - Show current system status"
        echo "  cleanup     - Clean up file locks"
        exit 1
        ;;
esac