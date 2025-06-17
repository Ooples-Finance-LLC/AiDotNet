#!/bin/bash

# Pattern Learning Database - ML-style pattern storage and retrieval
# Stores successful fix patterns and learns from each execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$SCRIPT_DIR/state/pattern_db"
PATTERNS_FILE="$DB_DIR/patterns.db"
INDEX_FILE="$DB_DIR/pattern_index.json"
METRICS_FILE="$DB_DIR/pattern_metrics.json"
LEARNING_LOG="$DB_DIR/learning.log"

# Configuration
PATTERN_VERSION="1.0"
MIN_SUCCESS_RATE=0.7
PATTERN_EXPIRY_DAYS=30
ENABLE_ML_FEATURES=${ENABLE_ML_FEATURES:-true}

# Create directories
mkdir -p "$DB_DIR"

# Initialize database files
init_database() {
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        cat > "$PATTERNS_FILE" << 'EOF'
# Pattern Learning Database
# Format: PATTERN_ID|ERROR_CODE|PATTERN_TYPE|PATTERN_CONTENT|SUCCESS_COUNT|FAILURE_COUNT|CREATED|LAST_USED|METADATA
EOF
    fi
    
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo '{"version": "'"$PATTERN_VERSION"'", "patterns": {}, "error_map": {}, "statistics": {}}' > "$INDEX_FILE"
    fi
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo '{"total_patterns": 0, "successful_fixes": 0, "failed_fixes": 0, "learning_rate": 0}' > "$METRICS_FILE"
    fi
}

# Generate unique pattern ID
generate_pattern_id() {
    local error_code="$1"
    local pattern_type="$2"
    local timestamp=$(date +%s)
    local random=$(openssl rand -hex 4)
    echo "${error_code}_${pattern_type}_${timestamp}_${random}"
}

# Store a new pattern
store_pattern() {
    local error_code="$1"
    local pattern_type="$2"
    local pattern_content="$3"
    local metadata="${4:-{}}"
    
    local pattern_id=$(generate_pattern_id "$error_code" "$pattern_type")
    local created=$(date -Iseconds)
    
    # Escape pattern content for storage
    local escaped_content=$(echo "$pattern_content" | base64 -w 0)
    
    # Add to patterns file
    echo "${pattern_id}|${error_code}|${pattern_type}|${escaped_content}|0|0|${created}|${created}|${metadata}" >> "$PATTERNS_FILE"
    
    # Update index
    local temp_index=$(mktemp)
    jq --arg id "$pattern_id" \
       --arg code "$error_code" \
       --arg type "$pattern_type" \
       --arg created "$created" \
       --argjson meta "$metadata" \
       '.patterns[$id] = {
           "error_code": $code,
           "type": $type,
           "created": $created,
           "success_rate": 0,
           "usage_count": 0,
           "metadata": $meta
       } |
       .error_map[$code] = (.error_map[$code] // []) + [$id] |
       .statistics.total_patterns = (.statistics.total_patterns // 0) + 1' \
       "$INDEX_FILE" > "$temp_index" && mv "$temp_index" "$INDEX_FILE"
    
    echo "$pattern_id"
}

# Retrieve patterns for an error code
get_patterns() {
    local error_code="$1"
    local min_success_rate="${2:-$MIN_SUCCESS_RATE}"
    
    # Get pattern IDs from index
    local pattern_ids=$(jq -r --arg code "$error_code" '.error_map[$code] // [] | .[]' "$INDEX_FILE")
    
    if [[ -z "$pattern_ids" ]]; then
        return 1
    fi
    
    # Filter by success rate and return sorted by effectiveness
    local patterns=()
    while IFS= read -r pattern_id; do
        local success_rate=$(jq -r --arg id "$pattern_id" '.patterns[$id].success_rate // 0' "$INDEX_FILE")
        
        if (( $(echo "$success_rate >= $min_success_rate" | bc -l) )); then
            # Get pattern from database
            local pattern_line=$(grep "^${pattern_id}|" "$PATTERNS_FILE" | tail -1)
            if [[ -n "$pattern_line" ]]; then
                patterns+=("$pattern_line")
            fi
        fi
    done <<< "$pattern_ids"
    
    # Sort by success rate (field 5) and usage count
    printf '%s\n' "${patterns[@]}" | sort -t'|' -k5,5nr -k6,6n
}

# Update pattern metrics after use
update_pattern_metrics() {
    local pattern_id="$1"
    local success="$2"  # true/false
    
    # Update pattern file
    local temp_file=$(mktemp)
    local updated=false
    
    while IFS='|' read -r id code type content succ_count fail_count created last_used meta; do
        if [[ "$id" == "$pattern_id" ]]; then
            if [[ "$success" == "true" ]]; then
                ((succ_count++))
            else
                ((fail_count++))
            fi
            last_used=$(date -Iseconds)
            echo "${id}|${code}|${type}|${content}|${succ_count}|${fail_count}|${created}|${last_used}|${meta}"
            updated=true
        else
            echo "${id}|${code}|${type}|${content}|${succ_count}|${fail_count}|${created}|${last_used}|${meta}"
        fi
    done < "$PATTERNS_FILE" > "$temp_file"
    
    if [[ "$updated" == "true" ]]; then
        mv "$temp_file" "$PATTERNS_FILE"
        
        # Update index with new success rate
        local pattern_data=$(grep "^${pattern_id}|" "$PATTERNS_FILE" | tail -1)
        local succ_count=$(echo "$pattern_data" | cut -d'|' -f5)
        local fail_count=$(echo "$pattern_data" | cut -d'|' -f6)
        local total=$((succ_count + fail_count))
        local success_rate=0
        
        if [[ $total -gt 0 ]]; then
            success_rate=$(echo "scale=4; $succ_count / $total" | bc)
        fi
        
        # Update index
        local temp_index=$(mktemp)
        jq --arg id "$pattern_id" \
           --arg rate "$success_rate" \
           --arg usage "$total" \
           '.patterns[$id].success_rate = ($rate | tonumber) |
            .patterns[$id].usage_count = ($usage | tonumber)' \
           "$INDEX_FILE" > "$temp_index" && mv "$temp_index" "$INDEX_FILE"
        
        # Update global metrics
        if [[ "$success" == "true" ]]; then
            jq '.successful_fixes += 1' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
        else
            jq '.failed_fixes += 1' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
        fi
    else
        rm -f "$temp_file"
    fi
    
    # Log learning event
    echo "$(date -Iseconds)|UPDATE|${pattern_id}|${success}" >> "$LEARNING_LOG"
}

# Learn from execution results
learn_from_execution() {
    local error_code="$1"
    local fix_applied="$2"
    local result="$3"  # success/failure
    local context="${4:-{}}"
    
    # Extract pattern type from fix
    local pattern_type="unknown"
    case "$fix_applied" in
        *"sed"*) pattern_type="sed" ;;
        *"awk"*) pattern_type="awk" ;;
        *"namespace"*) pattern_type="namespace" ;;
        *"nullable"*) pattern_type="nullable" ;;
        *"duplicate"*) pattern_type="duplicate" ;;
    esac
    
    # Check if pattern exists
    local existing_pattern=$(grep -E "\\|${error_code}\\|${pattern_type}\\|.*${fix_applied}" "$PATTERNS_FILE" 2>/dev/null | head -1 | cut -d'|' -f1)
    
    if [[ -n "$existing_pattern" ]]; then
        # Update existing pattern
        update_pattern_metrics "$existing_pattern" "$result"
    else
        # Store new pattern if successful
        if [[ "$result" == "success" ]]; then
            local pattern_id=$(store_pattern "$error_code" "$pattern_type" "$fix_applied" "$context")
            update_pattern_metrics "$pattern_id" "true"
            echo "Learned new pattern: $pattern_id"
        fi
    fi
    
    # Log learning event
    echo "$(date -Iseconds)|LEARN|${error_code}|${pattern_type}|${result}" >> "$LEARNING_LOG"
}

# Get best pattern for error
get_best_pattern() {
    local error_code="$1"
    
    # Get all patterns sorted by effectiveness
    local best_pattern=$(get_patterns "$error_code" 0 | head -1)
    
    if [[ -n "$best_pattern" ]]; then
        local pattern_id=$(echo "$best_pattern" | cut -d'|' -f1)
        local pattern_content=$(echo "$best_pattern" | cut -d'|' -f4 | base64 -d)
        local success_rate=$(jq -r --arg id "$pattern_id" '.patterns[$id].success_rate' "$INDEX_FILE")
        
        echo "{\"id\": \"$pattern_id\", \"content\": \"$pattern_content\", \"success_rate\": $success_rate}"
    else
        echo "{}"
    fi
}

# Export patterns for specific error code
export_patterns() {
    local error_code="$1"
    local output_file="${2:-patterns_${error_code}.json}"
    
    local patterns=$(get_patterns "$error_code" 0)
    
    echo '{"error_code": "'"$error_code"'", "patterns": [' > "$output_file"
    
    local first=true
    while IFS='|' read -r id code type content succ fail created last_used meta; do
        [[ "$first" == "true" ]] && first=false || echo "," >> "$output_file"
        
        local decoded_content=$(echo "$content" | base64 -d | jq -Rs .)
        cat >> "$output_file" << EOF
        {
            "id": "$id",
            "type": "$type",
            "content": $decoded_content,
            "success_count": $succ,
            "failure_count": $fail,
            "success_rate": $(echo "scale=4; $succ / ($succ + $fail)" | bc),
            "created": "$created",
            "last_used": "$last_used",
            "metadata": $meta
        }
EOF
    done <<< "$patterns"
    
    echo ']}'>> "$output_file"
    echo "Exported patterns to: $output_file"
}

# Analyze pattern effectiveness
analyze_patterns() {
    echo "=== Pattern Learning Database Analysis ==="
    echo "Database Location: $DB_DIR"
    echo ""
    
    # Overall statistics
    local total_patterns=$(jq -r '.statistics.total_patterns // 0' "$INDEX_FILE")
    local total_success=$(jq -r '.successful_fixes // 0' "$METRICS_FILE")
    local total_failed=$(jq -r '.failed_fixes // 0' "$METRICS_FILE")
    local total_attempts=$((total_success + total_failed))
    
    echo "Overall Statistics:"
    echo "  Total Patterns: $total_patterns"
    echo "  Total Attempts: $total_attempts"
    echo "  Successful Fixes: $total_success"
    echo "  Failed Fixes: $total_failed"
    
    if [[ $total_attempts -gt 0 ]]; then
        local overall_success_rate=$(echo "scale=2; $total_success * 100 / $total_attempts" | bc)
        echo "  Overall Success Rate: ${overall_success_rate}%"
    fi
    echo ""
    
    # Top patterns by success rate
    echo "Top Patterns by Success Rate:"
    jq -r '.patterns | to_entries | 
           map(select(.value.usage_count > 5)) |
           sort_by(-.value.success_rate) | 
           .[0:10] |
           .[] | 
           "  \(.value.error_code) - \(.value.type): \(.value.success_rate * 100 | floor)% (\(.value.usage_count) uses)"' \
       "$INDEX_FILE" 2>/dev/null || echo "  No patterns with sufficient usage"
    echo ""
    
    # Most common error codes
    echo "Most Common Error Codes:"
    jq -r '.error_map | to_entries | 
           sort_by(-.value | length) | 
           .[0:10] |
           .[] | 
           "  \(.key): \(.value | length) patterns"' \
       "$INDEX_FILE" 2>/dev/null || echo "  No error codes found"
}

# Cleanup old patterns
cleanup_patterns() {
    local expiry_date=$(date -d "$PATTERN_EXPIRY_DAYS days ago" +%s)
    local temp_file=$(mktemp)
    local removed=0
    
    while IFS='|' read -r id code type content succ fail created last_used meta; do
        local last_used_ts=$(date -d "$last_used" +%s 2>/dev/null || echo 0)
        
        if [[ $last_used_ts -lt $expiry_date ]]; then
            ((removed++))
            # Remove from index
            jq --arg id "$id" --arg code "$code" '
                del(.patterns[$id]) |
                .error_map[$code] = (.error_map[$code] // []) - [$id]' \
                "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"
        else
            echo "${id}|${code}|${type}|${content}|${succ}|${fail}|${created}|${last_used}|${meta}"
        fi
    done < "$PATTERNS_FILE" > "$temp_file"
    
    mv "$temp_file" "$PATTERNS_FILE"
    echo "Removed $removed expired patterns"
}

# ML-style pattern similarity detection
find_similar_patterns() {
    local error_code="$1"
    local error_message="$2"
    
    if [[ "$ENABLE_ML_FEATURES" != "true" ]]; then
        return
    fi
    
    # Simple similarity: find patterns for related error codes
    local similar_codes=()
    
    # Group similar error codes
    case "$error_code" in
        CS0*) similar_codes=(CS0*) ;;  # Syntax errors
        CS1*) similar_codes=(CS1*) ;;  # Type/member errors
        CS8*) similar_codes=(CS8*) ;;  # Nullable errors
        *) similar_codes=("$error_code") ;;
    esac
    
    # Find patterns from similar error codes
    local similar_patterns=()
    for code_pattern in "${similar_codes[@]}"; do
        local codes=$(jq -r '.error_map | keys[]' "$INDEX_FILE" | grep -E "^${code_pattern}")
        while IFS= read -r code; do
            if [[ "$code" != "$error_code" ]]; then
                local patterns=$(get_patterns "$code" 0.5)
                if [[ -n "$patterns" ]]; then
                    similar_patterns+=("$patterns")
                fi
            fi
        done <<< "$codes"
    done
    
    if [[ ${#similar_patterns[@]} -gt 0 ]]; then
        echo "Found ${#similar_patterns[@]} similar patterns from related error codes"
        printf '%s\n' "${similar_patterns[@]}"
    fi
}

# Main function for command-line usage
main() {
    init_database
    
    case "${1:-help}" in
        store)
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 store <error_code> <pattern_type> <pattern_content> [metadata]"
                exit 1
            fi
            store_pattern "$2" "$3" "$4" "${5:-{}}"
            ;;
        get)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 get <error_code> [min_success_rate]"
                exit 1
            fi
            get_patterns "$2" "${3:-$MIN_SUCCESS_RATE}"
            ;;
        best)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 best <error_code>"
                exit 1
            fi
            get_best_pattern "$2"
            ;;
        update)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 update <pattern_id> <success|failure>"
                exit 1
            fi
            update_pattern_metrics "$2" "$([[ "$3" == "success" ]] && echo "true" || echo "false")"
            ;;
        learn)
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 learn <error_code> <fix_applied> <success|failure> [context]"
                exit 1
            fi
            learn_from_execution "$2" "$3" "$4" "${5:-{}}"
            ;;
        export)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 export <error_code> [output_file]"
                exit 1
            fi
            export_patterns "$2" "${3:-}"
            ;;
        analyze)
            analyze_patterns
            ;;
        cleanup)
            cleanup_patterns
            ;;
        similar)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 similar <error_code> <error_message>"
                exit 1
            fi
            find_similar_patterns "$2" "$3"
            ;;
        *)
            cat << EOF
Pattern Learning Database - ML-style pattern storage and retrieval

Usage: $0 <command> [options]

Commands:
  store <error_code> <type> <content> [metadata]  - Store a new pattern
  get <error_code> [min_success_rate]            - Get patterns for error code
  best <error_code>                              - Get best pattern for error
  update <pattern_id> <success|failure>          - Update pattern metrics
  learn <error_code> <fix> <result> [context]    - Learn from execution
  export <error_code> [output_file]              - Export patterns to JSON
  analyze                                        - Analyze pattern effectiveness
  cleanup                                        - Remove expired patterns
  similar <error_code> <message>                 - Find similar patterns

Examples:
  # Store a new pattern
  $0 store CS8618 sed 's/string /string? /g' '{"scope":"properties"}'
  
  # Get best pattern for an error
  $0 best CS8618
  
  # Learn from a successful fix
  $0 learn CS8618 "sed 's/string /string? /g'" success
  
  # Analyze all patterns
  $0 analyze
EOF
            ;;
    esac
}

# Export functions for use by other scripts
export -f store_pattern
export -f get_patterns
export -f get_best_pattern
export -f update_pattern_metrics
export -f learn_from_execution
export -f find_similar_patterns

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi