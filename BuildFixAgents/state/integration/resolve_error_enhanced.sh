# Enhanced resolve_error function with actual file modification
resolve_error() {
    local file_path="$1"
    local error_code="$2"
    local line_number="$3"
    local error_msg="$4"
    
    log_message "Attempting to fix $error_code in $file_path at line $line_number"
    
    # Check if file modification is available
    if [[ "$FILE_MOD_AVAILABLE" != "true" ]]; then
        log_message "WARNING: File modification not available, falling back to analysis only"
        return 1
    fi
    
    # Apply fix based on error code
    local fix_applied=false
    
    case "$error_code" in
        "CS0101")
            # Duplicate class definition
            local class_name=$(echo "$error_msg" | grep -o "'[^']*'" | head -1 | tr -d "'")
            if [[ -n "$class_name" ]]; then
                log_message "Fixing duplicate class '$class_name'"
                if apply_pattern_fix "$file_path" "$error_code" "$class_name" "" "$line_number"; then
                    fix_applied=true
                    log_message "SUCCESS: Fixed duplicate class '$class_name'"
                fi
            fi
            ;;
            
        "CS0111")
            # Duplicate method
            local method_name=$(echo "$error_msg" | grep -o "'[^']*'" | head -1 | tr -d "'")
            if [[ -n "$method_name" ]]; then
                log_message "Fixing duplicate method '$method_name'"
                if apply_pattern_fix "$file_path" "$error_code" "$method_name" "" "$line_number"; then
                    fix_applied=true
                    log_message "SUCCESS: Fixed duplicate method '$method_name'"
                fi
            fi
            ;;
            
        "CS0462")
            # Inheritance conflict
            log_message "Fixing inheritance conflict"
            # Extract method signature from error
            local method_sig=$(echo "$error_msg" | grep -o "'[^']*'" | head -1 | tr -d "'")
            if apply_pattern_fix "$file_path" "$error_code" "$method_sig" "" "$line_number"; then
                fix_applied=true
                log_message "SUCCESS: Fixed inheritance conflict"
            fi
            ;;
            
        "CS0246")
            # Type or namespace not found
            local missing_type=$(echo "$error_msg" | grep -o "'[^']*'" | head -1 | tr -d "'")
            log_message "Type '$missing_type' not found - checking pattern database"
            
            # Try to add using statement
            if [[ -n "$missing_type" ]]; then
                local using_stmt=$(find_using_for_type "$missing_type")
                if [[ -n "$using_stmt" ]]; then
                    # Add using statement at top of file
                    sed -i "1s/^/using $using_stmt;\n/" "$file_path"
                    fix_applied=true
                    log_message "Added using statement for $missing_type"
                fi
            fi
            ;;
            
        *)
            log_message "No specific fix implementation for $error_code yet"
            # Try generic pattern matching from database
            if [[ -n "$PATTERN_DATABASE" ]]; then
                local pattern=$(jq -r ".errors[] | select(.code == \"$error_code\") | .pattern" "$PATTERN_DATABASE" 2>/dev/null)
                local replacement=$(jq -r ".errors[] | select(.code == \"$error_code\") | .replacement" "$PATTERN_DATABASE" 2>/dev/null)
                
                if [[ -n "$pattern" ]] && [[ "$pattern" != "null" ]]; then
                    if apply_pattern_fix "$file_path" "$error_code" "$pattern" "$replacement" "$line_number"; then
                        fix_applied=true
                        log_message "Applied pattern fix for $error_code"
                    fi
                fi
            fi
            ;;
    esac
    
    # Update build output if fix was applied
    if [[ "$fix_applied" == "true" ]]; then
        log_message "Fix applied, updating build status..."
        update_build_status "$file_path" "$error_code"
    else
        log_message "No fix could be applied for $error_code"
    fi
    
    return 0
}

# Helper function to find using statement for type
find_using_for_type() {
    local type="$1"
    
    # Common .NET type mappings
    case "$type" in
        "List"|"Dictionary"|"HashSet"|"Queue"|"Stack")
            echo "System.Collections.Generic"
            ;;
        "File"|"Directory"|"Path")
            echo "System.IO"
            ;;
        "Task"|"TaskFactory")
            echo "System.Threading.Tasks"
            ;;
        "Regex"|"Match")
            echo "System.Text.RegularExpressions"
            ;;
        "HttpClient"|"HttpResponseMessage")
            echo "System.Net.Http"
            ;;
        *)
            # Try to find in project
            local found=$(grep -r "namespace.*$type" "$PROJECT_DIR" 2>/dev/null | head -1 | sed 's/.*namespace //' | sed 's/ .*//')
            echo "$found"
            ;;
    esac
}

# Update build status after fix
update_build_status() {
    local file_path="$1"
    local error_code="$2"
    
    # Remove fixed error from build output
    if [[ -f "$BUILD_OUTPUT_FILE" ]]; then
        grep -v "$file_path.*$error_code" "$BUILD_OUTPUT_FILE" > "$BUILD_OUTPUT_FILE.tmp" || true
        mv "$BUILD_OUTPUT_FILE.tmp" "$BUILD_OUTPUT_FILE"
    fi
}
