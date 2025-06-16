#!/bin/bash

# Generic Multi-Agent Coordinator
# Dynamically creates and manages agents based on error analysis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
COORDINATION_FILE="$SCRIPT_DIR/AGENT_COORDINATION.md"
AGENT_SPEC_FILE="$SCRIPT_DIR/agent_specifications.json"
STATE_FILE="$SCRIPT_DIR/coordinator_state.json"

# Configuration
MAX_ITERATIONS=20
MAX_CONCURRENT_AGENTS=3
MODE="${1:-execute}"  # simulate, execute, or resume

# Initialize logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] COORDINATOR [$level]: $message" | tee -a "$LOG_FILE"
}

# Initialize coordination file
init_coordination_file() {
    cat > "$COORDINATION_FILE" << EOF
# Generic Multi-Agent Build Error Resolution
Generated: $(date)

## System Configuration
- Mode: $MODE
- Max Iterations: $MAX_ITERATIONS
- Max Concurrent Agents: $MAX_CONCURRENT_AGENTS

## Agent Status
EOF
}

# Save coordinator state
save_state() {
    local iteration="$1"
    local active_agents="$2"
    local completed_agents="$3"
    
    cat > "$STATE_FILE" << EOF
{
  "last_iteration": $iteration,
  "last_update": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "active_agents": [$active_agents],
  "completed_agents": [$completed_agents],
  "mode": "$MODE"
}
EOF
}

# Load previous state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        LAST_ITERATION=$(grep '"last_iteration":' "$STATE_FILE" | grep -oE '[0-9]+' || echo "0")
        log_message "Resuming from iteration $LAST_ITERATION"
    else
        LAST_ITERATION=0
    fi
}

# Run build analysis
analyze_build() {
    log_message "Running build analysis..."
    
    # Execute the generic build analyzer
    bash "$SCRIPT_DIR/generic_build_analyzer.sh" main
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "No agent specifications generated - build might be clean" "WARN"
        return 1
    fi
    
    # Count total agents needed
    local agent_count=$(grep -c '"agent_id":' "$AGENT_SPEC_FILE" || echo "0")
    log_message "Analysis complete - $agent_count specialized agents required"
    
    return 0
}

# Deploy agents based on specifications
deploy_agents() {
    local iteration="$1"
    local deployed_count=0
    local active_agents=""
    
    log_message "Deploying agents for iteration $iteration"
    
    # Read agent specifications
    local agents=$(grep '"agent_id":' "$AGENT_SPEC_FILE" | cut -d'"' -f4)
    
    # Deploy up to MAX_CONCURRENT_AGENTS
    while IFS= read -r agent_id; do
        [[ -z "$agent_id" ]] && continue
        [[ $deployed_count -ge $MAX_CONCURRENT_AGENTS ]] && break
        
        local agent_name=$(grep -A2 "\"agent_id\": \"$agent_id\"" "$AGENT_SPEC_FILE" | grep '"name":' | cut -d'"' -f4)
        local workload=$(grep -A6 "\"agent_id\": \"$agent_id\"" "$AGENT_SPEC_FILE" | grep '"estimated_workload":' | grep -oE '[0-9]+')
        
        # Skip if no workload
        [[ -z "$workload" || "$workload" -eq 0 ]] && continue
        
        log_message "Deploying $agent_name (workload: $workload errors)"
        
        if [[ "$MODE" == "execute" ]]; then
            # Actually run the agent
            (
                bash "$SCRIPT_DIR/generic_error_agent.sh" "$agent_id" "$AGENT_SPEC_FILE" &
                echo $! > "$SCRIPT_DIR/.pid_$agent_id"
            ) &
            
            active_agents="$active_agents\"$agent_id\","
            deployed_count=$((deployed_count + 1))
        else
            # Simulation mode
            log_message "[SIMULATE] Would deploy $agent_name"
            deployed_count=$((deployed_count + 1))
        fi
        
    done <<< "$agents"
    
    # Remove trailing comma
    active_agents=${active_agents%,}
    
    log_message "Deployed $deployed_count agents"
    
    # Update coordination file
    {
        echo ""
        echo "## Iteration $iteration - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Deployed agents: $deployed_count"
    } >> "$COORDINATION_FILE"
    
    return $deployed_count
}

# Monitor agent progress
monitor_agents() {
    local iteration="$1"
    local monitoring=true
    local check_interval=5
    
    log_message "Monitoring agent progress..."
    
    while $monitoring; do
        sleep $check_interval
        
        # Check each agent's status
        local active_count=0
        local agent_pids=$(ls "$SCRIPT_DIR"/.pid_agent_* 2>/dev/null || true)
        
        for pid_file in $agent_pids; do
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    active_count=$((active_count + 1))
                else
                    # Agent finished
                    rm -f "$pid_file"
                fi
            fi
        done
        
        log_message "Active agents: $active_count"
        
        if [[ $active_count -eq 0 ]]; then
            monitoring=false
        fi
    done
    
    log_message "All agents completed for iteration $iteration"
}

# Evaluate iteration results
evaluate_iteration() {
    local iteration="$1"
    
    log_message "Evaluating iteration $iteration results..."
    
    # Run build checker to get current state
    bash "$SCRIPT_DIR/build_checker_agent.sh" main
    
    # Check if errors remain
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        local error_count=$(cat "$SCRIPT_DIR/build_error_count.txt")
        log_message "Current error count: $error_count"
        
        if [[ $error_count -eq 0 ]]; then
            log_message "BUILD SUCCESSFUL! All errors resolved." "SUCCESS"
            return 0
        fi
    fi
    
    return 1
}

# Main coordination loop
run_coordination() {
    local iteration=${LAST_ITERATION:-1}
    local continue_processing=true
    
    while $continue_processing && [[ $iteration -le $MAX_ITERATIONS ]]; do
        log_message "=== ITERATION $iteration STARTING ==="
        
        # Step 1: Analyze current build state
        if ! analyze_build; then
            log_message "No errors to process - build is clean!"
            continue_processing=false
            break
        fi
        
        # Step 2: Deploy agents
        local deployed=$(deploy_agents $iteration)
        
        if [[ "$MODE" == "execute" && $deployed -gt 0 ]]; then
            # Step 3: Monitor agent progress
            monitor_agents $iteration
            
            # Step 4: Evaluate results
            if evaluate_iteration $iteration; then
                continue_processing=false
            fi
        elif [[ "$MODE" == "simulate" ]]; then
            log_message "[SIMULATE] Would wait for agents to complete"
            continue_processing=false
        else
            log_message "No agents deployed - stopping"
            continue_processing=false
        fi
        
        # Save state
        save_state $iteration "" ""
        
        iteration=$((iteration + 1))
        
        # Brief pause between iterations
        [[ $continue_processing == true ]] && sleep 2
    done
    
    log_message "=== COORDINATION COMPLETE ==="
}

# Cleanup function
cleanup() {
    log_message "Cleaning up..."
    rm -f "$SCRIPT_DIR"/.pid_agent_*
    rm -f "$SCRIPT_DIR"/.lock_*
}

# Main execution
main() {
    log_message "=== GENERIC MULTI-AGENT COORDINATOR STARTING ==="
    log_message "Mode: $MODE"
    
    # Initialize
    init_coordination_file
    
    # Load state if resuming
    if [[ "$MODE" == "resume" ]]; then
        load_state
    fi
    
    # Run coordination
    run_coordination
    
    # Cleanup
    cleanup
    
    log_message "=== COORDINATOR SHUTDOWN ==="
}

# Set trap for cleanup
trap cleanup EXIT

# Execute
main "$@"