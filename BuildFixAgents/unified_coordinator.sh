#!/bin/bash
# Unified Coordinator - Combines best features from all coordinators
# Supports: Sequential, Parallel, Hybrid, and Adaptive execution modes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/unified_coordinator"
LOG_DIR="$SCRIPT_DIR/state/logs"
LOCK_FILE="$STATE_DIR/.lock"

# Create necessary directories
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Configuration
MAX_CONCURRENT_AGENTS=${MAX_CONCURRENT_AGENTS:-3}
EXECUTION_MODE="${1:-smart}"  # smart, sequential, parallel, phase, full, minimal
PHASE_TIMEOUT=110  # seconds per phase (under 2-minute limit)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Hardware detection (from enhanced coordinator)
detect_hardware() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] Detecting hardware capabilities...${NC}"
    
    local cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
    local memory_gb=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo 4)
    
    # Adaptive concurrent agents based on hardware
    if [[ $cpu_cores -ge 8 ]] && [[ $memory_gb -ge 16 ]]; then
        MAX_CONCURRENT_AGENTS=6
        echo -e "${GREEN}High-performance system detected: $cpu_cores cores, ${memory_gb}GB RAM${NC}"
    elif [[ $cpu_cores -ge 4 ]] && [[ $memory_gb -ge 8 ]]; then
        MAX_CONCURRENT_AGENTS=4
        echo -e "${GREEN}Standard system detected: $cpu_cores cores, ${memory_gb}GB RAM${NC}"
    else
        MAX_CONCURRENT_AGENTS=2
        echo -e "${YELLOW}Limited system detected: $cpu_cores cores, ${memory_gb}GB RAM${NC}"
    fi
    
    echo -e "${CYAN}Setting MAX_CONCURRENT_AGENTS=$MAX_CONCURRENT_AGENTS${NC}"
}

# Lock management (from generic coordinator)
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            echo -e "${RED}Another coordinator is running (PID: $lock_pid)${NC}"
            exit 1
        else
            echo -e "${YELLOW}Removing stale lock file${NC}"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    release_lock
    # Kill any remaining agent processes
    for pid_file in "$STATE_DIR"/.pid_*; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            kill -TERM "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
}
trap cleanup EXIT

# Initialize state (from generic coordinator)
initialize_state() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] Initializing coordinator state...${NC}"
    
    cat > "$STATE_DIR/coordinator_state.json" << EOF
{
    "mode": "$EXECUTION_MODE",
    "start_time": "$(date -Iseconds)",
    "max_concurrent": $MAX_CONCURRENT_AGENTS,
    "phase": "initialization",
    "agents_deployed": 0,
    "agents_completed": 0,
    "agents_failed": 0,
    "iterations": 0,
    "status": "running"
}
EOF
}

# Error analysis (from generic coordinator)
analyze_errors() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] Analyzing build errors...${NC}"
    
    if [[ -f "build_output.txt" ]]; then
        bash "$SCRIPT_DIR/generic_build_analyzer.sh" > "$STATE_DIR/error_analysis.json"
        local error_count=$(jq '.total_errors // 0' "$STATE_DIR/error_analysis.json")
        echo -e "${YELLOW}Found $error_count errors to fix${NC}"
        return 0
    else
        echo -e "${RED}No build output found${NC}"
        return 1
    fi
}

# Agent deployment functions
deploy_agent_sequential() {
    local agent_script="$1"
    local agent_name="$2"
    local agent_args="${3:-}"
    
    echo -e "${BLUE}[$(date +'%H:%M:%S')] Deploying $agent_name (sequential)...${NC}"
    
    if timeout "$PHASE_TIMEOUT" bash "$SCRIPT_DIR/$agent_script" $agent_args > "$LOG_DIR/${agent_name}.log" 2>&1; then
        echo -e "${GREEN}✓ $agent_name completed${NC}"
        return 0
    else
        echo -e "${RED}✗ $agent_name failed or timed out${NC}"
        return 1
    fi
}

deploy_agent_parallel() {
    local agent_script="$1"
    local agent_name="$2"
    local agent_args="${3:-}"
    local agent_id="${agent_name//[^a-zA-Z0-9]/_}"
    
    echo -e "${BLUE}[$(date +'%H:%M:%S')] Deploying $agent_name (parallel)...${NC}"
    
    (
        timeout "$PHASE_TIMEOUT" bash "$SCRIPT_DIR/$agent_script" $agent_args > "$LOG_DIR/${agent_name}.log" 2>&1
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}✓ $agent_name completed${NC}"
            echo "completed" > "$STATE_DIR/.status_$agent_id"
        else
            echo -e "${RED}✗ $agent_name failed${NC}"
            echo "failed" > "$STATE_DIR/.status_$agent_id"
        fi
        
        rm -f "$STATE_DIR/.pid_$agent_id"
        exit $exit_code
    ) &
    
    local pid=$!
    echo $pid > "$STATE_DIR/.pid_$agent_id"
    return 0
}

wait_for_parallel_agents() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] Waiting for parallel agents to complete...${NC}"
    
    while true; do
        local running=0
        for pid_file in "$STATE_DIR"/.pid_*; do
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    ((running++))
                fi
            fi
        done
        
        if [[ $running -eq 0 ]]; then
            break
        fi
        
        echo -e "${YELLOW}$running agents still running...${NC}"
        sleep 2
    done
    
    # Count results
    local completed=0
    local failed=0
    for status_file in "$STATE_DIR"/.status_*; do
        if [[ -f "$status_file" ]]; then
            local status=$(cat "$status_file")
            if [[ "$status" == "completed" ]]; then
                ((completed++))
            else
                ((failed++))
            fi
            rm -f "$status_file"
        fi
    done
    
    echo -e "${GREEN}Completed: $completed${NC}, ${RED}Failed: $failed${NC}"
}

# Execution modes
execute_smart_mode() {
    echo -e "${CYAN}=== SMART MODE - Adaptive execution based on error analysis ===${NC}"
    
    # Analyze errors first
    if ! analyze_errors; then
        echo -e "${RED}No errors to fix${NC}"
        return 0
    fi
    
    local error_count=$(jq '.total_errors // 0' "$STATE_DIR/error_analysis.json")
    
    # Choose execution pattern based on error count
    if [[ $error_count -le 5 ]]; then
        echo -e "${YELLOW}Few errors detected, using sequential mode${NC}"
        execute_sequential_mode
    elif [[ $error_count -le 20 ]]; then
        echo -e "${YELLOW}Moderate errors detected, using hybrid mode${NC}"
        execute_phase_mode
    else
        echo -e "${YELLOW}Many errors detected, using parallel mode${NC}"
        execute_parallel_mode
    fi
}

execute_sequential_mode() {
    echo -e "${CYAN}=== SEQUENTIAL MODE - One agent at a time ===${NC}"
    
    # Core fix agents
    deploy_agent_sequential "generic_build_analyzer.sh" "Build Analyzer"
    deploy_agent_sequential "generic_error_agent.sh" "Error Agent"
    deploy_agent_sequential "unified_error_counter.sh" "Error Counter"
    
    # Development agents
    deploy_agent_sequential "architect_agent_v2.sh" "Architect" "plan"
    deploy_agent_sequential "dev_agent_core_fix.sh" "Core Dev"
    
    # Specialized fixes
    deploy_agent_sequential "agent1_duplicate_resolver.sh" "Duplicate Resolver"
    deploy_agent_sequential "agent2_constraints_specialist.sh" "Constraints"
    
    # QA
    deploy_agent_sequential "qa_agent_final.sh" "QA Final" "test"
}

execute_parallel_mode() {
    echo -e "${CYAN}=== PARALLEL MODE - Multiple agents simultaneously ===${NC}"
    
    # Deploy core agents in parallel
    local agents_deployed=0
    
    # Core fix agents
    deploy_agent_parallel "generic_build_analyzer.sh" "Build Analyzer" &
    deploy_agent_parallel "generic_error_agent.sh" "Error Agent" &
    deploy_agent_parallel "unified_error_counter.sh" "Error Counter" &
    
    wait_for_parallel_agents
    
    # Development agents in batches
    while IFS= read -r agent_spec; do
        if [[ $agents_deployed -ge $MAX_CONCURRENT_AGENTS ]]; then
            wait_for_parallel_agents
            agents_deployed=0
        fi
        
        local script=$(echo "$agent_spec" | cut -d'|' -f1)
        local name=$(echo "$agent_spec" | cut -d'|' -f2)
        local args=$(echo "$agent_spec" | cut -d'|' -f3)
        
        deploy_agent_parallel "$script" "$name" "$args"
        ((agents_deployed++))
    done << EOF
dev_agent_core_fix.sh|Core Dev|
dev_agent_integration.sh|Integration Dev|
dev_agent_patterns.sh|Pattern Dev|
architect_agent_v2.sh|Architect|plan
agent1_duplicate_resolver.sh|Duplicate Fix|
agent2_constraints_specialist.sh|Constraints Fix|
agent3_inheritance_specialist.sh|Inheritance Fix|
qa_automation_agent.sh|QA Automation|test
EOF
    
    wait_for_parallel_agents
}

execute_phase_mode() {
    echo -e "${CYAN}=== PHASE MODE - Sequential phases with parallel execution ===${NC}"
    
    # Phase 1: Analysis (Sequential)
    echo -e "${YELLOW}Phase 1: Analysis${NC}"
    deploy_agent_sequential "generic_build_analyzer.sh" "Build Analyzer"
    deploy_agent_sequential "analysis_agent.sh" "Code Analysis" "full"
    
    # Phase 2: Planning (Sequential)
    echo -e "${YELLOW}Phase 2: Planning${NC}"
    deploy_agent_sequential "architect_agent_v2.sh" "Architect" "plan"
    deploy_agent_sequential "project_manager_agent.sh" "Project Manager" "plan"
    
    # Phase 3: Development (Parallel)
    echo -e "${YELLOW}Phase 3: Development (Parallel)${NC}"
    deploy_agent_parallel "dev_agent_core_fix.sh" "Core Dev" &
    deploy_agent_parallel "dev_agent_integration.sh" "Integration" &
    deploy_agent_parallel "dev_agent_patterns.sh" "Patterns" &
    wait_for_parallel_agents
    
    # Phase 4: Fixes (Parallel)
    echo -e "${YELLOW}Phase 4: Error Fixes (Parallel)${NC}"
    deploy_agent_parallel "generic_error_agent.sh" "Error Agent" &
    deploy_agent_parallel "agent1_duplicate_resolver.sh" "Duplicates" &
    deploy_agent_parallel "agent2_constraints_specialist.sh" "Constraints" &
    wait_for_parallel_agents
    
    # Phase 5: QA (Sequential)
    echo -e "${YELLOW}Phase 5: Quality Assurance${NC}"
    deploy_agent_sequential "qa_agent_final.sh" "QA Final" "test"
    deploy_agent_sequential "testing_agent_v2.sh" "Testing V2" "full"
    
    # Phase 6: Deployment Prep (Sequential)
    echo -e "${YELLOW}Phase 6: Deployment Preparation${NC}"
    deploy_agent_sequential "deployment_agent.sh" "Deployment" "prepare"
}

execute_full_mode() {
    echo -e "${CYAN}=== FULL MODE - Deploy all available agents ===${NC}"
    
    # Get all agent scripts
    local all_agents=$(find "$SCRIPT_DIR" -name "*_agent*.sh" -o -name "*_coordinator.sh" | grep -v unified_coordinator.sh | sort)
    
    echo -e "${YELLOW}Found $(echo "$all_agents" | wc -l) agents to deploy${NC}"
    
    # Deploy in batches
    local batch_count=0
    while IFS= read -r agent_script; do
        if [[ $batch_count -ge $MAX_CONCURRENT_AGENTS ]]; then
            wait_for_parallel_agents
            batch_count=0
        fi
        
        local agent_name=$(basename "$agent_script" .sh)
        deploy_agent_parallel "$agent_script" "$agent_name" &
        ((batch_count++))
    done <<< "$all_agents"
    
    wait_for_parallel_agents
}

execute_minimal_mode() {
    echo -e "${CYAN}=== MINIMAL MODE - Essential agents only ===${NC}"
    
    # Just the core error fixing agents
    deploy_agent_sequential "generic_build_analyzer.sh" "Build Analyzer"
    deploy_agent_sequential "generic_error_agent.sh" "Error Agent"
    deploy_agent_sequential "unified_error_counter.sh" "Error Counter"
}

# Generate summary report
generate_summary() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] Generating summary report...${NC}"
    
    local report_file="$STATE_DIR/execution_report_$(date +%Y%m%d_%H%M%S).md"
    
    {
        echo "# Unified Coordinator Execution Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Execution Summary"
        echo "- Mode: $EXECUTION_MODE"
        echo "- Max Concurrent Agents: $MAX_CONCURRENT_AGENTS"
        echo "- Start Time: $(jq -r '.start_time' "$STATE_DIR/coordinator_state.json")"
        echo "- End Time: $(date -Iseconds)"
        echo ""
        
        if [[ -f "$STATE_DIR/error_analysis.json" ]]; then
            echo "## Error Analysis"
            echo "- Total Errors: $(jq '.total_errors // 0' "$STATE_DIR/error_analysis.json")"
            echo "- Error Categories:"
            jq -r '.error_categories | to_entries[] | "  - \(.key): \(.value)"' "$STATE_DIR/error_analysis.json" 2>/dev/null || echo "  - No categories available"
            echo ""
        fi
        
        echo "## Agent Execution Results"
        echo "| Agent | Status | Log File |"
        echo "|-------|--------|----------|"
        
        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                local agent_name=$(basename "$log_file" .log)
                local status="✅ Complete"
                if grep -q "error\|failed\|Error\|Failed" "$log_file"; then
                    status="❌ Failed"
                elif [[ ! -s "$log_file" ]]; then
                    status="⚠️ Empty"
                fi
                echo "| $agent_name | $status | $(basename "$log_file") |"
            fi
        done
        
        echo ""
        echo "## Recommendations"
        echo "- Review failed agent logs in: $LOG_DIR"
        echo "- Check error counts with: unified_error_counter.sh"
        echo "- Run tests with: qa_agent_final.sh"
    } > "$report_file"
    
    echo -e "${GREEN}Report saved to: $report_file${NC}"
    cat "$report_file"
}

# Main execution
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Unified Coordinator - All-in-One Solution        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Acquire lock
    acquire_lock
    
    # Detect hardware
    detect_hardware
    
    # Initialize state
    initialize_state
    
    # Execute based on mode
    case "$EXECUTION_MODE" in
        smart)
            execute_smart_mode
            ;;
        sequential)
            execute_sequential_mode
            ;;
        parallel)
            execute_parallel_mode
            ;;
        phase)
            execute_phase_mode
            ;;
        full)
            execute_full_mode
            ;;
        minimal)
            execute_minimal_mode
            ;;
        *)
            echo -e "${RED}Unknown mode: $EXECUTION_MODE${NC}"
            echo "Available modes: smart, sequential, parallel, phase, full, minimal"
            exit 1
            ;;
    esac
    
    # Update final state
    jq '.status = "completed" | .end_time = "'$(date -Iseconds)'"' "$STATE_DIR/coordinator_state.json" > "$STATE_DIR/coordinator_state.json.tmp"
    mv "$STATE_DIR/coordinator_state.json.tmp" "$STATE_DIR/coordinator_state.json"
    
    # Generate summary
    generate_summary
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Execution Complete!                      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Show usage if requested
if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [mode]"
    echo ""
    echo "Modes:"
    echo "  smart      - Adaptive mode based on error analysis (default)"
    echo "  sequential - Run agents one at a time"
    echo "  parallel   - Run multiple agents simultaneously"
    echo "  phase      - Sequential phases with parallel execution within"
    echo "  full       - Deploy all available agents"
    echo "  minimal    - Essential agents only"
    echo ""
    echo "Environment Variables:"
    echo "  MAX_CONCURRENT_AGENTS - Maximum parallel agents (default: auto-detect)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Smart mode (recommended)"
    echo "  $0 parallel           # Full parallel execution"
    echo "  $0 phase              # Phased execution"
    echo "  MAX_CONCURRENT_AGENTS=6 $0 parallel  # Custom concurrency"
    exit 0
fi

# Run main
main