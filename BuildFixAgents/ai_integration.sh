#!/bin/bash

# AI Integration Module for Build Fix Agents
# Provides AI-powered error analysis and fix generation

set -euo pipefail

# Load configuration
CONFIG_FILE="${AGENT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/config/api_config.yml"

# Parse YAML config (simple parser)
get_config() {
    local key=$1
    grep "^[[:space:]]*${key}:" "$CONFIG_FILE" 2>/dev/null | sed 's/.*: *//; s/"//g; s/^ *//; s/ *$//' || echo ""
}

# Initialize AI settings
AI_PROVIDER=$(get_config "provider")
CLAUDE_API_KEY=$(get_config "claude.api_key" | grep -v "^$" || echo "")
OPENAI_API_KEY=$(get_config "openai.api_key" | grep -v "^$" || echo "")
USE_AI_ANALYSIS=$(get_config "use_ai_analysis")
USE_AI_FIXES=$(get_config "use_ai_fixes")
FALLBACK_TO_PATTERNS=$(get_config "fallback_to_patterns")
MAX_REQUESTS=$(get_config "max_requests_per_run")
AI_LOG_FILE="${AGENT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/$(get_config "ai_log_file")"

# Counter for API requests
API_REQUEST_COUNT=0

# Create AI log directory
mkdir -p "$(dirname "$AI_LOG_FILE")"

# Log AI interactions
log_ai() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$AI_LOG_FILE"
}

# Check if AI is available
is_ai_available() {
    if [[ "$AI_PROVIDER" == "none" ]]; then
        return 1
    fi
    
    if [[ "$AI_PROVIDER" == "claude" && -n "$CLAUDE_API_KEY" ]]; then
        return 0
    fi
    
    if [[ "$AI_PROVIDER" == "openai" && -n "$OPENAI_API_KEY" ]]; then
        return 0
    fi
    
    return 1
}

# Make Claude API request
call_claude_api() {
    local prompt=$1
    local response
    
    if [[ -z "$CLAUDE_API_KEY" ]]; then
        echo "Error: Claude API key not configured" >&2
        return 1
    fi
    
    # Increment request counter
    ((API_REQUEST_COUNT++))
    
    # Check request limit
    if [[ $API_REQUEST_COUNT -gt $MAX_REQUESTS ]]; then
        echo "Error: API request limit reached ($MAX_REQUESTS)" >&2
        return 1
    fi
    
    log_ai "REQUEST to Claude: ${prompt:0:200}..."
    
    response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d @- <<EOF
{
    "model": "$(get_config "claude.model")",
    "max_tokens": $(get_config "claude.max_tokens"),
    "temperature": $(get_config "claude.temperature"),
    "messages": [{
        "role": "user",
        "content": "$prompt"
    }]
}
EOF
    )
    
    # Extract content from response
    local content=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
    
    if [[ -z "$content" ]]; then
        log_ai "ERROR: Failed to get response from Claude"
        echo "$response" >&2
        return 1
    fi
    
    log_ai "RESPONSE from Claude: ${content:0:200}..."
    echo "$content"
}

# Make OpenAI API request
call_openai_api() {
    local prompt=$1
    local response
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo "Error: OpenAI API key not configured" >&2
        return 1
    fi
    
    # Increment request counter
    ((API_REQUEST_COUNT++))
    
    # Check request limit
    if [[ $API_REQUEST_COUNT -gt $MAX_REQUESTS ]]; then
        echo "Error: API request limit reached ($MAX_REQUESTS)" >&2
        return 1
    fi
    
    log_ai "REQUEST to OpenAI: ${prompt:0:200}..."
    
    response=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d @- <<EOF
{
    "model": "$(get_config "openai.model")",
    "messages": [{
        "role": "system",
        "content": "You are an expert C# developer helping to fix build errors. Provide concise, accurate fixes."
    }, {
        "role": "user",
        "content": "$prompt"
    }],
    "max_tokens": $(get_config "openai.max_tokens"),
    "temperature": $(get_config "openai.temperature")
}
EOF
    )
    
    # Extract content from response
    local content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    
    if [[ -z "$content" ]]; then
        log_ai "ERROR: Failed to get response from OpenAI"
        echo "$response" >&2
        return 1
    fi
    
    log_ai "RESPONSE from OpenAI: ${content:0:200}..."
    echo "$content"
}

# Generic AI call wrapper
call_ai_api() {
    local prompt=$1
    
    case "$AI_PROVIDER" in
        claude)
            call_claude_api "$prompt"
            ;;
        openai)
            call_openai_api "$prompt"
            ;;
        *)
            echo "Error: Unknown AI provider: $AI_PROVIDER" >&2
            return 1
            ;;
    esac
}

# Analyze build errors using AI
ai_analyze_errors() {
    local error_file=$1
    local analysis_result=""
    
    if ! is_ai_available || [[ "$USE_AI_ANALYSIS" != "true" ]]; then
        return 1
    fi
    
    # Prepare error context
    local error_context=$(head -n 100 "$error_file")
    
    local prompt="Analyze these C# build errors and categorize them by type. For each category, explain the root cause and suggest a fixing strategy. Be concise.

Build errors:
$error_context

Provide analysis in this format:
CATEGORY: [error type]
ROOT_CAUSE: [explanation]
FIX_STRATEGY: [approach to fix]
---"
    
    # Escape the prompt for JSON
    prompt=$(echo "$prompt" | jq -Rs .)
    
    # Call AI API
    if analysis_result=$(call_ai_api "$prompt"); then
        echo "$analysis_result"
        return 0
    else
        return 1
    fi
}

# Generate fix for specific error using AI
ai_generate_fix() {
    local error_message=$1
    local file_path=$2
    local file_content=$3
    local fix_result=""
    
    if ! is_ai_available || [[ "$USE_AI_FIXES" != "true" ]]; then
        return 1
    fi
    
    # Limit file content to relevant section
    local line_num=$(echo "$error_message" | grep -oP '\(\d+,\d+\)' | grep -oP '\d+' | head -1)
    local start_line=$((line_num - 20))
    local end_line=$((line_num + 20))
    [[ $start_line -lt 1 ]] && start_line=1
    
    local relevant_content=$(echo "$file_content" | sed -n "${start_line},${end_line}p")
    
    local prompt="Fix this C# build error. Provide ONLY the corrected code snippet, no explanations.

Error: $error_message
File: $file_path
Code context (lines $start_line-$end_line):
$relevant_content

Return the fixed code that should replace the problematic section."
    
    # Escape the prompt for JSON
    prompt=$(echo "$prompt" | jq -Rs .)
    
    # Call AI API
    if fix_result=$(call_ai_api "$prompt"); then
        echo "$fix_result"
        return 0
    else
        return 1
    fi
}

# Batch analyze multiple errors
ai_batch_analyze() {
    local errors_json=$1
    local analysis_result=""
    
    if ! is_ai_available || [[ "$USE_AI_ANALYSIS" != "true" ]]; then
        return 1
    fi
    
    local prompt="Analyze these C# build errors and provide a fixing plan. Group similar errors and suggest the most efficient order to fix them.

Errors:
$errors_json

For each group:
1. Identify the pattern
2. Suggest a systematic fix
3. List affected files
4. Estimate complexity (simple/medium/complex)"
    
    # Escape the prompt for JSON
    prompt=$(echo "$prompt" | jq -Rs .)
    
    # Call AI API
    if analysis_result=$(call_ai_api "$prompt"); then
        echo "$analysis_result"
        return 0
    else
        return 1
    fi
}

# Cost estimation
estimate_ai_cost() {
    local error_count=$1
    local cost_per_request=0
    
    case "$AI_PROVIDER" in
        claude)
            # Rough estimates based on model
            case "$(get_config "claude.model")" in
                *opus*) cost_per_request=0.015 ;;
                *sonnet*) cost_per_request=0.003 ;;
                *haiku*) cost_per_request=0.00025 ;;
            esac
            ;;
        openai)
            # Rough estimates based on model
            case "$(get_config "openai.model")" in
                *gpt-4*) cost_per_request=0.03 ;;
                *gpt-3.5*) cost_per_request=0.002 ;;
            esac
            ;;
    esac
    
    local estimated_requests=$((error_count / 5 + 10)) # Rough estimate
    local estimated_cost=$(echo "$estimated_requests * $cost_per_request" | bc -l)
    
    printf "%.2f" "$estimated_cost"
}

# Export functions for use in other scripts
export -f is_ai_available
export -f ai_analyze_errors
export -f ai_generate_fix
export -f ai_batch_analyze
export -f estimate_ai_cost
export -f log_ai