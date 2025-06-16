#!/bin/bash

# Tester Agent - Runs applications and detects runtime issues
# Reports exceptions, crashes, and incorrect behavior to developer agents

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
TEST_RESULTS_DIR="$AGENT_DIR/state/test_results"
ISSUES_LOG="$AGENT_DIR/state/runtime_issues.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Agent ID
AGENT_ID="tester_agent_$$"

# Initialize
mkdir -p "$TEST_RESULTS_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] TESTER_AGENT [$level]: $message" | tee -a "$AGENT_DIR/logs/tester_agent.log"
}

# Find executable projects
find_executables() {
    local executables=()
    
    # Find console applications
    while IFS= read -r proj; do
        if grep -q "<OutputType>Exe</OutputType>" "$proj"; then
            executables+=("$proj")
        fi
    done < <(find "$PROJECT_DIR" -name "*.csproj" -type f)
    
    # Find test projects
    while IFS= read -r proj; do
        if grep -qE "(xunit|nunit|mstest|test)" "$proj"; then
            executables+=("$proj")
        fi
    done < <(find "$PROJECT_DIR" -name "*.csproj" -type f)
    
    printf '%s\n' "${executables[@]}" | sort -u
}

# Run a project and capture output
run_project() {
    local project_file="$1"
    local project_name=$(basename "$project_file" .csproj)
    local output_file="$TEST_RESULTS_DIR/${project_name}_$(date +%Y%m%d_%H%M%S).log"
    local timeout="${2:-30}"
    
    log_message "Running project: $project_name"
    
    # Build the project first
    if ! dotnet build "$project_file" -nologo > "$output_file.build" 2>&1; then
        log_message "Build failed for $project_name" "ERROR"
        return 1
    fi
    
    # Run with timeout and capture output
    local start_time=$(date +%s)
    timeout "$timeout" dotnet run --project "$project_file" --no-build > "$output_file" 2>&1 &
    local pid=$!
    
    # Monitor for issues
    local exit_code=0
    if wait $pid; then
        exit_code=$?
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Analyze results
    analyze_output "$project_name" "$output_file" "$exit_code" "$duration"
}

# Analyze program output for issues
analyze_output() {
    local project_name="$1"
    local output_file="$2"
    local exit_code="$3"
    local duration="$4"
    
    local issues=()
    
    # Check for exceptions
    if grep -qE "(Exception|Error:|FAIL|Failed)" "$output_file"; then
        local exceptions=$(grep -E "(Exception|Error:|FAIL|Failed)" "$output_file" | head -10)
        issues+=("EXCEPTION: Found runtime exceptions")
        
        # Extract specific exception types
        while IFS= read -r line; do
            if [[ "$line" =~ ([A-Z][a-zA-Z]*Exception) ]]; then
                local exception_type="${BASH_REMATCH[1]}"
                record_issue "$project_name" "exception" "$exception_type" "$line"
            fi
        done <<< "$exceptions"
    fi
    
    # Check exit code
    if [[ $exit_code -ne 0 ]] && [[ $exit_code -ne 124 ]]; then
        issues+=("CRASH: Process exited with code $exit_code")
        record_issue "$project_name" "crash" "exit_code_$exit_code" "Process crashed with exit code $exit_code"
    fi
    
    # Check for timeout
    if [[ $exit_code -eq 124 ]]; then
        issues+=("HANG: Process timed out after ${duration}s")
        record_issue "$project_name" "hang" "timeout" "Process did not complete within timeout"
    fi
    
    # Check for memory issues
    if grep -qE "(OutOfMemoryException|StackOverflowException)" "$output_file"; then
        issues+=("MEMORY: Memory-related exceptions detected")
        record_issue "$project_name" "memory" "memory_exception" "Memory issues detected"
    fi
    
    # Check for null reference
    if grep -qE "(NullReferenceException|Object reference not set)" "$output_file"; then
        issues+=("NULL: Null reference exceptions detected")
        record_issue "$project_name" "null_reference" "NullReferenceException" "Null reference issues"
    fi
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_message "✓ $project_name ran successfully (${duration}s)" "SUCCESS"
    else
        log_message "✗ $project_name has ${#issues[@]} runtime issues:" "ERROR"
        for issue in "${issues[@]}"; do
            log_message "  - $issue" "ERROR"
        done
    fi
}

# Record an issue for developer agents
record_issue() {
    local project="$1"
    local issue_type="$2"
    local detail="$3"
    local context="$4"
    
    # Create issue record
    local issue_record=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "$AGENT_ID",
  "project": "$project",
  "issue_type": "$issue_type",
  "detail": "$detail",
  "context": "$(echo "$context" | tr '\n' ' ' | sed 's/"/\\"/g')",
  "severity": "$(get_severity "$issue_type")",
  "suggested_action": "$(suggest_action "$issue_type" "$detail")"
}
EOF
)
    
    # Append to issues log
    echo "$issue_record," >> "$ISSUES_LOG"
    
    # Create task for developer agents
    create_developer_task "$project" "$issue_type" "$detail" "$context"
}

# Determine severity
get_severity() {
    local issue_type="$1"
    
    case "$issue_type" in
        "crash"|"hang")
            echo "critical"
            ;;
        "exception"|"memory")
            echo "high"
            ;;
        "null_reference")
            echo "medium"
            ;;
        *)
            echo "low"
            ;;
    esac
}

# Suggest action for issue
suggest_action() {
    local issue_type="$1"
    local detail="$2"
    
    case "$issue_type" in
        "exception")
            echo "Add exception handling for $detail"
            ;;
        "crash")
            echo "Debug crash and add error recovery"
            ;;
        "hang")
            echo "Add timeout handling or async operations"
            ;;
        "memory")
            echo "Optimize memory usage and add disposal"
            ;;
        "null_reference")
            echo "Add null checks and initialize objects"
            ;;
        *)
            echo "Investigate and fix runtime issue"
            ;;
    esac
}

# Create task for developer agents
create_developer_task() {
    local project="$1"
    local issue_type="$2"
    local detail="$3"
    local context="$4"
    
    # Add to coordination file for developer agents to pick up
    cat >> "$AGENT_DIR/state/AGENT_COORDINATION.md" << EOF

## Runtime Issue Detected - $(date '+%Y-%m-%d %H:%M:%S')
- **Project**: $project
- **Issue Type**: $issue_type
- **Detail**: $detail
- **Severity**: $(get_severity "$issue_type")
- **Action Required**: $(suggest_action "$issue_type" "$detail")
- **Context**: $context
- **Status**: PENDING_FIX
EOF
    
    log_message "Created developer task for $issue_type in $project"
}

# Run test suite if exists
run_tests() {
    log_message "Looking for test projects..."
    
    local test_projects=$(find "$PROJECT_DIR" -name "*.csproj" -type f | xargs grep -l "test" | grep -i test || true)
    
    if [[ -z "$test_projects" ]]; then
        log_message "No test projects found"
        return
    fi
    
    while IFS= read -r test_proj; do
        [[ -z "$test_proj" ]] && continue
        
        local test_name=$(basename "$test_proj" .csproj)
        log_message "Running tests in $test_name"
        
        local test_output="$TEST_RESULTS_DIR/${test_name}_test_$(date +%Y%m%d_%H%M%S).log"
        
        if dotnet test "$test_proj" --logger "console;verbosity=detailed" > "$test_output" 2>&1; then
            log_message "✓ Tests passed in $test_name" "SUCCESS"
        else
            log_message "✗ Tests failed in $test_name" "ERROR"
            
            # Extract failed tests
            grep -E "(Failed|Error|Exception)" "$test_output" | while IFS= read -r failure; do
                record_issue "$test_name" "test_failure" "unit_test" "$failure"
            done
        fi
    done <<< "$test_projects"
}

# Monitor for continuous testing
monitor_mode() {
    log_message "Starting continuous monitoring mode"
    
    while true; do
        # Check if build is successful
        if dotnet build "$PROJECT_DIR" > /dev/null 2>&1; then
            # Run all executables
            local executables=$(find_executables)
            
            if [[ -n "$executables" ]]; then
                while IFS= read -r exe; do
                    run_project "$exe" 30
                done <<< "$executables"
            fi
            
            # Run tests
            run_tests
        else
            log_message "Build failed - waiting for fixes"
        fi
        
        # Wait before next run
        sleep 60
    done
}

# Generate test report
generate_report() {
    local report_file="$AGENT_DIR/state/test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Test Execution Report
Generated: $(date)

## Summary
- Total Projects Tested: $(find_executables | wc -l)
- Runtime Issues Found: $(grep -c "issue_type" "$ISSUES_LOG" 2>/dev/null || echo "0")

## Issues by Type
EOF
    
    # Count issues by type
    if [[ -f "$ISSUES_LOG" ]]; then
        echo "| Issue Type | Count |" >> "$report_file"
        echo "|------------|-------|" >> "$report_file"
        
        grep "issue_type" "$ISSUES_LOG" | cut -d'"' -f6 | sort | uniq -c | \
            while read -r count type; do
                echo "| $type | $count |" >> "$report_file"
            done
    fi
    
    echo -e "\nReport saved to: $report_file"
}

# Main execution
main() {
    log_message "=== TESTER AGENT STARTING ==="
    
    case "${1:-run}" in
        "run")
            # Run all executables once
            local executables=$(find_executables)
            
            if [[ -z "$executables" ]]; then
                log_message "No executable projects found"
            else
                echo -e "${BLUE}Found $(echo "$executables" | wc -l) executable projects${NC}"
                
                while IFS= read -r exe; do
                    run_project "$exe"
                done <<< "$executables"
            fi
            
            # Run tests
            run_tests
            
            # Generate report
            generate_report
            ;;
            
        "monitor")
            monitor_mode
            ;;
            
        "test")
            run_tests
            ;;
            
        "report")
            generate_report
            ;;
            
        *)
            echo "Usage: $0 {run|monitor|test|report}"
            exit 1
            ;;
    esac
    
    log_message "=== TESTER AGENT COMPLETE ==="
}

# Execute
main "$@"