#!/bin/bash

# Build Checker Agent - Supervisor and Validation
# Coordinates builds, counts errors, validates changes, supervises worker agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
COORDINATION_FILE="$SCRIPT_DIR/AGENT_COORDINATION.md"
BUILD_OUTPUT_FILE="$SCRIPT_DIR/build_output.txt"
ERROR_COUNT_FILE="$SCRIPT_DIR/build_error_count.txt"

# Initialize logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] BUILD_CHECKER: $message" | tee -a "$LOG_FILE"
}

# Run build and count errors
run_build_and_count_errors() {
    log_message "Running build to count errors..."
    
    # Clean previous build output
    rm -f "$BUILD_OUTPUT_FILE"
    
    # Run build and capture output
    cd "${PROJECT_DIR:-/home/ooples/AiDotNet}"
    log_message "Running build with 180s timeout..."
    if timeout 180s dotnet build --no-restore > "$BUILD_OUTPUT_FILE" 2>&1; then
        log_message "Build succeeded with no errors"
        echo "0" > "$ERROR_COUNT_FILE"
        return 0
    else
        # Count unique errors (CS#### patterns)
        local error_count=$(grep -oE 'CS[0-9]{4}' "$BUILD_OUTPUT_FILE" | sort -u | wc -l)
        local total_error_instances=$(grep -c 'error CS' "$BUILD_OUTPUT_FILE" || echo "0")
        
        log_message "Build failed with $error_count unique error types ($total_error_instances total instances)"
        # Output just the total error count for scripts that parse this
        echo "$total_error_instances"
        echo "$error_count" > "$ERROR_COUNT_FILE"
        
        # Log error breakdown
        log_message "Error breakdown:"
        grep -oE 'error CS[0-9]{4}' "$BUILD_OUTPUT_FILE" | sort | uniq -c | while read -r count error; do
            log_message "  $error: $count instances"
        done
        
        return 1
    fi
}

# Analyze error types and priorities
analyze_errors() {
    log_message "Analyzing error types for agent assignment..."
    
    if [[ ! -f "$BUILD_OUTPUT_FILE" ]]; then
        log_message "No build output file found"
        return 1
    fi
    
    # Extract key error patterns
    local cs0101_count
    local cs0111_count
    local cs8377_count
    local cs0104_count
    local cs0462_count
    local cs0115_count
    
    if grep -q 'error CS0101' "$BUILD_OUTPUT_FILE"; then
        cs0101_count=$(grep -c 'error CS0101' "$BUILD_OUTPUT_FILE")
    else
        cs0101_count=0
    fi
    
    if grep -q 'error CS0111' "$BUILD_OUTPUT_FILE"; then
        cs0111_count=$(grep -c 'error CS0111' "$BUILD_OUTPUT_FILE")
    else
        cs0111_count=0
    fi
    
    if grep -q 'error CS8377' "$BUILD_OUTPUT_FILE"; then
        cs8377_count=$(grep -c 'error CS8377' "$BUILD_OUTPUT_FILE")
    else
        cs8377_count=0
    fi
    
    if grep -q 'error CS0104' "$BUILD_OUTPUT_FILE"; then
        cs0104_count=$(grep -c 'error CS0104' "$BUILD_OUTPUT_FILE")
    else
        cs0104_count=0
    fi
    
    if grep -q 'error CS0462' "$BUILD_OUTPUT_FILE"; then
        cs0462_count=$(grep -c 'error CS0462' "$BUILD_OUTPUT_FILE")
    else
        cs0462_count=0
    fi
    
    if grep -q 'error CS0115' "$BUILD_OUTPUT_FILE"; then
        cs0115_count=$(grep -c 'error CS0115' "$BUILD_OUTPUT_FILE")
    else
        cs0115_count=0
    fi
    
    log_message "Target error counts:"
    log_message "  CS0101 (Duplicate classes): $cs0101_count"
    log_message "  CS0111 (Duplicate members): $cs0111_count"
    log_message "  CS8377 (Generic constraints): $cs8377_count"
    log_message "  CS0104 (Ambiguous types): $cs0104_count"
    log_message "  CS0462 (Inheritance conflicts): $cs0462_count"
    log_message "  CS0115 (Missing overrides): $cs0115_count"
    
    # Determine priority assignments
    local agent1_target=$((cs0101_count + cs0111_count))
    local agent2_target=$((cs8377_count + cs0104_count))
    local agent3_target=$((cs0462_count + cs0115_count))
    
    log_message "Agent workload targets:"
    log_message "  Agent1 (Duplicates): $agent1_target errors"
    log_message "  Agent2 (Constraints): $agent2_target errors"  
    log_message "  Agent3 (Inheritance): $agent3_target errors"
}

# Check file lock status
check_file_lock() {
    local file_path="$1"
    local lock_file="$SCRIPT_DIR/.lock_$(basename "$file_path" | tr '/' '_')"
    
    if [[ -f "$lock_file" ]]; then
        local locker=$(cat "$lock_file")
        echo "LOCKED_BY:$locker"
        return 1
    else
        echo "AVAILABLE"
        return 0
    fi
}

# Claim file lock for an agent
claim_file_lock() {
    local agent_id="$1"
    local file_path="$2"
    local lock_file="$SCRIPT_DIR/.lock_$(basename "$file_path" | tr '/' '_')"
    
    if [[ -f "$lock_file" ]]; then
        local current_locker=$(cat "$lock_file")
        log_message "LOCK_DENIED: File $file_path already locked by $current_locker"
        return 1
    else
        echo "$agent_id" > "$lock_file"
        log_message "LOCK_GRANTED: File $file_path locked by $agent_id"
        return 0
    fi
}

# Release file lock
release_file_lock() {
    local agent_id="$1"
    local file_path="$2"
    local lock_file="$SCRIPT_DIR/.lock_$(basename "$file_path" | tr '/' '_')"
    
    if [[ -f "$lock_file" ]]; then
        local current_locker=$(cat "$lock_file")
        if [[ "$current_locker" == "$agent_id" ]]; then
            rm -f "$lock_file"
            log_message "LOCK_RELEASED: File $file_path released by $agent_id"
            return 0
        else
            log_message "LOCK_DENIED: Cannot release $file_path, locked by $current_locker (not $agent_id)"
            return 1
        fi
    else
        log_message "LOCK_WARNING: No lock found for $file_path"
        return 0
    fi
}

# Validate changes after agent work
validate_changes() {
    local agent_id="$1"
    local files_modified="$2"
    
    log_message "Validating changes made by $agent_id..."
    log_message "Files modified: $files_modified"
    
    # Save current error count
    local before_count=$(cat "$ERROR_COUNT_FILE")
    
    # Run build again
    run_build_and_count_errors
    local after_count=$(cat "$ERROR_COUNT_FILE")
    
    log_message "Error count: Before=$before_count, After=$after_count"
    
    if [[ $after_count -lt $before_count ]]; then
        local reduction=$((before_count - after_count))
        log_message "SUCCESS: $agent_id reduced errors by $reduction (${before_count}→${after_count})"
        return 0
    elif [[ $after_count -eq $before_count ]]; then
        log_message "NEUTRAL: $agent_id made no change to error count"
        return 0
    else
        local increase=$((after_count - before_count))
        log_message "ERROR: $agent_id increased errors by $increase (${before_count}→${after_count})"
        log_message "ROLLBACK_REQUIRED: Changes may need to be reverted"
        return 1
    fi
}

# Generate detailed error report for agents
generate_error_report() {
    log_message "Generating detailed error report for agents..."
    
    local report_file="$SCRIPT_DIR/current_error_report.txt"
    
    cat > "$report_file" << EOF
# Current Build Error Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Total Error Types: $(cat "$ERROR_COUNT_FILE")

## Duplicate Class/Member Errors (Agent1 Priority)
EOF
    
    # Extract CS0101 and CS0111 errors with file locations
    grep 'error CS010[1]' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    grep 'error CS0111' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    
    cat >> "$report_file" << EOF

## Generic Constraint Errors (Agent2 Priority)
EOF
    
    grep 'error CS8377' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    grep 'error CS0104' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    
    cat >> "$report_file" << EOF

## Inheritance/Override Errors (Agent3 Priority)
EOF
    
    grep 'error CS0462' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    grep 'error CS0115' "$BUILD_OUTPUT_FILE" | head -10 >> "$report_file" || true
    
    log_message "Error report generated: $report_file"
}

# Main execution
main() {
    log_message "=== BUILD CHECKER AGENT STARTING ==="
    log_message "Establishing build baseline for multi-agent system..."
    
    # Phase 1: Run initial build analysis
    if run_build_and_count_errors; then
        log_message "Build is clean - no errors to fix!"
        exit 0
    fi
    
    # Phase 2: Analyze errors and assign priorities
    analyze_errors
    
    # Phase 3: Generate detailed reports for agents
    generate_error_report
    
    log_message "=== BUILD CHECKER AGENT COMPLETE ==="
    log_message "System ready for agent deployment"
    log_message "Next step: Deploy worker agents via multi_agent_coordinator.sh"
    
    return 0
}

# Handle command line arguments
case "${1:-main}" in
    "main")
        main
        ;;
    "analyze")
        analyze_errors
        ;;
    "build")
        run_build_and_count_errors
        ;;
    "claim")
        claim_file_lock "$2" "$3"
        ;;
    "release")
        release_file_lock "$2" "$3"
        ;;
    "validate")
        validate_changes "$2" "$3"
        ;;
    "report")
        generate_error_report
        ;;
    *)
        echo "Usage: $0 {main|analyze|build|claim|release|validate|report}"
        exit 1
        ;;
esac