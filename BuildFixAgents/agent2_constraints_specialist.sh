#!/bin/bash

# Agent 2 - Constraints & Compatibility Specialist
# Handles CS8377 (generic constraints) and CS0104 (ambiguous types)
# Removes INumber constraints and fixes namespace conflicts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="AGENT2"
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

# Remove INumber constraints for .NET Framework compatibility
remove_inumber_constraints() {
    local file_path="$1"
    
    log_message "Removing INumber constraints from $file_path for .NET Framework compatibility"
    
    if [[ ! -f "$file_path" ]]; then
        log_message "File not found: $file_path"
        return 1
    fi
    
    # Check if file contains INumber constraints
    if grep -q "INumber<" "$file_path"; then
        log_message "Found INumber constraints in $file_path"
        
        # Create backup
        cp "$file_path" "${file_path}.backup.$(date +%s)"
        
        # Remove INumber constraints - replace with basic numeric constraints
        # INumber<T> where T : INumber<T> -> T where T : struct, IComparable<T>, IConvertible, IEquatable<T>
        sed -i 's/where T : INumber<T>/where T : struct, IComparable<T>, IConvertible, IEquatable<T>/g' "$file_path"
        sed -i 's/where T : struct, INumber<T>/where T : struct, IComparable<T>, IConvertible, IEquatable<T>/g' "$file_path"
        sed -i 's/INumber<T>/T/g' "$file_path"
        
        # Remove INumber using statement
        sed -i '/using.*System\.Numerics/d' "$file_path"
        
        log_message "Removed INumber constraints from $file_path"
        return 0
    else
        log_message "No INumber constraints found in $file_path"
        return 0
    fi
}

# Fix Vector<> namespace ambiguity
fix_vector_ambiguity() {
    local file_path="$1"
    
    log_message "Fixing Vector<> namespace ambiguity in $file_path"
    
    if [[ ! -f "$file_path" ]]; then
        log_message "File not found: $file_path"
        return 1
    fi
    
    # Check for Vector usage and potential ambiguity
    if grep -q "Vector<" "$file_path"; then
        log_message "Found Vector<> usage in $file_path"
        
        # Check if both System.Numerics and AiDotNet.LinearAlgebra are used
        local has_system_numerics=$(grep -c "using System.Numerics" "$file_path" || echo "0")
        local has_aidotnet_vector=$(grep -c "using AiDotNet.LinearAlgebra" "$file_path" || echo "0")
        
        if [[ $has_system_numerics -gt 0 && $has_aidotnet_vector -gt 0 ]]; then
            log_message "Potential Vector<> ambiguity detected"
            
            # Create backup
            cp "$file_path" "${file_path}.backup.$(date +%s)"
            
            # Use fully qualified names for System.Numerics.Vector
            sed -i 's/\bVector<\([^>]*\)>\b/AiDotNet.LinearAlgebra.Vector<\1>/g' "$file_path"
            
            log_message "Fixed Vector<> ambiguity by using fully qualified names"
            return 0
        else
            log_message "No Vector<> ambiguity detected in $file_path"
            return 0
        fi
    else
        log_message "No Vector<> usage found in $file_path"
        return 0
    fi
}

# Scan for CS8377 and CS0104 errors
scan_for_constraint_errors() {
    log_message "Scanning build output for constraint and ambiguity errors..."
    
    local build_output="$SCRIPT_DIR/build_output.txt"
    if [[ ! -f "$build_output" ]]; then
        log_message "No build output file found for scanning"
        return 1
    fi
    
    # Extract CS8377 errors (constraint violations)
    log_message "CS8377 errors found:"
    grep "error CS8377" "$build_output" | while read -r line; do
        log_message "  $line"
    done
    
    # Extract CS0104 errors (ambiguous references)  
    log_message "CS0104 errors found:"
    grep "error CS0104" "$build_output" | while read -r line; do
        log_message "  $line"
    done
}

# Main agent execution
main() {
    log_message "=== AGENT 2 - CONSTRAINTS & COMPATIBILITY SPECIALIST STARTING ==="
    log_message "Target: CS8377 (generic constraints) and CS0104 (ambiguous types)"
    
    local files_processed=()
    local errors_before=0
    
    # Get baseline error count
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        errors_before=$(cat "$SCRIPT_DIR/build_error_count.txt")
        log_message "Starting with $errors_before total error types"
    fi
    
    # Phase 1: Scan for constraint errors
    log_message "Phase 1: Scanning for constraint and ambiguity errors..."
    scan_for_constraint_errors
    
    # Report completion
    log_message "=== AGENT 2 PROCESSING COMPLETE ==="
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
    
    log_message "Agent 2 constraint resolution work complete"
    return 0
}

# Handle command line arguments
case "${1:-main}" in
    "main")
        main
        ;;
    "scan")
        scan_for_constraint_errors
        ;;
    *)
        echo "Usage: $0 {main|scan}"
        exit 1
        ;;
esac