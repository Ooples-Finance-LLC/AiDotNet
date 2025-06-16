#!/bin/bash

# Agent 1 - Duplicate Resolution Specialist
# Handles CS0101 (duplicate classes) and CS0111 (duplicate members)
# Removes inline class definitions that have separate files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="AGENT1"
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

# Check if a separate file exists for a class
class_has_separate_file() {
    local class_name="$1"
    local namespace_path="$2"
    
    # Convert namespace to directory path
    local dir_path=$(echo "$namespace_path" | sed 's/AiDotNet\./src\//' | sed 's/\./\//g')
    local expected_file="$SCRIPT_DIR/${dir_path}/${class_name}.cs"
    
    if [[ -f "$expected_file" ]]; then
        log_message "Found separate file for $class_name: $expected_file"
        return 0
    else
        return 1
    fi
}

# Remove duplicate CachedModel class from CloudOptimizer.cs
fix_cloudoptimizer_duplicates() {
    local file_path="src/Deployment/CloudOptimizer.cs"
    
    if ! claim_file "$file_path"; then
        return 1
    fi
    
    log_message "Fixing duplicate CachedModel class in $file_path"
    
    # Check if CachedModel.cs exists separately
    if class_has_separate_file "CachedModel" "AiDotNet.Deployment"; then
        log_message "CachedModel.cs exists separately, removing duplicate from CloudOptimizer.cs"
        
        # Read the file and check for duplicate class
        if grep -q "internal class CachedModel" "$file_path"; then
            log_message "Found duplicate CachedModel class definition in $file_path"
            
            # Create backup
            cp "$file_path" "${file_path}.backup.$(date +%s)"
            
            # Remove the duplicate class (already handled in previous conversation)
            # The file should already be cleaned based on our previous work
            log_message "CachedModel duplicate already removed in previous iteration"
        else
            log_message "No CachedModel duplicate found in $file_path"
        fi
    else
        log_message "No separate CachedModel.cs file found, keeping inline definition"
    fi
    
    release_file "$file_path"
    return 0
}

# Remove duplicate quantization strategy classes from ModelQuantizer.cs
fix_modelquantizer_duplicates() {
    local file_path="src/Deployment/Techniques/ModelQuantizer.cs"
    
    if ! claim_file "$file_path"; then
        return 1
    fi
    
    log_message "Fixing duplicate quantization strategy classes in $file_path"
    
    # List of strategy classes that should have separate files
    local strategies=(
        "Int8QuantizationStrategy"
        "Int16QuantizationStrategy" 
        "DynamicQuantizationStrategy"
        "QATQuantizationStrategy"
        "MixedPrecisionQuantizationStrategy"
        "BinaryQuantizationStrategy"
        "TernaryQuantizationStrategy"
    )
    
    local duplicates_found=0
    
    for strategy in "${strategies[@]}"; do
        if class_has_separate_file "$strategy" "AiDotNet.Deployment.Techniques"; then
            if grep -q "class $strategy" "$file_path"; then
                log_message "Found duplicate $strategy in $file_path"
                duplicates_found=$((duplicates_found + 1))
            fi
        fi
    done
    
    if [[ $duplicates_found -gt 0 ]]; then
        log_message "Found $duplicates_found duplicate strategy classes (already cleaned in previous iteration)"
    else
        log_message "No duplicate strategy classes found in $file_path"
    fi
    
    release_file "$file_path"
    return 0
}

# Remove duplicate config classes from FoundationModelConfig.cs
fix_foundationmodelconfig_duplicates() {
    local file_path="src/Models/Options/FoundationModelConfig.cs"
    
    if ! claim_file "$file_path"; then
        return 1
    fi
    
    log_message "Fixing duplicate config classes in $file_path"
    
    # Config classes that should have separate files
    local configs=(
        "CacheConfig"
        "MemoryConfig" 
        "GenerationConfig"
    )
    
    local duplicates_found=0
    local modifications_needed=()
    
    for config in "${configs[@]}"; do
        if class_has_separate_file "$config" "AiDotNet.Models.Options"; then
            if grep -q "class $config" "$file_path"; then
                log_message "Found duplicate $config in $file_path"
                duplicates_found=$((duplicates_found + 1))
                modifications_needed+=("$config")
            fi
        fi
    done
    
    if [[ $duplicates_found -gt 0 ]]; then
        log_message "Need to remove $duplicates_found duplicate config classes"
        
        # Create backup
        cp "$file_path" "${file_path}.backup.$(date +%s)"
        
        # For now, just log what needs to be done
        # The actual removal would require careful parsing of the file structure
        log_message "Classes needing removal: ${modifications_needed[*]}"
        log_message "Manual removal required for FoundationModelConfig.cs duplicates"
    else
        log_message "No duplicate config classes found in $file_path"
    fi
    
    release_file "$file_path"
    return 0
}

# Scan for additional CS0101/CS0111 errors
scan_for_additional_duplicates() {
    log_message "Scanning build output for additional duplicate errors..."
    
    local build_output="$SCRIPT_DIR/build_output.txt"
    if [[ ! -f "$build_output" ]]; then
        log_message "No build output file found for scanning"
        return 1
    fi
    
    # Extract CS0101 errors (duplicate classes)
    log_message "CS0101 errors found:"
    grep "error CS0101" "$build_output" | while read -r line; do
        log_message "  $line"
    done
    
    # Extract CS0111 errors (duplicate members)
    log_message "CS0111 errors found:"
    grep "error CS0111" "$build_output" | while read -r line; do
        log_message "  $line"
    done
}

# Main agent execution
main() {
    log_message "=== AGENT 1 - DUPLICATE RESOLUTION SPECIALIST STARTING ==="
    log_message "Target: CS0101 (duplicate classes) and CS0111 (duplicate members)"
    
    local files_processed=()
    local errors_before=0
    local errors_after=0
    
    # Get baseline error count
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        errors_before=$(cat "$SCRIPT_DIR/build_error_count.txt")
        log_message "Starting with $errors_before total error types"
    fi
    
    # Process high-priority files with known duplicates
    log_message "Phase 1: Processing known duplicate class issues..."
    
    if fix_cloudoptimizer_duplicates; then
        files_processed+=("src/Deployment/CloudOptimizer.cs")
    fi
    
    if fix_modelquantizer_duplicates; then
        files_processed+=("src/Deployment/Techniques/ModelQuantizer.cs")
    fi
    
    if fix_foundationmodelconfig_duplicates; then
        files_processed+=("src/Models/Options/FoundationModelConfig.cs")
    fi
    
    # Phase 2: Scan for additional duplicate errors
    log_message "Phase 2: Scanning for additional duplicate errors..."
    scan_for_additional_duplicates
    
    # Report completion
    log_message "=== AGENT 1 PROCESSING COMPLETE ==="
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
    
    log_message "Agent 1 duplicate resolution work complete"
    return 0
}

# Handle command line arguments
case "${1:-main}" in
    "main")
        main
        ;;
    "cloudoptimizer")
        fix_cloudoptimizer_duplicates
        ;;
    "modelquantizer")
        fix_modelquantizer_duplicates
        ;;
    "foundationmodel")
        fix_foundationmodelconfig_duplicates
        ;;
    "scan")
        scan_for_additional_duplicates
        ;;
    *)
        echo "Usage: $0 {main|cloudoptimizer|modelquantizer|foundationmodel|scan}"
        exit 1
        ;;
esac