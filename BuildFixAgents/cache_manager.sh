#!/bin/bash

# Cache Manager - Comprehensive caching system for all BuildFixAgents operations
# Handles build output, agent results, and analysis caching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_ROOT="$SCRIPT_DIR/state/cache"
CACHE_DB="$CACHE_ROOT/cache_index.db"
CACHE_STATS="$CACHE_ROOT/cache_stats.json"

# Cache directories
BUILD_CACHE="$CACHE_ROOT/build"
AGENT_CACHE="$CACHE_ROOT/agents"
ANALYSIS_CACHE="$CACHE_ROOT/analysis"
RESULT_CACHE="$CACHE_ROOT/results"

# Configuration
CACHE_TTL=${CACHE_TTL:-3600}  # 1 hour default
MAX_CACHE_SIZE=${MAX_CACHE_SIZE:-1073741824}  # 1GB default
ENABLE_COMPRESSION=${ENABLE_COMPRESSION:-true}
CACHE_STRATEGY=${CACHE_STRATEGY:-"lru"}  # lru, fifo, lfu

# Create directories
mkdir -p "$BUILD_CACHE" "$AGENT_CACHE" "$ANALYSIS_CACHE" "$RESULT_CACHE"

# Initialize cache database
init_cache_db() {
    if [[ ! -f "$CACHE_DB" ]]; then
        cat > "$CACHE_DB" << 'EOF'
# Cache Index Database
# Format: cache_key|cache_type|file_path|created_time|last_access|access_count|size|metadata
EOF
    fi
    
    if [[ ! -f "$CACHE_STATS" ]]; then
        echo '{
            "total_entries": 0,
            "total_size": 0,
            "cache_hits": 0,
            "cache_misses": 0,
            "evictions": 0,
            "compression_ratio": 0
        }' > "$CACHE_STATS"
    fi
}

# Generate cache key
generate_cache_key() {
    local input="$1"
    local context="${2:-}"
    
    # Create deterministic key
    echo -n "${input}${context}" | md5sum | cut -d' ' -f1
}

# Check cache validity
is_cache_valid() {
    local cache_file="$1"
    local ttl="${2:-$CACHE_TTL}"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
    
    if [[ $file_age -gt $ttl ]]; then
        return 1
    fi
    
    return 0
}

# Cache build output
cache_build_output() {
    local build_file="${1:-build_output.txt}"
    local metadata="${2:-{}}"
    
    if [[ ! -f "$build_file" ]]; then
        echo "[CACHE] Build file not found: $build_file"
        return 1
    fi
    
    local file_hash=$(md5sum "$build_file" | cut -d' ' -f1)
    local cache_key="build_${file_hash}"
    local cache_file="$BUILD_CACHE/${cache_key}.cache"
    
    # Check if already cached
    if is_cache_valid "$cache_file"; then
        echo "[CACHE] Build output already cached: $cache_key"
        return 0
    fi
    
    echo "[CACHE] Caching build output: $cache_key"
    
    # Copy and optionally compress
    if [[ "$ENABLE_COMPRESSION" == "true" ]]; then
        gzip -c "$build_file" > "${cache_file}.gz"
        cache_file="${cache_file}.gz"
    else
        cp "$build_file" "$cache_file"
    fi
    
    # Update database
    local size=$(stat -c %s "$cache_file" 2>/dev/null || stat -f %z "$cache_file" 2>/dev/null || echo 0)
    local timestamp=$(date +%s)
    
    echo "${cache_key}|build|${cache_file}|${timestamp}|${timestamp}|1|${size}|${metadata}" >> "$CACHE_DB"
    
    # Update stats
    update_cache_stats "add" "$size"
    
    echo "$cache_key"
}

# Get cached build output
get_cached_build() {
    local build_file="${1:-build_output.txt}"
    
    if [[ ! -f "$build_file" ]]; then
        update_cache_stats "miss"
        return 1
    fi
    
    local file_hash=$(md5sum "$build_file" | cut -d' ' -f1)
    local cache_key="build_${file_hash}"
    local cache_file="$BUILD_CACHE/${cache_key}.cache"
    
    # Check compressed version first
    if [[ -f "${cache_file}.gz" ]]; then
        cache_file="${cache_file}.gz"
    fi
    
    if is_cache_valid "$cache_file"; then
        echo "[CACHE] Build cache hit: $cache_key"
        update_cache_stats "hit"
        update_access_time "$cache_key"
        
        # Return decompressed if needed
        if [[ "$cache_file" =~ \.gz$ ]]; then
            gunzip -c "$cache_file"
        else
            cat "$cache_file"
        fi
        return 0
    else
        echo "[CACHE] Build cache miss: $cache_key" >&2
        update_cache_stats "miss"
        return 1
    fi
}

# Cache analysis results
cache_analysis() {
    local analysis_type="$1"
    local analysis_file="$2"
    local context="${3:-}"
    
    if [[ ! -f "$analysis_file" ]]; then
        return 1
    fi
    
    local content_hash=$(md5sum "$analysis_file" | cut -d' ' -f1)
    local cache_key=$(generate_cache_key "${analysis_type}_${content_hash}" "$context")
    local cache_file="$ANALYSIS_CACHE/${cache_key}.json"
    
    echo "[CACHE] Caching analysis: $analysis_type ($cache_key)"
    
    if [[ "$ENABLE_COMPRESSION" == "true" ]]; then
        gzip -c "$analysis_file" > "${cache_file}.gz"
        cache_file="${cache_file}.gz"
    else
        cp "$analysis_file" "$cache_file"
    fi
    
    # Update database
    local size=$(stat -c %s "$cache_file" 2>/dev/null || stat -f %z "$cache_file" 2>/dev/null || echo 0)
    local timestamp=$(date +%s)
    
    echo "${cache_key}|analysis|${cache_file}|${timestamp}|${timestamp}|1|${size}|type=${analysis_type}" >> "$CACHE_DB"
    
    update_cache_stats "add" "$size"
    echo "$cache_key"
}

# Get cached analysis
get_cached_analysis() {
    local analysis_type="$1"
    local context="${2:-}"
    local ttl="${3:-$CACHE_TTL}"
    
    # Search for matching cache entries
    local cache_entries=$(grep "|analysis|" "$CACHE_DB" 2>/dev/null | grep "type=${analysis_type}" || true)
    
    if [[ -z "$cache_entries" ]]; then
        update_cache_stats "miss"
        return 1
    fi
    
    # Find most recent valid cache
    while IFS='|' read -r key type file created accessed count size meta; do
        if is_cache_valid "$file" "$ttl"; then
            echo "[CACHE] Analysis cache hit: $key"
            update_cache_stats "hit"
            update_access_time "$key"
            
            if [[ "$file" =~ \.gz$ ]]; then
                gunzip -c "$file"
            else
                cat "$file"
            fi
            return 0
        fi
    done <<< "$cache_entries"
    
    update_cache_stats "miss"
    return 1
}

# Cache agent results
cache_agent_result() {
    local agent_name="$1"
    local input_hash="$2"
    local result_file="$3"
    local metadata="${4:-{}}"
    
    if [[ ! -f "$result_file" ]]; then
        return 1
    fi
    
    local cache_key="${agent_name}_${input_hash}"
    local cache_dir="$AGENT_CACHE/$agent_name"
    local cache_file="$cache_dir/${input_hash}.cache"
    
    mkdir -p "$cache_dir"
    
    echo "[CACHE] Caching agent result: $agent_name ($input_hash)"
    
    if [[ "$ENABLE_COMPRESSION" == "true" ]]; then
        gzip -c "$result_file" > "${cache_file}.gz"
        cache_file="${cache_file}.gz"
    else
        cp "$result_file" "$cache_file"
    fi
    
    # Update database
    local size=$(stat -c %s "$cache_file" 2>/dev/null || stat -f %z "$cache_file" 2>/dev/null || echo 0)
    local timestamp=$(date +%s)
    
    echo "${cache_key}|agent|${cache_file}|${timestamp}|${timestamp}|1|${size}|agent=${agent_name},${metadata}" >> "$CACHE_DB"
    
    update_cache_stats "add" "$size"
}

# Get cached agent result
get_cached_agent_result() {
    local agent_name="$1"
    local input_hash="$2"
    local ttl="${3:-$CACHE_TTL}"
    
    local cache_key="${agent_name}_${input_hash}"
    local cache_file="$AGENT_CACHE/$agent_name/${input_hash}.cache"
    
    # Check compressed version
    if [[ -f "${cache_file}.gz" ]]; then
        cache_file="${cache_file}.gz"
    fi
    
    if is_cache_valid "$cache_file" "$ttl"; then
        echo "[CACHE] Agent cache hit: $cache_key"
        update_cache_stats "hit"
        update_access_time "$cache_key"
        
        if [[ "$cache_file" =~ \.gz$ ]]; then
            gunzip -c "$cache_file"
        else
            cat "$cache_file"
        fi
        return 0
    else
        update_cache_stats "miss"
        return 1
    fi
}

# Update cache statistics
update_cache_stats() {
    local operation="$1"
    local size="${2:-0}"
    
    case "$operation" in
        "hit")
            jq '.cache_hits += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp" && mv "$CACHE_STATS.tmp" "$CACHE_STATS"
            ;;
        "miss")
            jq '.cache_misses += 1' "$CACHE_STATS" > "$CACHE_STATS.tmp" && mv "$CACHE_STATS.tmp" "$CACHE_STATS"
            ;;
        "add")
            jq --argjson size "$size" '.total_entries += 1 | .total_size += $size' "$CACHE_STATS" > "$CACHE_STATS.tmp" && \
                mv "$CACHE_STATS.tmp" "$CACHE_STATS"
            ;;
        "evict")
            jq --argjson size "$size" '.evictions += 1 | .total_entries -= 1 | .total_size -= $size' "$CACHE_STATS" > "$CACHE_STATS.tmp" && \
                mv "$CACHE_STATS.tmp" "$CACHE_STATS"
            ;;
    esac
}

# Update access time for LRU
update_access_time() {
    local cache_key="$1"
    local timestamp=$(date +%s)
    
    # Update access time and count in database
    local temp_db=$(mktemp)
    while IFS='|' read -r key type file created accessed count size meta; do
        if [[ "$key" == "$cache_key" ]]; then
            echo "${key}|${type}|${file}|${created}|${timestamp}|$((count + 1))|${size}|${meta}"
        else
            echo "${key}|${type}|${file}|${created}|${accessed}|${count}|${size}|${meta}"
        fi
    done < "$CACHE_DB" > "$temp_db"
    
    mv "$temp_db" "$CACHE_DB"
}

# Cache eviction
evict_cache() {
    local space_needed="${1:-0}"
    
    echo "[CACHE] Running cache eviction (strategy: $CACHE_STRATEGY)"
    
    local current_size=$(jq -r '.total_size' "$CACHE_STATS")
    local target_size=$((MAX_CACHE_SIZE - space_needed))
    
    if [[ $current_size -le $target_size ]]; then
        return 0
    fi
    
    # Sort entries based on strategy
    local sort_cmd
    case "$CACHE_STRATEGY" in
        "lru")
            sort_cmd="sort -t'|' -k5 -n"  # Sort by last access time
            ;;
        "fifo")
            sort_cmd="sort -t'|' -k4 -n"  # Sort by creation time
            ;;
        "lfu")
            sort_cmd="sort -t'|' -k6 -n"  # Sort by access count
            ;;
    esac
    
    # Evict entries until we have enough space
    grep -v "^#" "$CACHE_DB" | $sort_cmd | while IFS='|' read -r key type file created accessed count size meta; do
        if [[ $current_size -le $target_size ]]; then
            break
        fi
        
        echo "[CACHE] Evicting: $key (size: $size)"
        rm -f "$file"
        
        # Remove from database
        grep -v "^${key}|" "$CACHE_DB" > "$CACHE_DB.tmp" && mv "$CACHE_DB.tmp" "$CACHE_DB"
        
        update_cache_stats "evict" "$size"
        current_size=$((current_size - size))
    done
}

# Clear specific cache type
clear_cache() {
    local cache_type="${1:-all}"
    
    echo "[CACHE] Clearing cache: $cache_type"
    
    case "$cache_type" in
        "build")
            rm -rf "$BUILD_CACHE"/*
            ;;
        "agent")
            rm -rf "$AGENT_CACHE"/*
            ;;
        "analysis")
            rm -rf "$ANALYSIS_CACHE"/*
            ;;
        "result")
            rm -rf "$RESULT_CACHE"/*
            ;;
        "all")
            rm -rf "$CACHE_ROOT"/*
            init_cache_db
            ;;
    esac
    
    # Update database
    if [[ "$cache_type" != "all" ]]; then
        grep -v "|${cache_type}|" "$CACHE_DB" > "$CACHE_DB.tmp" && mv "$CACHE_DB.tmp" "$CACHE_DB" || true
    else
        echo "# Cache Index Database" > "$CACHE_DB"
        echo "# Format: cache_key|cache_type|file_path|created_time|last_access|access_count|size|metadata" >> "$CACHE_DB"
    fi
    
    # Reset stats
    echo '{
        "total_entries": 0,
        "total_size": 0,
        "cache_hits": 0,
        "cache_misses": 0,
        "evictions": 0,
        "compression_ratio": 0
    }' > "$CACHE_STATS"
}

# Show cache statistics
show_cache_stats() {
    echo "=== Cache Manager Statistics ==="
    echo "Cache Root: $CACHE_ROOT"
    echo ""
    
    if [[ -f "$CACHE_STATS" ]]; then
        jq -r '
            "Total Entries: \(.total_entries)",
            "Total Size: \(.total_size | tonumber / 1048576 | floor) MB",
            "Cache Hits: \(.cache_hits)",
            "Cache Misses: \(.cache_misses)",
            "Hit Rate: \(if (.cache_hits + .cache_misses) > 0 then (.cache_hits * 100 / (.cache_hits + .cache_misses) | floor) else 0 end)%",
            "Evictions: \(.evictions)"
        ' "$CACHE_STATS"
    fi
    
    echo ""
    echo "Cache Distribution:"
    for cache_type in build agent analysis result; do
        local count=$(grep -c "|${cache_type}|" "$CACHE_DB" 2>/dev/null || echo 0)
        local size=$(du -sh "$CACHE_ROOT/$cache_type" 2>/dev/null | cut -f1 || echo "0")
        echo "  $cache_type: $count entries ($size)"
    done
    
    echo ""
    echo "Top 10 Most Accessed:"
    grep -v "^#" "$CACHE_DB" 2>/dev/null | sort -t'|' -k6 -nr | head -10 | while IFS='|' read -r key type file created accessed count size meta; do
        echo "  $key ($type): $count accesses"
    done
}

# Warm up cache with common patterns
warmup_cache() {
    echo "[CACHE] Warming up cache..."
    
    # Pre-cache common analysis patterns
    if [[ -f "build_output.txt" ]]; then
        cache_build_output "build_output.txt"
    fi
    
    # Pre-cache common error patterns if pattern learning is available
    if [[ -f "$SCRIPT_DIR/pattern_learning_db.sh" ]]; then
        source "$SCRIPT_DIR/pattern_learning_db.sh"
        
        # Get top error codes
        local top_errors=$(jq -r '.error_map | to_entries | sort_by(-.value | length) | .[0:10] | .[].key' "$INDEX_FILE" 2>/dev/null || true)
        
        for error_code in $top_errors; do
            echo "[CACHE] Pre-caching patterns for $error_code"
            # This would cache pattern lookups
        done
    fi
    
    echo "[CACHE] Warmup complete"
}

# Main function
main() {
    init_cache_db
    
    case "${1:-help}" in
        cache-build)
            cache_build_output "${2:-build_output.txt}" "${3:-{}}"
            ;;
        get-build)
            get_cached_build "${2:-build_output.txt}"
            ;;
        cache-analysis)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 cache-analysis <type> <file> [context]"
                exit 1
            fi
            cache_analysis "$2" "$3" "${4:-}"
            ;;
        get-analysis)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 get-analysis <type> [context] [ttl]"
                exit 1
            fi
            get_cached_analysis "$2" "${3:-}" "${4:-$CACHE_TTL}"
            ;;
        cache-agent)
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 cache-agent <agent> <hash> <file> [metadata]"
                exit 1
            fi
            cache_agent_result "$2" "$3" "$4" "${5:-{}}"
            ;;
        get-agent)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 get-agent <agent> <hash> [ttl]"
                exit 1
            fi
            get_cached_agent_result "$2" "$3" "${4:-$CACHE_TTL}"
            ;;
        evict)
            evict_cache "${2:-0}"
            ;;
        clear)
            clear_cache "${2:-all}"
            ;;
        stats)
            show_cache_stats
            ;;
        warmup)
            warmup_cache
            ;;
        *)
            cat << EOF
Cache Manager - Comprehensive caching for BuildFixAgents

Usage: $0 <command> [options]

Commands:
  cache-build [file] [metadata]      - Cache build output
  get-build [file]                   - Get cached build output
  cache-analysis <type> <file> [ctx] - Cache analysis results
  get-analysis <type> [ctx] [ttl]    - Get cached analysis
  cache-agent <name> <hash> <file>   - Cache agent result
  get-agent <name> <hash> [ttl]      - Get cached agent result
  evict [space_needed]               - Run cache eviction
  clear [type]                       - Clear cache (build/agent/analysis/all)
  stats                              - Show cache statistics
  warmup                             - Warm up cache

Environment Variables:
  CACHE_TTL=3600                     - Cache time-to-live (seconds)
  MAX_CACHE_SIZE=1073741824          - Max cache size (bytes)
  ENABLE_COMPRESSION=true            - Enable gzip compression
  CACHE_STRATEGY=lru                 - Eviction strategy (lru/fifo/lfu)

Examples:
  # Cache build output
  $0 cache-build build_output.txt
  
  # Get cached analysis
  $0 get-analysis error_analysis
  
  # Show statistics
  $0 stats
EOF
            ;;
    esac
}

# Export functions for use by other scripts
export -f generate_cache_key
export -f is_cache_valid
export -f cache_build_output
export -f get_cached_build
export -f cache_analysis
export -f get_cached_analysis
export -f cache_agent_result
export -f get_cached_agent_result

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi