#!/bin/bash

# Agent Factory - Dynamically spawns fix agents based on build errors
# Manages agent lifecycle and coordinates batch operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_ID="AGENT_FACTORY"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
STATE_DIR="$SCRIPT_DIR/state/factory"
AGENT_REGISTRY="$STATE_DIR/agent_registry.json"
ERROR_ANALYSIS="$STATE_DIR/error_analysis.json"

# Configuration
MAX_AGENTS_PER_ERROR=${MAX_AGENTS_PER_ERROR:-3}
MIN_ERRORS_FOR_AGENT=${MIN_ERRORS_FOR_AGENT:-5}
AGENT_SPAWN_STRATEGY=${AGENT_SPAWN_STRATEGY:-"balanced"}

# Create directories
mkdir -p "$STATE_DIR"

# Initialize registry
if [[ ! -f "$AGENT_REGISTRY" ]]; then
    echo '{"agents": [], "spawned_at": null}' > "$AGENT_REGISTRY"
fi

# Logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $FACTORY_ID: $message" | tee -a "$LOG_FILE"
}

# Analyze build errors and determine agent needs
analyze_build_errors() {
    log_message "Analyzing build errors..."
    
    local build_output="$SCRIPT_DIR/build_output.txt"
    if [[ ! -f "$build_output" ]]; then
        log_message "No build output found"
        return 1
    fi
    
    # Extract and count errors by type
    local error_counts="$STATE_DIR/error_counts.txt"
    grep -oE "error [A-Z]+[0-9]+:" "$build_output" | \
        sed 's/error \([A-Z0-9]*\):/\1/' | \
        sort | uniq -c | sort -rn > "$error_counts"
    
    # Generate analysis report
    cat > "$ERROR_ANALYSIS" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_errors": $(grep -c "error [A-Z]" "$build_output" || echo 0),
    "unique_error_types": $(wc -l < "$error_counts"),
    "error_distribution": [
EOF
    
    # Add error distribution
    local first=true
    while read -r count code; do
        if [[ -n "$code" ]]; then
            [[ "$first" == "true" ]] && first=false || echo "," >> "$ERROR_ANALYSIS"
            cat >> "$ERROR_ANALYSIS" << EOF
        {
            "code": "$code",
            "count": $count,
            "severity": $(calculate_severity "$code" "$count"),
            "category": "$(categorize_error "$code")"
        }
EOF
        fi
    done < "$error_counts"
    
    echo -e "\n    ]\n}" >> "$ERROR_ANALYSIS"
    
    log_message "Error analysis complete: $(jq -r '.unique_error_types' "$ERROR_ANALYSIS") unique error types found"
}

# Calculate error severity based on type and count
calculate_severity() {
    local error_code="$1"
    local count="$2"
    
    # High severity: blocking errors or high count
    if [[ "$count" -gt 100 ]] || [[ "$error_code" =~ ^CS0 ]]; then
        echo 3
    # Medium severity: functional errors
    elif [[ "$count" -gt 20 ]] || [[ "$error_code" =~ ^CS1 ]]; then
        echo 2
    # Low severity: warnings or low count
    else
        echo 1
    fi
}

# Categorize errors for better agent assignment
categorize_error() {
    local error_code="$1"
    
    case "$error_code" in
        CS0*) echo "syntax" ;;
        CS1*) echo "type_member" ;;
        CS8*) echo "nullable" ;;
        CS2*) echo "accessibility" ;;
        CS3*) echo "declaration" ;;
        CS4*) echo "behavior" ;;
        CS5*) echo "compiler" ;;
        CS7*) echo "pattern" ;;
        TS*) echo "typescript" ;;
        *) echo "generic" ;;
    esac
}

# Determine optimal agent configuration
determine_agent_config() {
    log_message "Determining optimal agent configuration..."
    
    local agent_plan="$STATE_DIR/agent_plan.json"
    echo '{"agents_to_spawn": []}' > "$agent_plan"
    
    # Read error analysis
    local errors=$(jq -r '.error_distribution[] | @base64' "$ERROR_ANALYSIS")
    
    for error_data in $errors; do
        local error=$(echo "$error_data" | base64 -d)
        local code=$(echo "$error" | jq -r '.code')
        local count=$(echo "$error" | jq -r '.count')
        local severity=$(echo "$error" | jq -r '.severity')
        local category=$(echo "$error" | jq -r '.category')
        
        # Skip if below threshold
        if [[ "$count" -lt "$MIN_ERRORS_FOR_AGENT" ]]; then
            continue
        fi
        
        # Calculate number of agents needed
        local agents_needed=1
        case "$AGENT_SPAWN_STRATEGY" in
            "aggressive")
                # More agents for parallel processing
                agents_needed=$(( (count / 50) + 1 ))
                [[ "$agents_needed" -gt "$MAX_AGENTS_PER_ERROR" ]] && agents_needed=$MAX_AGENTS_PER_ERROR
                ;;
            "conservative")
                # Minimal agents
                agents_needed=1
                ;;
            "balanced")
                # Based on severity and count
                agents_needed=$(( severity * ((count / 100) + 1) ))
                [[ "$agents_needed" -gt "$MAX_AGENTS_PER_ERROR" ]] && agents_needed=$MAX_AGENTS_PER_ERROR
                [[ "$agents_needed" -lt 1 ]] && agents_needed=1
                ;;
        esac
        
        # Determine strategy for this error type
        local fix_strategy="auto"
        if [[ "$severity" -eq 3 ]]; then
            fix_strategy="aggressive"
        elif [[ "$severity" -eq 1 ]]; then
            fix_strategy="conservative"
        fi
        
        # Add to plan
        for ((i=1; i<=agents_needed; i++)); do
            jq --arg code "$code" \
               --arg strategy "$fix_strategy" \
               --arg category "$category" \
               --argjson instance "$i" \
               --argjson priority "$((4 - severity))" \
               '.agents_to_spawn += [{
                   "error_code": $code,
                   "instance": $instance,
                   "strategy": $strategy,
                   "category": $category,
                   "priority": $priority
               }]' "$agent_plan" > "$agent_plan.tmp" && mv "$agent_plan.tmp" "$agent_plan"
        done
    done
    
    local total_agents=$(jq -r '.agents_to_spawn | length' "$agent_plan")
    log_message "Planning to spawn $total_agents agents"
}

# Spawn dynamic fix agents
spawn_agents() {
    log_message "Spawning dynamic fix agents..."
    
    local agent_plan="$STATE_DIR/agent_plan.json"
    if [[ ! -f "$agent_plan" ]]; then
        log_message "No agent plan found"
        return 1
    fi
    
    # Clear previous registry
    echo '{"agents": [], "spawned_at": "'"$(date -Iseconds)"'"}' > "$AGENT_REGISTRY"
    
    # Sort agents by priority
    local agents=$(jq -r '.agents_to_spawn | sort_by(.priority) | .[] | @base64' "$agent_plan")
    
    local spawned=0
    for agent_data in $agents; do
        local agent=$(echo "$agent_data" | base64 -d)
        local error_code=$(echo "$agent" | jq -r '.error_code')
        local instance=$(echo "$agent" | jq -r '.instance')
        local strategy=$(echo "$agent" | jq -r '.strategy')
        local category=$(echo "$agent" | jq -r '.category')
        
        # Generate unique agent ID
        local agent_id="DYNAMIC_${error_code}_${instance}"
        
        log_message "Spawning agent: $agent_id (strategy: $strategy)"
        
        # Create agent configuration
        local agent_config="$STATE_DIR/agents/${agent_id}.conf"
        mkdir -p "$(dirname "$agent_config")"
        
        cat > "$agent_config" << EOF
#!/bin/bash
# Auto-generated agent configuration
export AGENT_ID="$agent_id"
export ERROR_CODE="$error_code"
export INSTANCE="$instance"
export STRATEGY="$strategy"
export CATEGORY="$category"
export SPAWNED_AT="$(date -Iseconds)"
EOF
        
        # Register agent
        jq --arg id "$agent_id" \
           --arg code "$error_code" \
           --arg strategy "$strategy" \
           --arg status "ready" \
           '.agents += [{
               "id": $id,
               "error_code": $code,
               "strategy": $strategy,
               "status": $status,
               "config": "'"$agent_config"'"
           }]' "$AGENT_REGISTRY" > "$AGENT_REGISTRY.tmp" && mv "$AGENT_REGISTRY.tmp" "$AGENT_REGISTRY"
        
        ((spawned++))
    done
    
    log_message "Successfully spawned $spawned agents"
}

# Get list of ready agents
get_ready_agents() {
    if [[ ! -f "$AGENT_REGISTRY" ]]; then
        echo "[]"
        return
    fi
    
    jq -r '.agents[] | select(.status == "ready") | .id' "$AGENT_REGISTRY"
}

# Execute an agent
execute_agent() {
    local agent_id="$1"
    
    # Get agent details
    local agent_info=$(jq -r --arg id "$agent_id" '.agents[] | select(.id == $id)' "$AGENT_REGISTRY")
    if [[ -z "$agent_info" ]]; then
        log_message "Agent $agent_id not found in registry"
        return 1
    fi
    
    local error_code=$(echo "$agent_info" | jq -r '.error_code')
    local strategy=$(echo "$agent_info" | jq -r '.strategy')
    local instance=$(echo "$agent_id" | grep -oE '[0-9]+$')
    
    # Update status
    update_agent_status "$agent_id" "running"
    
    # Execute dynamic fix agent
    log_message "Executing $agent_id..."
    if "$SCRIPT_DIR/dynamic_fix_agent.sh" "$error_code" "$instance" "$strategy"; then
        update_agent_status "$agent_id" "completed"
        log_message "Agent $agent_id completed successfully"
    else
        update_agent_status "$agent_id" "failed"
        log_message "Agent $agent_id failed"
    fi
}

# Update agent status
update_agent_status() {
    local agent_id="$1"
    local status="$2"
    
    jq --arg id "$agent_id" \
       --arg status "$status" \
       '(.agents[] | select(.id == $id) | .status) = $status' \
       "$AGENT_REGISTRY" > "$AGENT_REGISTRY.tmp" && mv "$AGENT_REGISTRY.tmp" "$AGENT_REGISTRY"
}

# Get agent statistics
get_agent_stats() {
    if [[ ! -f "$AGENT_REGISTRY" ]]; then
        echo "No agents registered"
        return
    fi
    
    local total=$(jq -r '.agents | length' "$AGENT_REGISTRY")
    local ready=$(jq -r '.agents | map(select(.status == "ready")) | length' "$AGENT_REGISTRY")
    local running=$(jq -r '.agents | map(select(.status == "running")) | length' "$AGENT_REGISTRY")
    local completed=$(jq -r '.agents | map(select(.status == "completed")) | length' "$AGENT_REGISTRY")
    local failed=$(jq -r '.agents | map(select(.status == "failed")) | length' "$AGENT_REGISTRY")
    
    cat << EOF
Agent Statistics:
  Total: $total
  Ready: $ready
  Running: $running
  Completed: $completed
  Failed: $failed
EOF
}

# Clean up old agents
cleanup_agents() {
    log_message "Cleaning up old agent configurations..."
    
    # Remove old agent configs
    find "$STATE_DIR/agents" -name "*.conf" -mtime +1 -delete 2>/dev/null || true
    
    # Archive old registries
    if [[ -f "$AGENT_REGISTRY" ]]; then
        local archive_name="$STATE_DIR/archive/registry_$(date +%Y%m%d_%H%M%S).json"
        mkdir -p "$(dirname "$archive_name")"
        mv "$AGENT_REGISTRY" "$archive_name"
        echo '{"agents": [], "spawned_at": null}' > "$AGENT_REGISTRY"
    fi
    
    log_message "Cleanup complete"
}

# Main factory operations
main() {
    case "${1:-analyze}" in
        "analyze")
            analyze_build_errors
            determine_agent_config
            ;;
        "spawn")
            analyze_build_errors
            determine_agent_config
            spawn_agents
            ;;
        "execute")
            local agent_id="${2:-}"
            if [[ -z "$agent_id" ]]; then
                log_message "No agent ID provided"
                exit 1
            fi
            execute_agent "$agent_id"
            ;;
        "list")
            get_ready_agents
            ;;
        "stats")
            get_agent_stats
            ;;
        "cleanup")
            cleanup_agents
            ;;
        *)
            echo "Usage: $0 {analyze|spawn|execute <agent_id>|list|stats|cleanup}"
            exit 1
            ;;
    esac
}

# Export functions for use by coordinator
export -f execute_agent
export -f get_ready_agents
export -f get_agent_stats

# Run main
main "$@"