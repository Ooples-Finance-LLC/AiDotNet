#!/bin/bash

# Claude Code Integration for Build Fix Agent
# Allows users to leverage Claude Code subscription without API keys

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check if running inside Claude Code
is_claude_code() {
    # Claude Code sets specific environment variables
    [[ -n "${CLAUDE_CODE:-}" ]] || [[ -n "${MCP_SERVERS:-}" ]] || [[ "$0" =~ claude ]]
}

# Generate fix request for Claude Code
generate_claude_request() {
    local error_file=$1
    local language=$2
    local output_file="${3:-$SCRIPT_DIR/claude_fix_request.md}"
    
    cat > "$output_file" << EOF
# Build Error Fix Request

**Language:** $language
**Project:** $PROJECT_DIR

## Instructions for Claude Code

Please analyze and fix the following build errors. For each error:

1. Identify the root cause
2. Provide the exact fix (code changes)
3. Explain why this fix works

### Output Format Required:

\`\`\`json
{
  "fixes": [
    {
      "file": "path/to/file.ext",
      "line": 123,
      "error": "CS0246",
      "original": "problematic code",
      "fixed": "corrected code",
      "explanation": "why this fixes it"
    }
  ]
}
\`\`\`

## Build Errors:

\`\`\`
$(cat "$error_file")
\`\`\`

## Context Files:

EOF
    
    # Add relevant files based on errors
    local files=$(grep -oE '^[^:]+' "$error_file" | sort -u | head -10)
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            echo "### $file" >> "$output_file"
            echo '```'$language >> "$output_file"
            head -100 "$file" >> "$output_file"
            echo '```' >> "$output_file"
            echo "" >> "$output_file"
        fi
    done <<< "$files"
    
    echo "$output_file"
}

# Interactive mode for Claude Code
claude_interactive_mode() {
    echo -e "${CYAN}${BOLD}Claude Code Interactive Fix Mode${NC}"
    echo -e "${YELLOW}This mode helps you fix build errors using your Claude Code subscription${NC}"
    echo ""
    
    # Detect language
    local language=$(detect_language)
    echo -e "${BLUE}Detected language: ${BOLD}$language${NC}"
    
    # Run build
    echo -e "${YELLOW}Running build to capture errors...${NC}"
    local build_output="$SCRIPT_DIR/claude_build_output.txt"
    capture_build_errors "$language" > "$build_output" 2>&1 || true
    
    # Count errors
    local error_count=$(grep -cE "(error|Error:|SyntaxError|TypeError)" "$build_output" || echo "0")
    
    if [[ $error_count -eq 0 ]]; then
        echo -e "${GREEN}✓ No build errors found!${NC}"
        return 0
    fi
    
    echo -e "${RED}Found $error_count errors${NC}"
    echo ""
    
    # Generate request
    local request_file=$(generate_claude_request "$build_output" "$language")
    
    echo -e "${CYAN}Generated fix request at: ${BOLD}$request_file${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Copy the content below and paste it into Claude Code"
    echo "2. Claude will analyze and provide fixes"
    echo "3. Run: ./claude_code_integration.sh apply-fixes <response_file>"
    echo ""
    echo -e "${CYAN}${BOLD}--- COPY BELOW THIS LINE ---${NC}"
    cat "$request_file"
    echo -e "${CYAN}${BOLD}--- COPY ABOVE THIS LINE ---${NC}"
}

# Apply fixes from Claude Code response
apply_claude_fixes() {
    local response_file=$1
    
    if [[ ! -f "$response_file" ]]; then
        echo -e "${RED}Error: Response file not found: $response_file${NC}"
        return 1
    fi
    
    # Extract JSON from response
    local fixes_json=$(grep -A1000 '```json' "$response_file" | grep -B1000 '```' | grep -v '```' || echo "{}")
    
    # Parse and apply fixes
    echo "$fixes_json" | jq -c '.fixes[]' 2>/dev/null | while IFS= read -r fix; do
        local file=$(echo "$fix" | jq -r '.file')
        local line=$(echo "$fix" | jq -r '.line')
        local original=$(echo "$fix" | jq -r '.original')
        local fixed=$(echo "$fix" | jq -r '.fixed')
        local explanation=$(echo "$fix" | jq -r '.explanation')
        
        echo -e "${YELLOW}Fixing: $file:$line${NC}"
        echo -e "${CYAN}Reason: $explanation${NC}"
        
        # Apply the fix
        if [[ -f "$file" ]]; then
            # Escape special characters for sed
            original_escaped=$(printf '%s\n' "$original" | sed 's/[[\.*^$()+?{|]/\\&/g')
            fixed_escaped=$(printf '%s\n' "$fixed" | sed 's/[[\.*^$()+?{|]/\\&/g')
            
            # Apply fix
            sed -i "${line}s/$original_escaped/$fixed_escaped/" "$file"
            echo -e "${GREEN}✓ Applied fix${NC}"
        else
            echo -e "${RED}✗ File not found${NC}"
        fi
        echo ""
    done
    
    # Run build again
    echo -e "${YELLOW}Running build to verify fixes...${NC}"
    if capture_build_errors > /dev/null 2>&1; then
        echo -e "${GREEN}${BOLD}✓ Build successful!${NC}"
    else
        echo -e "${YELLOW}Some errors remain. You may need to run again.${NC}"
    fi
}

# MCP Server mode for direct Claude Code integration
mcp_server_mode() {
    cat > "$SCRIPT_DIR/mcp_server_config.json" << 'EOF'
{
  "name": "build-fix-agent",
  "version": "1.0.0",
  "description": "Multi-language build error fixing agent",
  "commands": {
    "analyze-errors": {
      "description": "Analyze build errors and suggest fixes",
      "parameters": {
        "language": {
          "type": "string",
          "description": "Programming language",
          "optional": true
        }
      }
    },
    "apply-fix": {
      "description": "Apply a specific fix to a file",
      "parameters": {
        "file": {
          "type": "string",
          "description": "File path"
        },
        "line": {
          "type": "number",
          "description": "Line number"
        },
        "original": {
          "type": "string",
          "description": "Original code"
        },
        "replacement": {
          "type": "string",
          "description": "Replacement code"
        }
      }
    },
    "run-build": {
      "description": "Run build and return results",
      "parameters": {}
    }
  }
}
EOF
    
    echo -e "${GREEN}MCP Server configuration created${NC}"
    echo -e "${CYAN}Add this to your Claude Code settings:${NC}"
    echo ""
    echo "  \"mcp.servers\": {"
    echo "    \"build-fix\": {"
    echo "      \"command\": \"$SCRIPT_DIR/claude_code_integration.sh\","
    echo "      \"args\": [\"mcp-serve\"]"
    echo "    }"
    echo "  }"
}

# MCP Server implementation
mcp_serve() {
    # Simple MCP server that Claude Code can communicate with
    while IFS= read -r line; do
        # Parse JSON-RPC request
        local method=$(echo "$line" | jq -r '.method' 2>/dev/null || echo "")
        local params=$(echo "$line" | jq -r '.params' 2>/dev/null || echo "{}")
        local id=$(echo "$line" | jq -r '.id' 2>/dev/null || echo "0")
        
        case "$method" in
            "analyze-errors")
                local language=$(echo "$params" | jq -r '.language // empty')
                [[ -z "$language" ]] && language=$(detect_language)
                
                # Run build and analyze
                local build_output="/tmp/mcp_build_$$.txt"
                capture_build_errors "$language" > "$build_output" 2>&1 || true
                
                # Analyze errors
                local analysis=$(analyze_errors_for_mcp "$build_output" "$language")
                
                # Return response
                echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"result\": $analysis}"
                ;;
                
            "apply-fix")
                local file=$(echo "$params" | jq -r '.file')
                local line=$(echo "$params" | jq -r '.line')
                local original=$(echo "$params" | jq -r '.original')
                local replacement=$(echo "$params" | jq -r '.replacement')
                
                # Apply the fix
                if apply_single_fix "$file" "$line" "$original" "$replacement"; then
                    echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"result\": {\"success\": true}}"
                else
                    echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"error\": {\"code\": -32603, \"message\": \"Failed to apply fix\"}}"
                fi
                ;;
                
            "run-build")
                local result=$(capture_build_errors 2>&1 && echo "success" || echo "failed")
                echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"result\": {\"status\": \"$result\"}}"
                ;;
                
            *)
                echo "{\"jsonrpc\": \"2.0\", \"id\": $id, \"error\": {\"code\": -32601, \"message\": \"Method not found\"}}"
                ;;
        esac
    done
}

# Helper functions
detect_language() {
    # Reuse from main build analyzer
    source "$SCRIPT_DIR/generic_build_analyzer.sh"
    detect_language
}

capture_build_errors() {
    # Reuse from main build analyzer
    source "$SCRIPT_DIR/generic_build_analyzer.sh"
    capture_build_errors "$@"
}

analyze_errors_for_mcp() {
    local build_output=$1
    local language=$2
    
    # Simple analysis for MCP
    local errors=$(grep -cE "(error|Error:|SyntaxError|TypeError)" "$build_output" || echo "0")
    
    jq -n \
        --arg lang "$language" \
        --arg count "$errors" \
        --arg output "$(cat "$build_output")" \
        '{
            language: $lang,
            error_count: ($count | tonumber),
            build_output: $output
        }'
}

apply_single_fix() {
    local file=$1
    local line=$2
    local original=$3
    local replacement=$4
    
    if [[ -f "$file" ]]; then
        # Escape special characters
        original_escaped=$(printf '%s\n' "$original" | sed 's/[[\.*^$()+?{|]/\\&/g')
        replacement_escaped=$(printf '%s\n' "$replacement" | sed 's/[[\.*^$()+?{|]/\\&/g')
        
        # Apply fix
        sed -i "${line}s/$original_escaped/$replacement_escaped/" "$file"
        return 0
    else
        return 1
    fi
}

# Main entry point
case "${1:-}" in
    "interactive"|"-i")
        claude_interactive_mode
        ;;
        
    "apply-fixes"|"-a")
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Error: Please provide response file${NC}"
            echo "Usage: $0 apply-fixes <response_file>"
            exit 1
        fi
        apply_claude_fixes "$2"
        ;;
        
    "mcp-setup")
        mcp_server_mode
        ;;
        
    "mcp-serve")
        mcp_serve
        ;;
        
    "help"|"-h"|"--help")
        echo "Claude Code Integration for Build Fix Agent"
        echo ""
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  interactive, -i     Start interactive mode (default)"
        echo "  apply-fixes, -a     Apply fixes from Claude Code response"
        echo "  mcp-setup          Generate MCP server configuration"
        echo "  mcp-serve          Run as MCP server (for Claude Code)"
        echo "  help, -h           Show this help"
        echo ""
        echo "Examples:"
        echo "  $0                  # Start interactive mode"
        echo "  $0 apply-fixes response.md  # Apply fixes from file"
        echo "  $0 mcp-setup        # Setup for direct Claude Code integration"
        ;;
        
    *)
        # Default to interactive mode
        claude_interactive_mode
        ;;
esac