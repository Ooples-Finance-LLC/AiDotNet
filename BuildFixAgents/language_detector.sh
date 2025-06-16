#!/bin/bash

# Language Detector - Detects programming language and routes to appropriate parser
# Part of the Multi-Language Support System

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Supported languages and their build tools
declare -A LANGUAGE_PATTERNS=(
    ["csharp"]="*.csproj|*.cs|*.sln"
    ["typescript"]="tsconfig.json|*.ts|*.tsx"
    ["javascript"]="package.json|*.js|*.jsx"
    ["python"]="requirements.txt|setup.py|*.py|pyproject.toml"
    ["java"]="pom.xml|build.gradle|*.java"
    ["go"]="go.mod|*.go"
    ["rust"]="Cargo.toml|*.rs"
)

declare -A BUILD_COMMANDS=(
    ["csharp"]="dotnet build"
    ["typescript"]="npm run build || npx tsc"
    ["javascript"]="npm run build || npm test"
    ["python"]="python -m py_compile"
    ["java"]="mvn compile || gradle build"
    ["go"]="go build"
    ["rust"]="cargo build"
)

declare -A ERROR_PARSERS=(
    ["csharp"]="parse_csharp_errors"
    ["typescript"]="parse_typescript_errors"
    ["javascript"]="parse_javascript_errors"
    ["python"]="parse_python_errors"
    ["java"]="parse_java_errors"
    ["go"]="parse_go_errors"
    ["rust"]="parse_rust_errors"
)

# Detect project language
detect_language() {
    local detected=""
    local confidence=0
    
    echo -e "${BLUE}Detecting project language in: $PROJECT_DIR${NC}" >&2
    
    # Debug: Check if arrays are populated
    if [[ ${#LANGUAGE_PATTERNS[@]} -eq 0 ]]; then
        echo -e "${RED}ERROR: LANGUAGE_PATTERNS array is empty${NC}" >&2
        return 1
    fi
    
    for lang in "${!LANGUAGE_PATTERNS[@]}"; do
        local patterns="${LANGUAGE_PATTERNS[$lang]}"
        local count=0
        
        IFS='|' read -ra PATTERN_ARRAY <<< "$patterns"
        for pattern in "${PATTERN_ARRAY[@]}"; do
            # Use PROJECT_DIR directly with depth limit
            if timeout 2s find "$PROJECT_DIR" -maxdepth 3 -name "$pattern" -type f 2>/dev/null | head -1 | grep -q .; then
                ((count++))
            fi
        done
        
        if [[ $count -gt $confidence ]]; then
            confidence=$count
            detected=$lang
        fi
    done
    
    if [[ -n "$detected" ]]; then
        echo -e "${GREEN}Detected language: $detected (confidence: $confidence)${NC}" >&2
        # Save detected language for other scripts
        mkdir -p "$AGENT_DIR/state"
        echo "$detected" > "$AGENT_DIR/state/detected_language.txt"
        echo "$detected"
    else
        echo -e "${RED}Could not detect project language${NC}" >&2
        echo ""
        return 1
    fi
}

# Parse C# errors (existing functionality)
parse_csharp_errors() {
    local output="$1"
    echo "$output" | grep -E "error CS[0-9]+" | while read -r line; do
        local file=$(echo "$line" | grep -oP '^[^(]+(?=\()')
        local line_num=$(echo "$line" | grep -oP '\(\K[0-9]+(?=,)')
        local error_code=$(echo "$line" | grep -oP 'CS[0-9]+')
        local message=$(echo "$line" | sed 's/.*: error [^:]*: //')
        
        echo "CSHARP|$file|$line_num|$error_code|$message"
    done
}

# Parse TypeScript errors
parse_typescript_errors() {
    local output="$1"
    echo "$output" | grep -E "error TS[0-9]+:|\.ts.*:[0-9]+:[0-9]+ - error" | while read -r line; do
        if [[ "$line" =~ (.+\.tsx?).*:([0-9]+):([0-9]+).*error.*TS([0-9]+):(.+) ]]; then
            local file="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local error_code="TS${BASH_REMATCH[4]}"
            local message="${BASH_REMATCH[5]}"
            
            echo "TYPESCRIPT|$file|$line_num|$error_code|$message"
        fi
    done
}

# Parse JavaScript errors
parse_javascript_errors() {
    local output="$1"
    # ESLint format
    echo "$output" | grep -E ":[0-9]+:[0-9]+ error" | while read -r line; do
        if [[ "$line" =~ (.+\.jsx?):([0-9]+):([0-9]+).*error.*(.+) ]]; then
            local file="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[4]}"
            
            echo "JAVASCRIPT|$file|$line_num|ESLINT|$message"
        fi
    done
}

# Parse Python errors
parse_python_errors() {
    local output="$1"
    # Python compile errors
    echo "$output" | grep -E "File.*line [0-9]+" -A 2 | while read -r line; do
        if [[ "$line" =~ File[[:space:]]\"([^\"]+)\",.*line[[:space:]]([0-9]+) ]]; then
            local file="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            read -r error_type
            read -r message
            
            echo "PYTHON|$file|$line_num|$error_type|$message"
        fi
    done
}

# Parse Java errors
parse_java_errors() {
    local output="$1"
    echo "$output" | grep -E "\.java:[0-9]+: error:" | while read -r line; do
        if [[ "$line" =~ (.+\.java):([0-9]+):.*error:(.+) ]]; then
            local file="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[3]}"
            
            echo "JAVA|$file|$line_num|JAVAC|$message"
        fi
    done
}

# Parse Go errors
parse_go_errors() {
    local output="$1"
    echo "$output" | grep -E "\.go:[0-9]+:[0-9]+:" | while read -r line; do
        if [[ "$line" =~ (.+\.go):([0-9]+):([0-9]+):(.+) ]]; then
            local file="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[4]}"
            
            echo "GO|$file|$line_num|GOERR|$message"
        fi
    done
}

# Parse Rust errors
parse_rust_errors() {
    local output="$1"
    echo "$output" | grep -E "error\[E[0-9]+\]|error:" | while read -r line; do
        if [[ "$line" =~ error\[E([0-9]+)\]:(.+) ]]; then
            local error_code="E${BASH_REMATCH[1]}"
            local message="${BASH_REMATCH[2]}"
            
            # Try to find file location in next lines
            echo "RUST|unknown|0|$error_code|$message"
        fi
    done
}

# Run build and parse errors
run_language_build() {
    local lang="$1"
    local build_cmd="${BUILD_COMMANDS[$lang]}"
    local parser="${ERROR_PARSERS[$lang]}"
    
    echo -e "${BLUE}Running $lang build: $build_cmd${NC}"
    
    cd "$PROJECT_DIR"
    local output=$($build_cmd 2>&1 || true)
    
    # Parse errors using language-specific parser
    local errors=$($parser "$output")
    
    # Save to unified format
    local error_file="$AGENT_DIR/state/build_errors_${lang}.json"
    mkdir -p "$AGENT_DIR/state"
    
    echo "[" > "$error_file"
    local first=true
    echo "$errors" | while IFS='|' read -r lang file line code message; do
        [[ -z "$lang" ]] && continue
        
        [[ "$first" == "true" ]] && first=false || echo ","
        cat << EOF
{
    "language": "$lang",
    "file": "$file",
    "line": $line,
    "code": "$code",
    "message": "$message",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    done >> "$error_file"
    echo "]" >> "$error_file"
    
    echo -e "${GREEN}Errors saved to: $error_file${NC}"
    echo "$errors"
}

# Main execution
main() {
    local lang="${2:-}"
    
    if [[ -z "$lang" ]]; then
        lang=$(detect_language)
    fi
    
    if [[ -z "$lang" ]]; then
        echo -e "${RED}Failed to detect language${NC}"
        exit 1
    fi
    
    # Check if language is supported
    if [[ -z "${BUILD_COMMANDS[$lang]:-}" ]]; then
        echo -e "${YELLOW}Language '$lang' not yet supported${NC}"
        exit 1
    fi
    
    # Run build and parse errors
    run_language_build "$lang"
}

# Main function for build command
main() {
    local lang=$(detect_language)
    if [[ -n "$lang" ]]; then
        run_language_build "$lang"
    else
        echo -e "${RED}Could not detect language${NC}" >&2
        exit 1
    fi
}

# Command handling
case "${1:-detect}" in
    detect)
        # Handle directory argument for detect command
        if [[ -n "${2:-}" ]]; then
            PROJECT_DIR="$2"
        fi
        detect_language
        ;;
    build)
        main "$@"
        ;;
    parse)
        # Parse existing output
        lang="${2:-}"
        output="${3:-}"
        if [[ -n "$lang" ]] && [[ -n "${ERROR_PARSERS[$lang]:-}" ]]; then
            ${ERROR_PARSERS[$lang]} "$output"
        else
            echo "Usage: $0 parse <language> <output>"
            exit 1
        fi
        ;;
    build_command)
        # Return build command for detected language
        if [[ -n "${2:-}" ]]; then
            PROJECT_DIR="$2"
        fi
        language=$(detect_language)
        echo "${BUILD_COMMANDS[$language]:-}"
        ;;
    *)
        echo "Usage: $0 {detect|build|parse|build_command} [directory|language]"
        exit 1
        ;;
esac