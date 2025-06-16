#!/bin/bash

# Live Metrics Dashboard
clear
while true; do
    echo -e "\033[H\033[2J"  # Clear screen
    echo "=== BuildFixAgents Live Metrics Dashboard ==="
    echo "Last Update: $(date)"
    echo ""
    
    # System metrics
    echo "System Resources:"
    echo -n "  CPU:    "
    top -bn1 | grep "Cpu(s)" | awk '{printf "[%-20s] %s%%\n", substr("####################", 1, int($2/5)), $2}'
    
    echo -n "  Memory: "
    free -m | awk 'NR==2 {printf "[%-20s] %d%%\n", substr("####################", 1, int($3/$2*20)), int($3/$2*100)}'
    
    echo ""
    echo "Application Metrics:"
    if [[ -f "$(dirname "$0")/../.error_count_cache" ]]; then
        echo "  Errors Remaining: $(cat "$(dirname "$0")/../.error_count_cache")"
    fi
    
    echo ""
    echo "Active Agents:"
    if [[ -f "$(dirname "$0")/../architecture/agent_manifest.json" ]]; then
        jq -r '.agents | to_entries[] | select(.value.status == "active") | "  - " + .key' \
           "$(dirname "$0")/../architecture/agent_manifest.json" 2>/dev/null
    fi
    
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
