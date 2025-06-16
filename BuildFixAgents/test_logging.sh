#!/bin/bash
# Simple test of the logging system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the logging system
source "$SCRIPT_DIR/enhanced_logging_system.sh"

echo "Testing Enhanced Logging System..."

# Test basic logging
log_event "INFO" "TEST" "Starting logging test"
log_event "SUCCESS" "TEST" "This is a success message"
log_event "WARNING" "TEST" "This is a warning"
log_event "ERROR" "TEST" "This is an error" "With additional details"

# Test agent lifecycle
echo -e "\nTesting agent lifecycle..."
log_agent_start "test_agent_1" "Testing Role"
sleep 0.2
log_agent_ready "test_agent_1"
sleep 0.2
log_agent_complete "test_agent_1" "Completed 5 tasks successfully"

# Test task management
echo -e "\nTesting task management..."
task1=$(create_task "test_agent_1" "Analyze project structure" "HIGH")
echo "Created task: $task1"
sleep 0.2

assign_task "$task1" "analyzer_agent"
sleep 0.2

start_task "$task1" "analyzer_agent"
sleep 0.2

complete_task "$task1" "analyzer_agent" "Found 10 source files"

# Test communication
echo -e "\nTesting communication logging..."
log_communication "test_agent_1" "coordinator" "STATUS_UPDATE" "Ready for next phase"
log_communication "coordinator" "test_agent_1" "TASK_ASSIGNMENT" "New task available"

# Test decision logging
echo -e "\nTesting decision logging..."
log_decision "test_agent_1" "Use async processing" "Better performance for I/O operations"

# Test performance logging
echo -e "\nTesting performance logging..."
log_performance "test_agent_1" "File analysis" "2.5" "150MB"

echo -e "\nGenerating summary..."
generate_execution_summary

echo -e "\n✅ Logging test complete!"
echo -e "\nCheck the following files:"
echo "  - Master log: $MASTER_LOG"
echo "  - Agent status: $AGENT_STATUS_LOG"
echo "  - Task tracking: $TASK_TRACKING_LOG"