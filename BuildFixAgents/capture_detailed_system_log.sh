#\!/bin/bash
# Capture extremely detailed log with all agent interactions

DETAILED_LOG="full_system_detailed_log_$(date +%Y%m%d_%H%M%S).log"

echo "Capturing detailed system execution to $DETAILED_LOG"

{
    echo "=============================================="
    echo "BuildFixAgents - Ultra-Detailed System Log"
    echo "=============================================="
    echo "Generated: $(date)"
    echo "System: $(uname -a)"
    echo "Working Directory: $(pwd)"
    echo
    
    # Enable maximum verbosity
    export DEBUG=true
    export VERBOSE=true
    export TRACE=true
    set -x
    
    echo "=== PHASE 1: SYSTEM INITIALIZATION ==="
    bash -x ./enhanced_coordinator_v2.sh init 2>&1
    
    echo
    echo "=== PHASE 2: AGENT DEPLOYMENT ==="
    bash -x ./enhanced_coordinator_v2.sh deploy 2>&1
    
    echo
    echo "=== PHASE 3: RUNNING AUTOFIX BATCH ==="
    bash -x ./autofix_batch.sh run 2>&1
    
    echo
    echo "=== PHASE 4: FULL ORCHESTRATION ==="
    bash -x ./enhanced_coordinator_v2.sh orchestrate 2>&1
    
    echo
    echo "=== PHASE 5: AGENT REPORTS ==="
    
    # Run each agent individually to capture their output
    for agent in architect_agent_v2 project_manager_agent scrum_master_agent \
                 learning_agent metrics_collector_agent performance_agent_v2; do
        if [[ -f "./${agent}.sh" ]]; then
            echo
            echo "--- Running $agent ---"
            bash "./${agent}.sh" report 2>&1 || true
        fi
    done
    
    echo
    echo "=== PHASE 6: SYSTEM STATE ==="
    
    # Show all log files
    echo "--- Log Files ---"
    find ./logs -type f -name "*.log" -exec echo {} \; -exec tail -20 {} \; 2>/dev/null
    
    # Show all state files
    echo
    echo "--- State Files ---"
    find ./state -type f \( -name "*.json" -o -name "*.md" \) -exec echo {} \; -exec head -20 {} \; 2>/dev/null
    
    echo
    echo "=== DETAILED LOG COMPLETE ==="
    echo "End time: $(date)"
    
} > "$DETAILED_LOG" 2>&1

echo "Detailed log saved to: $DETAILED_LOG"
echo "Size: $(ls -lh "$DETAILED_LOG"  < /dev/null |  awk '{print $5}')"

# Also create a summary version
SUMMARY_LOG="system_execution_summary_$(date +%Y%m%d_%H%M%S).log"
{
    echo "BuildFixAgents Execution Summary"
    echo "================================"
    echo "Date: $(date)"
    echo
    grep -E "(===|✓|✗|Error|Warning|Success|Complete)" "$DETAILED_LOG" | head -100
} > "$SUMMARY_LOG"

echo "Summary log saved to: $SUMMARY_LOG"
