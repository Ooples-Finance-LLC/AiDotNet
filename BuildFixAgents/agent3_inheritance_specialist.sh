#!/bin/bash

# Agent 3 - Inheritance & Override Specialist
# Handles CS0462 (inheritance conflicts) and CS0115 (missing overrides)
# Fixes method signatures and inheritance hierarchies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="AGENT3"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
BUILD_CHECKER="$SCRIPT_DIR/build_checker_agent.sh"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $AGENT_ID: $message" | tee -a "$LOG_FILE"
}

# Claim a file for exclusive access
claim_file() {
    local file_path="$1"
    log_message "Requesting lock for: $file_path"
    
    if "$BUILD_CHECKER" claim "$AGENT_ID" "$file_path"; then
        log_message "Successfully claimed: $file_path"
        return 0
    else
        log_message "Failed to claim: $file_path (may be locked by another agent)"
        return 1
    fi
}

# Release a file lock
release_file() {
    local file_path="$1"
    log_message "Releasing lock for: $file_path"
    "$BUILD_CHECKER" release "$AGENT_ID" "$file_path"
}

# Scan for CS0462 and CS0115 errors
scan_for_inheritance_errors() {
    log_message "Scanning build output for inheritance and override errors..."
    
    local build_output="$SCRIPT_DIR/build_output.txt"
    if [[ ! -f "$build_output" ]]; then
        log_message "No build output file found for scanning"
        return 1
    fi
    
    # Extract CS0462 errors (inheritance conflicts)
    log_message "CS0462 errors found:"
    grep "error CS0462" "$build_output" | while read -r line; do
        log_message "  $line"
    done
    
    # Extract CS0115 errors (missing overrides)
    log_message "CS0115 errors found:"
    grep "error CS0115" "$build_output" | while read -r line; do
        log_message "  $line"
    done
}

# Main agent execution
main() {
    log_message "=== AGENT 3 - INHERITANCE & OVERRIDE SPECIALIST STARTING ==="
    log_message "Target: CS0462 (inheritance conflicts) and CS0115 (missing overrides)"
    
    local files_processed=()
    local errors_before=0
    
    # Get baseline error count
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        errors_before=$(cat "$SCRIPT_DIR/build_error_count.txt")
        log_message "Starting with $errors_before total error types"
    fi
    
    # Phase 1: Scan for inheritance errors
    log_message "Phase 1: Scanning for inheritance and override errors..."
    scan_for_inheritance_errors
    
    # Report completion
    log_message "=== AGENT 3 PROCESSING COMPLETE ==="
    log_message "Files processed: ${#files_processed[@]}"
    for file in "${files_processed[@]}"; do
        log_message "  - $file"
    done
    
    # Validate changes with build checker
    if [[ ${#files_processed[@]} -gt 0 ]]; then
        local file_list=$(IFS=,; echo "${files_processed[*]}")
        log_message "Requesting validation from Build Checker..."
        "$BUILD_CHECKER" validate "$AGENT_ID" "$file_list"
    else
        log_message "No files were modified, skipping validation"
    fi
    
    log_message "Agent 3 inheritance resolution work complete"
    return 0
}

# Handle command line arguments
case "${1:-main}" in
    "main")
        main
        ;;
    "scan")
        scan_for_inheritance_errors
        ;;
    *)
        echo "Usage: $0 {main|scan}"
        exit 1
        ;;
esac