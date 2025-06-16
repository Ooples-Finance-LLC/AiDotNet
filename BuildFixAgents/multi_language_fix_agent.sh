#!/bin/bash

# Multi-Language Fix Agent - Handles error fixing for multiple programming languages
# Extends the existing agent system to support TypeScript, JavaScript, Python, Java, Go, and Rust

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

# Source common functions
source "$AGENT_DIR/generic_agent_coordinator.sh" 2>/dev/null || true

# Global pattern database
PATTERN_DB=""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load pattern database based on language
load_pattern_database() {
    local language="$1"
    local pattern_script="$AGENT_DIR/${language}_patterns.sh"
    
    if [[ -f "$pattern_script" ]]; then
        echo -e "${BLUE}Loading $language patterns...${NC}" >&2
        PATTERN_DB=$("$pattern_script" 2>/dev/null || echo "{}")
    else
        echo -e "${YELLOW}No pattern database found for $language${NC}" >&2
        PATTERN_DB="{}"
    fi
}

# Apply pattern-based fix
apply_pattern_fix() {
    local file_path="$1"
    local line_number="$2"
    local error_code="$3"
    local error_message="$4"
    local language="$5"
    
    # Load patterns if not already loaded
    if [[ -z "$PATTERN_DB" ]]; then
        load_pattern_database "$language"
    fi
    
    # Extract pattern for this error
    local pattern=$(echo "$PATTERN_DB" | jq -r ".patterns.\"$error_code\" // empty" 2>/dev/null)
    
    if [[ -n "$pattern" && "$pattern" != "null" ]]; then
        echo -e "${GREEN}Found pattern for $error_code${NC}" >&2
        
        # Get the fix with highest confidence
        local fix=$(echo "$pattern" | jq -r '.fixes | sort_by(.confidence // 0.5) | reverse | .[0] // empty' 2>/dev/null)
        
        if [[ -n "$fix" && "$fix" != "null" ]]; then
            local fix_name=$(echo "$fix" | jq -r '.name // "unknown"')
            echo -e "${BLUE}Applying fix: $fix_name${NC}" >&2
            
            # Apply fix actions
            echo "$fix" | jq -r '.actions[]? // empty' | while IFS= read -r action; do
                if [[ -n "$action" && "$action" != "null" ]]; then
                    apply_fix_action "$file_path" "$line_number" "$action"
                fi
            done
            
            return 0
        fi
    fi
    
    return 1
}

# Apply a single fix action
apply_fix_action() {
    local file_path="$1"
    local line_number="$2"
    local action="$3"
    
    local action_type=$(echo "$action" | jq -r '.type // "unknown"')
    
    case "$action_type" in
        "replace")
            local from=$(echo "$action" | jq -r '.from // ""')
            local to=$(echo "$action" | jq -r '.to // ""')
            if [[ -n "$from" && -n "$to" ]]; then
                sed -i "s/$from/$to/g" "$file_path"
            fi
            ;;
        "insert")
            local text=$(echo "$action" | jq -r '.text // ""')
            if [[ -n "$text" ]]; then
                sed -i "${line_number}i\\$text" "$file_path"
            fi
            ;;
        "add_import"|"add_using")
            # Language-specific import handling
            local import_text=$(echo "$action" | jq -r '.text // ""')
            if [[ -n "$import_text" ]]; then
                # Add at the beginning of the file after existing imports
                sed -i "1i\\$import_text" "$file_path"
            fi
            ;;
        *)
            echo -e "${YELLOW}Unknown action type: $action_type${NC}" >&2
            ;;
    esac
}

# Language-specific fix strategies
declare -A FIX_STRATEGIES

# TypeScript/JavaScript common fixes
FIX_STRATEGIES["typescript_missing_import"]='
fix_typescript_missing_import() {
    local file="$1"
    local missing_type="$2"
    
    # Common imports
    case "$missing_type" in
        "React")
            sed -i "1i import React from '\''react'\'';" "$file"
            ;;
        "Component")
            sed -i "1i import { Component } from '\''react'\'';" "$file"
            ;;
        *)
            # Try to find the type in node_modules
            local import_path=$(find node_modules -name "*.d.ts" -exec grep -l "export.*$missing_type" {} \; | head -1)
            if [[ -n "$import_path" ]]; then
                local module_name=$(echo "$import_path" | sed "s|node_modules/||" | sed "s|/.*||")
                sed -i "1i import { $missing_type } from '\''$module_name'\'';" "$file"
            fi
            ;;
    esac
}
'

FIX_STRATEGIES["python_import_error"]='
fix_python_import_error() {
    local file="$1"
    local module="$2"
    
    # Common fixes
    case "$module" in
        "numpy"|"pandas"|"requests"|"flask"|"django")
            echo "# Install with: pip install $module" >> "$file.fix_notes"
            ;;
        *)
            # Check if module exists in project
            if find . -name "${module}.py" | grep -q .; then
                # Add relative import
                sed -i "1i from . import $module" "$file"
            fi
            ;;
    esac
}
'

FIX_STRATEGIES["java_symbol_not_found"]='
fix_java_symbol_not_found() {
    local file="$1"
    local symbol="$2"
    
    # Common Java imports
    case "$symbol" in
        "List"|"ArrayList"|"Map"|"HashMap")
            sed -i "1i import java.util.$symbol;" "$file"
            ;;
        "IOException"|"File")
            sed -i "1i import java.io.$symbol;" "$file"
            ;;
        *)
            # Search in project
            local import=$(grep -r "class $symbol" --include="*.java" . | head -1 | sed "s|^\./||" | sed "s|\.java:.*||" | tr "/" ".")
            if [[ -n "$import" ]]; then
                sed -i "1i import $import.$symbol;" "$file"
            fi
            ;;
    esac
}
'

# Initialize fix strategies
eval "${FIX_STRATEGIES["typescript_missing_import"]}"
eval "${FIX_STRATEGIES["python_import_error"]}"
eval "${FIX_STRATEGIES["java_symbol_not_found"]}"

# Language-specific error handlers
handle_typescript_error() {
    local error_file="$1"
    local error_line="$2"
    local error_code="$3"
    local error_message="$4"
    
    echo -e "${CYAN}Handling TypeScript error $error_code in $error_file:$error_line${NC}"
    
    case "$error_code" in
        "TS2304") # Cannot find name
            local missing_name=$(echo "$error_message" | grep -oP "Cannot find name '\''\\K[^'\'']+")
            fix_typescript_missing_import "$error_file" "$missing_name"
            ;;
        "TS2307") # Cannot find module
            local module=$(echo "$error_message" | grep -oP "Cannot find module '\''\\K[^'\'']+")
            echo "npm install $module" >> "$AGENT_DIR/state/npm_install_queue.txt"
            ;;
        "TS2339") # Property does not exist
            echo "// TODO: Add property or type definition" >> "$error_file.todo"
            ;;
        *)
            echo -e "${YELLOW}Unknown TypeScript error: $error_code${NC}"
            ;;
    esac
}

handle_python_error() {
    local error_file="$1"
    local error_line="$2"
    local error_type="$3"
    local error_message="$4"
    
    echo -e "${CYAN}Handling Python error in $error_file:$error_line${NC}"
    
    case "$error_type" in
        "ImportError"|"ModuleNotFoundError")
            local module=$(echo "$error_message" | grep -oP "No module named '\''\\K[^'\'']+")
            fix_python_import_error "$error_file" "$module"
            ;;
        "NameError")
            local name=$(echo "$error_message" | grep -oP "name '\''\\K[^'\'']+")
            echo "# TODO: Define '$name' or import it" >> "$error_file.todo"
            ;;
        "SyntaxError")
            echo -e "${YELLOW}Syntax error requires manual fix${NC}"
            ;;
        *)
            echo -e "${YELLOW}Unknown Python error: $error_type${NC}"
            ;;
    esac
}

handle_java_error() {
    local error_file="$1"
    local error_line="$2"
    local error_code="$3"
    local error_message="$4"
    
    echo -e "${CYAN}Handling Java error in $error_file:$error_line${NC}"
    
    if [[ "$error_message" =~ "cannot find symbol" ]]; then
        local symbol=$(echo "$error_message" | grep -oP "symbol:\\s*class\\s*\\K\\w+")
        if [[ -n "$symbol" ]]; then
            fix_java_symbol_not_found "$error_file" "$symbol"
        fi
    elif [[ "$error_message" =~ "package.*does not exist" ]]; then
        local package=$(echo "$error_message" | grep -oP "package\\s+\\K[^\\s]+")
        echo "// TODO: Add dependency for package: $package" >> "$error_file.todo"
    fi
}

# Generic language error handler
handle_language_error() {
    local language="$1"
    local error_file="$2"
    local error_line="$3"
    local error_code="$4"
    local error_message="$5"
    
    # Convert language to lowercase for pattern matching
    local lang_lower=$(echo "$language" | tr '[:upper:]' '[:lower:]')
    
    # First try pattern-based fix
    if apply_pattern_fix "$error_file" "$error_line" "$error_code" "$error_message" "$lang_lower"; then
        echo -e "${GREEN}Successfully applied pattern-based fix for $error_code${NC}"
        return 0
    fi
    
    # Fall back to language-specific handlers
    case "$language" in
        "TYPESCRIPT")
            handle_typescript_error "$error_file" "$error_line" "$error_code" "$error_message"
            ;;
        "JAVASCRIPT")
            handle_typescript_error "$error_file" "$error_line" "$error_code" "$error_message"  # Similar handling
            ;;
        "PYTHON")
            handle_python_error "$error_file" "$error_line" "$error_code" "$error_message"
            ;;
        "JAVA")
            handle_java_error "$error_file" "$error_line" "$error_code" "$error_message"
            ;;
        "GO")
            # Pattern-based fixes are already tried above
            echo -e "${YELLOW}No handler for Go error $error_code${NC}"
            ;;
        "RUST")
            # Pattern-based fixes are already tried above
            echo -e "${YELLOW}No handler for Rust error $error_code${NC}"
            ;;
        "CSHARP")
            # Fallback to existing C# agent if patterns didn't work
            "$AGENT_DIR/generic_error_agent.sh" "$error_code"
            ;;
        *)
            echo -e "${RED}Unknown language: $language${NC}"
            ;;
    esac
}

# Process errors from all languages
process_multi_language_errors() {
    local error_files=("$AGENT_DIR/state/build_errors_"*.json)
    
    for error_file in "${error_files[@]}"; do
        [[ ! -f "$error_file" ]] && continue
        
        echo -e "${BLUE}Processing errors from: $error_file${NC}"
        
        # Parse JSON and handle each error
        jq -r '.[] | "\(.language)|\(.file)|\(.line)|\(.code)|\(.message)"' "$error_file" | while IFS='|' read -r lang file line code message; do
            handle_language_error "$lang" "$file" "$line" "$code" "$message"
        done
    done
}

# Run post-fix actions
run_post_fix_actions() {
    # Install npm packages if needed
    if [[ -f "$AGENT_DIR/state/npm_install_queue.txt" ]]; then
        echo -e "${BLUE}Installing required npm packages...${NC}"
        sort -u "$AGENT_DIR/state/npm_install_queue.txt" | while read -r package; do
            echo "npm install $package"
            cd "$PROJECT_DIR" && npm install "$package" || true
        done
        rm -f "$AGENT_DIR/state/npm_install_queue.txt"
    fi
    
    # Show TODO items
    local todo_files=$(find "$PROJECT_DIR" -name "*.todo" -type f 2>/dev/null)
    if [[ -n "$todo_files" ]]; then
        echo -e "${YELLOW}Manual fixes required:${NC}"
        cat $todo_files
    fi
}

# Main execution
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Multi-Language Fix Agent v1.0        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    
    # Detect and build
    "$AGENT_DIR/language_detector.sh" build "$PROJECT_DIR"
    
    # Process errors
    process_multi_language_errors
    
    # Run post-fix actions
    run_post_fix_actions
    
    # Re-run build to check if errors are fixed
    echo -e "\n${BLUE}Re-running build to verify fixes...${NC}"
    "$AGENT_DIR/language_detector.sh" build "$PROJECT_DIR"
    
    echo -e "\n${GREEN}Multi-language fix process completed!${NC}"
}

# Execute
main "$@"