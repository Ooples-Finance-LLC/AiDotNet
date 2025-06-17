#!/bin/bash

# Agent Cache Wrapper - Automatic caching layer for all agent executions
# Wraps agent calls with intelligent caching to avoid redundant work

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source cache manager
source "$SCRIPT_DIR/cache_manager.sh"

# Configuration
CACHE_AGENT_RESULTS=${CACHE_AGENT_RESULTS:-true}
AGENT_CACHE_TTL=${AGENT_CACHE_TTL:-3600}  # 1 hour default
CACHE_KEY_STRATEGY=${CACHE_KEY_STRATEGY:-"smart"}  # smart, simple, full

# Generate cache key for agent execution
generate_agent_cache_key() {
    local agent_name="$1"
    local agent_args="${@:2}"
    
    case "$CACHE_KEY_STRATEGY" in
        "smart")
            # Smart key based on agent type and relevant context
            local context_key=""
            
            # Include build output hash for error-dependent agents
            if [[ "$agent_name" =~ (error|fix|analyzer) ]]; then
                if [[ -f "build_output.txt" ]]; then
                    local build_hash=$(md5sum build_output.txt 2>/dev/null | cut -d' ' -f1 | cut -c1-8)
                    context_key="${context_key}_build:${build_hash}"
                fi
            fi
            
            # Include file hashes for file-specific agents
            if [[ "$agent_name" =~ (duplicate|constraints|inheritance) ]]; then
                local file_pattern="*.cs"
                local files_hash=$(find . -name "$file_pattern" -type f -exec md5sum {} \; 2>/dev/null | \
                    sort | md5sum | cut -d' ' -f1 | cut -c1-8)
                context_key="${context_key}_files:${files_hash}"
            fi
            
            # Include error count for scaling decisions
            if [[ -f "$STATE_DIR/error_analysis.json" ]]; then
                local error_count=$(jq -r '.total_errors // 0' "$STATE_DIR/error_analysis.json")
                context_key="${context_key}_errors:${error_count}"
            fi
            
            # Generate final key
            echo -n "${agent_name}${context_key}_args:$(echo "$agent_args" | md5sum | cut -d' ' -f1)" | \
                md5sum | cut -d' ' -f1
            ;;
            
        "simple")
            # Simple key based on agent name and args only
            echo -n "${agent_name}_${agent_args}" | md5sum | cut -d' ' -f1
            ;;
            
        "full")
            # Full context key including timestamps
            local timestamp=$(date +%Y%m%d_%H)  # Hourly cache
            echo -n "${agent_name}_${timestamp}_${agent_args}" | md5sum | cut -d' ' -f1
            ;;
    esac
}

# Execute agent with caching
execute_agent_cached() {
    local agent_path="$1"
    local agent_name=$(basename "$agent_path" .sh)
    shift
    local agent_args="$@"
    
    if [[ "$CACHE_AGENT_RESULTS" != "true" ]]; then
        # Caching disabled, execute directly
        "$agent_path" "$@"
        return $?
    fi
    
    # Generate cache key
    local cache_key=$(generate_agent_cache_key "$agent_name" "$@")
    
    echo "[CACHE] Agent: $agent_name, Key: $cache_key"
    
    # Check cache
    local cached_result=$(mktemp)
    if get_cached_agent_result "$agent_name" "$cache_key" "$AGENT_CACHE_TTL" > "$cached_result" 2>/dev/null; then
        echo "[CACHE] Cache hit for $agent_name"
        cat "$cached_result"
        local exit_code=$(jq -r '.exit_code // 0' "$cached_result" 2>/dev/null || echo 0)
        rm -f "$cached_result"
        return $exit_code
    fi
    
    rm -f "$cached_result"
    echo "[CACHE] Cache miss for $agent_name, executing..."
    
    # Execute agent and capture output
    local output_file=$(mktemp)
    local error_file=$(mktemp)
    local start_time=$(date +%s)
    
    # Run agent
    "$agent_path" "$@" > "$output_file" 2> "$error_file"
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create result object
    local result_file=$(mktemp)
    cat > "$result_file" << EOF
{
    "agent": "$agent_name",
    "exit_code": $exit_code,
    "duration": $duration,
    "timestamp": "$(date -Iseconds)",
    "output": $(jq -Rs . < "$output_file"),
    "errors": $(jq -Rs . < "$error_file"),
    "args": $(printf '%s\n' "$@" | jq -R . | jq -s .),
    "cache_key": "$cache_key"
}
EOF
    
    # Cache the result
    cache_agent_result "$agent_name" "$cache_key" "$result_file" "{\"duration\": $duration, \"exit_code\": $exit_code}"
    
    # Output the actual agent output
    cat "$output_file"
    cat "$error_file" >&2
    
    # Cleanup
    rm -f "$output_file" "$error_file" "$result_file"
    
    return $exit_code
}

# Invalidate agent cache
invalidate_agent_cache() {
    local agent_name="${1:-all}"
    
    if [[ "$agent_name" == "all" ]]; then
        echo "[CACHE] Invalidating all agent caches"
        rm -rf "$AGENT_CACHE"/*
    else
        echo "[CACHE] Invalidating cache for agent: $agent_name"
        rm -rf "$AGENT_CACHE/$agent_name"
    fi
}

# Preload cache for common operations
preload_agent_cache() {
    echo "[CACHE] Preloading agent cache..."
    
    # Common agent operations to cache
    local common_operations=(
        "generic_build_analyzer.sh"
        "unified_error_counter.sh"
        "generic_error_agent.sh analyze"
    )
    
    for op in "${common_operations[@]}"; do
        local agent=$(echo "$op" | cut -d' ' -f1)
        local args=$(echo "$op" | cut -d' ' -f2-)
        
        if [[ -f "$SCRIPT_DIR/$agent" ]]; then
            echo "[CACHE] Preloading: $agent $args"
            execute_agent_cached "$SCRIPT_DIR/$agent" $args >/dev/null 2>&1 || true
        fi
    done
    
    echo "[CACHE] Preload complete"
}

# Show agent cache statistics
show_agent_cache_stats() {
    echo "=== Agent Cache Statistics ==="
    
    # Overall stats from cache manager
    "$SCRIPT_DIR/cache_manager.sh" stats | grep -A20 "agent:"
    
    # Agent-specific stats
    echo ""
    echo "Cached Agents:"
    
    if [[ -d "$AGENT_CACHE" ]]; then
        for agent_dir in "$AGENT_CACHE"/*; do
            if [[ -d "$agent_dir" ]]; then
                local agent_name=$(basename "$agent_dir")
                local cache_count=$(find "$agent_dir" -name "*.cache*" 2>/dev/null | wc -l)
                local cache_size=$(du -sh "$agent_dir" 2>/dev/null | cut -f1)
                
                echo "  $agent_name: $cache_count entries ($cache_size)"
                
                # Show recent cache hits
                local recent_hits=$(find "$agent_dir" -name "*.cache*" -mmin -60 2>/dev/null | wc -l)
                if [[ $recent_hits -gt 0 ]]; then
                    echo "    Recent hits (last hour): $recent_hits"
                fi
            fi
        done
    fi
}

# Wrap all agents in a directory
wrap_all_agents() {
    local target_dir="${1:-$SCRIPT_DIR}"
    local wrapper_dir="$target_dir/cached_agents"
    
    mkdir -p "$wrapper_dir"
    
    echo "[CACHE] Creating cached wrappers for all agents..."
    
    for agent in "$target_dir"/*.sh; do
        if [[ -f "$agent" ]] && [[ "$agent" != *"cache"* ]] && [[ "$agent" != *"wrapper"* ]]; then
            local agent_name=$(basename "$agent")
            local wrapper="$wrapper_dir/cached_$agent_name"
            
            cat > "$wrapper" << EOF
#!/bin/bash
# Auto-generated cache wrapper for $agent_name
source "$SCRIPT_DIR/agent_cache_wrapper.sh"
execute_agent_cached "$agent" "\$@"
EOF
            chmod +x "$wrapper"
            echo "[CACHE] Created wrapper: cached_$agent_name"
        fi
    done
    
    echo "[CACHE] Wrappers created in: $wrapper_dir"
}

# Monitor cache effectiveness
monitor_cache_effectiveness() {
    local duration="${1:-60}"  # Monitor for 60 seconds by default
    
    echo "[CACHE] Monitoring cache effectiveness for ${duration}s..."
    
    local start_time=$(date +%s)
    local initial_hits=$(jq -r '.cache_hits // 0' "$CACHE_STATS" 2>/dev/null || echo 0)
    local initial_misses=$(jq -r '.cache_misses // 0' "$CACHE_STATS" 2>/dev/null || echo 0)
    
    sleep "$duration"
    
    local final_hits=$(jq -r '.cache_hits // 0' "$CACHE_STATS" 2>/dev/null || echo 0)
    local final_misses=$(jq -r '.cache_misses // 0' "$CACHE_STATS" 2>/dev/null || echo 0)
    
    local new_hits=$((final_hits - initial_hits))
    local new_misses=$((final_misses - initial_misses))
    local total_requests=$((new_hits + new_misses))
    
    if [[ $total_requests -gt 0 ]]; then
        local hit_rate=$(echo "scale=2; $new_hits * 100 / $total_requests" | bc)
        echo "[CACHE] Effectiveness Report:"
        echo "  Requests: $total_requests"
        echo "  Hits: $new_hits"
        echo "  Misses: $new_misses"
        echo "  Hit Rate: ${hit_rate}%"
    else
        echo "[CACHE] No cache activity during monitoring period"
    fi
}

# Main function
main() {
    case "${1:-help}" in
        execute)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 execute <agent_path> [args...]"
                exit 1
            fi
            shift
            execute_agent_cached "$@"
            ;;
        invalidate)
            invalidate_agent_cache "${2:-all}"
            ;;
        preload)
            preload_agent_cache
            ;;
        stats)
            show_agent_cache_stats
            ;;
        wrap)
            wrap_all_agents "${2:-$SCRIPT_DIR}"
            ;;
        monitor)
            monitor_cache_effectiveness "${2:-60}"
            ;;
        test)
            # Test caching
            echo "[CACHE] Testing agent caching..."
            
            # Create test agent
            local test_agent=$(mktemp --suffix=.sh)
            cat > "$test_agent" << 'EOF'
#!/bin/bash
echo "Test output: $(date +%s.%N)"
echo "Args: $@"
exit 0
EOF
            chmod +x "$test_agent"
            
            # Test cache miss and hit
            echo "First call (cache miss):"
            execute_agent_cached "$test_agent" test arg1
            
            echo -e "\nSecond call (cache hit):"
            execute_agent_cached "$test_agent" test arg1
            
            rm -f "$test_agent"
            ;;
        *)
            cat << EOF
Agent Cache Wrapper - Intelligent caching for agent executions

Usage: $0 <command> [options]

Commands:
  execute <agent> [args]  - Execute agent with caching
  invalidate [agent]      - Invalidate cache (all or specific)
  preload                 - Preload common operations
  stats                   - Show cache statistics
  wrap [directory]        - Create cached wrappers
  monitor [duration]      - Monitor cache effectiveness
  test                    - Test caching functionality

Environment Variables:
  CACHE_AGENT_RESULTS=true       - Enable agent caching
  AGENT_CACHE_TTL=3600          - Cache TTL in seconds
  CACHE_KEY_STRATEGY=smart      - Key strategy (smart/simple/full)

Examples:
  # Execute agent with caching
  $0 execute ./generic_build_analyzer.sh
  
  # Create cached wrappers
  $0 wrap
  
  # Monitor effectiveness
  $0 monitor 300
EOF
            ;;
    esac
}

# Export functions
export -f generate_agent_cache_key
export -f execute_agent_cached
export -f invalidate_agent_cache

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi