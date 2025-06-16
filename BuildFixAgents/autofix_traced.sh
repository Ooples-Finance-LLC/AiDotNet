#!/bin/bash

# Traced version of autofix without timeouts

set -euo pipefail

# Timestamp function
ts() {
    echo "[$(date +%H:%M:%S.%N | cut -b1-12)] $1" >&2
}

ts "AUTOFIX TRACED VERSION STARTING"

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$(pwd)")" == "BuildFixAgents" ]]; then
    PROJECT_DIR="${PROJECT_DIR:-$(dirname "$(pwd)")}"
else
    PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
fi

ts "Directories set: AGENT_DIR=$AGENT_DIR, PROJECT_DIR=$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Simple banner
echo -e "${CYAN}=== Multi-Agent Build Fix System - TRACED ===${NC}"

# Step 1: Count errors
ts "Starting error count"
cd "$PROJECT_DIR"
ts "Running: dotnet build --no-restore"
ERROR_COUNT=$(dotnet build --no-restore 2>&1 | tee /tmp/build_trace.log | grep -c "error CS" || echo "0")
ts "Error count complete: $ERROR_COUNT errors"

if [[ $ERROR_COUNT -eq 0 ]]; then
    echo "✓ No errors found!"
    exit 0
fi

# Step 2: Run analyzer
ts "Starting generic_build_analyzer.sh"
bash "$AGENT_DIR/generic_build_analyzer.sh" "$PROJECT_DIR" 2>&1 | while IFS= read -r line; do
    echo "[ANALYZER] $line"
done &
ANALYZER_PID=$!

# Monitor analyzer
ts "Monitoring analyzer PID $ANALYZER_PID"
while ps -p $ANALYZER_PID > /dev/null; do
    sleep 5
    ts "Analyzer still running..."
done
ts "Analyzer completed"

# Step 3: Check if we have agent specifications
if [[ -f "$AGENT_DIR/agent_specifications.json" ]]; then
    ts "Agent specifications created successfully"
    cat "$AGENT_DIR/agent_specifications.json" | head -20
fi

# Step 4: Test enhanced coordinator
ts "Starting enhanced_coordinator.sh"
bash "$AGENT_DIR/enhanced_coordinator.sh" smart 2>&1 | while IFS= read -r line; do
    echo "[COORD] $line"
done &
COORD_PID=$!

# Monitor coordinator for a bit
ts "Monitoring coordinator PID $COORD_PID"
for i in {1..10}; do
    if ! ps -p $COORD_PID > /dev/null; then
        ts "Coordinator finished after $i seconds"
        break
    fi
    ts "Coordinator still running... $i/10"
    sleep 1
done

if ps -p $COORD_PID > /dev/null; then
    ts "Coordinator still running after 10 seconds - this might be where it hangs"
    ts "Letting it run for 20 more seconds..."
    
    for i in {11..30}; do
        if ! ps -p $COORD_PID > /dev/null; then
            ts "Coordinator finished after $i seconds"
            break
        fi
        if [[ $((i % 5)) -eq 0 ]]; then
            ts "Coordinator still running... $i/30"
        fi
        sleep 1
    done
    
    if ps -p $COORD_PID > /dev/null; then
        ts "HANG DETECTED: Coordinator still running after 30 seconds"
        ts "Killing coordinator..."
        kill -9 $COORD_PID 2>/dev/null
    fi
fi

ts "TRACE COMPLETE"
echo -e "\n${YELLOW}Check the timestamps above to see where delays occur${NC}"