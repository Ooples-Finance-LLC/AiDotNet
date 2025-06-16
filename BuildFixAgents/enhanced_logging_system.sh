#!/bin/bash
# Enhanced Logging System for ZeroDev/BuildFixAgents
# Provides comprehensive, human-readable logging with full agent visibility

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
STRUCTURED_LOG_DIR="$LOG_DIR/structured"
HUMAN_LOG_DIR="$LOG_DIR/human_readable"

# Create log directories
mkdir -p "$STRUCTURED_LOG_DIR" "$HUMAN_LOG_DIR"

# Colors for terminal output
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Log files
MASTER_LOG="$HUMAN_LOG_DIR/master_execution_$(date +%Y%m%d_%H%M%S).log"
AGENT_STATUS_LOG="$HUMAN_LOG_DIR/agent_status.log"
TASK_TRACKING_LOG="$HUMAN_LOG_DIR/task_tracking.log"
DEBUG_LOG="$STRUCTURED_LOG_DIR/debug_$(date +%Y%m%d_%H%M%S).json"

# Initialize master log
cat > "$MASTER_LOG" << EOF
════════════════════════════════════════════════════════════════════════
                    ZeroDev/BuildFixAgents Execution Log
════════════════════════════════════════════════════════════════════════
Started: $(date)
System: $(uname -a)
User: $(whoami)
Working Directory: $(pwd)
════════════════════════════════════════════════════════════════════════

EOF

# Agent status tracking
declare -gA AGENT_STATUS=()
declare -gA AGENT_TASKS=()
declare -gA TASK_STATUS=()
declare -g TASK_COUNTER=0

# Enhanced logging function
log_event() {
    local level="$1"
    local agent="${2:-SYSTEM}"
    local event="$3"
    local details="${4:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Color coding based on level
    local color=""
    case "$level" in
        ERROR) color="$RED" ;;
        SUCCESS) color="$GREEN" ;;
        WARNING) color="$YELLOW" ;;
        INFO) color="$BLUE" ;;
        DEBUG) color="$GRAY" ;;
        TASK) color="$PURPLE" ;;
        STATUS) color="$CYAN" ;;
    esac
    
    # Terminal output (if interactive)
    if [[ -t 1 ]]; then
        printf "${color}[%s] %-12s | %-20s | %s${NC}\n" \
            "$timestamp" "$level" "$agent" "$event" >&2
        [[ -n "$details" ]] && printf "${GRAY}%s└─ %s${NC}\n" \
            "$(printf ' %.0s' {1..55})" "$details" >&2
    fi
    
    # Human-readable log
    {
        printf "[%s] %-12s | %-20s | %s\n" "$timestamp" "$level" "$agent" "$event"
        [[ -n "$details" ]] && printf "%s└─ %s\n" "$(printf ' %.0s' {1..55})" "$details"
    } >> "$MASTER_LOG"
    
    # Structured JSON log
    jq -n \
        --arg ts "$timestamp" \
        --arg lvl "$level" \
        --arg agt "$agent" \
        --arg evt "$event" \
        --arg dtl "$details" \
        '{timestamp: $ts, level: $lvl, agent: $agt, event: $evt, details: $dtl}' \
        >> "$DEBUG_LOG"
}

# Agent lifecycle logging
log_agent_start() {
    local agent="$1"
    local role="${2:-unknown}"
    
    AGENT_STATUS["$agent"]="STARTING"
    log_event "STATUS" "$agent" "Agent starting" "Role: $role"
    
    # Update agent status file
    update_agent_status_file
}

log_agent_ready() {
    local agent="$1"
    
    AGENT_STATUS["$agent"]="READY"
    log_event "SUCCESS" "$agent" "Agent ready"
    update_agent_status_file
}

log_agent_complete() {
    local agent="$1"
    local summary="${2:-No summary provided}"
    
    AGENT_STATUS["$agent"]="COMPLETE"
    log_event "SUCCESS" "$agent" "Agent completed" "$summary"
    update_agent_status_file
}

log_agent_error() {
    local agent="$1"
    local error="$2"
    
    AGENT_STATUS["$agent"]="ERROR"
    log_event "ERROR" "$agent" "Agent error" "$error"
    update_agent_status_file
}

# Task tracking
create_task() {
    local agent="$1"
    local description="$2"
    local priority="${3:-NORMAL}"
    
    TASK_COUNTER=$((TASK_COUNTER + 1))
    local task_id="TASK-$(printf '%04d' $TASK_COUNTER)"
    
    AGENT_TASKS["$task_id"]="$agent"
    TASK_STATUS["$task_id"]="CREATED|$description|$priority"
    
    log_event "TASK" "$agent" "Task created: $task_id" "$description (Priority: $priority)"
    update_task_tracking_file
    
    echo "$task_id"
}

assign_task() {
    local task_id="$1"
    local target_agent="$2"
    
    local creating_agent="${AGENT_TASKS["$task_id"]:-unknown}"
    local current_status="${TASK_STATUS["$task_id"]:-}"
    TASK_STATUS["$task_id"]="ASSIGNED|$(echo "$current_status" | cut -d'|' -f2-)|$target_agent"
    
    log_event "TASK" "$creating_agent" "Task assigned: $task_id → $target_agent"
    update_task_tracking_file
}

start_task() {
    local task_id="$1"
    local agent="$2"
    
    TASK_STATUS["$task_id"]="IN_PROGRESS|$(echo "${TASK_STATUS["$task_id"]}" | cut -d'|' -f2-)"
    log_event "TASK" "$agent" "Task started: $task_id"
    update_task_tracking_file
}

complete_task() {
    local task_id="$1"
    local agent="$2"
    local result="${3:-Success}"
    
    TASK_STATUS["$task_id"]="COMPLETE|$(echo "${TASK_STATUS["$task_id"]}" | cut -d'|' -f2-)|$result"
    log_event "SUCCESS" "$agent" "Task completed: $task_id" "$result"
    update_task_tracking_file
}

fail_task() {
    local task_id="$1"
    local agent="$2"
    local reason="$3"
    
    TASK_STATUS["$task_id"]="FAILED|$(echo "${TASK_STATUS["$task_id"]}" | cut -d'|' -f2-)|$reason"
    log_event "ERROR" "$agent" "Task failed: $task_id" "$reason"
    update_task_tracking_file
}

# Status file updates
update_agent_status_file() {
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "                        Agent Status Report"
        echo "════════════════════════════════════════════════════════════════"
        echo "Updated: $(date)"
        echo ""
        echo "Agent Name                    | Status      | Tasks | Completed"
        echo "─────────────────────────────┼─────────────┼───────┼──────────"
        
        for agent in "${!AGENT_STATUS[@]}"; do
            local status="${AGENT_STATUS[$agent]}"
            local total_tasks=0
            local completed_tasks=0
            
            # Count tasks for this agent (check if array has elements)
            if [[ ${#AGENT_TASKS[@]} -gt 0 ]]; then
                for task_id in "${!AGENT_TASKS[@]}"; do
                    if [[ "${AGENT_TASKS["$task_id"]:-}" == "$agent" ]]; then
                        ((total_tasks++))
                        if [[ "${TASK_STATUS["$task_id"]:-}" =~ ^COMPLETE ]]; then
                            ((completed_tasks++))
                        fi
                    fi
                done
            fi
            
            printf "%-28s | %-11s | %5d | %9d\n" \
                "$agent" "$status" "$total_tasks" "$completed_tasks"
        done
    } > "$AGENT_STATUS_LOG"
}

update_task_tracking_file() {
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "                      Task Tracking Report"
        echo "════════════════════════════════════════════════════════════════"
        echo "Updated: $(date)"
        echo ""
        echo "Task ID   | Status       | Created By           | Assigned To          | Description"
        echo "──────────┼──────────────┼─────────────────────┼─────────────────────┼─────────────"
        
        if [[ ${#TASK_STATUS[@]} -gt 0 ]]; then
            for task_id in "${!TASK_STATUS[@]}"; do
            IFS='|' read -r status desc priority assigned_to result <<< "${TASK_STATUS["$task_id"]}"
            local created_by="${AGENT_TASKS["$task_id"]}"
            
            printf "%-9s | %-12s | %-19s | %-19s | %s\n" \
                "$task_id" "$status" "$created_by" "${assigned_to:-N/A}" "$desc"
            done | sort
        fi
    } > "$TASK_TRACKING_LOG"
}

# Performance tracking
log_performance() {
    local agent="$1"
    local operation="$2"
    local duration="$3"
    local memory="${4:-N/A}"
    
    log_event "DEBUG" "$agent" "Performance: $operation" \
        "Duration: ${duration}s, Memory: $memory"
}

# Decision logging
log_decision() {
    local agent="$1"
    local decision="$2"
    local reasoning="$3"
    
    log_event "INFO" "$agent" "Decision: $decision" "Reasoning: $reasoning"
}

# Communication logging
log_communication() {
    local from_agent="$1"
    local to_agent="$2"
    local message_type="$3"
    local content="${4:-}"
    
    log_event "INFO" "$from_agent" "Message → $to_agent ($message_type)" "$content"
}

# Summary generation
generate_execution_summary() {
    local summary_file="$HUMAN_LOG_DIR/execution_summary_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$summary_file" << EOF
# Execution Summary Report

**Generated**: $(date)  
**Duration**: ${EXECUTION_DURATION:-Unknown}

## Overview

### Agent Performance
EOF
    
    # Agent summary
    local total_agents=${#AGENT_STATUS[@]}
    local successful_agents=0
    local failed_agents=0
    
    for status in "${AGENT_STATUS[@]}"; do
        case "$status" in
            COMPLETE) ((successful_agents++)) ;;
            ERROR) ((failed_agents++)) ;;
        esac
    done
    
    cat >> "$summary_file" << EOF
- Total Agents: $total_agents
- Successful: $successful_agents
- Failed: $failed_agents
- Success Rate: $(( total_agents > 0 ? successful_agents * 100 / total_agents : 0 ))%

### Task Execution
EOF
    
    # Task summary
    local total_tasks=${#TASK_STATUS[@]}
    local completed_tasks=0
    local failed_tasks=0
    
    for task_status in "${TASK_STATUS[@]}"; do
        if [[ "$task_status" =~ ^COMPLETE ]]; then
            ((completed_tasks++))
        elif [[ "$task_status" =~ ^FAILED ]]; then
            ((failed_tasks++))
        fi
    done
    
    cat >> "$summary_file" << EOF
- Total Tasks: $total_tasks
- Completed: $completed_tasks
- Failed: $failed_tasks
- Success Rate: $(( total_tasks > 0 ? completed_tasks * 100 / total_tasks : 0 ))%

## Detailed Agent Report

| Agent | Status | Tasks Created | Tasks Completed | Success Rate |
|-------|--------|---------------|-----------------|--------------|
EOF
    
    for agent in "${!AGENT_STATUS[@]}"; do
        local status="${AGENT_STATUS[$agent]}"
        local created=0
        local completed=0
        
        for task_id in "${!AGENT_TASKS[@]}"; do
            if [[ "${AGENT_TASKS["$task_id"]}" == "$agent" ]]; then
                ((created++))
                if [[ "${TASK_STATUS["$task_id"]}" =~ ^COMPLETE ]]; then
                    ((completed++))
                fi
            fi
        done
        
        local rate=$(( created > 0 ? completed * 100 / created : 0 ))
        echo "| $agent | $status | $created | $completed | $rate% |" >> "$summary_file"
    done
    
    echo -e "\n## Key Events\n" >> "$summary_file"
    grep -E "(ERROR|SUCCESS|WARNING)" "$MASTER_LOG" | tail -20 >> "$summary_file"
    
    echo -e "\n---\n*Full logs available at: $MASTER_LOG*" >> "$summary_file"
    
    log_event "INFO" "SYSTEM" "Execution summary generated" "$summary_file"
}

# Export functions for use by other scripts
export -f log_event log_agent_start log_agent_ready log_agent_complete log_agent_error
export -f create_task assign_task start_task complete_task fail_task
export -f log_performance log_decision log_communication
export -f generate_execution_summary

# If sourced, provide log locations
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export MASTER_LOG
    export AGENT_STATUS_LOG
    export TASK_TRACKING_LOG
    export DEBUG_LOG
    
    log_event "INFO" "SYSTEM" "Enhanced logging system initialized"
fi