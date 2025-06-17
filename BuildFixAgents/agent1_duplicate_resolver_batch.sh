#!/bin/bash

# Agent 1 - Duplicate Resolution Specialist (Batch Optimized)
# Handles CS0101 (duplicate classes) and CS0111 (duplicate members)
# Uses batch operations for improved performance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="AGENT1_BATCH"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
BUILD_CHECKER="$SCRIPT_DIR/build_checker_agent.sh"
STATE_DIR="$SCRIPT_DIR/state/agent1_batch"
CACHE_DIR="$STATE_DIR/cache"

# Source batch operations library
source "$SCRIPT_DIR/batch_file_operations.sh"

# Create directories
mkdir -p "$STATE_DIR" "$CACHE_DIR"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $AGENT_ID: $message" | tee -a "$LOG_FILE"
}

# Analyze all CS0101 errors in batch
analyze_duplicate_errors() {
    log_message "Analyzing duplicate errors in batch mode..."
    
    local error_file="$STATE_DIR/cs0101_errors.txt"
    local analysis_file="$STATE_DIR/duplicate_analysis.json"
    
    # Extract all CS0101 errors
    grep -E "error CS0101:|error CS0111:" build_output.txt > "$error_file" || {
        log_message "No duplicate errors found"
        return 1
    }
    
    # Parse errors and group by type
    local duplicate_classes=()
    local duplicate_members=()
    local affected_files=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ([^:]+\.cs)\([0-9]+,[0-9]+\):[[:space:]]*error[[:space:]]+(CS[0-9]+):[[:space:]]*(.*) ]]; then
            local file="${BASH_REMATCH[1]}"
            local error_code="${BASH_REMATCH[2]}"
            local error_msg="${BASH_REMATCH[3]}"
            
            # Add to affected files list
            affected_files+=("$file")
            
            # Categorize by error type
            if [[ "$error_code" == "CS0101" ]]; then
                # Extract class name from error message
                if [[ "$error_msg" =~ namespace[[:space:]]\'([^\']+)\'[[:space:]]already[[:space:]]contains[[:space:]].*\'([^\']+)\' ]]; then
                    local namespace="${BASH_REMATCH[1]}"
                    local class_name="${BASH_REMATCH[2]}"
                    duplicate_classes+=("$namespace|$class_name|$file")
                fi
            elif [[ "$error_code" == "CS0111" ]]; then
                duplicate_members+=("$file|$error_msg")
            fi
        fi
    done < "$error_file"
    
    # Remove duplicates from file list
    local unique_files=($(printf '%s\n' "${affected_files[@]}" | sort -u))
    
    # Generate analysis report
    cat > "$analysis_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_errors": $(wc -l < "$error_file"),
    "duplicate_classes": $(printf '%s\n' "${duplicate_classes[@]}" | wc -l),
    "duplicate_members": $(printf '%s\n' "${duplicate_members[@]}" | wc -l),
    "affected_files": ${#unique_files[@]},
    "files": $(printf '%s\n' "${unique_files[@]}" | jq -R . | jq -s .),
    "class_duplicates": $(printf '%s\n' "${duplicate_classes[@]}" | jq -R 'split("|") | {namespace: .[0], class: .[1], file: .[2]}' | jq -s .)
}
EOF
    
    log_message "Analysis complete: ${#unique_files[@]} files affected"
    echo "${unique_files[@]}"
}

# Batch process duplicate classes
fix_duplicate_classes_batch() {
    local analysis_file="$STATE_DIR/duplicate_analysis.json"
    
    if [[ ! -f "$analysis_file" ]]; then
        log_message "No analysis file found"
        return 1
    fi
    
    # Get unique namespace/class combinations
    local duplicates=$(jq -r '.class_duplicates[] | "\(.namespace)|\(.class)"' "$analysis_file" | sort -u)
    
    if [[ -z "$duplicates" ]]; then
        log_message "No duplicate classes to fix"
        return 0
    fi
    
    log_message "Processing duplicate classes in batch..."
    
    # Create sed patterns file
    local patterns_file="$STATE_DIR/duplicate_patterns.sed"
    > "$patterns_file"
    
    # Generate patterns for each duplicate
    while IFS='|' read -r namespace class_name; do
        # Check if class has a dedicated file
        local dedicated_file=$(find_dedicated_class_file "$namespace" "$class_name")
        
        if [[ -n "$dedicated_file" ]]; then
            log_message "Class $class_name has dedicated file: $dedicated_file"
            
            # Create pattern to remove inline definitions
            cat >> "$patterns_file" << EOF
# Remove inline definition of $class_name
/^[[:space:]]*\(public\|internal\|private\)[[:space:]]\+\(static\|abstract\|sealed\|partial\)*[[:space:]]*class[[:space:]]\+$class_name[[:space:]]*{/,/^[[:space:]]*}[[:space:]]*$/ {
    # Check if this is the start of the class
    /^[[:space:]]*\(public\|internal\|private\)[[:space:]]\+/ {
        # Save the line
        h
        # Read next lines until we find the closing brace
        :loop
        n
        /^[[:space:]]*}[[:space:]]*$/! b loop
        # Delete the entire block
        g
        s/.*//
        d
    }
}
EOF
        else
            # Rename duplicate occurrences
            echo "s/class $class_name/class ${class_name}_2/g" >> "$patterns_file"
        fi
    done <<< "$duplicates"
    
    # Get all affected files
    local files=($(jq -r '.files[]' "$analysis_file"))
    
    # Backup files before modification
    log_message "Creating backups..."
    batch_backup ".cs0101_backup" "${files[@]}"
    
    # Apply fixes in batch
    log_message "Applying fixes to ${#files[@]} files..."
    batch_sed_multi "$patterns_file" "${files[@]}"
    
    # Verify fixes
    local fixed_count=0
    for file in "${files[@]}"; do
        if diff -q "$file" "${file}.cs0101_backup" >/dev/null; then
            log_message "No changes needed in: $file"
        else
            log_message "Fixed duplicates in: $file"
            ((fixed_count++))
        fi
    done
    
    log_message "Fixed $fixed_count files"
    return 0
}

# Find dedicated file for a class
find_dedicated_class_file() {
    local namespace="$1"
    local class_name="$2"
    
    # Convert namespace to directory path
    local dir_path=$(echo "$namespace" | sed 's/AiDotNet\./src\//' | sed 's/\./\//g')
    
    # Look for dedicated class file
    local potential_files=(
        "$SCRIPT_DIR/${dir_path}/${class_name}.cs"
        "$SCRIPT_DIR/src/${class_name}.cs"
        "$(find "$SCRIPT_DIR/src" -name "${class_name}.cs" -type f 2>/dev/null | head -1)"
    )
    
    for file in "${potential_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "$file"
            return 0
        fi
    done
    
    return 1
}

# Batch fix duplicate members
fix_duplicate_members_batch() {
    log_message "Fixing duplicate members in batch..."
    
    # Find all files with CS0111 errors
    local error_files=($(grep -l "error CS0111:" build_output.txt | xargs -I {} grep -l {} *.cs 2>/dev/null || true))
    
    if [[ ${#error_files[@]} -eq 0 ]]; then
        log_message "No duplicate member errors found"
        return 0
    fi
    
    # Create patterns for common duplicate member fixes
    local patterns_file="$STATE_DIR/member_patterns.sed"
    cat > "$patterns_file" << 'EOF'
# Remove duplicate parameterless constructors
/^[[:space:]]*public[[:space:]]\+[A-Za-z0-9_]\+()[[:space:]]*{/,/^[[:space:]]*}/ {
    # Mark first occurrence
    t skip
    :skip
    # Delete subsequent occurrences
    s/^[[:space:]]*public[[:space:]]\+\([A-Za-z0-9_]\+\)()[[:space:]]*{/\/\/ Duplicate constructor removed: \1()/
}

# Rename duplicate methods by adding suffix
s/\(public\|private\|protected\)[[:space:]]\+\(void\|string\|int\|bool\)[[:space:]]\+\([A-Za-z0-9_]\+\)(/\1 \2 \3_Alt(/2g
EOF
    
    # Apply fixes
    batch_sed_multi "$patterns_file" "${error_files[@]}"
    
    log_message "Duplicate member fixes applied to ${#error_files[@]} files"
}

# Optimize file processing with caching
process_with_cache() {
    local file="$1"
    local operation="$2"
    
    # Generate cache key
    local file_hash=$(md5sum "$file" | cut -d' ' -f1)
    local cache_file="$CACHE_DIR/${file_hash}.${operation}"
    
    # Check cache
    if [[ -f "$cache_file" ]] && [[ "$cache_file" -nt "$file" ]]; then
        log_message "Using cached result for $file"
        cat "$cache_file"
        return 0
    fi
    
    # Process and cache
    case "$operation" in
        "analyze")
            analyze_file_structure "$file" | tee "$cache_file"
            ;;
        "fix")
            fix_file_duplicates "$file" | tee "$cache_file"
            ;;
    esac
}

# Main execution
main() {
    log_message "Starting batch duplicate resolution..."
    
    # Analyze all duplicate errors
    local affected_files=($(analyze_duplicate_errors))
    
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        log_message "No duplicate errors to fix"
        exit 0
    fi
    
    # Fix duplicate classes in batch
    fix_duplicate_classes_batch
    
    # Fix duplicate members in batch
    fix_duplicate_members_batch
    
    # Clean up old backups
    find "$SCRIPT_DIR" -name "*.cs0101_backup" -mtime +7 -delete 2>/dev/null || true
    
    # Report results
    local analysis_file="$STATE_DIR/duplicate_analysis.json"
    if [[ -f "$analysis_file" ]]; then
        local total_errors=$(jq -r '.total_errors' "$analysis_file")
        local files_processed=$(jq -r '.affected_files' "$analysis_file")
        
        log_message "Batch processing complete:"
        log_message "  - Total errors: $total_errors"
        log_message "  - Files processed: $files_processed"
        log_message "  - Cache hits: $(find "$CACHE_DIR" -type f | wc -l)"
    fi
    
    log_message "Duplicate resolution complete"
}

# Export functions
export -f find_dedicated_class_file
export -f process_with_cache

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi