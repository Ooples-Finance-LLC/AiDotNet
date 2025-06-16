#\!/bin/bash
# Capture comprehensive log of the entire self-improving system

LOG_FILE="full_system_comprehensive_log_$(date +%Y%m%d_%H%M%S).log"

echo "Starting comprehensive system capture to $LOG_FILE"

{
    echo "==============================================="
    echo "BuildFixAgents - Complete System Log"
    echo "Generated: $(date)"
    echo "==============================================="
    echo
    
    # Run with full debugging and verbosity
    export DEBUG=true
    export VERBOSE=true
    
    # Start the self-improving system
    echo "=== STARTING SELF-IMPROVING SYSTEM ==="
    bash -x ./start_self_improving_system.sh auto 2>&1
    
    echo
    echo "=== SYSTEM EXECUTION COMPLETE ==="
    echo
    
    # Capture all state files created
    echo "=== STATE FILES CREATED ==="
    find ./state -type f -name "*.md" -o -name "*.json"  < /dev/null |  sort
    
    echo
    echo "=== KEY REPORTS ==="
    
    if [[ -f ./state/coordinator/EXECUTIVE_SUMMARY.md ]]; then
        echo "--- Executive Summary ---"
        cat ./state/coordinator/EXECUTIVE_SUMMARY.md
    fi
    
    if [[ -f ./state/learning/LEARNING_REPORT.md ]]; then
        echo
        echo "--- Learning Report ---"
        cat ./state/learning/LEARNING_REPORT.md
    fi
    
    if [[ -f ./state/metrics/ANALYTICS_REPORT.md ]]; then
        echo
        echo "--- Analytics Report ---"
        cat ./state/metrics/ANALYTICS_REPORT.md
    fi
    
    echo
    echo "=== LOG CAPTURE COMPLETE ==="
    echo "End time: $(date)"
    
} > "$LOG_FILE" 2>&1

echo "Log saved to: $LOG_FILE"
echo "Size: $(ls -lh "$LOG_FILE" | awk '{print $5}')"
