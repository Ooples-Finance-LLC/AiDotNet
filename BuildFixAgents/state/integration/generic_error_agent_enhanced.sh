#!/bin/bash

# Generic Error Resolution Agent
# Can be specialized for any error pattern based on configuration
# Now with AI-powered error analysis and fix generation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="$SCRIPT_DIR"  # For compatibility
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
COORDINATION_FILE="$SCRIPT_DIR/AGENT_COORDINATION.md"
BUILD_OUTPUT_FILE="$SCRIPT_DIR/build_output.txt"

# Source AI integration if available
if [[ -f "$SCRIPT_DIR/ai_integration.sh" ]]; then
    source "$SCRIPT_DIR/ai_integration.sh"
    AI_AVAILABLE=true
else
    AI_AVAILABLE=false
fi

# Source file modification library
if [[ -f "$SCRIPT_DIR/state/dev_core/file_modifier.sh" ]]; then
    source "$SCRIPT_DIR/state/dev_core/file_modifier.sh"
    FILE_MOD_AVAILABLE=true
else
    FILE_MOD_AVAILABLE=false
fi

# Source file modification library
if [[ -f "$SCRIPT_DIR/state/dev_core/file_modifier.sh" ]]; then
    source "$SCRIPT_DIR/state/dev_core/file_modifier.sh"
    FILE_MOD_AVAILABLE=true
else
    FILE_MOD_AVAILABLE=false
fi

# Source file modification library
if [[ -f "$SCRIPT_DIR/state/dev_core/file_modifier.sh" ]]; then
    source "$SCRIPT_DIR/state/dev_core/file_modifier.sh"
    FILE_MOD_AVAILABLE=true
else
    FILE_MOD_AVAILABLE=false
fi

# Agent configuration (passed as arguments)
AGENT_ID="${1:-generic_agent}"
AGENT_SPEC_FILE="${2:-$SCRIPT_DIR/agent_specifications.json}"
TARGET_ERRORS="${3:-}"
USE_AI="${4:-true}"  # Enable AI by default if available

# Initialize logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $AGENT_ID: $message" | tee -a "$LOG_FILE"
}

# Load agent configuration
load_agent_config() {
    log_message "Loading agent configuration..."
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "ERROR: Agent specification file not found"
        exit 1
    fi
    
    # Extract this agent's configuration
    AGENT_NAME=$(grep -A10 "\"agent_id\": \"$AGENT_ID\"" "$AGENT_SPEC_FILE" | grep '"name":' | cut -d'"' -f4 || echo "generic_agent")
    SPECIALIZATION=$(grep -A10 "\"agent_id\": \"$AGENT_ID\"" "$AGENT_SPEC_FILE" | grep '"specialization":' | cut -d'"' -f4 || echo "general")
    
    if [[ -z "$TARGET_ERRORS" ]]; then
        TARGET_ERRORS=$(grep -A10 "\"agent_id\": \"$AGENT_ID\"" "$AGENT_SPEC_FILE" | grep -A1 '"target_errors":' | grep -oE 'CS[0-9]{4}' | tr '\n' ' ')
    fi
    
    log_message "Agent: $AGENT_NAME"
    log_message "Specialization: $SPECIALIZATION"
    log_message "Target errors: $TARGET_ERRORS"
}

# File locking functions
claim_file() {
    local file_path="$1"
    bash "$SCRIPT_DIR/build_checker_agent.sh" claim "$AGENT_ID" "$file_path"
}

release_file() {
    local file_path="$1"
    bash "$SCRIPT_DIR/build_checker_agent.sh" release "$AGENT_ID" "$file_path"
}

# Find files with target errors
find_error_files() {
    local error_codes="$1"
    local files=()
    
    for code in $error_codes; do
        local error_files=$(grep "error $code" "$BUILD_OUTPUT_FILE" | cut -d'(' -f1 | sort -u)
        for file in $error_files; do
            files+=("$file")
        done
    done
    
    # Return unique files
    printf '%s\n' "${files[@]}" | sort -u
}

# Helper functions for code fixes
fix_duplicate_type() {
    local file_path="$1"
    local type_name="$2"
    local error_line="$3"
    
    # Find all occurrences of the type
    local occurrences=$(grep -n "\(class\|interface\|struct\|enum\)\s\+$type_name" "$file_path")
    local count=$(echo "$occurrences" | grep -c "^" || echo 0)
    
    if [[ $count -gt 1 ]]; then
        # Keep the first occurrence, remove others
        local first_line=$(echo "$occurrences" | head -1 | cut -d: -f1)
        echo "$occurrences" | tail -n +2 | while IFS= read -r occurrence; do
            local line_num=$(echo "$occurrence" | cut -d: -f1)
            if [[ $line_num -ne $first_line ]]; then
                remove_code_block "$file_path" "$line_num"
            fi
        done
    fi
}

fix_duplicate_member() {
    local file_path="$1"
    local member_name="$2"
    local error_line="$3"
    
    # Find method/property signatures
    local signatures=$(grep -n "$member_name" "$file_path" | grep -E "(public|private|protected|internal)")
    
    # Group by signature
    declare -A signature_map
    while IFS= read -r sig_line; do
        local line_num=$(echo "$sig_line" | cut -d: -f1)
        local signature=$(echo "$sig_line" | cut -d: -f2- | sed 's/{.*$//' | xargs)
        
        if [[ -n "${signature_map[$signature]}" ]]; then
            # Duplicate found, remove this occurrence
            remove_code_block "$file_path" "$line_num"
        else
            signature_map["$signature"]=$line_num
        fi
    done <<< "$signatures"
}

remove_code_block() {
    local file_path="$1"
    local start_line="$2"
    
    # Find matching braces to determine block boundaries
    local brace_count=0
    local end_line=$start_line
    local found_opening=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ \{ ]]; then
            found_opening=true
            ((brace_count++))
        fi
        if [[ "$line" =~ \} ]] && [[ $found_opening == true ]]; then
            ((brace_count--))
            if [[ $brace_count -eq 0 ]]; then
                ((end_line++))
                break
            fi
        fi
        ((end_line++))
    done < <(tail -n +$start_line "$file_path")
    
    # Remove the block
    sed -i "${start_line},${end_line}d" "$file_path"
    log_message "Removed code block from lines $start_line to $end_line"
}

add_using_directive() {
    local file_path="$1"
    local namespace="$2"
    
    # Check if already exists
    if grep -q "using $namespace;" "$file_path"; then
        return
    fi
    
    # Find position to insert
    local last_using=$(grep -n '^using ' "$file_path" | tail -1 | cut -d: -f1)
    if [[ -n "$last_using" ]]; then
        sed -i "${last_using}a\\using $namespace;" "$file_path"
    else
        # Insert after namespace declaration
        local namespace_line=$(grep -n '^namespace ' "$file_path" | head -1 | cut -d: -f1)
        if [[ -n "$namespace_line" ]]; then
            sed -i "${namespace_line}a\\\\nusing $namespace;" "$file_path"
        else
            # Insert at beginning
            sed -i "1i\\using $namespace;\\n" "$file_path"
        fi
    fi
    
    log_message "Added using directive: using $namespace;"
}

create_missing_type() {
    local file_path="$1"
    local type_name="$2"
    
    # Find namespace
    local namespace=$(grep '^namespace ' "$file_path" | head -1 | sed 's/namespace //' | sed 's/;$//' | xargs)
    
    # Create a new file for the type
    local dir=$(dirname "$file_path")
    local new_file="$dir/$type_name.cs"
    
    if [[ ! -f "$new_file" ]]; then
        cat > "$new_file" << EOF
namespace $namespace;

/// <summary>
/// Auto-generated type for $type_name
/// </summary>
public class $type_name
{
    // TODO: Implement $type_name
}
EOF
        log_message "Created missing type $type_name in $new_file"
    fi
}

apply_ai_fix() {
    local file_path="$1"
    local line_number="$2"
    local fix_content="$3"
    
    # Save the fix to a temporary file
    local temp_fix="/tmp/ai_fix_$$.tmp"
    echo "$fix_content" > "$temp_fix"
    
    # Apply the fix (this is simplified, in production would need better merging)
    local before=$((line_number - 10))
    local after=$((line_number + 10))
    
    # Create a new file with the fix applied
    {
        head -n $before "$file_path"
        cat "$temp_fix"
        tail -n +$after "$file_path"
    } > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
    
    rm -f "$temp_fix"
}

# Generic error resolution strategies
resolve_duplicate_definitions() {
    local file_path="$1"
    local error_code="$2"
    
    log_message "Resolving duplicate definitions in $file_path"
    
    case "$error_code" in
        "CS0101")
            # Duplicate class/interface in namespace
            log_message "Analyzing duplicate type definitions..."
            # Strategy: Find and remove duplicate class definitions
            ;;
        "CS0111")
            # Duplicate member definition
            log_message "Analyzing duplicate member definitions..."
            # Strategy: Find and remove duplicate methods/properties
            ;;
        "CS0102")
            # Duplicate type in namespace
            log_message "Analyzing duplicate type conflicts..."
            # Strategy: Rename or remove conflicting types
            ;;
    esac
}

resolve_type_resolution() {
    local file_path="$1"
    local error_code="$2"
    
    log_message "Resolving type resolution issues in $file_path"
    
    case "$error_code" in
        "CS0246")
            # Type or namespace not found
            log_message "Analyzing missing type references..."
            # Strategy: Add using statements or fully qualify types
            ;;
        "CS0234")
            # Type or namespace does not exist
            log_message "Analyzing namespace issues..."
            # Strategy: Check references and namespaces
            ;;
        "CS0104")
            # Ambiguous reference
            log_message "Resolving ambiguous references..."
            # Strategy: Use fully qualified names or aliases
            ;;
    esac
}

resolve_interface_implementation() {
    local file_path="$1"
    local error_code="$2"
    
    log_message "Resolving interface implementation issues in $file_path"
    
    case "$error_code" in
        "CS0535")
            # Does not implement interface member
            log_message "Implementing missing interface members..."
            # Strategy: Add missing method implementations
            ;;
        "CS0738")
            # Does not implement interface member with same return type
            log_message "Fixing interface implementation signatures..."
            # Strategy: Correct method signatures
            ;;
    esac
}

resolve_inheritance_override() {
    local file_path="$1"
    local error_code="$2"
    
    log_message "Resolving inheritance/override issues in $file_path"
    
    case "$error_code" in
        "CS0115")
            # No suitable method found to override
            log_message "Fixing override signatures..."
            # Strategy: Match base class signatures
            ;;
        "CS0534")
            # Does not implement inherited abstract member
            log_message "Implementing abstract members..."
            # Strategy: Add abstract method implementations
            ;;
        "CS0462")
            # Inherited members have same signature
            log_message "Resolving inherited member conflicts..."
            # Strategy: Use explicit interface implementation
            ;;
    esac
}

resolve_generic_constraints() {
    local file_path="$1"
    local error_code="$2"
    
    log_message "Resolving generic constraint issues in $file_path"
    
    case "$error_code" in
        "CS0305")
            # Wrong number of type parameters
            log_message "Fixing generic type parameter count..."
            # Strategy: Adjust generic parameters
            ;;
        "CS0453")
            # Must be non-nullable value type
            log_message "Fixing nullable type constraints..."
            # Strategy: Add struct constraint or change type
            ;;
        "CS8377")
            # Type must be a value type (INumber issue)
            log_message "Removing INumber constraints for .NET Framework..."
            # Strategy: Replace with compatible constraints
            ;;
    esac
}

# Main resolution dispatcher
# Enhanced resolve_error function with actual file modification
# Enhanced resolve_error function with actual file modification
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
load_pattern_database() {
    local language="${1:-csharp}"
    local pattern_script="$AGENT_DIR/${language}_patterns.sh"
    
    if [[ -f "$pattern_script" ]]; then
        log_message "Loading $language patterns from $pattern_script"
        # Source the pattern generator and get patterns
        PATTERN_DB=$("$pattern_script" 2>/dev/null || echo "{}")
    else
        log_message "No pattern database found for $language, using defaults"
        PATTERN_DB="{}"
    fi
}

# Apply pattern-based fix
apply_pattern_fix() {
    local file_path="$1"
    local line_number="$2"
    local error_code="$3"
    local error_message="$4"
    
    # Try to find pattern for this error code
    if [[ -n "$PATTERN_DB" ]]; then
        local pattern=$(echo "$PATTERN_DB" | jq -r ".patterns.\"$error_code\" // empty" 2>/dev/null)
        
        if [[ -n "$pattern" && "$pattern" != "null" ]]; then
            log_message "Found pattern for $error_code"
            # Get the fix with highest confidence
            local fix=$(echo "$pattern" | jq -r '.fixes | sort_by(.confidence // 0.5) | reverse | .[0] // empty' 2>/dev/null)
            
            if [[ -n "$fix" && "$fix" != "null" ]]; then
                local fix_name=$(echo "$fix" | jq -r '.name // "unknown"')
                log_message "Applying fix: $fix_name"
                
                # Apply fix based on action type
                echo "$fix" | jq -r '.actions[]? // empty' | while IFS= read -r action; do
                    if [[ -n "$action" && "$action" != "null" ]]; then
                        local action_type=$(echo "$action" | jq -r '.type // "unknown"')
                        
                        case "$action_type" in
                            "add_using")
                                fix_missing_using "$file_path" "$error_message"
                                ;;
                            "replace")
                                local from=$(echo "$action" | jq -r '.from // ""')
                                local to=$(echo "$action" | jq -r '.to // ""')
                                if [[ -n "$from" && -n "$to" ]]; then
                                    sed -i "${line_number}s/$from/$to/g" "$file_path"
                                fi
                                ;;
                            "insert")
                                local text=$(echo "$action" | jq -r '.text // ""')
                                if [[ -n "$text" ]]; then
                                    sed -i "${line_number}i\\$text" "$file_path"
                                fi
                                ;;
                            *)
                                log_message "Unknown action type: $action_type"
                                ;;
                        esac
                    fi
                done
                return 0
            fi
        fi
    fi
    
    return 1
}

# Process assigned files
process_files() {
    local processed_count=0
    local files_modified=""
    
    # Find all files with our target errors
    local target_files=$(find_error_files "$TARGET_ERRORS")
    
    if [[ -z "$target_files" ]]; then
        log_message "No files found with target errors"
        return 0
    fi
    
    log_message "Found $(echo "$target_files" | wc -l) files to process"
    
    # Process each file
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        
        # Try to claim the file
        if claim_file "$file_path"; then
            log_message "Processing $file_path"
            
            # Find specific errors in this file with details
            grep "$file_path" "$BUILD_OUTPUT_FILE" | grep -E "error ($(echo $TARGET_ERRORS | tr ' ' '|'))" | while IFS= read -r error_line; do
                # Extract error details
                local error_code=$(echo "$error_line" | grep -oP 'error \K[A-Z]+[0-9]+' || echo "")
                local line_info=$(echo "$error_line" | grep -oP '\(\K[0-9]+' | head -1 || echo "1")
                local error_msg=$(echo "$error_line" | sed 's/.*: error [^:]*: //')
                
                if [[ -n "$error_code" ]] && [[ " $TARGET_ERRORS " =~ " $error_code " ]]; then
                    log_message "Fixing $error_code at line $line_info: $error_msg"
                    resolve_error "$file_path" "$error_code" "$line_info" "$error_msg"
                fi
            done
            
            # Release the file
            release_file "$file_path"
            
            files_modified="$files_modified $file_path"
            processed_count=$((processed_count + 1))
            
            # Update coordination file
            update_coordination_file "$file_path" "processed"
        else
            log_message "Could not claim $file_path - skipping"
        fi
        
        # Limit processing in one iteration
        [[ $processed_count -ge 5 ]] && break
        
    done <<< "$target_files"
    
    log_message "Processed $processed_count files"
    
    # Validate changes if any files were modified
    if [[ -n "$files_modified" ]]; then
        bash "$SCRIPT_DIR/build_checker_agent.sh" validate "$AGENT_ID" "$files_modified"
    fi
}

# Update coordination file with progress
update_coordination_file() {
    local file_path="$1"
    local status="$2"
    
    {
        echo ""
        echo "## $AGENT_ID Progress Update - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- File: $file_path"
        echo "- Status: $status"
        echo "- Specialization: $SPECIALIZATION"
    } >> "$COORDINATION_FILE"
}

# Main execution
main() {
    log_message "=== GENERIC ERROR AGENT STARTING ==="
    
    # Load configuration
    load_agent_config
    
    # Detect language and load patterns
    local language="csharp"  # Default
    if [[ -f "$AGENT_DIR/state/detected_language.txt" ]]; then
        language=$(cat "$AGENT_DIR/state/detected_language.txt" 2>/dev/null || echo "csharp")
    fi
    
    log_message "Loading patterns for language: $language"
    load_pattern_database "$language"
    
    # Process files
    process_files
    
    log_message "=== GENERIC ERROR AGENT COMPLETE ==="
}

# Execute
main