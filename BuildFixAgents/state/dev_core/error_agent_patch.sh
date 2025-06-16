#!/bin/bash

# Patch to add file modification to generic_error_agent.sh

# Source the file modifier
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/state/dev_core/file_modifier.sh"

# Add to the fix_errors function
patch_fix_errors() {
    cat << 'PATCH'
# Enhanced fix_errors function with actual file modification
fix_errors() {
    log_message "Fixing errors with pattern matching and file modification"
    
    # Get error list
    local errors=$(cat "$AGENT_DIR/logs/build_output.txt" | grep "error CS")
    
    while IFS= read -r error_line; do
        # Parse error details
        local file=$(echo "$error_line" | cut -d'(' -f1)
        local line=$(echo "$error_line" | cut -d'(' -f2 | cut -d',' -f1)
        local error_code=$(echo "$error_line" | grep -o 'CS[0-9]\+')
        
        log_message "Processing $error_code in $file at line $line"
        
        # Apply appropriate fix
        case "$error_code" in
            "CS0101")
                # Extract duplicate name
                local dup_name=$(echo "$error_line" | grep -o "'[^']*'" | head -1 | tr -d "'")
                apply_pattern_fix "$file" "$error_code" "$dup_name" "" "$line"
                ;;
            "CS0111")
                # Extract method name
                local method=$(echo "$error_line" | grep -o "'[^']*'" | head -1 | tr -d "'")
                apply_pattern_fix "$file" "$error_code" "$method" "" "$line"
                ;;
            "CS0462")
                # Fix inheritance issue
                local old_sig=$(grep -n "GetModelMetadata" "$file" | tail -1)
                apply_pattern_fix "$file" "$error_code" "$old_sig" "" "$line"
                ;;
        esac
    done <<< "$errors"
    
    log_message "Fix attempt complete"
}
PATCH
}

# Apply the patch
echo "Patching generic_error_agent.sh to add file modification..."
patch_fix_errors >> "$SCRIPT_DIR/generic_error_agent_enhanced.sh"
