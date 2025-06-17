#!/bin/bash

# Connection Pooler - Manages pools of persistent connections for external services
# Reduces connection overhead and improves performance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/connection_pool"
POOLS_FILE="$STATE_DIR/pools.json"
CONNECTIONS_DIR="$STATE_DIR/connections"
METRICS_FILE="$STATE_DIR/pool_metrics.json"

# Configuration
DEFAULT_POOL_SIZE=${DEFAULT_POOL_SIZE:-10}
MIN_POOL_SIZE=${MIN_POOL_SIZE:-2}
MAX_POOL_SIZE=${MAX_POOL_SIZE:-50}
CONNECTION_TIMEOUT=${CONNECTION_TIMEOUT:-30}
IDLE_TIMEOUT=${IDLE_TIMEOUT:-300}
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-60}
ENABLE_CONNECTION_REUSE=${ENABLE_CONNECTION_REUSE:-true}

# Create directories
mkdir -p "$STATE_DIR" "$CONNECTIONS_DIR"

# Initialize pool tracking
init_pools() {
    if [[ ! -f "$POOLS_FILE" ]]; then
        cat > "$POOLS_FILE" << EOF
{
    "version": "1.0",
    "pools": {},
    "global_settings": {
        "max_total_connections": 200,
        "enable_multiplexing": true,
        "connection_reuse": true
    }
}
EOF
    fi
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        cat > "$METRICS_FILE" << EOF
{
    "total_connections": 0,
    "active_connections": 0,
    "idle_connections": 0,
    "failed_connections": 0,
    "reused_connections": 0,
    "connection_wait_time_ms": 0,
    "pool_efficiency": 0
}
EOF
    fi
}

# Create a connection pool
create_pool() {
    local pool_name="$1"
    local service_type="$2"
    local config="${3:-{}}"
    
    echo "[POOL] Creating pool: $pool_name ($service_type)"
    
    # Parse config
    local pool_size=$(echo "$config" | jq -r '.size // '$DEFAULT_POOL_SIZE'')
    local min_size=$(echo "$config" | jq -r '.min_size // '$MIN_POOL_SIZE'')
    local max_size=$(echo "$config" | jq -r '.max_size // '$MAX_POOL_SIZE'')
    
    # Create pool directory
    local pool_dir="$CONNECTIONS_DIR/$pool_name"
    mkdir -p "$pool_dir"
    
    # Update pools file
    jq --arg name "$pool_name" \
       --arg type "$service_type" \
       --argjson size "$pool_size" \
       --argjson min "$min_size" \
       --argjson max "$max_size" \
       --argjson config "$config" \
       '.pools[$name] = {
           "type": $type,
           "size": $size,
           "min_size": $min,
           "max_size": $max,
           "created_at": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
           "config": $config,
           "connections": [],
           "stats": {
               "total_requests": 0,
               "cache_hits": 0,
               "timeouts": 0,
               "errors": 0
           }
       }' "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
    
    # Initialize connections
    initialize_connections "$pool_name" "$service_type" "$pool_size"
}

# Initialize connections for a pool
initialize_connections() {
    local pool_name="$1"
    local service_type="$2"
    local pool_size="$3"
    
    echo "[POOL] Initializing $pool_size connections for $pool_name"
    
    case "$service_type" in
        "http")
            init_http_connections "$pool_name" "$pool_size"
            ;;
        "database")
            init_database_connections "$pool_name" "$pool_size"
            ;;
        "cache")
            init_cache_connections "$pool_name" "$pool_size"
            ;;
        "api")
            init_api_connections "$pool_name" "$pool_size"
            ;;
        *)
            echo "[POOL] Unknown service type: $service_type"
            return 1
            ;;
    esac
}

# Initialize HTTP connections (using curl with connection reuse)
init_http_connections() {
    local pool_name="$1"
    local pool_size="$2"
    local pool_dir="$CONNECTIONS_DIR/$pool_name"
    
    for ((i=1; i<=pool_size; i++)); do
        local conn_id="${pool_name}_http_${i}"
        local conn_file="$pool_dir/conn_${i}.conf"
        
        # Create connection config
        cat > "$conn_file" << EOF
{
    "id": "$conn_id",
    "type": "http",
    "status": "idle",
    "created_at": "$(date -Iseconds)",
    "last_used": null,
    "use_count": 0,
    "curl_opts": [
        "--keepalive-time", "120",
        "--compressed",
        "--http2",
        "--tcp-nodelay"
    ]
}
EOF
        
        # Add to pool
        add_connection_to_pool "$pool_name" "$conn_id" "$conn_file"
    done
}

# Initialize database connections (simulated)
init_database_connections() {
    local pool_name="$1"
    local pool_size="$2"
    local pool_dir="$CONNECTIONS_DIR/$pool_name"
    
    # Get database config
    local db_config=$(jq -r --arg name "$pool_name" '.pools[$name].config' "$POOLS_FILE")
    local host=$(echo "$db_config" | jq -r '.host // "localhost"')
    local port=$(echo "$db_config" | jq -r '.port // 5432')
    local database=$(echo "$db_config" | jq -r '.database // "default"')
    
    for ((i=1; i<=pool_size; i++)); do
        local conn_id="${pool_name}_db_${i}"
        local conn_file="$pool_dir/conn_${i}.conf"
        
        # Create connection config
        cat > "$conn_file" << EOF
{
    "id": "$conn_id",
    "type": "database",
    "status": "idle",
    "created_at": "$(date -Iseconds)",
    "last_used": null,
    "use_count": 0,
    "connection_string": "host=$host port=$port dbname=$database",
    "prepared_statements": {}
}
EOF
        
        add_connection_to_pool "$pool_name" "$conn_id" "$conn_file"
    done
}

# Initialize cache connections
init_cache_connections() {
    local pool_name="$1"
    local pool_size="$2"
    local pool_dir="$CONNECTIONS_DIR/$pool_name"
    
    local cache_config=$(jq -r --arg name "$pool_name" '.pools[$name].config' "$POOLS_FILE")
    local host=$(echo "$cache_config" | jq -r '.host // "localhost"')
    local port=$(echo "$cache_config" | jq -r '.port // 6379')
    
    for ((i=1; i<=pool_size; i++)); do
        local conn_id="${pool_name}_cache_${i}"
        local conn_file="$pool_dir/conn_${i}.conf"
        local socket_file="$pool_dir/conn_${i}.sock"
        
        # Create persistent connection using netcat
        cat > "$conn_file" << EOF
{
    "id": "$conn_id",
    "type": "cache",
    "status": "idle",
    "created_at": "$(date -Iseconds)",
    "last_used": null,
    "use_count": 0,
    "host": "$host",
    "port": $port,
    "socket": "$socket_file"
}
EOF
        
        add_connection_to_pool "$pool_name" "$conn_id" "$conn_file"
    done
}

# Initialize API connections
init_api_connections() {
    local pool_name="$1"
    local pool_size="$2"
    local pool_dir="$CONNECTIONS_DIR/$pool_name"
    
    local api_config=$(jq -r --arg name "$pool_name" '.pools[$name].config' "$POOLS_FILE")
    local base_url=$(echo "$api_config" | jq -r '.base_url // ""')
    local auth_token=$(echo "$api_config" | jq -r '.auth_token // ""')
    
    for ((i=1; i<=pool_size; i++)); do
        local conn_id="${pool_name}_api_${i}"
        local conn_file="$pool_dir/conn_${i}.conf"
        local cookie_jar="$pool_dir/conn_${i}.cookies"
        
        # Create connection config
        cat > "$conn_file" << EOF
{
    "id": "$conn_id",
    "type": "api",
    "status": "idle",
    "created_at": "$(date -Iseconds)",
    "last_used": null,
    "use_count": 0,
    "base_url": "$base_url",
    "cookie_jar": "$cookie_jar",
    "headers": {
        "Authorization": "Bearer $auth_token",
        "Accept": "application/json",
        "Connection": "keep-alive"
    }
}
EOF
        
        # Initialize cookie jar
        touch "$cookie_jar"
        
        add_connection_to_pool "$pool_name" "$conn_id" "$conn_file"
    done
}

# Add connection to pool
add_connection_to_pool() {
    local pool_name="$1"
    local conn_id="$2"
    local conn_file="$3"
    
    jq --arg pool "$pool_name" \
       --arg id "$conn_id" \
       --arg file "$conn_file" \
       '.pools[$pool].connections += [{
           "id": $id,
           "config_file": $file,
           "status": "idle",
           "acquired_by": null
       }]' "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
}

# Acquire a connection from pool
acquire_connection() {
    local pool_name="$1"
    local requester="${2:-anonymous}"
    local timeout="${3:-$CONNECTION_TIMEOUT}"
    
    local start_time=$(date +%s)
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        # Try to get an idle connection
        local conn_info=$(jq -r --arg pool "$pool_name" '
            .pools[$pool].connections[] | 
            select(.status == "idle") | 
            .id + "|" + .config_file
        ' "$POOLS_FILE" 2>/dev/null | head -1)
        
        if [[ -n "$conn_info" ]]; then
            local conn_id=$(echo "$conn_info" | cut -d'|' -f1)
            local conn_file=$(echo "$conn_info" | cut -d'|' -f2)
            
            # Mark as active
            if mark_connection_active "$pool_name" "$conn_id" "$requester"; then
                echo "[POOL] Connection acquired: $conn_id"
                
                # Update metrics
                local wait_time=$(($(date +%s) - start_time))
                update_metric "connection_wait_time_ms" $((wait_time * 1000))
                increment_metric "active_connections"
                decrement_metric "idle_connections"
                
                # Return connection info
                cat "$conn_file"
                return 0
            fi
        fi
        
        # Check if we can grow the pool
        if can_grow_pool "$pool_name"; then
            echo "[POOL] Growing pool $pool_name"
            grow_pool "$pool_name"
        else

            # Wait and retry
            sleep 0.5
        fi
        
        elapsed=$(($(date +%s) - start_time))
    done
    
    echo "[POOL] Failed to acquire connection from $pool_name (timeout)"
    increment_metric "failed_connections"
    return 1
}

# Mark connection as active
mark_connection_active() {
    local pool_name="$1"
    local conn_id="$2"
    local requester="$3"
    
    # Use atomic operation with lock
    local lock_file="$STATE_DIR/.pool_${pool_name}.lock"
    local lock_acquired=false
    
    # Try to acquire lock
    for i in {1..10}; do
        if mkdir "$lock_file" 2>/dev/null; then
            lock_acquired=true
            break
        fi
        sleep 0.1
    done
    
    if [[ "$lock_acquired" != "true" ]]; then
        return 1
    fi
    
    # Update connection status
    jq --arg pool "$pool_name" \
       --arg id "$conn_id" \
       --arg req "$requester" \
       '(.pools[$pool].connections[] | select(.id == $id)) |= 
        (.status = "active" | .acquired_by = $req | .acquired_at = now)' \
       "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
    
    local result=$?
    
    # Release lock
    rmdir "$lock_file" 2>/dev/null
    
    return $result
}

# Release connection back to pool
release_connection() {
    local pool_name="$1"
    local conn_id="$2"
    
    echo "[POOL] Releasing connection: $conn_id"
    
    # Update connection status
    jq --arg pool "$pool_name" \
       --arg id "$conn_id" \
       '(.pools[$pool].connections[] | select(.id == $id)) |= 
        (.status = "idle" | .acquired_by = null | .last_used = now | .use_count += 1)' \
       "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
    
    # Update metrics
    decrement_metric "active_connections"
    increment_metric "idle_connections"
    increment_metric "reused_connections"
    
    # Update pool stats
    jq --arg pool "$pool_name" \
       '.pools[$pool].stats.total_requests += 1' \
       "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
}

# Execute with connection from pool
execute_with_connection() {
    local pool_name="$1"
    local command="$2"
    shift 2
    local args=("$@")
    
    # Acquire connection
    local conn_info=$(acquire_connection "$pool_name" "$command")
    if [[ $? -ne 0 ]]; then
        echo "[POOL] Failed to acquire connection"
        return 1
    fi
    
    local conn_id=$(echo "$conn_info" | jq -r '.id')
    local conn_type=$(echo "$conn_info" | jq -r '.type')
    
    # Execute based on connection type
    local result=0
    case "$conn_type" in
        "http")
            execute_http_request "$conn_info" "$command" "${args[@]}"
            result=$?
            ;;
        "database")
            execute_database_query "$conn_info" "$command" "${args[@]}"
            result=$?
            ;;
        "cache")
            execute_cache_command "$conn_info" "$command" "${args[@]}"
            result=$?
            ;;
        "api")
            execute_api_call "$conn_info" "$command" "${args[@]}"
            result=$?
            ;;
    esac
    
    # Release connection
    release_connection "$pool_name" "$conn_id"
    
    return $result
}

# Execute HTTP request with pooled connection
execute_http_request() {
    local conn_info="$1"
    local url="$2"
    shift 2
    local curl_args=("$@")
    
    # Get connection options
    local curl_opts=$(echo "$conn_info" | jq -r '.curl_opts[]')
    
    # Execute request with connection reuse
    curl $curl_opts "${curl_args[@]}" "$url"
}

# Execute database query (simulated)
execute_database_query() {
    local conn_info="$1"
    local query="$2"
    
    local conn_string=$(echo "$conn_info" | jq -r '.connection_string')
    
    echo "[POOL] Executing query on connection: $conn_string"
    echo "Query: $query"
    
    # Simulate query execution
    echo '{"result": "OK", "rows": 0}'
}

# Execute cache command
execute_cache_command() {
    local conn_info="$1"
    local command="$2"
    shift 2
    local args=("$@")
    
    local host=$(echo "$conn_info" | jq -r '.host')
    local port=$(echo "$conn_info" | jq -r '.port')
    
    # Use existing connection or create new one
    echo "$command ${args[@]}" | nc "$host" "$port"
}

# Execute API call
execute_api_call() {
    local conn_info="$1"
    local endpoint="$2"
    shift 2
    local args=("$@")
    
    local base_url=$(echo "$conn_info" | jq -r '.base_url')
    local cookie_jar=$(echo "$conn_info" | jq -r '.cookie_jar')
    local headers=$(echo "$conn_info" | jq -r '.headers | to_entries[] | "-H \"" + .key + ": " + .value + "\""')
    
    # Build curl command
    eval "curl -s -b \"$cookie_jar\" -c \"$cookie_jar\" $headers \"${base_url}${endpoint}\" ${args[@]}"
}

# Check if pool can grow
can_grow_pool() {
    local pool_name="$1"
    
    local current_size=$(jq -r --arg pool "$pool_name" '.pools[$pool].connections | length' "$POOLS_FILE")
    local max_size=$(jq -r --arg pool "$pool_name" '.pools[$pool].max_size' "$POOLS_FILE")
    
    [[ $current_size -lt $max_size ]]
}

# Grow pool size
grow_pool() {
    local pool_name="$1"
    local growth_size="${2:-1}"
    
    local pool_type=$(jq -r --arg pool "$pool_name" '.pools[$pool].type' "$POOLS_FILE")
    
    echo "[POOL] Growing pool $pool_name by $growth_size connections"
    
    initialize_connections "$pool_name" "$pool_type" "$growth_size"
}

# Shrink pool size
shrink_pool() {
    local pool_name="$1"
    local shrink_size="${2:-1}"
    
    echo "[POOL] Shrinking pool $pool_name by $shrink_size connections"
    
    # Remove idle connections
    local removed=0
    
    while [[ $removed -lt $shrink_size ]]; do
        local idle_conn=$(jq -r --arg pool "$pool_name" '
            .pools[$pool].connections[] | 
            select(.status == "idle") | 
            .id
        ' "$POOLS_FILE" 2>/dev/null | tail -1)
        
        if [[ -z "$idle_conn" ]]; then
            break
        fi
        
        remove_connection "$pool_name" "$idle_conn"
        ((removed++))
    done
    
    echo "[POOL] Removed $removed connections"
}

# Remove connection from pool
remove_connection() {
    local pool_name="$1"
    local conn_id="$2"
    
    # Get connection file
    local conn_file=$(jq -r --arg pool "$pool_name" --arg id "$conn_id" '
        .pools[$pool].connections[] | 
        select(.id == $id) | 
        .config_file
    ' "$POOLS_FILE")
    
    # Remove from pool
    jq --arg pool "$pool_name" \
       --arg id "$conn_id" \
       '.pools[$pool].connections = [.pools[$pool].connections[] | select(.id != $id)]' \
       "$POOLS_FILE" > "$POOLS_FILE.tmp" && \
        mv "$POOLS_FILE.tmp" "$POOLS_FILE"
    
    # Clean up files
    rm -f "$conn_file"
    
    decrement_metric "total_connections"
}

# Health check for all pools
health_check() {
    echo "[POOL] Running health check..."
    
    local unhealthy=0
    
    # Check each pool
    while IFS= read -r pool_name; do
        echo "[POOL] Checking pool: $pool_name"
        
        local pool_health=$(check_pool_health "$pool_name")
        local health_status=$(echo "$pool_health" | jq -r '.status')
        
        if [[ "$health_status" != "healthy" ]]; then
            echo "[POOL] Pool $pool_name is $health_status"
            ((unhealthy++))
        fi
        
        # Auto-scale based on usage
        auto_scale_pool "$pool_name" "$pool_health"
        
    done < <(jq -r '.pools | keys[]' "$POOLS_FILE")
    
    echo "[POOL] Health check complete. Unhealthy pools: $unhealthy"
}

# Check pool health
check_pool_health() {
    local pool_name="$1"
    
    local total=$(jq -r --arg pool "$pool_name" '.pools[$pool].connections | length' "$POOLS_FILE")
    local active=$(jq -r --arg pool "$pool_name" '.pools[$pool].connections | map(select(.status == "active")) | length' "$POOLS_FILE")
    local idle=$(jq -r --arg pool "$pool_name" '.pools[$pool].connections | map(select(.status == "idle")) | length' "$POOLS_FILE")
    
    local usage_percent=0
    if [[ $total -gt 0 ]]; then
        usage_percent=$(echo "scale=2; $active * 100 / $total" | bc)
    fi
    
    local status="healthy"
    if (( $(echo "$usage_percent > 90" | bc -l) )); then
        status="overloaded"
    elif (( $(echo "$usage_percent < 10" | bc -l) )) && [[ $total -gt $(jq -r --arg pool "$pool_name" '.pools[$pool].min_size' "$POOLS_FILE") ]]; then
        status="underutilized"
    fi
    
    cat << EOF
{
    "pool": "$pool_name",
    "status": "$status",
    "total": $total,
    "active": $active,
    "idle": $idle,
    "usage_percent": $usage_percent
}
EOF
}

# Auto-scale pool based on usage
auto_scale_pool() {
    local pool_name="$1"
    local health_info="$2"
    
    local status=$(echo "$health_info" | jq -r '.status')
    local total=$(echo "$health_info" | jq -r '.total')
    local min_size=$(jq -r --arg pool "$pool_name" '.pools[$pool].min_size' "$POOLS_FILE")
    local max_size=$(jq -r --arg pool "$pool_name" '.pools[$pool].max_size' "$POOLS_FILE")
    
    case "$status" in
        "overloaded")
            if [[ $total -lt $max_size ]]; then
                local grow_by=$((max_size - total > 5 ? 5 : max_size - total))
                grow_pool "$pool_name" "$grow_by"
            fi
            ;;
        "underutilized")
            if [[ $total -gt $min_size ]]; then
                local shrink_by=$((total - min_size > 5 ? 5 : total - min_size))
                shrink_pool "$pool_name" "$shrink_by"
            fi
            ;;
    esac
}

# Update metric
update_metric() {
    local metric="$1"
    local value="$2"
    
    jq --arg metric "$metric" \
       --argjson value "$value" \
       '.[$metric] = $value' \
       "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
        mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Increment metric
increment_metric() {
    local metric="$1"
    local amount="${2:-1}"
    
    jq --arg metric "$metric" \
       --argjson amount "$amount" \
       '.[$metric] = ((.[$metric] // 0) + $amount)' \
       "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
        mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Decrement metric
decrement_metric() {
    local metric="$1"
    local amount="${2:-1}"
    
    jq --arg metric "$metric" \
       --argjson amount "$amount" \
       '.[$metric] = [(.[$metric] // 0) - $amount, 0] | max' \
       "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
        mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Show pool status
show_status() {
    echo "=== Connection Pool Status ==="
    
    # Global metrics
    echo -e "\nGlobal Metrics:"
    jq -r 'to_entries[] | "  \(.key): \(.value)"' "$METRICS_FILE"
    
    # Pool details
    echo -e "\nPools:"
    
    while IFS= read -r pool_name; do
        local pool_info=$(jq -r --arg pool "$pool_name" '.pools[$pool]' "$POOLS_FILE")
        local health=$(check_pool_health "$pool_name")
        
        echo -e "\n  $pool_name:"
        echo "    Type: $(echo "$pool_info" | jq -r '.type')"
        echo "    Status: $(echo "$health" | jq -r '.status')"
        echo "    Connections: $(echo "$health" | jq -r '.active')/$(echo "$health" | jq -r '.total') active"
        echo "    Usage: $(echo "$health" | jq -r '.usage_percent')%"
        echo "    Total Requests: $(echo "$pool_info" | jq -r '.stats.total_requests')"
        
    done < <(jq -r '.pools | keys[]' "$POOLS_FILE")
    
    # Calculate efficiency
    local total_reused=$(jq -r '.reused_connections // 0' "$METRICS_FILE")
    local total_created=$(jq -r '.total_connections // 0' "$METRICS_FILE")
    
    if [[ $total_created -gt 0 ]]; then
        local efficiency=$(echo "scale=2; $total_reused * 100 / ($total_reused + $total_created)" | bc)
        echo -e "\nConnection Reuse Efficiency: ${efficiency}%"
    fi
}

# Main function
main() {
    init_pools
    
    case "${1:-help}" in
        create)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 create <pool_name> <type> [config_json]"
                exit 1
            fi
            create_pool "$2" "$3" "${4:-{}}"
            ;;
        acquire)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 acquire <pool_name> [requester] [timeout]"
                exit 1
            fi
            acquire_connection "$2" "${3:-anonymous}" "${4:-$CONNECTION_TIMEOUT}"
            ;;
        release)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 release <pool_name> <connection_id>"
                exit 1
            fi
            release_connection "$2" "$3"
            ;;
        execute)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 execute <pool_name> <command> [args...]"
                exit 1
            fi
            pool="$2"
            shift 2
            execute_with_connection "$pool" "$@"
            ;;
        grow)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 grow <pool_name> [size]"
                exit 1
            fi
            grow_pool "$2" "${3:-1}"
            ;;
        shrink)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 shrink <pool_name> [size]"
                exit 1
            fi
            shrink_pool "$2" "${3:-1}"
            ;;
        health)
            health_check
            ;;
        status)
            show_status
            ;;
        test)
            echo "[POOL] Running connection pool test..."
            
            # Create test pool
            create_pool "test_http" "http" '{"size": 3}'
            
            # Test acquire/release
            echo -e "\n[TEST] Acquiring connection..."
            conn1=$(acquire_connection "test_http" "test1")
            echo "Acquired: $(echo "$conn1" | jq -r '.id')"
            
            echo -e "\n[TEST] Pool status after acquire:"
            check_pool_health "test_http" | jq .
            
            # Release
            echo -e "\n[TEST] Releasing connection..."
            release_connection "test_http" "$(echo "$conn1" | jq -r '.id')"
            
            # Execute with pool
            echo -e "\n[TEST] Executing with pooled connection..."
            execute_with_connection "test_http" "https://httpbin.org/get" -s
            
            # Show final status
            echo -e "\n[TEST] Final status:"
            show_status
            ;;
        *)
            cat << EOF
Connection Pooler - Efficient connection management

Usage: $0 <command> [options]

Commands:
  create <name> <type> [config]  - Create connection pool
  acquire <pool> [requester]     - Acquire connection from pool
  release <pool> <conn_id>       - Release connection back to pool
  execute <pool> <cmd> [args]    - Execute with pooled connection
  grow <pool> [size]             - Grow pool by size
  shrink <pool> [size]           - Shrink pool by size
  health                         - Run health check on all pools
  status                         - Show pool status
  test                           - Run test scenario

Pool Types:
  http      - HTTP/HTTPS connections with keep-alive
  database  - Database connection pooling
  cache     - Cache server connections (Redis, Memcached)
  api       - API endpoint connections with auth

Configuration Example:
  {
    "size": 10,
    "min_size": 2,
    "max_size": 50,
    "host": "localhost",
    "port": 5432,
    "database": "mydb"
  }

Examples:
  # Create HTTP connection pool
  $0 create web_api http '{"size": 20, "max_size": 100}'
  
  # Execute API call with pooled connection
  $0 execute web_api "https://api.example.com/data" -X GET
  
  # Monitor pool health
  $0 health

Environment Variables:
  DEFAULT_POOL_SIZE=10       - Default pool size
  CONNECTION_TIMEOUT=30      - Connection acquire timeout
  IDLE_TIMEOUT=300          - Idle connection timeout
  ENABLE_CONNECTION_REUSE=true - Enable connection reuse
EOF
            ;;
    esac
}

# Export functions
export -f acquire_connection
export -f release_connection
export -f execute_with_connection

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi