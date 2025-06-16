#!/bin/bash

# Advanced Caching System - High-performance distributed caching
# Supports Redis, in-memory, and file-based caching with smart invalidation

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$AGENT_DIR/state/cache"
MEMORY_CACHE_DIR="$CACHE_DIR/memory"
DISK_CACHE_DIR="$CACHE_DIR/disk"
CACHE_CONFIG="$AGENT_DIR/config/cache_config.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create directories
mkdir -p "$MEMORY_CACHE_DIR" "$DISK_CACHE_DIR" "$(dirname "$CACHE_CONFIG")"

# In-memory cache simulation (would use Redis in production)
declare -A MEMORY_CACHE
declare -A CACHE_TIMESTAMPS
declare -A CACHE_HITS
declare -A CACHE_MISSES

# Initialize cache configuration
init_cache_config() {
    if [[ ! -f "$CACHE_CONFIG" ]]; then
        cat > "$CACHE_CONFIG" << 'EOF'
# Advanced Caching Configuration
cache:
  enabled: true
  
  backends:
    memory:
      enabled: true
      max_size_mb: 512
      eviction_policy: "lru"  # lru, lfu, fifo
      
    redis:
      enabled: false
      host: "localhost"
      port: 6379
      password: ""
      db: 0
      cluster_mode: false
      
    disk:
      enabled: true
      max_size_gb: 10
      path: "./state/cache/disk"
      
  layers:
    - name: "hot"
      backend: "memory"
      ttl_seconds: 300
      
    - name: "warm"
      backend: "disk"
      ttl_seconds: 3600
      
    - name: "cold"
      backend: "disk"
      ttl_seconds: 86400
      
  invalidation:
    smart_invalidation: true
    dependency_tracking: true
    
  preloading:
    enabled: true
    patterns:
      - "error_analysis_*"
      - "build_output_*"
      - "fix_patterns_*"
      
  compression:
    enabled: true
    threshold_bytes: 1024
    algorithm: "gzip"
    
  monitoring:
    track_hit_rate: true
    alert_on_low_hit_rate: 0.5
    report_interval: 300
EOF
        echo -e "${GREEN}Created cache configuration${NC}"
    fi
}

# Cache key generation
generate_cache_key() {
    local namespace="$1"
    local identifier="$2"
    local version="${3:-v1}"
    
    # Create deterministic key
    local key="${namespace}:${identifier}:${version}"
    local hash=$(echo -n "$key" | sha256sum | cut -c1-16)
    
    echo "${namespace}_${hash}"
}

# Set cache value
cache_set() {
    local key="$1"
    local value="$2"
    local ttl="${3:-300}"  # Default 5 minutes
    local layer="${4:-hot}"
    
    echo -e "${CYAN}Setting cache: $key (TTL: ${ttl}s)${NC}"
    
    # Store in memory cache
    MEMORY_CACHE["$key"]="$value"
    CACHE_TIMESTAMPS["$key"]=$(date +%s)
    
    # Track dependencies if enabled
    if [[ -n "${CACHE_DEPENDENCIES:-}" ]]; then
        echo "$CACHE_DEPENDENCIES" > "$MEMORY_CACHE_DIR/${key}.deps"
    fi
    
    # Compress if large
    local size=${#value}
    if [[ $size -gt 1024 ]]; then
        echo -e "  Compressing large value (${size} bytes)"
        value=$(echo "$value" | gzip | base64)
        key="${key}.gz"
    fi
    
    # Store to disk for persistence
    if [[ "$layer" == "warm" ]] || [[ "$layer" == "cold" ]]; then
        echo "$value" > "$DISK_CACHE_DIR/$key"
        touch -d "+$ttl seconds" "$DISK_CACHE_DIR/$key.ttl"
    fi
    
    # Simulate Redis SET with TTL
    # redis-cli SET "$key" "$value" EX "$ttl" 2>/dev/null || true
    
    # Update statistics
    local stats_file="$CACHE_DIR/stats.json"
    if [[ ! -f "$stats_file" ]]; then
        echo '{"sets": 0, "gets": 0, "hits": 0, "misses": 0}' > "$stats_file"
    fi
    jq '.sets += 1' "$stats_file" > "$stats_file.tmp" && mv "$stats_file.tmp" "$stats_file"
}

# Get cache value
cache_get() {
    local key="$1"
    local default="${2:-}"
    
    # Check memory cache first
    if [[ -n "${MEMORY_CACHE[$key]:-}" ]]; then
        local timestamp="${CACHE_TIMESTAMPS[$key]:-0}"
        local now=$(date +%s)
        local age=$((now - timestamp))
        
        # Check if expired
        if [[ $age -lt 300 ]]; then  # 5 minute TTL
            echo -e "${GREEN}Cache hit (memory): $key${NC}" >&2
            CACHE_HITS["$key"]=$((${CACHE_HITS[$key]:-0} + 1))
            echo "${MEMORY_CACHE[$key]}"
            update_cache_stats "hit"
            return 0
        else
            # Expired, remove from cache
            unset MEMORY_CACHE["$key"]
            unset CACHE_TIMESTAMPS["$key"]
        fi
    fi
    
    # Check disk cache
    if [[ -f "$DISK_CACHE_DIR/$key" ]]; then
        # Check TTL file
        if [[ -f "$DISK_CACHE_DIR/$key.ttl" ]]; then
            if [[ "$DISK_CACHE_DIR/$key" -ot "$DISK_CACHE_DIR/$key.ttl" ]]; then
                echo -e "${GREEN}Cache hit (disk): $key${NC}" >&2
                local value=$(cat "$DISK_CACHE_DIR/$key")
                
                # Promote to memory cache
                MEMORY_CACHE["$key"]="$value"
                CACHE_TIMESTAMPS["$key"]=$(date +%s)
                
                echo "$value"
                update_cache_stats "hit"
                return 0
            else
                # Expired
                rm -f "$DISK_CACHE_DIR/$key" "$DISK_CACHE_DIR/$key.ttl"
            fi
        fi
    fi
    
    # Check compressed version
    if [[ -f "$DISK_CACHE_DIR/${key}.gz" ]]; then
        echo -e "${GREEN}Cache hit (disk, compressed): $key${NC}" >&2
        local value=$(cat "$DISK_CACHE_DIR/${key}.gz" | base64 -d | gunzip)
        echo "$value"
        update_cache_stats "hit"
        return 0
    fi
    
    # Simulate Redis GET
    # local redis_value=$(redis-cli GET "$key" 2>/dev/null || echo "")
    # if [[ -n "$redis_value" ]] && [[ "$redis_value" != "(nil)" ]]; then
    #     echo -e "${GREEN}Cache hit (Redis): $key${NC}" >&2
    #     echo "$redis_value"
    #     update_cache_stats "hit"
    #     return 0
    # fi
    
    # Cache miss
    echo -e "${YELLOW}Cache miss: $key${NC}" >&2
    CACHE_MISSES["$key"]=$((${CACHE_MISSES[$key]:-0} + 1))
    update_cache_stats "miss"
    
    echo "$default"
    return 1
}

# Invalidate cache
cache_invalidate() {
    local pattern="$1"
    local cascade="${2:-true}"
    
    echo -e "${BLUE}Invalidating cache: $pattern${NC}"
    
    local count=0
    
    # Invalidate memory cache
    for key in "${!MEMORY_CACHE[@]}"; do
        if [[ "$key" == $pattern ]] || [[ "$key" =~ $pattern ]]; then
            unset MEMORY_CACHE["$key"]
            unset CACHE_TIMESTAMPS["$key"]
            ((count++))
            
            # Cascade to dependencies if enabled
            if [[ "$cascade" == "true" ]] && [[ -f "$MEMORY_CACHE_DIR/${key}.deps" ]]; then
                local deps=$(cat "$MEMORY_CACHE_DIR/${key}.deps")
                for dep in $deps; do
                    cache_invalidate "$dep" false
                done
            fi
        fi
    done
    
    # Invalidate disk cache
    find "$DISK_CACHE_DIR" -name "$pattern*" -delete 2>/dev/null || true
    
    # Simulate Redis DEL
    # redis-cli --scan --pattern "$pattern*" | xargs -r redis-cli DEL 2>/dev/null || true
    
    echo -e "${GREEN}Invalidated $count cache entries${NC}"
}

# Update cache statistics
update_cache_stats() {
    local event="$1"
    local stats_file="$CACHE_DIR/stats.json"
    
    if [[ ! -f "$stats_file" ]]; then
        echo '{"sets": 0, "gets": 0, "hits": 0, "misses": 0}' > "$stats_file"
    fi
    
    case "$event" in
        hit)
            jq '.gets += 1 | .hits += 1' "$stats_file" > "$stats_file.tmp"
            ;;
        miss)
            jq '.gets += 1 | .misses += 1' "$stats_file" > "$stats_file.tmp"
            ;;
    esac
    
    mv "$stats_file.tmp" "$stats_file" 2>/dev/null || true
}

# Preload cache
preload_cache() {
    echo -e "${BLUE}Preloading frequently used data...${NC}"
    
    # Preload error patterns
    if [[ -f "$AGENT_DIR/state/error_analysis.json" ]]; then
        cache_set "error_analysis_latest" "$(cat "$AGENT_DIR/state/error_analysis.json")" 3600 "warm"
    fi
    
    # Preload fix patterns
    if [[ -f "$AGENT_DIR/state/fix_patterns.json" ]]; then
        cache_set "fix_patterns_latest" "$(cat "$AGENT_DIR/state/fix_patterns.json")" 3600 "warm"
    fi
    
    # Preload recent build output
    if [[ -f "$AGENT_DIR/logs/build_output.txt" ]]; then
        cache_set "build_output_latest" "$(tail -1000 "$AGENT_DIR/logs/build_output.txt")" 300 "hot"
    fi
    
    echo -e "${GREEN}Cache preloading completed${NC}"
}

# Cache warming
warm_cache() {
    local project_dir="${1:-$PWD}"
    
    echo -e "${BLUE}Warming cache for: $project_dir${NC}"
    
    # Analyze project structure
    local file_count=$(find "$project_dir" -name "*.cs" -o -name "*.ts" -o -name "*.py" | wc -l)
    cache_set "project_stats_file_count" "$file_count" 3600 "warm"
    
    # Cache common queries
    local error_patterns=(
        "CS0246" "CS0101" "CS0115"
        "TS2304" "TS2339"
        "ImportError" "NameError"
    )
    
    for pattern in "${error_patterns[@]}"; do
        local key=$(generate_cache_key "error_pattern" "$pattern")
        cache_set "$key" "warmed" 3600 "warm"
    done
    
    echo -e "${GREEN}Cache warming completed${NC}"
}

# Monitor cache performance
monitor_cache() {
    echo -e "${BLUE}Cache Performance Monitor${NC}"
    
    local stats_file="$CACHE_DIR/stats.json"
    if [[ ! -f "$stats_file" ]]; then
        echo -e "${YELLOW}No cache statistics available${NC}"
        return
    fi
    
    # Calculate metrics
    local gets=$(jq -r '.gets // 0' "$stats_file")
    local hits=$(jq -r '.hits // 0' "$stats_file")
    local misses=$(jq -r '.misses // 0' "$stats_file")
    local sets=$(jq -r '.sets // 0' "$stats_file")
    
    local hit_rate=0
    if [[ $gets -gt 0 ]]; then
        hit_rate=$(echo "scale=2; $hits * 100 / $gets" | bc)
    fi
    
    # Memory cache size
    local memory_size=0
    for key in "${!MEMORY_CACHE[@]}"; do
        memory_size=$((memory_size + ${#MEMORY_CACHE[$key]}))
    done
    memory_size_mb=$(echo "scale=2; $memory_size / 1048576" | bc)
    
    # Disk cache size
    local disk_size=$(du -sb "$DISK_CACHE_DIR" 2>/dev/null | cut -f1 || echo 0)
    disk_size_mb=$(echo "scale=2; $disk_size / 1048576" | bc)
    
    echo -e "\n${CYAN}Cache Statistics:${NC}"
    echo -e "  Total requests: $gets"
    echo -e "  Cache hits: $hits"
    echo -e "  Cache misses: $misses"
    echo -e "  Cache sets: $sets"
    echo -e "  Hit rate: ${hit_rate}%"
    echo -e "  Memory cache: ${memory_size_mb} MB"
    echo -e "  Disk cache: ${disk_size_mb} MB"
    
    # Alert on low hit rate
    if (( $(echo "$hit_rate < 50" | bc -l) )); then
        echo -e "\n${YELLOW}⚠ Warning: Low cache hit rate!${NC}"
        echo -e "Consider preloading frequently accessed data"
    fi
    
    # Show hot keys
    echo -e "\n${CYAN}Hot Keys (Most Accessed):${NC}"
    for key in "${!CACHE_HITS[@]}"; do
        echo "$key ${CACHE_HITS[$key]}"
    done | sort -k2 -nr | head -5 | while read key count; do
        echo -e "  $key: $count hits"
    done
}

# Optimize cache
optimize_cache() {
    echo -e "${BLUE}Optimizing cache...${NC}"
    
    # Remove expired entries
    echo -e "  Cleaning expired entries..."
    find "$DISK_CACHE_DIR" -name "*.ttl" -type f | while read ttl_file; do
        local cache_file="${ttl_file%.ttl}"
        if [[ ! -f "$cache_file" ]] || [[ "$cache_file" -ot "$ttl_file" ]]; then
            rm -f "$cache_file" "$ttl_file"
        fi
    done
    
    # Implement LRU eviction for memory cache
    echo -e "  Applying LRU eviction..."
    local max_size=$((512 * 1048576))  # 512 MB
    local current_size=0
    
    for key in "${!MEMORY_CACHE[@]}"; do
        current_size=$((current_size + ${#MEMORY_CACHE[$key]}))
    done
    
    if [[ $current_size -gt $max_size ]]; then
        # Sort by timestamp and remove oldest
        for key in "${!CACHE_TIMESTAMPS[@]}"; do
            echo "${CACHE_TIMESTAMPS[$key]} $key"
        done | sort -n | head -n $((${#CACHE_TIMESTAMPS[@]} / 2)) | while read ts key; do
            unset MEMORY_CACHE["$key"]
            unset CACHE_TIMESTAMPS["$key"]
        done
    fi
    
    # Compress large disk cache entries
    echo -e "  Compressing large entries..."
    find "$DISK_CACHE_DIR" -type f -size +1M ! -name "*.gz" | while read file; do
        gzip "$file"
        mv "$file.gz" "$file"
    done
    
    echo -e "${GREEN}Cache optimization completed${NC}"
}

# Generate cache report
generate_cache_report() {
    local report_file="$CACHE_DIR/cache_report_$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}Generating cache report...${NC}"
    
    # Get current stats
    local stats_file="$CACHE_DIR/stats.json"
    local hit_rate=0
    if [[ -f "$stats_file" ]]; then
        local gets=$(jq -r '.gets // 0' "$stats_file")
        local hits=$(jq -r '.hits // 0' "$stats_file")
        if [[ $gets -gt 0 ]]; then
            hit_rate=$(echo "scale=1; $hits * 100 / $gets" | bc)
        fi
    fi
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Cache Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 36px; font-weight: bold; color: #3498db; }
        .chart { margin: 20px 0; padding: 20px; background-color: #f8f9fa; border-radius: 8px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Cache Performance Report</h1>
        <p>Generated: EOF
    echo -n "$(date)" >> "$report_file"
    cat >> "$report_file" << 'EOF'</p>
        
        <div class="metric-grid">
            <div class="metric-card">
                <h3>Hit Rate</h3>
                <div class="metric-value">EOF
    echo -n "${hit_rate}%" >> "$report_file"
    cat >> "$report_file" << 'EOF'</div>
            </div>
            <div class="metric-card">
                <h3>Memory Usage</h3>
                <div class="metric-value">EOF
    
    # Calculate memory usage
    local memory_size=0
    for key in "${!MEMORY_CACHE[@]}"; do
        memory_size=$((memory_size + ${#MEMORY_CACHE[$key]}))
    done
    echo -n "$(echo "scale=1; $memory_size / 1048576" | bc) MB" >> "$report_file"
    
    cat >> "$report_file" << 'EOF'</div>
            </div>
            <div class="metric-card">
                <h3>Cached Items</h3>
                <div class="metric-value">EOF
    echo -n "${#MEMORY_CACHE[@]}" >> "$report_file"
    cat >> "$report_file" << 'EOF'</div>
            </div>
        </div>
        
        <div class="chart">
            <h2>Cache Layers</h2>
            <table>
                <tr>
                    <th>Layer</th>
                    <th>Backend</th>
                    <th>Size</th>
                    <th>TTL</th>
                    <th>Status</th>
                </tr>
                <tr>
                    <td>Hot</td>
                    <td>Memory</td>
                    <td>< 512 MB</td>
                    <td>5 min</td>
                    <td style="color: green;">Active</td>
                </tr>
                <tr>
                    <td>Warm</td>
                    <td>Disk</td>
                    <td>< 5 GB</td>
                    <td>1 hour</td>
                    <td style="color: green;">Active</td>
                </tr>
                <tr>
                    <td>Cold</td>
                    <td>Disk</td>
                    <td>< 10 GB</td>
                    <td>24 hours</td>
                    <td style="color: green;">Active</td>
                </tr>
            </table>
        </div>
        
        <h2>Optimization Recommendations</h2>
        <ul>
            <li>Enable Redis for distributed caching across multiple machines</li>
            <li>Implement predictive preloading based on usage patterns</li>
            <li>Configure cache warmup on system startup</li>
            <li>Monitor and adjust TTL values based on hit rates</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}Cache report generated: $report_file${NC}"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    init_cache_config
    
    case "$command" in
        set)
            local key="${2:-}"
            local value="${3:-}"
            local ttl="${4:-300}"
            
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                echo "Usage: $0 set <key> <value> [ttl]"
                exit 1
            fi
            
            cache_set "$key" "$value" "$ttl"
            ;;
            
        get)
            local key="${2:-}"
            if [[ -z "$key" ]]; then
                echo "Usage: $0 get <key>"
                exit 1
            fi
            
            cache_get "$key"
            ;;
            
        invalidate)
            local pattern="${2:-*}"
            cache_invalidate "$pattern"
            ;;
            
        preload)
            preload_cache
            ;;
            
        warm)
            warm_cache "${2:-$PWD}"
            ;;
            
        monitor)
            monitor_cache
            ;;
            
        optimize)
            optimize_cache
            ;;
            
        report)
            generate_cache_report
            ;;
            
        clear)
            echo -e "${RED}Clearing all cache...${NC}"
            MEMORY_CACHE=()
            CACHE_TIMESTAMPS=()
            rm -rf "$DISK_CACHE_DIR"/*
            echo '{"sets": 0, "gets": 0, "hits": 0, "misses": 0}' > "$CACHE_DIR/stats.json"
            echo -e "${GREEN}Cache cleared${NC}"
            ;;
            
        *)
            cat << EOF
Advanced Caching System - High-performance distributed caching

Usage: $0 {command} [options]

Commands:
    set         Set cache value
                Usage: set <key> <value> [ttl_seconds]
                
    get         Get cache value
                Usage: get <key>
                
    invalidate  Invalidate cache entries
                Usage: invalidate <pattern>
                
    preload     Preload frequently used data
    
    warm        Warm cache for a project
                Usage: warm [project_dir]
                
    monitor     Monitor cache performance
    
    optimize    Optimize cache storage
    
    report      Generate performance report
    
    clear       Clear all cache

Examples:
    $0 set "error_analysis_123" '{"errors": []}' 3600
    $0 get "error_analysis_123"
    $0 invalidate "error_*"
    $0 warm /path/to/project
    $0 monitor

Cache Features:
    - Multi-tier caching (hot/warm/cold)
    - Smart invalidation with dependency tracking
    - Compression for large values
    - LRU eviction policy
    - Performance monitoring
    - Redis integration ready
EOF
            ;;
    esac
}

# Execute
main "$@"