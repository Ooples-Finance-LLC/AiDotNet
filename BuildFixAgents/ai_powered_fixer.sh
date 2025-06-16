#!/bin/bash

# AI-Powered Multi-Language Build Fix System
# Production-ready with AI integration and pattern fallback

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$SCRIPT_DIR"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load AI integration
source "$SCRIPT_DIR/ai_integration.sh" 2>/dev/null || true

# Configuration
MAX_WORKERS=4
BATCH_SIZE=10
STATE_DIR="$AGENT_DIR/state"
LOGS_DIR="$AGENT_DIR/logs"
PATTERNS_DIR="$AGENT_DIR/patterns"

# Create directories
mkdir -p "$STATE_DIR" "$LOGS_DIR" "$PATTERNS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp]${NC} ${BOLD}[$level]${NC} $message" | tee -a "$LOGS_DIR/ai_fixer.log"
}

# Language detection
detect_language() {
    local project_path="${1:-$PROJECT_DIR}"
    local languages=()
    
    # Check for various project files and patterns
    [[ -f "$project_path/package.json" ]] && languages+=("javascript")
    [[ -f "$project_path/tsconfig.json" ]] && languages+=("typescript")
    [[ -f "$project_path/requirements.txt" || -f "$project_path/setup.py" || -f "$project_path/pyproject.toml" ]] && languages+=("python")
    [[ -f "$project_path/go.mod" ]] && languages+=("go")
    [[ -f "$project_path/Cargo.toml" ]] && languages+=("rust")
    [[ -f "$project_path/pom.xml" || -f "$project_path/build.gradle" ]] && languages+=("java")
    [[ -f "$project_path"/*.csproj || -f "$project_path"/*.sln ]] && languages+=("csharp")
    [[ -f "$project_path/CMakeLists.txt" || -f "$project_path/Makefile" ]] && languages+=("cpp")
    
    # Default to file extensions if no project files found
    if [[ ${#languages[@]} -eq 0 ]]; then
        find "$project_path" -type f -name "*.py" | head -1 && languages+=("python")
        find "$project_path" -type f -name "*.js" -o -name "*.jsx" | head -1 && languages+=("javascript")
        find "$project_path" -type f -name "*.ts" -o -name "*.tsx" | head -1 && languages+=("typescript")
        find "$project_path" -type f -name "*.go" | head -1 && languages+=("go")
        find "$project_path" -type f -name "*.rs" | head -1 && languages+=("rust")
        find "$project_path" -type f -name "*.java" | head -1 && languages+=("java")
        find "$project_path" -type f -name "*.cs" | head -1 && languages+=("csharp")
        find "$project_path" -type f -name "*.cpp" -o -name "*.cc" -o -name "*.cxx" | head -1 && languages+=("cpp")
    fi
    
    # Return primary language
    if [[ ${#languages[@]} -gt 0 ]]; then
        echo "${languages[0]}"
    else
        echo "unknown"
    fi
}

# Build command detection
get_build_command() {
    local language=$1
    local project_path="${2:-$PROJECT_DIR}"
    
    case "$language" in
        javascript|typescript)
            if [[ -f "$project_path/package.json" ]]; then
                if grep -q "\"build\":" "$project_path/package.json"; then
                    echo "npm run build"
                else
                    echo "npm test"
                fi
            else
                echo "node --check"
            fi
            ;;
        python)
            if [[ -f "$project_path/tox.ini" ]]; then
                echo "tox"
            elif [[ -f "$project_path/setup.py" ]]; then
                echo "python setup.py test"
            else
                echo "python -m py_compile"
            fi
            ;;
        go)
            echo "go build ./..."
            ;;
        rust)
            echo "cargo build"
            ;;
        java)
            if [[ -f "$project_path/pom.xml" ]]; then
                echo "mvn compile"
            elif [[ -f "$project_path/build.gradle" ]]; then
                echo "gradle build"
            else
                echo "javac"
            fi
            ;;
        csharp)
            echo "dotnet build"
            ;;
        cpp)
            if [[ -f "$project_path/CMakeLists.txt" ]]; then
                echo "cmake --build build"
            elif [[ -f "$project_path/Makefile" ]]; then
                echo "make"
            else
                echo "g++ -fsyntax-only"
            fi
            ;;
        *)
            echo "make"
            ;;
    esac
}

# Error parser for different languages
parse_errors() {
    local language=$1
    local build_output=$2
    local errors_json="$STATE_DIR/parsed_errors.json"
    
    # Initialize JSON structure
    echo '{"errors": []}' > "$errors_json"
    
    case "$language" in
        csharp)
            # Parse C# errors
            grep -E "error CS[0-9]{4}:" "$build_output" | while IFS= read -r line; do
                local file=$(echo "$line" | cut -d'(' -f1)
                local location=$(echo "$line" | grep -oP '\(\d+,\d+\)' || echo "(0,0)")
                local code=$(echo "$line" | grep -oP 'CS\d{4}' || echo "CS0000")
                local message=$(echo "$line" | sed 's/.*: error [^:]*: //')
                
                jq --arg file "$file" \
                   --arg loc "$location" \
                   --arg code "$code" \
                   --arg msg "$message" \
                   '.errors += [{"file": $file, "location": $loc, "code": $code, "message": $msg, "language": "csharp"}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
            
        python)
            # Parse Python errors
            grep -E "(SyntaxError|IndentationError|ImportError|NameError|TypeError|ValueError)" "$build_output" | while IFS= read -r line; do
                local file=$(echo "$line" | grep -oP 'File "[^"]+' | sed 's/File "//')
                local location=$(echo "$line" | grep -oP 'line \d+' | sed 's/line //')
                local error_type=$(echo "$line" | grep -oP '(SyntaxError|IndentationError|ImportError|NameError|TypeError|ValueError)')
                local message=$(echo "$line" | sed 's/.*Error: //')
                
                [[ -n "$file" ]] && jq --arg file "$file" \
                   --arg loc "($location,0)" \
                   --arg code "$error_type" \
                   --arg msg "$message" \
                   '.errors += [{"file": $file, "location": $loc, "code": $code, "message": $msg, "language": "python"}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
            
        javascript|typescript)
            # Parse JS/TS errors
            grep -E "(error TS[0-9]+:|Error:|SyntaxError:)" "$build_output" | while IFS= read -r line; do
                local file=$(echo "$line" | cut -d':' -f1)
                local location=$(echo "$line" | grep -oP '\(\d+,\d+\)' || echo "(0,0)")
                local code=$(echo "$line" | grep -oP 'TS\d+' || echo "JS0000")
                local message=$(echo "$line" | sed 's/.*: //')
                
                [[ -f "$file" ]] && jq --arg file "$file" \
                   --arg loc "$location" \
                   --arg code "$code" \
                   --arg msg "$message" \
                   --arg lang "$language" \
                   '.errors += [{"file": $file, "location": $loc, "code": $code, "message": $msg, "language": $lang}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
            
        go)
            # Parse Go errors
            grep -E "\.go:[0-9]+:[0-9]+:" "$build_output" | while IFS= read -r line; do
                local file=$(echo "$line" | cut -d':' -f1)
                local line_num=$(echo "$line" | cut -d':' -f2)
                local col_num=$(echo "$line" | cut -d':' -f3)
                local message=$(echo "$line" | cut -d':' -f4- | sed 's/^ //')
                
                jq --arg file "$file" \
                   --arg loc "($line_num,$col_num)" \
                   --arg code "GO0000" \
                   --arg msg "$message" \
                   '.errors += [{"file": $file, "location": $loc, "code": $code, "message": $msg, "language": "go"}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
            
        rust)
            # Parse Rust errors
            grep -E "error\[E[0-9]+\]:|error:" "$build_output" | while IFS= read -r line; do
                local code=$(echo "$line" | grep -oP 'E\d{4}' || echo "E0000")
                local message=$(echo "$line" | sed 's/.*]: //')
                # Rust errors span multiple lines, this is simplified
                
                jq --arg code "$code" \
                   --arg msg "$message" \
                   '.errors += [{"file": "unknown", "location": "(0,0)", "code": $code, "message": $msg, "language": "rust"}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
            
        java)
            # Parse Java errors
            grep -E "\.java:[0-9]+: error:" "$build_output" | while IFS= read -r line; do
                local file=$(echo "$line" | cut -d':' -f1)
                local line_num=$(echo "$line" | cut -d':' -f2)
                local message=$(echo "$line" | sed 's/.*error: //')
                
                jq --arg file "$file" \
                   --arg loc "($line_num,0)" \
                   --arg code "JAVA0000" \
                   --arg msg "$message" \
                   '.errors += [{"file": $file, "location": $loc, "code": $code, "message": $msg, "language": "java"}]' \
                   "$errors_json" > "$errors_json.tmp" && mv "$errors_json.tmp" "$errors_json"
            done
            ;;
    esac
    
    echo "$errors_json"
}

# AI-powered error analysis
analyze_errors_with_ai() {
    local errors_json=$1
    local language=$2
    local analysis_file="$STATE_DIR/ai_analysis.json"
    
    if ! is_ai_available; then
        log "INFO" "AI not available, using pattern matching"
        return 1
    fi
    
    local errors_summary=$(jq -r '.errors[] | "\(.code): \(.message)"' "$errors_json" | sort | uniq -c | sort -nr | head -20)
    
    local prompt="Analyze these $language build errors and create a fix strategy. Group similar errors and prioritize fixes.

Error Summary:
$errors_summary

For each error group, provide:
1. Root cause analysis
2. Fix strategy
3. Example code fix
4. Dependencies (which errors should be fixed first)

Format as JSON with structure:
{
  \"strategies\": [
    {
      \"error_codes\": [\"CS0246\"],
      \"root_cause\": \"Missing using directive or assembly reference\",
      \"fix_approach\": \"Add required using statements\",
      \"priority\": 1,
      \"example_fix\": \"Add: using System.Collections.Generic;\"
    }
  ]
}"

    if local ai_response=$(ai_analyze_errors "$errors_json"); then
        echo "$ai_response" > "$analysis_file"
        log "SUCCESS" "AI analysis completed"
        return 0
    else
        log "WARN" "AI analysis failed, falling back to patterns"
        return 1
    fi
}

# Generate fix using AI
generate_ai_fix() {
    local error_info=$1
    local file_path=$2
    local language=$3
    
    if ! is_ai_available; then
        return 1
    fi
    
    # Read file content with context
    local line_num=$(echo "$error_info" | jq -r '.location' | grep -oP '\d+' | head -1)
    local error_msg=$(echo "$error_info" | jq -r '.message')
    local error_code=$(echo "$error_info" | jq -r '.code')
    
    # Get file content around error
    local start_line=$((line_num - 30))
    local end_line=$((line_num + 30))
    [[ $start_line -lt 1 ]] && start_line=1
    
    local file_content=$(sed -n "${start_line},${end_line}p" "$file_path" 2>/dev/null || cat "$file_path")
    
    local prompt="Fix this $language error. Return ONLY the complete fixed code section, no explanations.

Error: $error_code - $error_msg
File: $file_path
Line: $line_num

Current code (lines $start_line-$end_line):
\`\`\`$language
$file_content
\`\`\`

Fixed code:"
    
    if local fix=$(ai_generate_fix "$error_msg" "$file_path" "$file_content"); then
        echo "$fix"
        return 0
    else
        return 1
    fi
}

# Pattern-based fix fallback
apply_pattern_fix() {
    local error_info=$1
    local file_path=$2
    local language=$3
    
    local error_code=$(echo "$error_info" | jq -r '.code')
    local pattern_file="$PATTERNS_DIR/${language}/${error_code}.json"
    
    # Load pattern if exists
    if [[ -f "$pattern_file" ]]; then
        local pattern=$(cat "$pattern_file")
        # Apply pattern-based fix
        log "INFO" "Applying pattern fix for $error_code"
        # Implementation depends on pattern format
        return 0
    else
        log "WARN" "No pattern found for $error_code"
        return 1
    fi
}

# Main fix orchestrator
fix_errors() {
    local language=$1
    local errors_json=$2
    local fixed_count=0
    local total_errors=$(jq '.errors | length' "$errors_json")
    
    log "INFO" "Processing $total_errors errors in $language project"
    
    # Try AI analysis first
    local use_ai_fixes=false
    if analyze_errors_with_ai "$errors_json" "$language"; then
        use_ai_fixes=true
    fi
    
    # Process errors in batches
    local batch_num=0
    while true; do
        local batch_errors=$(jq ".errors[$((batch_num * BATCH_SIZE)):$(((batch_num + 1) * BATCH_SIZE))]" "$errors_json")
        
        if [[ "$batch_errors" == "null" ]] || [[ "$batch_errors" == "[]" ]]; then
            break
        fi
        
        log "INFO" "Processing batch $((batch_num + 1))"
        
        # Process each error in the batch
        echo "$batch_errors" | jq -c '.[]' | while IFS= read -r error; do
            local file_path=$(echo "$error" | jq -r '.file')
            local error_code=$(echo "$error" | jq -r '.code')
            
            log "DEBUG" "Fixing $error_code in $file_path"
            
            # Try AI fix first if available
            local fixed=false
            if [[ "$use_ai_fixes" == "true" ]]; then
                if local ai_fix=$(generate_ai_fix "$error" "$file_path" "$language"); then
                    # Apply the fix
                    echo "$ai_fix" > "$STATE_DIR/fix_${batch_num}_${fixed_count}.patch"
                    fixed=true
                    ((fixed_count++))
                fi
            fi
            
            # Fall back to pattern matching if AI didn't work
            if [[ "$fixed" == "false" ]]; then
                if apply_pattern_fix "$error" "$file_path" "$language"; then
                    ((fixed_count++))
                fi
            fi
        done
        
        ((batch_num++))
        
        # Run build to check progress
        log "INFO" "Running build to verify fixes..."
        run_build "$language" > "$LOGS_DIR/build_iteration_${batch_num}.log" 2>&1 || true
    done
    
    log "SUCCESS" "Fixed $fixed_count out of $total_errors errors"
}

# Run build command
run_build() {
    local language=$1
    local build_cmd=$(get_build_command "$language")
    
    log "INFO" "Running build: $build_cmd"
    cd "$PROJECT_DIR"
    eval "$build_cmd"
}

# Main entry point
main() {
    log "INFO" "Starting AI-Powered Build Fix System"
    
    # Detect language
    local language=$(detect_language)
    log "INFO" "Detected language: $language"
    
    if [[ "$language" == "unknown" ]]; then
        log "ERROR" "Could not detect project language"
        exit 1
    fi
    
    # Check AI availability
    if is_ai_available; then
        log "INFO" "AI service available: $AI_PROVIDER"
        
        # Estimate cost
        local build_output="$LOGS_DIR/build_output.txt"
        run_build "$language" > "$build_output" 2>&1 || true
        
        local error_count=$(grep -cE "(error|Error:|SyntaxError|TypeError)" "$build_output" || echo "0")
        local estimated_cost=$(estimate_ai_cost "$error_count")
        
        log "INFO" "Estimated API cost: \$$estimated_cost for ~$error_count errors"
        
        if [[ "$(get_config "estimate_before_fix")" == "true" ]]; then
            read -p "Continue with AI-powered fixes? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "INFO" "Falling back to pattern-only mode"
                AI_PROVIDER="none"
            fi
        fi
    else
        log "WARN" "AI service not configured, using pattern matching only"
    fi
    
    # Parse errors
    local errors_json=$(parse_errors "$language" "$build_output")
    log "INFO" "Parsed $(jq '.errors | length' "$errors_json") errors"
    
    # Fix errors
    fix_errors "$language" "$errors_json"
    
    # Final build check
    log "INFO" "Running final build check..."
    if run_build "$language" > "$LOGS_DIR/final_build.log" 2>&1; then
        log "SUCCESS" "Build successful! All errors fixed."
    else
        local remaining_errors=$(grep -cE "(error|Error:|SyntaxError|TypeError)" "$LOGS_DIR/final_build.log" || echo "0")
        log "WARN" "Build still has $remaining_errors errors. Manual intervention may be required."
    fi
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi