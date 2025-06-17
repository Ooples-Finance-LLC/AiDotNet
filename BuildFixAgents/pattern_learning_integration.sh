#!/bin/bash

# Pattern Learning Integration - Connects agents with the learning database
# Provides easy functions for agents to use learned patterns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERN_DB="$SCRIPT_DIR/pattern_learning_db.sh"

# Source the pattern database
source "$PATTERN_DB"

# Initialize database on load
init_database

# Try learned patterns first before custom logic
try_learned_patterns() {
    local error_code="$1"
    local file_path="${2:-}"
    local context="${3:-{}}"
    
    # Get best pattern for this error
    local best_pattern_json=$(get_best_pattern "$error_code")
    
    if [[ "$best_pattern_json" == "{}" ]]; then
        return 1
    fi
    
    local pattern_id=$(echo "$best_pattern_json" | jq -r '.id')
    local pattern_content=$(echo "$best_pattern_json" | jq -r '.content')
    local success_rate=$(echo "$best_pattern_json" | jq -r '.success_rate')
    
    echo "[PATTERN_LEARNING] Found pattern $pattern_id with ${success_rate} success rate"
    
    # Apply pattern based on type
    local success=false
    local result=""
    
    if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
        # File-specific fix
        if echo "$pattern_content" | grep -q "^s/"; then
            # Sed pattern
            if sed -i.bak "$pattern_content" "$file_path" 2>/dev/null; then
                success=true
                result="Applied sed pattern to $file_path"
            fi
        elif [[ "$pattern_content" =~ ^using[[:space:]] ]]; then
            # Using statement pattern
            if ! grep -q "$pattern_content" "$file_path"; then
                sed -i "1i\\$pattern_content" "$file_path"
                success=true
                result="Added using statement to $file_path"
            fi
        fi
    else
        # General fix pattern
        result="$pattern_content"
        success=true
    fi
    
    # Update metrics
    update_pattern_metrics "$pattern_id" "$success"
    
    if [[ "$success" == "true" ]]; then
        echo "[PATTERN_LEARNING] Successfully applied pattern: $result"
        return 0
    else
        echo "[PATTERN_LEARNING] Failed to apply pattern"
        return 1
    fi
}

# Record successful fix for learning
record_successful_fix() {
    local error_code="$1"
    local fix_applied="$2"
    local context="${3:-{}}"
    
    learn_from_execution "$error_code" "$fix_applied" "success" "$context"
    echo "[PATTERN_LEARNING] Recorded successful fix for $error_code"
}

# Record failed fix for learning
record_failed_fix() {
    local error_code="$1"
    local fix_applied="$2"
    local context="${3:-{}}"
    
    learn_from_execution "$error_code" "$fix_applied" "failure" "$context"
    echo "[PATTERN_LEARNING] Recorded failed fix for $error_code"
}

# Get all patterns for an error with filtering
get_filtered_patterns() {
    local error_code="$1"
    local min_success_rate="${2:-0.7}"
    local pattern_type="${3:-}"
    
    local patterns=$(get_patterns "$error_code" "$min_success_rate")
    
    if [[ -n "$pattern_type" ]]; then
        # Filter by type
        echo "$patterns" | grep "|${pattern_type}|"
    else
        echo "$patterns"
    fi
}

# Batch learn from multiple fixes
batch_learn() {
    local results_file="$1"
    
    if [[ ! -f "$results_file" ]]; then
        echo "[PATTERN_LEARNING] Results file not found: $results_file"
        return 1
    fi
    
    local learned=0
    while IFS='|' read -r error_code fix_applied result context; do
        if [[ -n "$error_code" ]] && [[ -n "$fix_applied" ]] && [[ -n "$result" ]]; then
            learn_from_execution "$error_code" "$fix_applied" "$result" "${context:-{}}"
            ((learned++))
        fi
    done < "$results_file"
    
    echo "[PATTERN_LEARNING] Batch learned from $learned fixes"
}

# Check if we have patterns for an error
has_patterns() {
    local error_code="$1"
    local patterns=$(get_patterns "$error_code" 0)
    
    if [[ -n "$patterns" ]]; then
        return 0
    else
        return 1
    fi
}

# Get pattern statistics for an error
get_pattern_stats() {
    local error_code="$1"
    
    local total_patterns=0
    local total_success=0
    local total_failures=0
    
    while IFS='|' read -r id code type content succ fail created last_used meta; do
        ((total_patterns++))
        ((total_success += succ))
        ((total_failures += fail))
    done < <(get_patterns "$error_code" 0)
    
    local total_attempts=$((total_success + total_failures))
    local success_rate=0
    
    if [[ $total_attempts -gt 0 ]]; then
        success_rate=$(echo "scale=2; $total_success * 100 / $total_attempts" | bc)
    fi
    
    echo "{
        \"error_code\": \"$error_code\",
        \"total_patterns\": $total_patterns,
        \"total_attempts\": $total_attempts,
        \"successful_fixes\": $total_success,
        \"failed_fixes\": $total_failures,
        \"success_rate\": $success_rate
    }"
}

# Integration with dynamic fix agent
integrate_with_agent() {
    local agent_type="${1:-dynamic}"
    
    case "$agent_type" in
        dynamic)
            # Export functions for dynamic agents
            export -f try_learned_patterns
            export -f record_successful_fix
            export -f record_failed_fix
            export -f get_filtered_patterns
            export -f has_patterns
            
            echo "[PATTERN_LEARNING] Integration enabled for dynamic agents"
            ;;
        static)
            # Create wrapper script for static agents
            cat > "$SCRIPT_DIR/pattern_wrapper.sh" << 'EOF'
#!/bin/bash
# Pattern learning wrapper for static agents

source "$(dirname "${BASH_SOURCE[0]}")/pattern_learning_integration.sh"

# Try learned patterns first
ERROR_CODE="$1"
FILE_PATH="${2:-}"

if try_learned_patterns "$ERROR_CODE" "$FILE_PATH"; then
    echo "Fixed using learned pattern"
    exit 0
fi

# Fall back to original agent logic
shift
exec "$@"
EOF
            chmod +x "$SCRIPT_DIR/pattern_wrapper.sh"
            echo "[PATTERN_LEARNING] Created wrapper script for static agents"
            ;;
    esac
}

# Monitor pattern effectiveness over time
monitor_patterns() {
    local report_file="$SCRIPT_DIR/state/pattern_effectiveness_$(date +%Y%m%d).json"
    
    echo "[" > "$report_file"
    
    local first=true
    for error_code in $(jq -r '.error_map | keys[]' "$INDEX_FILE"); do
        [[ "$first" == "true" ]] && first=false || echo "," >> "$report_file"
        get_pattern_stats "$error_code" >> "$report_file"
    done
    
    echo "]" >> "$report_file"
    
    echo "[PATTERN_LEARNING] Effectiveness report saved to: $report_file"
}

# Auto-suggest patterns based on error analysis
suggest_patterns() {
    local error_analysis_file="${1:-$SCRIPT_DIR/state/error_analysis.json}"
    
    if [[ ! -f "$error_analysis_file" ]]; then
        echo "[PATTERN_LEARNING] Error analysis file not found"
        return 1
    fi
    
    echo "[PATTERN_LEARNING] Analyzing errors for pattern suggestions..."
    
    # Extract top errors
    local top_errors=$(jq -r '.analysis.by_type[] | select(.count > 10) | .code' "$error_analysis_file" 2>/dev/null)
    
    for error_code in $top_errors; do
        if ! has_patterns "$error_code"; then
            echo "[PATTERN_LEARNING] No patterns found for $error_code - consider adding patterns"
            
            # Suggest patterns from similar errors
            local similar=$(find_similar_patterns "$error_code" "")
            if [[ -n "$similar" ]]; then
                echo "[PATTERN_LEARNING] Found similar patterns that might work:"
                echo "$similar" | head -3
            fi
        else
            local stats=$(get_pattern_stats "$error_code")
            local success_rate=$(echo "$stats" | jq -r '.success_rate')
            
            if (( $(echo "$success_rate < 50" | bc -l) )); then
                echo "[PATTERN_LEARNING] Low success rate for $error_code patterns (${success_rate}%)"
                echo "[PATTERN_LEARNING] Consider adding new patterns or improving existing ones"
            fi
        fi
    done
}

# Main function for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        test)
            echo "Testing pattern learning integration..."
            
            # Test pattern storage and retrieval
            store_pattern "TEST001" "sed" "s/test/TEST/g" '{"test": true}'
            
            if try_learned_patterns "TEST001"; then
                echo "✓ Pattern retrieval working"
            fi
            
            # Test learning
            record_successful_fix "TEST001" "s/test/TEST/g" '{"file": "test.cs"}'
            
            # Test stats
            get_pattern_stats "TEST001"
            
            echo "Integration test complete"
            ;;
        integrate)
            integrate_with_agent "${2:-dynamic}"
            ;;
        monitor)
            monitor_patterns
            ;;
        suggest)
            suggest_patterns "${2:-}"
            ;;
        *)
            echo "Pattern Learning Integration"
            echo "Usage: $0 {test|integrate|monitor|suggest}"
            ;;
    esac
fi