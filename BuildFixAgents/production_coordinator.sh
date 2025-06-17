#!/bin/bash
# Production-Ready Unified Coordinator
# Enterprise-grade multi-agent orchestration with advanced features

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/production_coordinator"
LOG_DIR="$SCRIPT_DIR/state/logs"
METRICS_DIR="$STATE_DIR/metrics"
CHECKPOINT_DIR="$STATE_DIR/checkpoints"
LOCK_FILE="$STATE_DIR/.lock"

# Create necessary directories
mkdir -p "$STATE_DIR" "$LOG_DIR" "$METRICS_DIR" "$CHECKPOINT_DIR"

# Production configuration
EXECUTION_MODE="${1:-smart}"
MAX_CONCURRENT_AGENTS=${MAX_CONCURRENT_AGENTS:-4}
AGENT_TIMEOUT=${AGENT_TIMEOUT:-300}  # 5 minutes default
RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-3}
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-10}
ENABLE_METRICS=${ENABLE_METRICS:-true}
ENABLE_CHECKPOINTS=${ENABLE_CHECKPOINTS:-true}
DRY_RUN=${DRY_RUN:-false}
PRIORITY_MODE=${PRIORITY_MODE:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Agent registry with priorities and dependencies
declare -A AGENT_REGISTRY
declare -A AGENT_PRIORITIES
declare -A AGENT_DEPENDENCIES
declare -A AGENT_RESOURCE_REQUIREMENTS

# Initialize agent registry
initialize_agent_registry() {
    # Core agents (Priority 1 - Highest)
    AGENT_REGISTRY["build_analyzer"]="generic_build_analyzer.sh|Build Analyzer|"
    AGENT_PRIORITIES["build_analyzer"]=1
    AGENT_DEPENDENCIES["build_analyzer"]=""
    AGENT_RESOURCE_REQUIREMENTS["build_analyzer"]="cpu:1,memory:512M"
    
    AGENT_REGISTRY["error_counter"]="unified_error_counter.sh|Error Counter|"
    AGENT_PRIORITIES["error_counter"]=1
    AGENT_DEPENDENCIES["error_counter"]="build_analyzer"
    AGENT_RESOURCE_REQUIREMENTS["error_counter"]="cpu:1,memory:256M"
    
    # Analysis agents (Priority 2)
    AGENT_REGISTRY["error_agent"]="generic_error_agent.sh|Error Agent|"
    AGENT_PRIORITIES["error_agent"]=2
    AGENT_DEPENDENCIES["error_agent"]="build_analyzer,error_counter"
    AGENT_RESOURCE_REQUIREMENTS["error_agent"]="cpu:2,memory:1G"
    
    AGENT_REGISTRY["analysis"]="analysis_agent.sh|Code Analysis|full"
    AGENT_PRIORITIES["analysis"]=2
    AGENT_DEPENDENCIES["analysis"]=""
    AGENT_RESOURCE_REQUIREMENTS["analysis"]="cpu:2,memory:2G"
    
    # Architecture agents (Priority 3)
    AGENT_REGISTRY["architect"]="architect_agent_v2.sh|Architect|plan"
    AGENT_PRIORITIES["architect"]=3
    AGENT_DEPENDENCIES["architect"]="analysis"
    AGENT_RESOURCE_REQUIREMENTS["architect"]="cpu:1,memory:1G"
    
    # Development agents (Priority 4)
    AGENT_REGISTRY["dev_core"]="dev_agent_core_fix.sh|Core Dev|"
    AGENT_PRIORITIES["dev_core"]=4
    AGENT_DEPENDENCIES["dev_core"]="architect,error_agent"
    AGENT_RESOURCE_REQUIREMENTS["dev_core"]="cpu:2,memory:1G"
    
    AGENT_REGISTRY["dev_integration"]="dev_agent_integration.sh|Integration Dev|"
    AGENT_PRIORITIES["dev_integration"]=4
    AGENT_DEPENDENCIES["dev_integration"]="architect"
    AGENT_RESOURCE_REQUIREMENTS["dev_integration"]="cpu:2,memory:1G"
    
    AGENT_REGISTRY["dev_patterns"]="dev_agent_patterns.sh|Pattern Dev|"
    AGENT_PRIORITIES["dev_patterns"]=4
    AGENT_DEPENDENCIES["dev_patterns"]="architect"
    AGENT_RESOURCE_REQUIREMENTS["dev_patterns"]="cpu:1,memory:512M"
    
    # Fix specialists (Priority 5)
    AGENT_REGISTRY["duplicate_fix"]="agent1_duplicate_resolver.sh|Duplicate Fix|"
    AGENT_PRIORITIES["duplicate_fix"]=5
    AGENT_DEPENDENCIES["duplicate_fix"]="error_agent"
    AGENT_RESOURCE_REQUIREMENTS["duplicate_fix"]="cpu:1,memory:512M"
    
    AGENT_REGISTRY["constraints_fix"]="agent2_constraints_specialist.sh|Constraints Fix|"
    AGENT_PRIORITIES["constraints_fix"]=5
    AGENT_DEPENDENCIES["constraints_fix"]="error_agent"
    AGENT_RESOURCE_REQUIREMENTS["constraints_fix"]="cpu:1,memory:512M"
    
    AGENT_REGISTRY["inheritance_fix"]="agent3_inheritance_specialist.sh|Inheritance Fix|"
    AGENT_PRIORITIES["inheritance_fix"]=5
    AGENT_DEPENDENCIES["inheritance_fix"]="error_agent"
    AGENT_RESOURCE_REQUIREMENTS["inheritance_fix"]="cpu:1,memory:512M"
    
    # QA agents (Priority 6)
    AGENT_REGISTRY["qa_automation"]="qa_automation_agent.sh|QA Automation|test"
    AGENT_PRIORITIES["qa_automation"]=6
    AGENT_DEPENDENCIES["qa_automation"]="dev_core,dev_integration,dev_patterns"
    AGENT_RESOURCE_REQUIREMENTS["qa_automation"]="cpu:2,memory:2G"
    
    AGENT_REGISTRY["qa_final"]="qa_agent_final.sh|QA Final|test"
    AGENT_PRIORITIES["qa_final"]=7
    AGENT_DEPENDENCIES["qa_final"]="qa_automation"
    AGENT_RESOURCE_REQUIREMENTS["qa_final"]="cpu:1,memory:1G"
}

# Production logging with structured output
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    local log_entry="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}"
    
    echo "$log_entry" >> "$LOG_DIR/production_coordinator.jsonl"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "INFO")  echo -e "${CYAN}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "DEBUG") [[ "${DEBUG:-false}" == "true" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $message" ;;
    esac
}

# Resource monitoring
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_free=$(free -m | awk '/^Mem:/{print $4}')
    local disk_free=$(df -BG "$SCRIPT_DIR" | awk 'NR==2{print $4}' | sed 's/G//')
    
    log "INFO" "System resources - CPU: ${cpu_usage}%, Free Memory: ${memory_free}MB, Free Disk: ${disk_free}GB"
    
    # Check if resources are sufficient
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        log "WARN" "High CPU usage detected: ${cpu_usage}%"
        MAX_CONCURRENT_AGENTS=$((MAX_CONCURRENT_AGENTS / 2))
    fi
    
    if [[ $memory_free -lt 1000 ]]; then
        log "WARN" "Low memory detected: ${memory_free}MB"
        MAX_CONCURRENT_AGENTS=$((MAX_CONCURRENT_AGENTS / 2))
    fi
}

# Advanced hardware detection
detect_hardware_advanced() {
    log "INFO" "Performing advanced hardware detection..."
    
    local cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
    local memory_gb=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo 4)
    local cpu_model=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2 | xargs || echo "Unknown")
    
    # Detect container/VM environment
    local is_container="false"
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        is_container="true"
        log "INFO" "Running in container environment"
    fi
    
    # Adaptive configuration based on environment
    if [[ "$is_container" == "true" ]]; then
        MAX_CONCURRENT_AGENTS=$((cpu_cores > 2 ? cpu_cores - 1 : 1))
    else
        if [[ $cpu_cores -ge 16 ]] && [[ $memory_gb -ge 32 ]]; then
            MAX_CONCURRENT_AGENTS=12
            log "INFO" "Enterprise hardware detected: $cpu_cores cores, ${memory_gb}GB RAM"
        elif [[ $cpu_cores -ge 8 ]] && [[ $memory_gb -ge 16 ]]; then
            MAX_CONCURRENT_AGENTS=8
            log "INFO" "High-performance hardware: $cpu_cores cores, ${memory_gb}GB RAM"
        elif [[ $cpu_cores -ge 4 ]] && [[ $memory_gb -ge 8 ]]; then
            MAX_CONCURRENT_AGENTS=4
            log "INFO" "Standard hardware: $cpu_cores cores, ${memory_gb}GB RAM"
        else
            MAX_CONCURRENT_AGENTS=2
            log "WARN" "Limited hardware: $cpu_cores cores, ${memory_gb}GB RAM"
        fi
    fi
    
    # Store hardware info
    cat > "$STATE_DIR/hardware_info.json" << EOF
{
    "cpu_cores": $cpu_cores,
    "memory_gb": $memory_gb,
    "cpu_model": "$cpu_model",
    "is_container": $is_container,
    "max_concurrent_agents": $MAX_CONCURRENT_AGENTS
}
EOF
}

# Lock management with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ -f "$LOCK_FILE" ]] && [[ $elapsed -lt $timeout ]]; do
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
        if ! kill -0 "$lock_pid" 2>/dev/null; then
            log "WARN" "Removing stale lock file (PID: $lock_pid)"
            rm -f "$LOCK_FILE"
            break
        fi
        log "INFO" "Waiting for lock (PID: $lock_pid owns it)..."
        sleep 1
        ((elapsed++))
    done
    
    if [[ -f "$LOCK_FILE" ]]; then
        log "ERROR" "Failed to acquire lock after ${timeout}s"
        exit 1
    fi
    
    echo $$ > "$LOCK_FILE"
    log "DEBUG" "Lock acquired (PID: $$)"
}

release_lock() {
    rm -f "$LOCK_FILE"
    log "DEBUG" "Lock released"
}

# Cleanup handler
cleanup() {
    log "INFO" "Cleanup initiated..."
    
    # Kill remaining agent processes
    for pid_file in "$STATE_DIR"/.pid_*; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log "INFO" "Terminating agent process: $pid"
                kill -TERM "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Save final state
    if [[ "$ENABLE_CHECKPOINTS" == "true" ]]; then
        save_checkpoint "final"
    fi
    
    release_lock
    log "INFO" "Cleanup completed"
}
trap cleanup EXIT INT TERM

# Checkpoint management
save_checkpoint() {
    local checkpoint_name="$1"
    local checkpoint_file="$CHECKPOINT_DIR/checkpoint_${checkpoint_name}_$(date +%Y%m%d_%H%M%S).json"
    
    log "INFO" "Saving checkpoint: $checkpoint_name"
    
    jq -n \
        --arg name "$checkpoint_name" \
        --arg time "$(date -Iseconds)" \
        --argjson state "$(cat "$STATE_DIR/coordinator_state.json" 2>/dev/null || echo '{}')" \
        '{name: $name, timestamp: $time, state: $state}' > "$checkpoint_file"
}

restore_checkpoint() {
    local checkpoint_file="$1"
    
    if [[ -f "$checkpoint_file" ]]; then
        log "INFO" "Restoring from checkpoint: $checkpoint_file"
        jq '.state' "$checkpoint_file" > "$STATE_DIR/coordinator_state.json"
        return 0
    else
        log "ERROR" "Checkpoint not found: $checkpoint_file"
        return 1
    fi
}

# Initialize coordinator state
initialize_state() {
    log "INFO" "Initializing coordinator state..."
    
    cat > "$STATE_DIR/coordinator_state.json" << EOF
{
    "mode": "$EXECUTION_MODE",
    "start_time": "$(date -Iseconds)",
    "max_concurrent": $MAX_CONCURRENT_AGENTS,
    "phase": "initialization",
    "agents": {},
    "metrics": {
        "total_agents": 0,
        "completed": 0,
        "failed": 0,
        "running": 0,
        "pending": 0,
        "retries": 0
    },
    "status": "initializing"
}
EOF

    # Initialize agent states
    for agent_id in "${!AGENT_REGISTRY[@]}"; do
        jq --arg id "$agent_id" '.agents[$id] = {
            "status": "pending",
            "attempts": 0,
            "start_time": null,
            "end_time": null,
            "exit_code": null,
            "dependencies_met": false
        }' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
        mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
    done
}

# Dependency resolution
check_dependencies() {
    local agent_id="$1"
    local deps="${AGENT_DEPENDENCIES[$agent_id]}"
    
    if [[ -z "$deps" ]]; then
        return 0  # No dependencies
    fi
    
    IFS=',' read -ra dep_array <<< "$deps"
    for dep in "${dep_array[@]}"; do
        local dep_status=$(jq -r --arg dep "$dep" '.agents[$dep].status // "unknown"' "$STATE_DIR/coordinator_state.json")
        if [[ "$dep_status" != "completed" ]]; then
            log "DEBUG" "Agent $agent_id waiting for dependency: $dep (status: $dep_status)"
            return 1
        fi
    done
    
    return 0
}

# Agent deployment with retry logic
deploy_agent_production() {
    local agent_id="$1"
    local agent_spec="${AGENT_REGISTRY[$agent_id]}"
    local script=$(echo "$agent_spec" | cut -d'|' -f1)
    local name=$(echo "$agent_spec" | cut -d'|' -f2)
    local args=$(echo "$agent_spec" | cut -d'|' -f3)
    local priority="${AGENT_PRIORITIES[$agent_id]}"
    
    log "INFO" "Deploying agent: $name (ID: $agent_id, Priority: $priority)"
    
    # Update state
    jq --arg id "$agent_id" --arg time "$(date -Iseconds)" '
        .agents[$id].status = "running" |
        .agents[$id].start_time = $time |
        .metrics.running += 1 |
        .metrics.pending -= 1
    ' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
    
    # Create agent log directory
    local agent_log_dir="$LOG_DIR/agents/$agent_id"
    mkdir -p "$agent_log_dir"
    
    # Deploy agent in background
    (
        local attempt=1
        local success=false
        
        while [[ $attempt -le $RETRY_ATTEMPTS ]] && [[ "$success" == "false" ]]; do
            log "INFO" "Agent $name - Attempt $attempt/$RETRY_ATTEMPTS"
            
            local log_file="$agent_log_dir/attempt_${attempt}.log"
            local metrics_file="$agent_log_dir/metrics_${attempt}.json"
            
            # Record start metrics
            local start_time=$(date +%s)
            
            # Execute agent
            if [[ "$DRY_RUN" == "true" ]]; then
                log "INFO" "DRY RUN: Would execute $script $args"
                sleep 2  # Simulate execution
                local exit_code=0
            else
                timeout "$AGENT_TIMEOUT" bash "$SCRIPT_DIR/$script" $args > "$log_file" 2>&1
                local exit_code=$?
            fi
            
            # Record end metrics
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            # Save metrics
            jq -n \
                --arg agent "$agent_id" \
                --arg attempt "$attempt" \
                --arg duration "$duration" \
                --arg exit_code "$exit_code" \
                '{agent: $agent, attempt: $attempt | tonumber, duration: $duration | tonumber, exit_code: $exit_code | tonumber}' > "$metrics_file"
            
            if [[ $exit_code -eq 0 ]]; then
                success=true
                log "SUCCESS" "Agent $name completed successfully"
                
                # Update state
                jq --arg id "$agent_id" --arg time "$(date -Iseconds)" --arg code "$exit_code" '
                    .agents[$id].status = "completed" |
                    .agents[$id].end_time = $time |
                    .agents[$id].exit_code = ($code | tonumber) |
                    .metrics.completed += 1 |
                    .metrics.running -= 1
                ' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
                mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
            else
                log "WARN" "Agent $name failed with exit code: $exit_code"
                
                if [[ $attempt -lt $RETRY_ATTEMPTS ]]; then
                    local backoff=$((attempt * 5))
                    log "INFO" "Retrying in ${backoff}s..."
                    sleep $backoff
                else
                    # Final failure
                    jq --arg id "$agent_id" --arg time "$(date -Iseconds)" --arg code "$exit_code" '
                        .agents[$id].status = "failed" |
                        .agents[$id].end_time = $time |
                        .agents[$id].exit_code = ($code | tonumber) |
                        .metrics.failed += 1 |
                        .metrics.running -= 1
                    ' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
                    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
                fi
            fi
            
            ((attempt++))
        done
        
        # Remove PID file
        rm -f "$STATE_DIR/.pid_$agent_id"
        
    ) &
    
    local pid=$!
    echo $pid > "$STATE_DIR/.pid_$agent_id"
    
    # Update metrics
    jq '.metrics.total_agents += 1' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
}

# Priority-based scheduling
schedule_agents() {
    log "INFO" "Starting priority-based agent scheduling..."
    
    local agents_by_priority=()
    
    # Sort agents by priority
    for agent_id in "${!AGENT_PRIORITIES[@]}"; do
        local priority="${AGENT_PRIORITIES[$agent_id]}"
        agents_by_priority+=("$priority:$agent_id")
    done
    
    # Sort array
    IFS=$'\n' sorted_agents=($(sort -n <<<"${agents_by_priority[*]}"))
    unset IFS
    
    # Process agents by priority
    local current_priority=""
    local priority_batch=()
    
    for agent_entry in "${sorted_agents[@]}"; do
        local priority=$(echo "$agent_entry" | cut -d':' -f1)
        local agent_id=$(echo "$agent_entry" | cut -d':' -f2)
        
        if [[ "$priority" != "$current_priority" ]] && [[ ${#priority_batch[@]} -gt 0 ]]; then
            # Process previous priority batch
            process_agent_batch "${priority_batch[@]}"
            priority_batch=()
        fi
        
        current_priority="$priority"
        priority_batch+=("$agent_id")
    done
    
    # Process final batch
    if [[ ${#priority_batch[@]} -gt 0 ]]; then
        process_agent_batch "${priority_batch[@]}"
    fi
}

# Process batch of agents
process_agent_batch() {
    local agents=("$@")
    log "INFO" "Processing batch of ${#agents[@]} agents"
    
    while true; do
        local deployed=0
        local pending=0
        
        for agent_id in "${agents[@]}"; do
            local status=$(jq -r --arg id "$agent_id" '.agents[$id].status' "$STATE_DIR/coordinator_state.json")
            
            case "$status" in
                "completed"|"failed")
                    continue
                    ;;
                "running")
                    deployed=1
                    ;;
                "pending")
                    # Check if can deploy
                    if check_dependencies "$agent_id"; then
                        local running_count=$(jq -r '.metrics.running' "$STATE_DIR/coordinator_state.json")
                        
                        if [[ $running_count -lt $MAX_CONCURRENT_AGENTS ]]; then
                            deploy_agent_production "$agent_id"
                            deployed=1
                        else
                            pending=1
                        fi
                    else
                        pending=1
                    fi
                    ;;
            esac
        done
        
        # Check if batch is complete
        if [[ $deployed -eq 0 ]] && [[ $pending -eq 0 ]]; then
            break
        fi
        
        # Health check
        perform_health_check
        
        sleep 2
    done
}

# Health monitoring
perform_health_check() {
    local running_count=$(jq -r '.metrics.running' "$STATE_DIR/coordinator_state.json")
    local failed_count=$(jq -r '.metrics.failed' "$STATE_DIR/coordinator_state.json")
    
    # Check for stuck agents
    for pid_file in "$STATE_DIR"/.pid_*; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            local agent_id=$(basename "$pid_file" | sed 's/\.pid_//')
            
            if ! kill -0 "$pid" 2>/dev/null; then
                log "WARN" "Agent $agent_id process died unexpectedly"
                rm -f "$pid_file"
                
                # Update state
                jq --arg id "$agent_id" '
                    .agents[$id].status = "failed" |
                    .metrics.failed += 1 |
                    .metrics.running -= 1
                ' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
                mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
            fi
        fi
    done
    
    # Save checkpoint periodically
    if [[ "$ENABLE_CHECKPOINTS" == "true" ]] && [[ $((RANDOM % 10)) -eq 0 ]]; then
        save_checkpoint "auto"
    fi
}

# Execution modes with production features
execute_smart_production() {
    log "INFO" "Executing in SMART mode with production features"
    
    # Analyze build output
    if [[ -f "build_output.txt" ]]; then
        bash "$SCRIPT_DIR/generic_build_analyzer.sh" > "$STATE_DIR/error_analysis.json"
        local error_count=$(jq '.total_errors // 0' "$STATE_DIR/error_analysis.json")
        log "INFO" "Detected $error_count errors"
        
        # Adjust strategy based on errors
        if [[ $error_count -eq 0 ]]; then
            log "INFO" "No errors detected, running minimal validation"
            AGENT_PRIORITIES["qa_final"]=1  # Only run QA
        elif [[ $error_count -le 10 ]]; then
            log "INFO" "Few errors, focusing on targeted fixes"
            # Adjust priorities for targeted approach
        else
            log "INFO" "Many errors, running comprehensive fix"
            # Use default priorities
        fi
    fi
    
    schedule_agents
}

execute_parallel_production() {
    log "INFO" "Executing in PARALLEL mode - maximum concurrency"
    
    # Temporarily increase concurrency for parallel mode
    local original_max=$MAX_CONCURRENT_AGENTS
    MAX_CONCURRENT_AGENTS=$((MAX_CONCURRENT_AGENTS * 2))
    
    schedule_agents
    
    MAX_CONCURRENT_AGENTS=$original_max
}

execute_minimal_production() {
    log "INFO" "Executing in MINIMAL mode - essential agents only"
    
    # Only enable core agents
    for agent_id in "${!AGENT_PRIORITIES[@]}"; do
        if [[ ${AGENT_PRIORITIES[$agent_id]} -gt 2 ]]; then
            jq --arg id "$agent_id" '.agents[$id].status = "skipped"' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
            mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
        fi
    done
    
    schedule_agents
}

# Generate comprehensive report
generate_production_report() {
    log "INFO" "Generating production report..."
    
    local report_file="$STATE_DIR/production_report_$(date +%Y%m%d_%H%M%S).json"
    local summary_file="$STATE_DIR/production_summary_$(date +%Y%m%d_%H%M%S).md"
    
    # Generate JSON report
    jq -n \
        --arg mode "$EXECUTION_MODE" \
        --arg start "$(jq -r '.start_time' "$STATE_DIR/coordinator_state.json")" \
        --arg end "$(date -Iseconds)" \
        --argjson state "$(cat "$STATE_DIR/coordinator_state.json")" \
        --argjson hardware "$(cat "$STATE_DIR/hardware_info.json" 2>/dev/null || echo '{}')" \
        '{
            execution_mode: $mode,
            start_time: $start,
            end_time: $end,
            hardware: $hardware,
            state: $state,
            metrics: $state.metrics,
            agents: $state.agents
        }' > "$report_file"
    
    # Generate markdown summary
    {
        echo "# Production Coordinator Execution Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Execution Summary"
        echo "- Mode: $EXECUTION_MODE"
        echo "- Duration: $(jq -r '(.end_time as $e | .start_time as $s | (($e | fromdateiso8601) - ($s | fromdateiso8601)) / 60 | floor) as $m | "\($m) minutes"' "$report_file")"
        echo "- Max Concurrent: $MAX_CONCURRENT_AGENTS"
        echo ""
        echo "## Results"
        jq -r '.metrics | "- Total Agents: \(.total_agents)\n- Completed: \(.completed)\n- Failed: \(.failed)\n- Skipped: \(.pending)"' "$report_file"
        echo ""
        echo "## Agent Details"
        echo "| Agent | Status | Duration | Attempts |"
        echo "|-------|--------|----------|----------|"
        jq -r '.agents | to_entries[] | "| \(.key) | \(.value.status) | \(if .value.end_time and .value.start_time then (((.value.end_time | fromdateiso8601) - (.value.start_time | fromdateiso8601)) | tostring + "s") else "N/A" end) | \(.value.attempts // 0) |"' "$report_file"
        echo ""
        echo "## Recommendations"
        local failed_count=$(jq -r '.metrics.failed' "$report_file")
        if [[ $failed_count -gt 0 ]]; then
            echo "- **Action Required**: $failed_count agents failed. Review logs in: $LOG_DIR/agents/"
        else
            echo "- **Success**: All agents completed successfully"
        fi
    } > "$summary_file"
    
    log "SUCCESS" "Reports generated:"
    log "SUCCESS" "  - JSON: $report_file"
    log "SUCCESS" "  - Summary: $summary_file"
    
    # Display summary
    cat "$summary_file"
}

# Main execution
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Production Coordinator - Enterprise Edition         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pre-flight checks
    log "INFO" "Starting pre-flight checks..."
    
    # Check required tools
    for tool in jq bc timeout; do
        if ! command -v "$tool" &> /dev/null; then
            log "ERROR" "Required tool not found: $tool"
            exit 1
        fi
    done
    
    # Acquire lock
    acquire_lock
    
    # System checks
    detect_hardware_advanced
    check_system_resources
    
    # Initialize
    initialize_agent_registry
    initialize_state
    
    # Update status
    jq '.status = "running"' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
    
    # Execute based on mode
    case "$EXECUTION_MODE" in
        smart)
            execute_smart_production
            ;;
        parallel)
            execute_parallel_production
            ;;
        minimal)
            execute_minimal_production
            ;;
        sequential)
            MAX_CONCURRENT_AGENTS=1
            schedule_agents
            ;;
        phase)
            # Phase mode uses priority groups
            schedule_agents
            ;;
        full)
            # Full mode runs everything
            schedule_agents
            ;;
        *)
            log "ERROR" "Unknown mode: $EXECUTION_MODE"
            exit 1
            ;;
    esac
    
    # Wait for all agents to complete
    log "INFO" "Waiting for all agents to complete..."
    while true; do
        local running=$(jq -r '.metrics.running' "$STATE_DIR/coordinator_state.json")
        if [[ $running -eq 0 ]]; then
            break
        fi
        log "INFO" "Agents still running: $running"
        sleep 5
    done
    
    # Final status update
    jq '.status = "completed"' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
    
    # Generate reports
    generate_production_report
    
    # Final metrics
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        log "INFO" "Metrics saved to: $METRICS_DIR"
    fi
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Production Execution Complete!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Help function
show_help() {
    cat << EOF
Production Coordinator - Enterprise-grade multi-agent orchestration

Usage: $0 [mode] [options]

Modes:
  smart      - Adaptive based on error analysis (default)
  parallel   - Maximum parallelization
  minimal    - Essential agents only
  sequential - One agent at a time
  phase      - Priority-based phases
  full       - All agents

Options:
  --dry-run              - Simulate execution without running agents
  --max-agents N         - Set maximum concurrent agents
  --timeout N            - Set agent timeout in seconds (default: 300)
  --retry N              - Set retry attempts (default: 3)
  --no-metrics           - Disable metrics collection
  --no-checkpoints       - Disable checkpointing
  --restore FILE         - Restore from checkpoint
  --priority-mode        - Enable priority-based scheduling (default)

Environment Variables:
  MAX_CONCURRENT_AGENTS  - Maximum parallel agents
  AGENT_TIMEOUT          - Timeout per agent
  RETRY_ATTEMPTS         - Retry attempts for failed agents
  ENABLE_METRICS         - Enable metrics collection
  ENABLE_CHECKPOINTS     - Enable checkpointing
  DEBUG                  - Enable debug logging

Examples:
  # Standard execution
  $0

  # Dry run to see what would execute
  $0 smart --dry-run

  # High concurrency with custom timeout
  $0 parallel --max-agents 10 --timeout 600

  # Restore from checkpoint
  $0 --restore checkpoints/checkpoint_auto_20240614_120000.json

  # Minimal mode for quick fixes
  $0 minimal --no-metrics
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --max-agents)
            MAX_CONCURRENT_AGENTS="$2"
            shift 2
            ;;
        --timeout)
            AGENT_TIMEOUT="$2"
            shift 2
            ;;
        --retry)
            RETRY_ATTEMPTS="$2"
            shift 2
            ;;
        --no-metrics)
            ENABLE_METRICS=false
            shift
            ;;
        --no-checkpoints)
            ENABLE_CHECKPOINTS=false
            shift
            ;;
        --restore)
            restore_checkpoint "$2"
            shift 2
            ;;
        --priority-mode)
            PRIORITY_MODE=true
            shift
            ;;
        smart|parallel|minimal|sequential|phase|full)
            EXECUTION_MODE="$1"
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main
main