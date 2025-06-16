#!/bin/bash

# Enhanced Multi-Agent Coordinator with Dynamic Scaling
# Integrates tester and performance agents with hardware-based scaling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/agent_coordination.log"
COORDINATION_FILE="$SCRIPT_DIR/state/AGENT_COORDINATION.md"
HARDWARE_PROFILE="$SCRIPT_DIR/state/hardware_profile.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Mode
MODE="${1:-smart}"  # smart, full, minimal, custom

# Initialize logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp]${NC} ${MAGENTA}ENHANCED_COORDINATOR${NC} [${level}]: $message" | tee -a "$LOG_FILE"
}

# Detect hardware and set limits
detect_and_configure() {
    log_message "Detecting hardware capabilities..."
    
    # Generate hardware profile
    bash "$SCRIPT_DIR/hardware_detector.sh" generate
    
    # Load recommendations
    MAX_DEVELOPER_AGENTS=$(bash "$SCRIPT_DIR/hardware_detector.sh" get developer_agents)
    MAX_TESTER_AGENTS=$(bash "$SCRIPT_DIR/hardware_detector.sh" get tester_agents)
    MAX_PERFORMANCE_AGENTS=$(bash "$SCRIPT_DIR/hardware_detector.sh" get performance_agents)
    MAX_TOTAL_AGENTS=$(bash "$SCRIPT_DIR/hardware_detector.sh" get max_total_agents)
    PERFORMANCE_TIER=$(bash "$SCRIPT_DIR/hardware_detector.sh" get performance_tier)
    
    log_message "Hardware tier: ${PERFORMANCE_TIER}"
    log_message "Agent limits - Dev: $MAX_DEVELOPER_AGENTS, Test: $MAX_TESTER_AGENTS, Perf: $MAX_PERFORMANCE_AGENTS"
}

# Initialize coordination
init_coordination() {
    cat > "$COORDINATION_FILE" << EOF
# Enhanced Multi-Agent Coordination
Generated: $(date)
Hardware Tier: $PERFORMANCE_TIER

## Configuration
- Mode: $MODE
- Max Developer Agents: $MAX_DEVELOPER_AGENTS
- Max Tester Agents: $MAX_TESTER_AGENTS
- Max Performance Agents: $MAX_PERFORMANCE_AGENTS
- Total Agent Limit: $MAX_TOTAL_AGENTS

## Active Agents
EOF
}

# Deploy developer agents
# Deploy visionary agent for strategic planning
deploy_visionary_agent() {
    log_message "Deploying visionary agent for strategic analysis..."
    
    if [[ -f "$SCRIPT_DIR/visionary_agent.sh" ]]; then
        (
            bash "$SCRIPT_DIR/visionary_agent.sh" analyze > "$LOG_DIR/visionary_agent.log" 2>&1
            echo "visionary:completed" >> "$STATE_DIR/agent_status.txt"
        ) &
        
        local visionary_pid=$!
        AGENT_PIDS+=($visionary_pid)
        echo "visionary:$visionary_pid" >> "$STATE_DIR/agent_pids.txt"
        log_message "Visionary agent deployed (PID: $visionary_pid)"
    fi
}

# Original function backed up
# Deploy developer agents based on specifications
deploy_developer_agents() {
    log_message "Deploying developer agents..."
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "No agent specifications found. Running build analyzer..."
        bash "$AGENT_DIR/generic_build_analyzer.sh" "$PROJECT_DIR"
    fi
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "ERROR: Failed to generate agent specifications"
        return 1
    fi
    
    # Read agent specifications
    local agent_count=$(jq '.agent_specifications | length' "$AGENT_SPEC_FILE" 2>/dev/null || echo 0)
    log_message "Found specifications for $agent_count agents"
    
    if [[ $agent_count -eq 0 ]]; then
        log_message "WARNING: No agent specifications found. Creating generic agent..."
        # Create a generic agent specification
        cat > "$AGENT_SPEC_FILE" << GENERICEOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent_specifications": [
    {
      "agent_id": "generic_error_fixer",
      "name": "Generic Error Fixer",
      "type": "error_fixer",
      "specialization": "general",
      "target_errors": ["CS0101", "CS0111", "CS0246", "CS0462"],
      "priority": "high",
      "max_iterations": 3
    }
  ]
}
GENERICEOF
        agent_count=1
    fi
    
    # Deploy each agent
    local deployed=0
    for ((i=0; i<agent_count && i<MAX_CONCURRENT_AGENTS; i++)); do
        local agent_spec=$(jq ".agent_specifications[$i]" "$AGENT_SPEC_FILE")
        local agent_id=$(echo "$agent_spec" | jq -r '.agent_id')
        local target_errors=$(echo "$agent_spec" | jq -r '.target_errors[]' | tr '\n' ' ')
        
        log_message "Deploying agent: $agent_id"
        log_message "Target errors: $target_errors"
        
        # Create agent log
        local agent_log="$LOG_DIR/agent_${agent_id}.log"
        
        # Deploy the agent
        (
            bash "$AGENT_DIR/generic_error_agent.sh" \
                "$agent_id" \
                "$AGENT_SPEC_FILE" \
                "$target_errors" \
                > "$agent_log" 2>&1
            
            echo "$agent_id:completed" >> "$STATE_DIR/agent_status.txt"
        ) &
        
        local agent_pid=$!
        AGENT_PIDS+=($agent_pid)
        echo "$agent_id:$agent_pid" >> "$STATE_DIR/agent_pids.txt"
        
        ((deployed++))
    done
    
    log_message "Deployed $deployed developer agents"
    return 0
}

# Deploy tester agents
deploy_tester_agents() {
    local deploy_count="${1:-$MAX_TESTER_AGENTS}"
    local deployed=0
    
    if [[ $deploy_count -eq 0 ]] || [[ "$PERFORMANCE_TIER" == "low" ]]; then
        log_message "Skipping tester agents (hardware tier: $PERFORMANCE_TIER)"
        return 0
    fi
    
    log_message "Deploying up to $deploy_count tester agents"
    
    for ((i=1; i<=deploy_count; i++)); do
        log_message "  ${GREEN}→${NC} Deploying tester_agent_$i"
        
        (
            bash "$SCRIPT_DIR/tester_agent.sh" run &
            echo $! > "$SCRIPT_DIR/.pid_test_$i"
        ) &
        
        deployed=$((deployed + 1))
    done
    
    log_message "Deployed $deployed tester agents"
    return $deployed
}

# Deploy performance agents
deploy_performance_agents() {
    local deploy_count="${1:-$MAX_PERFORMANCE_AGENTS}"
    local deployed=0
    
    if [[ $deploy_count -eq 0 ]] || [[ "$PERFORMANCE_TIER" == "low" ]]; then
        log_message "Skipping performance agents (hardware tier: $PERFORMANCE_TIER)"
        return 0
    fi
    
    log_message "Deploying up to $deploy_count performance agents"
    
    for ((i=1; i<=deploy_count; i++)); do
        log_message "  ${GREEN}→${NC} Deploying performance_agent_$i"
        
        (
            bash "$SCRIPT_DIR/performance_agent.sh" analyze &
            echo $! > "$SCRIPT_DIR/.pid_perf_$i"
        ) &
        
        deployed=$((deployed + 1))
    done
    
    log_message "Deployed $deployed performance agents"
    return $deployed
}

# Monitor all agents
monitor_agents() {
    local monitoring=true
    local start_time=$(date +%s)
    local timeout=600  # 10 minutes max
    
    log_message "Monitoring agent activity..."
    
    while $monitoring; do
        # Count active agents by type
        local active_dev=$(ls "$SCRIPT_DIR"/.pid_dev_* 2>/dev/null | wc -l | tr -d '\n' || echo "0")
        local active_test=$(ls "$SCRIPT_DIR"/.pid_test_* 2>/dev/null | wc -l | tr -d '\n' || echo "0")
        local active_perf=$(ls "$SCRIPT_DIR"/.pid_perf_* 2>/dev/null | wc -l | tr -d '\n' || echo "0")
        local total_active=$((active_dev + active_test + active_perf))
        
        # Check each agent type
        for pid_file in "$SCRIPT_DIR"/.pid_*; do
            [[ -f "$pid_file" ]] || continue
            
            local pid=$(cat "$pid_file")
            if ! kill -0 "$pid" 2>/dev/null; then
                rm -f "$pid_file"
            fi
        done
        
        # Update status
        echo -e "\r${CYAN}Active Agents:${NC} Dev: ${GREEN}$active_dev${NC}, Test: ${YELLOW}$active_test${NC}, Perf: ${MAGENTA}$active_perf${NC} (Total: $total_active)   "
        
        # Check if all done
        if [[ $total_active -eq 0 ]]; then
            echo ""
            log_message "All agents completed"
            monitoring=false
        fi
        
        # Check timeout
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -gt $timeout ]]; then
            echo ""
            log_message "Timeout reached - stopping remaining agents" "WARNING"
            monitoring=false
        fi
        
        sleep 2
    done
}

# Process feedback from tester/performance agents
process_agent_feedback() {
    log_message "Processing feedback from quality agents..."
    
    local runtime_issues=0
    local perf_bottlenecks=0
    
    # Check for runtime issues
    if [[ -f "$SCRIPT_DIR/state/runtime_issues.json" ]]; then
        runtime_issues=$(grep -c "issue_type" "$SCRIPT_DIR/state/runtime_issues.json" 2>/dev/null || echo "0")
        if [[ $runtime_issues -gt 0 ]]; then
            log_message "Found $runtime_issues runtime issues to address"
        fi
    fi
    
    # Check for performance bottlenecks
    if [[ -f "$SCRIPT_DIR/state/performance_bottlenecks.json" ]]; then
        perf_bottlenecks=$(grep -c "bottleneck_type" "$SCRIPT_DIR/state/performance_bottlenecks.json" 2>/dev/null || echo "0")
        if [[ $perf_bottlenecks -gt 0 ]]; then
            log_message "Found $perf_bottlenecks performance bottlenecks to optimize"
        fi
    fi
    
    # Create tasks for developer agents
    local total_quality_issues=$((runtime_issues + perf_bottlenecks))
    if [[ $total_quality_issues -gt 0 ]]; then
        log_message "Creating $total_quality_issues quality improvement tasks"
        
        # This would trigger another round of developer agents
        # focusing on the quality issues found
        return $total_quality_issues
    fi
    
    return 0
}

# Smart deployment based on mode
smart_deployment() {
    local iteration=1
    local max_iterations=5
    
    while [[ $iteration -le $max_iterations ]]; do
        log_message "${BOLD}=== ITERATION $iteration ===${NC}"
        
        # Phase 1: Build and fix compile errors
        local error_count=$(bash "$SCRIPT_DIR/build_checker_agent.sh" build 2>&1 | grep -E '^[0-9]+$' | head -1 | tr -d '\n\r' | sed 's/[^0-9]//g')
        error_count=${error_count:-0}
        
        if [[ $error_count -gt 0 ]]; then
            log_message "Phase 1: Fixing $error_count build errors"
            deploy_developer_agents "$error_count"
            monitor_agents
        else
            log_message "Phase 1: Build successful ✓"
        fi
        
        # Phase 2: Runtime testing (if build succeeds)
        if [[ $error_count -eq 0 ]] && [[ "$PERFORMANCE_TIER" != "low" ]]; then
            log_message "Phase 2: Runtime testing"
            deploy_tester_agents 1
            monitor_agents
        fi
        
        # Phase 3: Performance analysis (if tier allows)
        if [[ $error_count -eq 0 ]] && [[ "$PERFORMANCE_TIER" == "high" ]]; then
            log_message "Phase 3: Performance analysis"
            deploy_performance_agents 1
            monitor_agents
        fi
        
        # Phase 4: Process feedback and create new tasks
        process_agent_feedback
        local quality_issues=$?
        if [[ $quality_issues -gt 0 ]]; then
            log_message "Phase 4: Addressing $quality_issues quality issues"
            deploy_developer_agents "$quality_issues"
            monitor_agents
        fi
        
        # Check if we're done
        error_count=$(bash "$SCRIPT_DIR/build_checker_agent.sh" build 2>&1 | grep -E '^[0-9]+$' | head -1 | tr -d '\n' || echo "0")
        if [[ $error_count -eq 0 ]] && [[ $quality_issues -eq 0 ]]; then
            log_message "${GREEN}✓ All issues resolved!${NC}"
            break
        fi
        
        iteration=$((iteration + 1))
    done
}

# Show deployment plan
show_deployment_plan() {
    echo -e "\n${CYAN}═══ Deployment Plan ═══${NC}"
    echo -e "Hardware Tier: ${YELLOW}$PERFORMANCE_TIER${NC}"
    echo -e "\nAgent Allocation:"
    echo -e "  ${GREEN}●${NC} Developer Agents: $MAX_DEVELOPER_AGENTS"
    echo -e "  ${YELLOW}●${NC} Tester Agents: $MAX_TESTER_AGENTS"
    echo -e "  ${MAGENTA}●${NC} Performance Agents: $MAX_PERFORMANCE_AGENTS"
    echo -e "  ${BLUE}●${NC} Total Capacity: $MAX_TOTAL_AGENTS"
    
    case "$MODE" in
        "smart")
            echo -e "\n${BOLD}Smart Mode:${NC} Adaptive deployment based on needs"
            echo -e "  1. Fix build errors first"
            echo -e "  2. Run tests if build succeeds"
            echo -e "  3. Analyze performance if tier allows"
            echo -e "  4. Address quality issues found"
            ;;
        "full")
            echo -e "\n${BOLD}Full Mode:${NC} Deploy all available agents"
            ;;
        "minimal")
            echo -e "\n${BOLD}Minimal Mode:${NC} Essential agents only"
            ;;
    esac
    echo ""
}

# Cleanup
cleanup() {
    log_message "Cleaning up..."
    
    # Kill any remaining agents
    for pid_file in "$SCRIPT_DIR"/.pid_*; do
        [[ -f "$pid_file" ]] || continue
        
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$pid_file"
    done
    
    # Remove locks
    rm -f "$SCRIPT_DIR"/.lock_*
}

# Main execution
main() {
    log_message "${BOLD}=== ENHANCED COORDINATOR STARTING ===${NC}"
    
    # Detect hardware
    detect_and_configure
    
    # Initialize
    init_coordination
    
    # Show plan
    show_deployment_plan
    
    # Execute based on mode
    case "$MODE" in
        "smart")
            smart_deployment
            ;;
        "full")
            # Deploy everything at once
            local error_count=$(bash "$SCRIPT_DIR/build_checker_agent.sh" build 2>&1 | grep -E '^[0-9]+$' | head -1 || echo "0")
            deploy_developer_agents "$error_count"
            deploy_tester_agents
            deploy_performance_agents
            monitor_agents
            process_agent_feedback
            ;;
        "minimal")
            # Just fix build errors
            local error_count=$(bash "$SCRIPT_DIR/build_checker_agent.sh" build 2>&1 | grep -E '^[0-9]+$' | head -1 || echo "0")
            MAX_DEVELOPER_AGENTS=$((MAX_DEVELOPER_AGENTS / 2))
            deploy_developer_agents "$error_count"
            monitor_agents
            ;;
        *)
            log_message "Unknown mode: $MODE" "ERROR"
            exit 1
            ;;
    esac
    
    # Generate final report
    log_message "Generating final report..."
    
    echo -e "\n${CYAN}═══ Final Report ═══${NC}"
    echo -e "Build Status: $(dotnet build > /dev/null 2>&1 && echo "${GREEN}✓ Success${NC}" || echo "${RED}✗ Failed${NC}")"
    
    if [[ -f "$SCRIPT_DIR/state/test_report_"*.md ]]; then
        echo -e "Test Results: Available in state/test_report_*.md"
    fi
    
    if [[ -f "$SCRIPT_DIR/state/performance_report_"*.md ]]; then
        echo -e "Performance Report: Available in state/performance_report_*.md"
    fi
    
    log_message "${BOLD}=== COORDINATOR COMPLETE ===${NC}"
}

# Set trap
trap cleanup EXIT INT TERM

# Execute
main
