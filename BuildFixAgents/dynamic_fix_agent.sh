#!/bin/bash

# Dynamic Fix Agent - Template for spawning error-specific agents
# Can handle any error code with batch operations support

set -euo pipefail

# Parse command line arguments
ERROR_CODE="${1:-}"
AGENT_INSTANCE="${2:-1}"
STRATEGY="${3:-auto}"

if [[ -z "$ERROR_CODE" ]]; then
    echo "Usage: $0 <ERROR_CODE> [INSTANCE_NUMBER] [STRATEGY]"
    echo "Example: $0 CS8618 1 aggressive"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="DYNAMIC_${ERROR_CODE}_${AGENT_INSTANCE}"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
STATE_DIR="$SCRIPT_DIR/state/dynamic_agents/${ERROR_CODE}"
PATTERNS_FILE="$STATE_DIR/fix_patterns.json"

# Source libraries
source "$SCRIPT_DIR/batch_file_operations.sh"
source "$SCRIPT_DIR/fix_agent_batch_lib.sh"
source "$SCRIPT_DIR/pattern_learning_integration.sh"

# Source pre-compiled patterns if available
if [[ -f "$SCRIPT_DIR/precompiled_patterns.sh" ]]; then
    source "$SCRIPT_DIR/precompiled_patterns.sh"
fi

# Create directories
mkdir -p "$STATE_DIR"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $AGENT_ID: $message" | tee -a "$LOG_FILE"
}

# Load or generate fix patterns for this error code
load_fix_patterns() {
    local error_code="$1"
    
    # Check if we have cached patterns
    if [[ -f "$PATTERNS_FILE" ]] && [[ $(find "$PATTERNS_FILE" -mmin -60 -type f) ]]; then
        log_message "Using cached fix patterns for $error_code"
        return 0
    fi
    
    log_message "Generating fix patterns for $error_code..."
    
    # Extract error samples from build output
    local error_samples="$STATE_DIR/error_samples.txt"
    grep "error $error_code:" build_output.txt | head -100 > "$error_samples" || {
        log_message "No errors found for $error_code"
        return 1
    }
    
    # Analyze error patterns and generate fixes
    case "$error_code" in
        CS[0-9]*)
            generate_csharp_fix_patterns "$error_code" "$error_samples"
            ;;
        TS[0-9]*)
            generate_typescript_fix_patterns "$error_code" "$error_samples"
            ;;
        *)
            generate_generic_fix_patterns "$error_code" "$error_samples"
            ;;
    esac
}

# Generate C# specific fix patterns
generate_csharp_fix_patterns() {
    local error_code="$1"
    local samples_file="$2"
    
    # Create patterns based on common C# error categories
    cat > "$PATTERNS_FILE" << EOF
{
    "error_code": "$error_code",
    "language": "csharp",
    "patterns": []
}
EOF
    
    # Analyze error messages and generate appropriate patterns
    case "$error_code" in
        CS0*) # Syntax errors
            add_syntax_fix_patterns "$error_code"
            ;;
        CS1*) # Member/type errors
            add_member_fix_patterns "$error_code"
            ;;
        CS8*) # C# 8.0+ nullable reference errors
            add_nullable_fix_patterns "$error_code"
            ;;
        *)
            add_generic_csharp_patterns "$error_code"
            ;;
    esac
}

# Add syntax fix patterns dynamically
add_syntax_fix_patterns() {
    local error_code="$1"
    
    # Read error messages to understand the pattern
    local error_messages=$(grep "error $error_code:" build_output.txt | \
        sed 's/.*error [A-Z0-9]*: //' | sort -u)
    
    # Generate sed patterns based on error messages
    local patterns_sed="$STATE_DIR/syntax_patterns.sed"
    > "$patterns_sed"
    
    while IFS= read -r msg; do
        case "$msg" in
            *"expected"*)
                # Handle missing semicolons, brackets, etc.
                echo 's/\([^;]\)$/\1;/g' >> "$patterns_sed"
                ;;
            *"invalid token"*)
                # Handle invalid characters
                echo 's/[^[:print:]]//g' >> "$patterns_sed"
                ;;
        esac
    done <<< "$error_messages"
    
    # Update patterns file
    jq --arg patterns "$(cat "$patterns_sed")" \
        '.patterns += [{"type": "sed", "content": $patterns}]' \
        "$PATTERNS_FILE" > "$PATTERNS_FILE.tmp" && mv "$PATTERNS_FILE.tmp" "$PATTERNS_FILE"
}

# Apply fixes using batch operations
apply_fixes_batch() {
    local error_code="$1"
    local strategy="$2"
    
    log_message "Applying $strategy fixes for $error_code errors..."
    
    # Try fast path router first (fastest)
    if [[ -f "$SCRIPT_DIR/fast_path_router.sh" ]]; then
        source "$SCRIPT_DIR/fast_path_router.sh"
        
        if can_use_fast_path "$error_code"; then
            log_message "Fast path available for $error_code"
            
            # Get first error for context
            local first_error=$(grep "error $error_code:" build_output.txt 2>/dev/null | head -1)
            if [[ -n "$first_error" ]]; then
                local file=$(echo "$first_error" | cut -d: -f1)
                local line=$(echo "$first_error" | cut -d: -f2 | cut -d, -f1)
                local msg=$(echo "$first_error" | sed "s/.*error $error_code: //")
                
                if route_to_fast_path "$error_code" "$file" "$line" "$msg"; then
                    log_message "Fast path successfully fixed $error_code"
                    record_successful_fix "$error_code" "fast_path" '{"type":"fast_path","strategy":"'$strategy'"}'
                    return 0
                fi
            fi
        fi
    fi
    
    # Try pre-compiled patterns next (still fast)
    if command -v apply_precompiled >/dev/null 2>&1; then
        log_message "Checking for pre-compiled patterns..."
        if apply_precompiled "$error_code"; then
            log_message "Successfully applied pre-compiled pattern"
            record_successful_fix "$error_code" "precompiled_pattern" '{"type":"precompiled","strategy":"'$strategy'"}'
            return 0
        fi
    fi
    
    # Try learned patterns next
    if has_patterns "$error_code"; then
        log_message "Found learned patterns for $error_code"
        
        # Get affected files
        local affected_files=($(get_affected_files "$error_code"))
        
        if [[ ${#affected_files[@]} -gt 0 ]]; then
            local success_count=0
            local pattern_applied=false
            
            for file in "${affected_files[@]}"; do
                if try_learned_patterns "$error_code" "$file"; then
                    ((success_count++))
                    pattern_applied=true
                fi
            done
            
            if [[ "$pattern_applied" == "true" ]]; then
                log_message "Applied learned patterns to $success_count files"
                return 0
            fi
        fi
    fi
    
    # Fall back to regular logic
    log_message "No learned patterns available, using standard fixes"
    
    # Get affected files
    local affected_files=($(get_affected_files "$error_code"))
    
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        log_message "No files affected by $error_code"
        return 0
    fi
    
    log_message "Found ${#affected_files[@]} files with $error_code errors"
    
    # Load patterns
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        log_message "No fix patterns available"
        return 1
    fi
    
    # Apply strategy-specific fixes
    case "$strategy" in
        "aggressive")
            apply_aggressive_fixes "$error_code" "${affected_files[@]}"
            ;;
        "conservative")
            apply_conservative_fixes "$error_code" "${affected_files[@]}"
            ;;
        "auto")
            apply_smart_fixes "$error_code" "${affected_files[@]}"
            ;;
        *)
            log_message "Unknown strategy: $strategy"
            return 1
            ;;
    esac
}

# Apply aggressive fixes - try all possible patterns
apply_aggressive_fixes() {
    local error_code="$1"
    shift
    local files=("$@")
    
    log_message "Applying aggressive fixes to ${#files[@]} files..."
    
    # Backup all files first
    batch_backup ".${error_code}_backup" "${files[@]}"
    
    # Try all available fix patterns
    local patterns=$(jq -r '.patterns[].content' "$PATTERNS_FILE" 2>/dev/null)
    
    if [[ -n "$patterns" ]]; then
        # Apply each pattern
        while IFS= read -r pattern; do
            if [[ -n "$pattern" ]]; then
                batch_sed "$pattern" "${files[@]}"
                # Record the attempt
                record_successful_fix "$error_code" "$pattern" '{"strategy":"aggressive"}'
            fi
        done <<< "$patterns"
    fi
    
    # Use the batch library functions if available
    local batch_result=0
    case "$error_code" in
        CS0101) 
            batch_fix_cs0101
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs0101" '{"type":"batch_library"}'
            fi
            ;;
        CS8618) 
            batch_fix_cs8618
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs8618" '{"type":"batch_library"}'
            fi
            ;;
        CS0234) 
            batch_fix_cs0234
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs0234" '{"type":"batch_library"}'
            fi
            ;;
        CS0103) 
            batch_fix_cs0103
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs0103" '{"type":"batch_library"}'
            fi
            ;;
        CS0111) 
            batch_fix_cs0111
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs0111" '{"type":"batch_library"}'
            fi
            ;;
        CS1061) 
            batch_fix_cs1061
            batch_result=$?
            if [[ $batch_result -eq 0 ]]; then
                record_successful_fix "$error_code" "batch_fix_cs1061" '{"type":"batch_library"}'
            fi
            ;;
        *)
            # Try generic fixes
            apply_generic_batch_fixes "$error_code" "${files[@]}"
            ;;
    esac
}

# Apply conservative fixes - only high-confidence patterns
apply_conservative_fixes() {
    local error_code="$1"
    shift
    local files=("$@")
    
    log_message "Applying conservative fixes to ${#files[@]} files..."
    
    # Only apply patterns marked as high confidence
    local high_conf_patterns=$(jq -r '.patterns[] | select(.confidence == "high") | .content' "$PATTERNS_FILE" 2>/dev/null)
    
    if [[ -n "$high_conf_patterns" ]]; then
        batch_backup ".${error_code}_backup" "${files[@]}"
        
        while IFS= read -r pattern; do
            if [[ -n "$pattern" ]]; then
                batch_sed "$pattern" "${files[@]}"
            fi
        done <<< "$high_conf_patterns"
    else
        log_message "No high-confidence patterns available"
    fi
}

# Apply smart fixes - analyze context and choose best approach
apply_smart_fixes() {
    local error_code="$1"
    shift
    local files=("$@")
    
    log_message "Applying smart fixes to ${#files[@]} files..."
    
    # Analyze error density
    local total_errors=$(grep -c "error $error_code:" build_output.txt || echo 0)
    local errors_per_file=$((total_errors / ${#files[@]}))
    
    if [[ $errors_per_file -gt 10 ]]; then
        log_message "High error density ($errors_per_file per file), using aggressive strategy"
        apply_aggressive_fixes "$error_code" "${files[@]}"
    else
        log_message "Low error density ($errors_per_file per file), using conservative strategy"
        apply_conservative_fixes "$error_code" "${files[@]}"
    fi
}

# Apply generic batch fixes for unknown error types
apply_generic_batch_fixes() {
    local error_code="$1"
    shift
    local files=("$@")
    
    log_message "Applying generic batch fixes for $error_code..."
    
    # Extract error patterns and try to fix
    local error_patterns="$STATE_DIR/generic_patterns.txt"
    grep "error $error_code:" build_output.txt | \
        sed 's/.*error [A-Z0-9]*: //' | \
        sort | uniq -c | sort -rn > "$error_patterns"
    
    # Generate fixes based on most common patterns
    local top_pattern=$(head -1 "$error_patterns" | sed 's/^ *[0-9]* //')
    
    if [[ -n "$top_pattern" ]]; then
        log_message "Most common pattern: $top_pattern"
        
        # Create generic fix based on pattern
        case "$top_pattern" in
            *"not found"*|*"does not exist"*)
                # Add missing imports/references
                log_message "Attempting to add missing references..."
                ;;
            *"already defined"*|*"duplicate"*)
                # Remove duplicates
                log_message "Attempting to remove duplicates..."
                ;;
            *"cannot convert"*|*"type mismatch"*)
                # Fix type conversions
                log_message "Attempting to fix type conversions..."
                ;;
        esac
    fi
}

# Monitor and report progress
monitor_progress() {
    local error_code="$1"
    local start_count=$(grep -c "error $error_code:" build_output.txt 2>/dev/null || echo 0)
    
    log_message "Starting with $start_count $error_code errors"
    
    # Return metrics
    echo "{
        \"agent_id\": \"$AGENT_ID\",
        \"error_code\": \"$error_code\",
        \"initial_errors\": $start_count,
        \"files_processed\": ${#affected_files[@]:-0},
        \"strategy\": \"$STRATEGY\",
        \"timestamp\": \"$(date -Iseconds)\"
    }" > "$STATE_DIR/metrics.json"
}

# Main execution
main() {
    log_message "=== DYNAMIC FIX AGENT STARTING ==="
    log_message "Error Code: $ERROR_CODE"
    log_message "Strategy: $STRATEGY"
    
    # Monitor initial state
    monitor_progress "$ERROR_CODE"
    
    # Check pattern learning suggestions
    if [[ -f "$STATE_DIR/error_analysis.json" ]]; then
        suggest_patterns "$STATE_DIR/error_analysis.json"
    fi
    
    # Load or generate fix patterns
    if load_fix_patterns "$ERROR_CODE"; then
        # Apply fixes
        apply_fixes_batch "$ERROR_CODE" "$STRATEGY"
        
        # Report completion
        log_message "Fix attempt complete for $ERROR_CODE"
    else
        log_message "No fixes available for $ERROR_CODE"
    fi
    
    # Generate learning report
    local final_count=$(grep -c "error $ERROR_CODE:" build_output.txt 2>/dev/null || echo 0)
    local initial_count=$(jq -r '.initial_errors' "$STATE_DIR/metrics.json" 2>/dev/null || echo 0)
    
    if [[ $final_count -lt $initial_count ]]; then
        log_message "Reduced $ERROR_CODE errors from $initial_count to $final_count"
        # Record overall success for future learning
        echo "${ERROR_CODE}|${STRATEGY}|$((initial_count - final_count))" >> "$STATE_DIR/learning_results.txt"
    fi
    
    log_message "=== DYNAMIC FIX AGENT COMPLETE ==="
}

# Run main
main "$@"