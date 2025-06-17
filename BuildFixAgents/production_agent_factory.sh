#!/bin/bash

# Production Agent Factory - Enterprise-grade dynamic agent spawning
# Features: Health monitoring, resource limits, circuit breakers, telemetry

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_ID="PROD_AGENT_FACTORY_$$"
LOG_FILE="$SCRIPT_DIR/logs/agent_factory.log"
STATE_DIR="$SCRIPT_DIR/state/factory"
METRICS_DIR="$SCRIPT_DIR/state/metrics"
LOCK_DIR="$SCRIPT_DIR/state/locks"

# Production Configuration
MAX_AGENTS_PER_ERROR=${MAX_AGENTS_PER_ERROR:-5}
MIN_ERRORS_FOR_AGENT=${MIN_ERRORS_FOR_AGENT:-10}
MAX_CONCURRENT_AGENTS=${MAX_CONCURRENT_AGENTS:-10}
AGENT_TIMEOUT=${AGENT_TIMEOUT:-300}
AGENT_MEMORY_LIMIT=${AGENT_MEMORY_LIMIT:-"512M"}
AGENT_CPU_LIMIT=${AGENT_CPU_LIMIT:-"0.5"}
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}
CIRCUIT_BREAKER_THRESHOLD=${CIRCUIT_BREAKER_THRESHOLD:-3}
CIRCUIT_BREAKER_TIMEOUT=${CIRCUIT_BREAKER_TIMEOUT:-300}
ENABLE_TELEMETRY=${ENABLE_TELEMETRY:-true}
ENABLE_AUDIT_LOG=${ENABLE_AUDIT_LOG:-true}

# State files
AGENT_REGISTRY="$STATE_DIR/agent_registry.json"
ERROR_ANALYSIS="$STATE_DIR/error_analysis.json"
HEALTH_STATUS="$STATE_DIR/health_status.json"
CIRCUIT_BREAKERS="$STATE_DIR/circuit_breakers.json"
AGENT_POOL="$STATE_DIR/agent_pool.json"
AUDIT_LOG="$STATE_DIR/audit.log"

# Create directories
mkdir -p "$STATE_DIR" "$METRICS_DIR" "$LOCK_DIR" "$(dirname "$LOG_FILE")"

# Initialize state files
[[ ! -f "$AGENT_REGISTRY" ]] && echo '{"agents": {}, "version": "2.0"}' > "$AGENT_REGISTRY"
[[ ! -f "$CIRCUIT_BREAKERS" ]] && echo '{}' > "$CIRCUIT_BREAKERS"
[[ ! -f "$AGENT_POOL" ]] && echo '{"available": [], "in_use": {}}' > "$AGENT_POOL"
[[ ! -f "$HEALTH_STATUS" ]] && echo '{"status": "initializing", "last_check": null}' > "$HEALTH_STATUS"

# Production logging with levels
log_message() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local log_entry="[$timestamp] [$FACTORY_ID] [$level] $message"
    
    echo "$log_entry" | tee -a "$LOG_FILE"
    
    # Audit log for critical operations
    if [[ "$ENABLE_AUDIT_LOG" == "true" ]] && [[ "$level" =~ ^(ERROR|CRITICAL|AUDIT)$ ]]; then
        echo "$log_entry" >> "$AUDIT_LOG"
    fi
    
    # Send to telemetry if enabled
    if [[ "$ENABLE_TELEMETRY" == "true" ]]; then
        send_telemetry "$level" "$message"
    fi
}

# Distributed locking
acquire_lock() {
    local lock_name="$1"
    local timeout="${2:-30}"
    local lock_file="$LOCK_DIR/${lock_name}.lock"
    local start_time=$(date +%s)
    
    while true; do
        if mkdir "$lock_file" 2>/dev/null; then
            echo "$$" > "$lock_file/pid"
            echo "$(date +%s)" > "$lock_file/acquired"
            return 0
        fi
        
        # Check for stale locks
        if [[ -f "$lock_file/pid" ]]; then
            local lock_pid=$(cat "$lock_file/pid" 2>/dev/null || echo "0")
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                log_message "WARN" "Removing stale lock: $lock_name (PID: $lock_pid)"
                rm -rf "$lock_file"
                continue
            fi
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        if [[ $((current_time - start_time)) -gt $timeout ]]; then
            log_message "ERROR" "Failed to acquire lock: $lock_name (timeout)"
            return 1
        fi
        
        sleep 0.1
    done
}

release_lock() {
    local lock_name="$1"
    local lock_file="$LOCK_DIR/${lock_name}.lock"
    
    if [[ -d "$lock_file" ]]; then
        local lock_pid=$(cat "$lock_file/pid" 2>/dev/null || echo "0")
        if [[ "$lock_pid" == "$$" ]]; then
            rm -rf "$lock_file"
        else
            log_message "WARN" "Attempted to release lock not owned by this process: $lock_name"
        fi
    fi
}

# Health monitoring
update_health_status() {
    local status="$1"
    local details="${2:-}"
    
    if acquire_lock "health_status" 5; then
        jq --arg status "$status" \
           --arg details "$details" \
           --arg timestamp "$(date -Iseconds)" \
           '.status = $status | .last_check = $timestamp | .details = $details' \
           "$HEALTH_STATUS" > "$HEALTH_STATUS.tmp" && mv "$HEALTH_STATUS.tmp" "$HEALTH_STATUS"
        release_lock "health_status"
    fi
}

# Circuit breaker implementation
check_circuit_breaker() {
    local error_code="$1"
    
    if [[ ! -f "$CIRCUIT_BREAKERS" ]]; then
        return 0
    fi
    
    local breaker_state=$(jq -r --arg code "$error_code" '.[$code].state // "closed"' "$CIRCUIT_BREAKERS")
    local last_failure=$(jq -r --arg code "$error_code" '.[$code].last_failure // 0' "$CIRCUIT_BREAKERS")
    local current_time=$(date +%s)
    
    case "$breaker_state" in
        "open")
            # Check if timeout has passed
            if [[ $((current_time - last_failure)) -gt $CIRCUIT_BREAKER_TIMEOUT ]]; then
                log_message "INFO" "Circuit breaker half-open for $error_code"
                update_circuit_breaker "$error_code" "half-open"
                return 0
            else
                log_message "WARN" "Circuit breaker open for $error_code"
                return 1
            fi
            ;;
        "half-open")
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

update_circuit_breaker() {
    local error_code="$1"
    local state="$2"
    local failure_count="${3:-0}"
    
    if acquire_lock "circuit_breakers" 5; then
        jq --arg code "$error_code" \
           --arg state "$state" \
           --argjson failures "$failure_count" \
           --arg timestamp "$(date +%s)" \
           '.[$code] = {
               "state": $state,
               "failures": $failures,
               "last_failure": ($timestamp | tonumber)
           }' "$CIRCUIT_BREAKERS" > "$CIRCUIT_BREAKERS.tmp" && mv "$CIRCUIT_BREAKERS.tmp" "$CIRCUIT_BREAKERS"
        release_lock "circuit_breakers"
    fi
}

# Resource management
check_resource_availability() {
    # Check CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_message "WARN" "High CPU usage: ${cpu_usage}%"
        return 1
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
    if (( $(echo "$mem_usage > 80" | bc -l) )); then
        log_message "WARN" "High memory usage: ${mem_usage}%"
        return 1
    fi
    
    # Check active agent count
    local active_agents=$(jq -r '.agents | to_entries | map(select(.value.status == "running")) | length' "$AGENT_REGISTRY" 2>/dev/null || echo 0)
    if [[ $active_agents -ge $MAX_CONCURRENT_AGENTS ]]; then
        log_message "WARN" "Max concurrent agents reached: $active_agents"
        return 1
    fi
    
    return 0
}

# Enhanced error analysis with ML-style pattern detection
analyze_build_errors_enhanced() {
    log_message "INFO" "Starting enhanced error analysis..."
    
    local build_output="$SCRIPT_DIR/build_output.txt"
    if [[ ! -f "$build_output" ]]; then
        log_message "ERROR" "No build output found"
        return 1
    fi
    
    # Try cache first
    if [[ -f "$SCRIPT_DIR/cache_manager.sh" ]]; then
        source "$SCRIPT_DIR/cache_manager.sh"
        
        if get_cached_analysis "build_errors" > "$ERROR_ANALYSIS"; then
            log_message "INFO" "Using cached error analysis"
            return 0
        fi
    fi
    
    # Extract comprehensive error data
    local temp_analysis="$STATE_DIR/temp_analysis.json"
    echo '{"errors": []}' > "$temp_analysis"
    
    # Parse errors with context
    grep -B2 -A2 "error [A-Z]+[0-9]+:" "$build_output" | \
    awk -v RS="--" -v ORS="\n" '
    /error [A-Z]+[0-9]+:/ {
        match($0, /([^:]+):([0-9]+),([0-9]+).*error ([A-Z]+[0-9]+): (.*)/, arr)
        if (arr[1]) {
            gsub(/"/,"\\\"",arr[5])
            printf "{\"file\":\"%s\",\"line\":%s,\"col\":%s,\"code\":\"%s\",\"message\":\"%s\"},\n", 
                   arr[1], arr[2], arr[3], arr[4], arr[5]
        }
    }' | sed '$ s/,$//' > "$STATE_DIR/raw_errors.json"
    
    # Aggregate and analyze
    if [[ -s "$STATE_DIR/raw_errors.json" ]]; then
        cat > "$ERROR_ANALYSIS" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "build_id": "$(md5sum "$build_output" | cut -d' ' -f1)",
    "total_errors": $(wc -l < "$STATE_DIR/raw_errors.json"),
    "analysis": {
        "by_type": $(jq -s 'group_by(.code) | map({
            code: .[0].code,
            count: length,
            files: [.[].file] | unique | length,
            sample_messages: [.[].message] | unique | .[0:3],
            severity: (if .[0].code | startswith("CS0") then 3
                      elif .[0].code | startswith("CS8") then 2
                      else 1 end),
            pattern: (if (.[].message | unique | length) == 1 then "uniform"
                     elif (.[].message | unique | length) < 5 then "similar"
                     else "diverse" end)
        }) | sort_by(-.count)' "$STATE_DIR/raw_errors.json"),
        "by_file": $(jq -s 'group_by(.file) | map({
            file: .[0].file,
            error_count: length,
            error_types: [.[].code] | unique
        }) | sort_by(-.error_count) | .[0:10]' "$STATE_DIR/raw_errors.json"),
        "hotspots": $(jq -s 'group_by(.file + ":" + (.line|tostring)) | 
                             map({location: .[0].file + ":" + (.[0].line|tostring), 
                                  errors: length}) | 
                             sort_by(-.errors) | .[0:5]' "$STATE_DIR/raw_errors.json")
    }
}
EOF
    fi
    
    log_message "INFO" "Error analysis complete"
    
    # Cache the analysis
    if [[ -f "$SCRIPT_DIR/cache_manager.sh" ]]; then
        cache_analysis "build_errors" "$ERROR_ANALYSIS"
    fi
}

# Smart agent configuration with resource limits
create_agent_config() {
    local agent_id="$1"
    local error_code="$2"
    local instance="$3"
    local strategy="$4"
    local priority="$5"
    
    local config_file="$STATE_DIR/agents/${agent_id}/config.json"
    mkdir -p "$(dirname "$config_file")"
    
    # Determine resource allocation based on priority
    local memory_limit="$AGENT_MEMORY_LIMIT"
    local cpu_limit="$AGENT_CPU_LIMIT"
    local timeout="$AGENT_TIMEOUT"
    
    case "$priority" in
        1) # Critical
            memory_limit="1G"
            cpu_limit="1.0"
            timeout=600
            ;;
        2) # High
            memory_limit="768M"
            cpu_limit="0.75"
            timeout=450
            ;;
        3) # Normal
            # Use defaults
            ;;
        4) # Low
            memory_limit="256M"
            cpu_limit="0.25"
            timeout=180
            ;;
    esac
    
    cat > "$config_file" << EOF
{
    "id": "$agent_id",
    "error_code": "$error_code",
    "instance": $instance,
    "strategy": "$strategy",
    "priority": $priority,
    "resources": {
        "memory_limit": "$memory_limit",
        "cpu_limit": "$cpu_limit",
        "timeout": $timeout
    },
    "environment": {
        "AGENT_ID": "$agent_id",
        "ERROR_CODE": "$error_code",
        "STRATEGY": "$strategy",
        "BATCH_SIZE": 100,
        "MAX_RETRIES": 3
    },
    "created_at": "$(date -Iseconds)",
    "status": "configured"
}
EOF
    
    echo "$config_file"
}

# Agent pool management for reuse
get_or_create_agent() {
    local error_code="$1"
    local instance="$2"
    local strategy="$3"
    local priority="$4"
    
    # Check pool for available agent
    if acquire_lock "agent_pool" 5; then
        local available_agent=$(jq -r --arg code "$error_code" \
            '.available[] | select(.error_code == $code) | .id' \
            "$AGENT_POOL" | head -1)
        
        if [[ -n "$available_agent" ]]; then
            # Move from available to in_use
            jq --arg id "$available_agent" \
               '.available = [.available[] | select(.id != $id)] |
                .in_use[$id] = {
                    "id": $id,
                    "error_code": "'"$error_code"'",
                    "acquired_at": "'"$(date -Iseconds)"'"
                }' "$AGENT_POOL" > "$AGENT_POOL.tmp" && mv "$AGENT_POOL.tmp" "$AGENT_POOL"
            
            release_lock "agent_pool"
            log_message "INFO" "Reusing pooled agent: $available_agent"
            return 0
        fi
        release_lock "agent_pool"
    fi
    
    # Create new agent
    local agent_id="AGENT_${error_code}_${instance}_$$"
    local config_file=$(create_agent_config "$agent_id" "$error_code" "$instance" "$strategy" "$priority")
    
    # Register agent
    if acquire_lock "agent_registry" 5; then
        jq --arg id "$agent_id" \
           --argjson config "$(cat "$config_file")" \
           '.agents[$id] = $config' \
           "$AGENT_REGISTRY" > "$AGENT_REGISTRY.tmp" && mv "$AGENT_REGISTRY.tmp" "$AGENT_REGISTRY"
        release_lock "agent_registry"
    fi
    
    echo "$agent_id"
}

# Execute agent with resource limits and monitoring
execute_agent_production() {
    local agent_id="$1"
    
    # Get agent configuration
    local config=$(jq -r --arg id "$agent_id" '.agents[$id]' "$AGENT_REGISTRY")
    if [[ "$config" == "null" ]]; then
        log_message "ERROR" "Agent $agent_id not found"
        return 1
    fi
    
    local error_code=$(echo "$config" | jq -r '.error_code')
    local strategy=$(echo "$config" | jq -r '.strategy')
    local instance=$(echo "$config" | jq -r '.instance')
    local memory_limit=$(echo "$config" | jq -r '.resources.memory_limit')
    local cpu_limit=$(echo "$config" | jq -r '.resources.cpu_limit')
    local timeout=$(echo "$config" | jq -r '.resources.timeout')
    
    # Check circuit breaker
    if ! check_circuit_breaker "$error_code"; then
        log_message "WARN" "Circuit breaker preventing execution for $error_code"
        return 1
    fi
    
    # Update status
    update_agent_status "$agent_id" "starting"
    
    # Create execution wrapper with resource limits
    local wrapper_script="$STATE_DIR/agents/${agent_id}/wrapper.sh"
    cat > "$wrapper_script" << EOF
#!/bin/bash
# Resource-limited wrapper for agent execution

# Set memory limit
ulimit -v \$(echo "$memory_limit" | sed 's/M/*1024/;s/G/*1024*1024/' | bc)

# Set CPU limit using nice and cpulimit if available
if command -v cpulimit >/dev/null 2>&1; then
    cpulimit -l \$(echo "$cpu_limit * 100" | bc | cut -d. -f1) -i -z -- \\
        "$SCRIPT_DIR/dynamic_fix_agent.sh" "$error_code" "$instance" "$strategy"
else
    nice -n 10 "$SCRIPT_DIR/dynamic_fix_agent.sh" "$error_code" "$instance" "$strategy"
fi
EOF
    chmod +x "$wrapper_script"
    
    # Execute with timeout and monitoring
    log_message "INFO" "Executing agent $agent_id (timeout: ${timeout}s)"
    update_agent_status "$agent_id" "running"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    if timeout "$timeout" "$wrapper_script" > "$STATE_DIR/agents/${agent_id}/output.log" 2>&1; then
        exit_code=0
        update_agent_status "$agent_id" "completed"
        log_message "INFO" "Agent $agent_id completed successfully"
        
        # Reset circuit breaker on success
        update_circuit_breaker "$error_code" "closed" 0
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            update_agent_status "$agent_id" "timeout"
            log_message "ERROR" "Agent $agent_id timed out after ${timeout}s"
        else
            update_agent_status "$agent_id" "failed"
            log_message "ERROR" "Agent $agent_id failed with exit code: $exit_code"
        fi
        
        # Update circuit breaker
        local current_failures=$(jq -r --arg code "$error_code" '.[$code].failures // 0' "$CIRCUIT_BREAKERS")
        local new_failures=$((current_failures + 1))
        
        if [[ $new_failures -ge $CIRCUIT_BREAKER_THRESHOLD ]]; then
            update_circuit_breaker "$error_code" "open" "$new_failures"
            log_message "CRITICAL" "Circuit breaker opened for $error_code after $new_failures failures"
        else
            update_circuit_breaker "$error_code" "closed" "$new_failures"
        fi
    fi
    
    # Record metrics
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    record_agent_metrics "$agent_id" "$duration" "$exit_code"
    
    # Return agent to pool if successful
    if [[ $exit_code -eq 0 ]] && [[ "$ENABLE_AGENT_POOLING" == "true" ]]; then
        return_agent_to_pool "$agent_id" "$error_code"
    fi
    
    return $exit_code
}

# Update agent status with timestamp
update_agent_status() {
    local agent_id="$1"
    local status="$2"
    
    if acquire_lock "agent_registry" 5; then
        jq --arg id "$agent_id" \
           --arg status "$status" \
           --arg timestamp "$(date -Iseconds)" \
           '.agents[$id].status = $status |
            .agents[$id].last_update = $timestamp' \
           "$AGENT_REGISTRY" > "$AGENT_REGISTRY.tmp" && mv "$AGENT_REGISTRY.tmp" "$AGENT_REGISTRY"
        release_lock "agent_registry"
    fi
}

# Record agent execution metrics
record_agent_metrics() {
    local agent_id="$1"
    local duration="$2"
    local exit_code="$3"
    
    local metrics_file="$METRICS_DIR/agent_metrics_$(date +%Y%m%d).jsonl"
    
    jq -nc --arg id "$agent_id" \
           --argjson duration "$duration" \
           --argjson exit_code "$exit_code" \
           --arg timestamp "$(date -Iseconds)" \
           '{
               "agent_id": $id,
               "duration_seconds": $duration,
               "exit_code": $exit_code,
               "success": ($exit_code == 0),
               "timestamp": $timestamp
           }' >> "$metrics_file"
}

# Return agent to pool for reuse
return_agent_to_pool() {
    local agent_id="$1"
    local error_code="$2"
    
    if acquire_lock "agent_pool" 5; then
        jq --arg id "$agent_id" \
           --arg code "$error_code" \
           '.in_use[$id] = empty |
            .available += [{
                "id": $id,
                "error_code": $code,
                "returned_at": "'"$(date -Iseconds)"'"
            }]' "$AGENT_POOL" > "$AGENT_POOL.tmp" && mv "$AGENT_POOL.tmp" "$AGENT_POOL"
        release_lock "agent_pool"
    fi
}

# Health check daemon
health_check_daemon() {
    while true; do
        # Check overall system health
        local health="healthy"
        local issues=[]
        
        # Check resource availability
        if ! check_resource_availability; then
            health="degraded"
            issues+=("High resource usage")
        fi
        
        # Check agent failures
        local failed_agents=$(jq -r '.agents | to_entries | map(select(.value.status == "failed")) | length' "$AGENT_REGISTRY" 2>/dev/null || echo 0)
        if [[ $failed_agents -gt 5 ]]; then
            health="unhealthy"
            issues+=("Too many failed agents: $failed_agents")
        fi
        
        # Check circuit breakers
        local open_breakers=$(jq -r 'to_entries | map(select(.value.state == "open")) | length' "$CIRCUIT_BREAKERS" 2>/dev/null || echo 0)
        if [[ $open_breakers -gt 0 ]]; then
            health="degraded"
            issues+=("Open circuit breakers: $open_breakers")
        fi
        
        update_health_status "$health" "$(printf '%s\n' "${issues[@]}")"
        
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Telemetry sender
send_telemetry() {
    local level="$1"
    local message="$2"
    
    # Send to metrics endpoint if configured
    if [[ -n "${TELEMETRY_ENDPOINT:-}" ]]; then
        curl -s -X POST "$TELEMETRY_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"$level\",\"message\":\"$message\",\"factory_id\":\"$FACTORY_ID\",\"timestamp\":\"$(date -Iseconds)\"}" \
            >/dev/null 2>&1 || true
    fi
}

# Graceful shutdown
cleanup() {
    log_message "INFO" "Shutting down agent factory..."
    
    # Stop all running agents
    local running_agents=$(jq -r '.agents | to_entries | map(select(.value.status == "running")) | .[].key' "$AGENT_REGISTRY" 2>/dev/null)
    
    for agent_id in $running_agents; do
        log_message "INFO" "Stopping agent: $agent_id"
        update_agent_status "$agent_id" "stopped"
    done
    
    # Release all locks
    rm -rf "$LOCK_DIR"/*.lock
    
    # Final health update
    update_health_status "shutdown" "Factory shutdown at $(date -Iseconds)"
    
    log_message "INFO" "Agent factory shutdown complete"
}

# Signal handlers
trap cleanup EXIT INT TERM

# Main orchestration function
orchestrate_agents() {
    log_message "INFO" "Starting agent orchestration..."
    
    # Start health check daemon in background
    health_check_daemon &
    local health_pid=$!
    
    # Check if parallel processing is available
    if [[ -f "$SCRIPT_DIR/parallel_processor.sh" ]] && [[ "$MAX_CONCURRENT_AGENTS" -gt 2 ]]; then
        source "$SCRIPT_DIR/parallel_processor.sh"
        
        # Analyze errors
        analyze_build_errors_enhanced
        
        # Use parallel processing for large error counts
        local total_errors=$(jq -r '.total_errors // 0' "$ERROR_ANALYSIS" 2>/dev/null)
        
        if [[ $total_errors -gt 200 ]]; then
            log_message "INFO" "Using parallel processing for $total_errors errors"
            
            # Process errors in parallel chunks
            MAX_PARALLEL=$MAX_CONCURRENT_AGENTS process_errors_parallel "$ERROR_ANALYSIS"
            
            # Read results and determine agent needs
            if [[ -f "$STATE_DIR/../parallel_processing_results.json" ]]; then
                local fixes_applied=$(jq -r '.total_fixes // 0' "$STATE_DIR/../parallel_processing_results.json")
                log_message "INFO" "Parallel processing applied $fixes_applied fixes"
                
                # Re-analyze remaining errors
                analyze_build_errors_enhanced
            fi
        fi
    else
        # Analyze errors normally
        analyze_build_errors_enhanced
    fi
    
    # Get error distribution
    local error_types=$(jq -r '.analysis.by_type[] | @base64' "$ERROR_ANALYSIS" 2>/dev/null)
    
    if [[ -z "$error_types" ]]; then
        log_message "WARN" "No errors found to process"
        return 0
    fi
    
    # Process each error type
    while IFS= read -r error_data; do
        local error=$(echo "$error_data" | base64 -d)
        local code=$(echo "$error" | jq -r '.code')
        local count=$(echo "$error" | jq -r '.count')
        local severity=$(echo "$error" | jq -r '.severity')
        local pattern=$(echo "$error" | jq -r '.pattern')
        
        # Skip if below threshold
        if [[ $count -lt $MIN_ERRORS_FOR_AGENT ]]; then
            log_message "INFO" "Skipping $code: only $count errors (threshold: $MIN_ERRORS_FOR_AGENT)"
            continue
        fi
        
        # Determine agent count based on pattern and severity
        local agent_count=1
        if [[ "$pattern" == "diverse" ]] && [[ $severity -ge 2 ]]; then
            agent_count=$((count / 50 + 1))
            [[ $agent_count -gt $MAX_AGENTS_PER_ERROR ]] && agent_count=$MAX_AGENTS_PER_ERROR
        elif [[ $severity -eq 3 ]]; then
            agent_count=2
        fi
        
        log_message "INFO" "Spawning $agent_count agents for $code ($count errors, pattern: $pattern)"
        
        # Spawn agents
        for ((i=1; i<=agent_count; i++)); do
            # Check resource availability
            if ! check_resource_availability; then
                log_message "WARN" "Resource constraints preventing agent spawn"
                sleep 5
                continue
            fi
            
            # Determine strategy
            local strategy="auto"
            [[ $severity -eq 3 ]] && strategy="aggressive"
            [[ "$pattern" == "uniform" ]] && strategy="aggressive"
            [[ $count -lt 20 ]] && strategy="conservative"
            
            # Get or create agent
            local agent_id=$(get_or_create_agent "$code" "$i" "$strategy" "$severity")
            
            # Execute agent asynchronously
            (
                execute_agent_production "$agent_id"
            ) &
            
            # Rate limiting
            sleep 0.5
        done
    done <<< "$error_types"
    
    # Wait for all agents to complete
    wait
    
    # Stop health check daemon
    kill $health_pid 2>/dev/null || true
    
    log_message "INFO" "Agent orchestration complete"
}

# Main function with command handling
main() {
    case "${1:-orchestrate}" in
        "orchestrate")
            orchestrate_agents
            ;;
        "analyze")
            analyze_build_errors_enhanced
            ;;
        "spawn")
            local error_code="${2:-}"
            local count="${3:-1}"
            if [[ -z "$error_code" ]]; then
                log_message "ERROR" "Error code required for spawn"
                exit 1
            fi
            for ((i=1; i<=count; i++)); do
                get_or_create_agent "$error_code" "$i" "auto" 2
            done
            ;;
        "execute")
            local agent_id="${2:-}"
            if [[ -z "$agent_id" ]]; then
                log_message "ERROR" "Agent ID required for execute"
                exit 1
            fi
            execute_agent_production "$agent_id"
            ;;
        "status")
            echo "=== Production Agent Factory Status ==="
            echo "Health: $(jq -r '.status' "$HEALTH_STATUS" 2>/dev/null || echo "unknown")"
            echo "Active Agents: $(jq -r '.agents | to_entries | map(select(.value.status == "running")) | length' "$AGENT_REGISTRY" 2>/dev/null || echo 0)"
            echo "Failed Agents: $(jq -r '.agents | to_entries | map(select(.value.status == "failed")) | length' "$AGENT_REGISTRY" 2>/dev/null || echo 0)"
            echo "Open Circuit Breakers: $(jq -r 'to_entries | map(select(.value.state == "open")) | length' "$CIRCUIT_BREAKERS" 2>/dev/null || echo 0)"
            echo "Pool Available: $(jq -r '.available | length' "$AGENT_POOL" 2>/dev/null || echo 0)"
            ;;
        "metrics")
            local today=$(date +%Y%m%d)
            if [[ -f "$METRICS_DIR/agent_metrics_${today}.jsonl" ]]; then
                echo "=== Today's Metrics ==="
                jq -s '{
                    total_executions: length,
                    successful: [.[] | select(.success)] | length,
                    failed: [.[] | select(.success | not)] | length,
                    avg_duration: ([.[].duration_seconds] | add / length),
                    max_duration: ([.[].duration_seconds] | max),
                    min_duration: ([.[].duration_seconds] | min)
                }' "$METRICS_DIR/agent_metrics_${today}.jsonl"
            else
                echo "No metrics available for today"
            fi
            ;;
        *)
            echo "Usage: $0 {orchestrate|analyze|spawn <code> [count]|execute <id>|status|metrics}"
            exit 1
            ;;
    esac
}

# Run main
main "$@"