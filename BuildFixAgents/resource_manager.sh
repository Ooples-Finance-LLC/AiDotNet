#!/bin/bash

# Resource Manager - Intelligent resource allocation and monitoring
# Manages CPU, memory, disk I/O, and file handles for optimal performance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/resources"
ALLOCATIONS_FILE="$STATE_DIR/allocations.json"
METRICS_FILE="$STATE_DIR/resource_metrics.json"
LIMITS_FILE="$STATE_DIR/resource_limits.json"

# Configuration
MAX_CPU_PERCENT=${MAX_CPU_PERCENT:-80}
MAX_MEMORY_PERCENT=${MAX_MEMORY_PERCENT:-75}
MAX_DISK_IO_MB=${MAX_DISK_IO_MB:-100}
MAX_FILE_HANDLES=${MAX_FILE_HANDLES:-1000}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-5}
ENABLE_THROTTLING=${ENABLE_THROTTLING:-true}

# Create directories
mkdir -p "$STATE_DIR"

# Initialize resource tracking
init_resources() {
    if [[ ! -f "$ALLOCATIONS_FILE" ]]; then
        cat > "$ALLOCATIONS_FILE" << EOF
{
    "version": "1.0",
    "allocations": {},
    "pending_requests": [],
    "total_allocated": {
        "cpu": 0,
        "memory_mb": 0,
        "file_handles": 0,
        "disk_io_mb": 0
    }
}
EOF
    fi
    
    if [[ ! -f "$LIMITS_FILE" ]]; then
        # Detect system resources
        local total_cpu=$(nproc)
        local total_memory_mb=$(free -m | awk '/^Mem:/{print $2}')
        local max_files=$(ulimit -n)
        
        cat > "$LIMITS_FILE" << EOF
{
    "system": {
        "cpu_cores": $total_cpu,
        "memory_mb": $total_memory_mb,
        "max_file_handles": $max_files
    },
    "limits": {
        "cpu_percent": $MAX_CPU_PERCENT,
        "memory_percent": $MAX_MEMORY_PERCENT,
        "memory_mb": $((total_memory_mb * MAX_MEMORY_PERCENT / 100)),
        "file_handles": $((max_files * 80 / 100)),
        "disk_io_mb": $MAX_DISK_IO_MB
    },
    "reservations": {
        "system": {
            "cpu_percent": 20,
            "memory_mb": 1024
        }
    }
}
EOF
    fi
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo '{
            "samples": [],
            "averages": {
                "cpu_usage": 0,
                "memory_usage": 0,
                "disk_io": 0
            }
        }' > "$METRICS_FILE"
    fi
}

# Get current resource usage
get_current_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_used=$(free -m | awk '/^Mem:/{print $3}')
    local memory_total=$(free -m | awk '/^Mem:/{print $2}')
    local memory_percent=$(echo "scale=2; $memory_used * 100 / $memory_total" | bc)
    
    # Disk I/O (requires iostat)
    local disk_io=0
    if command -v iostat >/dev/null 2>&1; then
        disk_io=$(iostat -m 1 2 | tail -n +7 | awk '{sum += $3 + $4} END {print sum}' | cut -d'.' -f1)
    fi
    
    # File handles
    local file_handles=$(lsof 2>/dev/null | wc -l || echo 0)
    
    cat << EOF
{
    "timestamp": "$(date -Iseconds)",
    "cpu_percent": $cpu_usage,
    "memory_mb": $memory_used,
    "memory_percent": $memory_percent,
    "disk_io_mb": $disk_io,
    "file_handles": $file_handles
}
EOF
}

# Check if resources are available
check_resource_availability() {
    local required_cpu="${1:-1}"     # CPU cores
    local required_memory="${2:-512}" # MB
    local required_files="${3:-100}"  # File handles
    
    # Get current usage
    local usage=$(get_current_usage)
    local cpu_usage=$(echo "$usage" | jq -r '.cpu_percent')
    local memory_used=$(echo "$usage" | jq -r '.memory_mb')
    local file_handles=$(echo "$usage" | jq -r '.file_handles')
    
    # Get limits
    local cpu_limit=$(jq -r '.limits.cpu_percent' "$LIMITS_FILE")
    local memory_limit=$(jq -r '.limits.memory_mb' "$LIMITS_FILE")
    local files_limit=$(jq -r '.limits.file_handles' "$LIMITS_FILE")
    
    # Check CPU
    local cpu_cores=$(jq -r '.system.cpu_cores' "$LIMITS_FILE")
    local cpu_required_percent=$(echo "scale=2; $required_cpu * 100 / $cpu_cores" | bc)
    local cpu_available=$(echo "$cpu_limit - $cpu_usage" | bc)
    
    if (( $(echo "$cpu_required_percent > $cpu_available" | bc -l) )); then
        echo "[RESOURCE] Insufficient CPU: need ${cpu_required_percent}%, available ${cpu_available}%"
        return 1
    fi
    
    # Check memory
    local memory_available=$((memory_limit - memory_used))
    if [[ $required_memory -gt $memory_available ]]; then
        echo "[RESOURCE] Insufficient memory: need ${required_memory}MB, available ${memory_available}MB"
        return 1
    fi
    
    # Check file handles
    local files_available=$((files_limit - file_handles))
    if [[ $required_files -gt $files_available ]]; then
        echo "[RESOURCE] Insufficient file handles: need $required_files, available $files_available"
        return 1
    fi
    
    return 0
}

# Allocate resources for a process
allocate_resources() {
    local process_id="$1"
    local process_name="$2"
    local required_cpu="${3:-1}"
    local required_memory="${4:-512}"
    local required_files="${5:-100}"
    local priority="${6:-normal}"
    
    # Lock for atomic operations
    local lock_file="$STATE_DIR/.allocations.lock"
    local timeout=30
    local elapsed=0
    
    while [[ -f "$lock_file" ]] && [[ $elapsed -lt $timeout ]]; do
        sleep 0.5
        ((elapsed++))
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        echo "[RESOURCE] Failed to acquire allocation lock"
        return 1
    fi
    
    touch "$lock_file"
    
    # Check availability
    if ! check_resource_availability "$required_cpu" "$required_memory" "$required_files"; then
        # Add to pending queue if high priority
        if [[ "$priority" == "high" ]]; then
            jq --arg id "$process_id" \
               --arg name "$process_name" \
               --argjson cpu "$required_cpu" \
               --argjson mem "$required_memory" \
               --argjson files "$required_files" \
               '.pending_requests += [{
                   "id": $id,
                   "name": $name,
                   "cpu": $cpu,
                   "memory_mb": $mem,
                   "file_handles": $files,
                   "queued_at": "'"$(date -Iseconds)"'"
               }]' "$ALLOCATIONS_FILE" > "$ALLOCATIONS_FILE.tmp" && \
                mv "$ALLOCATIONS_FILE.tmp" "$ALLOCATIONS_FILE"
            
            echo "[RESOURCE] Added $process_name to pending queue"
        fi
        rm -f "$lock_file"
        return 1
    fi
    
    # Allocate resources
    jq --arg id "$process_id" \
       --arg name "$process_name" \
       --argjson cpu "$required_cpu" \
       --argjson mem "$required_memory" \
       --argjson files "$required_files" \
       '.allocations[$id] = {
           "name": $name,
           "cpu": $cpu,
           "memory_mb": $mem,
           "file_handles": $files,
           "allocated_at": "'"$(date -Iseconds)"'",
           "priority": "'"$priority"'"
       } |
       .total_allocated.cpu += $cpu |
       .total_allocated.memory_mb += $mem |
       .total_allocated.file_handles += $files' \
       "$ALLOCATIONS_FILE" > "$ALLOCATIONS_FILE.tmp" && \
        mv "$ALLOCATIONS_FILE.tmp" "$ALLOCATIONS_FILE"
    
    rm -f "$lock_file"
    
    echo "[RESOURCE] Allocated resources for $process_name (PID: $process_id)"
    return 0
}

# Release allocated resources
release_resources() {
    local process_id="$1"
    
    # Get allocation details
    local allocation=$(jq -r --arg id "$process_id" '.allocations[$id] // empty' "$ALLOCATIONS_FILE")
    
    if [[ -z "$allocation" ]]; then
        echo "[RESOURCE] No allocation found for process $process_id"
        return 1
    fi
    
    local cpu=$(echo "$allocation" | jq -r '.cpu')
    local memory=$(echo "$allocation" | jq -r '.memory_mb')
    local files=$(echo "$allocation" | jq -r '.file_handles')
    local name=$(echo "$allocation" | jq -r '.name')
    
    # Release resources
    jq --arg id "$process_id" \
       --argjson cpu "$cpu" \
       --argjson mem "$memory" \
       --argjson files "$files" \
       'del(.allocations[$id]) |
        .total_allocated.cpu -= $cpu |
        .total_allocated.memory_mb -= $mem |
        .total_allocated.file_handles -= $files' \
       "$ALLOCATIONS_FILE" > "$ALLOCATIONS_FILE.tmp" && \
        mv "$ALLOCATIONS_FILE.tmp" "$ALLOCATIONS_FILE"
    
    echo "[RESOURCE] Released resources for $name (PID: $process_id)"
    
    # Process pending requests
    process_pending_requests
}

# Process pending resource requests
process_pending_requests() {
    local pending=$(jq -r '.pending_requests | length' "$ALLOCATIONS_FILE")
    
    if [[ $pending -eq 0 ]]; then
        return
    fi
    
    echo "[RESOURCE] Processing $pending pending requests..."
    
    # Try to allocate pending requests
    local processed=()
    
    while IFS= read -r request; do
        local id=$(echo "$request" | jq -r '.id')
        local name=$(echo "$request" | jq -r '.name')
        local cpu=$(echo "$request" | jq -r '.cpu')
        local memory=$(echo "$request" | jq -r '.memory_mb')
        local files=$(echo "$request" | jq -r '.file_handles')
        
        if allocate_resources "$id" "$name" "$cpu" "$memory" "$files" "high"; then
            processed+=("$id")
        fi
    done < <(jq -c '.pending_requests[]' "$ALLOCATIONS_FILE")
    
    # Remove processed requests
    for id in "${processed[@]}"; do
        jq --arg id "$id" '.pending_requests = [.pending_requests[] | select(.id != $id)]' \
           "$ALLOCATIONS_FILE" > "$ALLOCATIONS_FILE.tmp" && \
            mv "$ALLOCATIONS_FILE.tmp" "$ALLOCATIONS_FILE"
    done
}

# Monitor resource usage
monitor_resources() {
    echo "[RESOURCE] Starting resource monitor (interval: ${MONITOR_INTERVAL}s)..."
    
    while true; do
        # Get current usage
        local usage=$(get_current_usage)
        
        # Add to metrics
        jq --argjson usage "$usage" \
           '.samples = (.samples + [$usage] | .[-100:])' \
           "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        
        # Calculate averages
        local avg_cpu=$(jq '[.samples[].cpu_percent] | add / length' "$METRICS_FILE")
        local avg_mem=$(jq '[.samples[].memory_percent] | add / length' "$METRICS_FILE")
        local avg_io=$(jq '[.samples[].disk_io_mb] | add / length' "$METRICS_FILE")
        
        jq --argjson cpu "$avg_cpu" \
           --argjson mem "$avg_mem" \
           --argjson io "$avg_io" \
           '.averages.cpu_usage = $cpu |
            .averages.memory_usage = $mem |
            .averages.disk_io = $io' \
           "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        
        # Check for resource pressure
        local cpu_percent=$(echo "$usage" | jq -r '.cpu_percent')
        local mem_percent=$(echo "$usage" | jq -r '.memory_percent')
        
        if (( $(echo "$cpu_percent > 90" | bc -l) )); then
            echo "[RESOURCE] WARNING: High CPU usage: ${cpu_percent}%"
            if [[ "$ENABLE_THROTTLING" == "true" ]]; then
                throttle_processes "cpu"
            fi
        fi
        
        if (( $(echo "$mem_percent > 85" | bc -l) )); then
            echo "[RESOURCE] WARNING: High memory usage: ${mem_percent}%"
            if [[ "$ENABLE_THROTTLING" == "true" ]]; then
                throttle_processes "memory"
            fi
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Throttle processes based on resource pressure
throttle_processes() {
    local resource_type="$1"
    
    echo "[RESOURCE] Throttling processes due to $resource_type pressure"
    
    # Get low priority allocations
    local low_priority=$(jq -r '.allocations | to_entries[] | select(.value.priority == "low") | .key' "$ALLOCATIONS_FILE")
    
    for pid in $low_priority; do
        if kill -0 "$pid" 2>/dev/null; then
            # Send SIGSTOP to pause process
            kill -STOP "$pid"
            echo "[RESOURCE] Paused low priority process: $pid"
            
            # Schedule resume after pressure reduces
            (
                sleep 30
                kill -CONT "$pid" 2>/dev/null && echo "[RESOURCE] Resumed process: $pid"
            ) &
        fi
    done
}

# Show resource allocation status
show_status() {
    echo "=== Resource Manager Status ==="
    
    # System resources
    echo -e "\nSystem Resources:"
    jq -r '.system | to_entries[] | "  \(.key): \(.value)"' "$LIMITS_FILE"
    
    # Current usage
    echo -e "\nCurrent Usage:"
    local usage=$(get_current_usage)
    echo "$usage" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
    
    # Allocations
    echo -e "\nActive Allocations:"
    local total_alloc=$(jq -r '.allocations | length' "$ALLOCATIONS_FILE")
    echo "  Total: $total_alloc"
    
    if [[ $total_alloc -gt 0 ]]; then
        echo "  Details:"
        jq -r '.allocations | to_entries[] | "    \(.key): \(.value.name) (CPU: \(.value.cpu), Mem: \(.value.memory_mb)MB)"' "$ALLOCATIONS_FILE"
    fi
    
    # Pending requests
    local pending=$(jq -r '.pending_requests | length' "$ALLOCATIONS_FILE")
    if [[ $pending -gt 0 ]]; then
        echo -e "\nPending Requests: $pending"
        jq -r '.pending_requests[] | "  \(.name): CPU: \(.cpu), Mem: \(.memory_mb)MB"' "$ALLOCATIONS_FILE"
    fi
    
    # Resource averages
    echo -e "\nResource Averages:"
    jq -r '.averages | to_entries[] | "  \(.key): \(.value | tostring | .[0:5])%"' "$METRICS_FILE"
}

# Clean up stale allocations
cleanup_allocations() {
    echo "[RESOURCE] Cleaning up stale allocations..."
    
    local cleaned=0
    local stale_pids=()
    
    # Check each allocation
    while IFS= read -r entry; do
        local pid=$(echo "$entry" | jq -r '.key')
        local name=$(echo "$entry" | jq -r '.value.name')
        
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "[RESOURCE] Found stale allocation: $name (PID: $pid)"
            stale_pids+=("$pid")
            ((cleaned++))
        fi
    done < <(jq -c '.allocations | to_entries[]' "$ALLOCATIONS_FILE")
    
    # Release stale allocations
    for pid in "${stale_pids[@]}"; do
        release_resources "$pid"
    done
    
    echo "[RESOURCE] Cleaned up $cleaned stale allocations"
}

# Main function
main() {
    init_resources
    
    case "${1:-status}" in
        allocate)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 allocate <pid> <name> [cpu] [memory_mb] [files] [priority]"
                exit 1
            fi
            allocate_resources "$2" "$3" "${4:-1}" "${5:-512}" "${6:-100}" "${7:-normal}"
            ;;
        release)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 release <pid>"
                exit 1
            fi
            release_resources "$2"
            ;;
        check)
            check_resource_availability "${2:-1}" "${3:-512}" "${4:-100}"
            ;;
        monitor)
            monitor_resources
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup_allocations
            ;;
        test)
            echo "[RESOURCE] Running resource manager test..."
            
            # Test allocation
            allocate_resources $$ "test_process" 1 256 50 "normal"
            
            # Show status
            show_status
            
            # Release
            sleep 2
            release_resources $$
            ;;
        *)
            cat << EOF
Resource Manager - Intelligent resource allocation and monitoring

Usage: $0 <command> [options]

Commands:
  allocate <pid> <name> [cpu] [mem] [files] [priority] - Allocate resources
  release <pid>                                        - Release resources
  check [cpu] [memory] [files]                        - Check availability
  monitor                                              - Start monitor daemon
  status                                               - Show current status
  cleanup                                              - Clean stale allocations
  test                                                 - Run test

Resource Types:
  cpu      - CPU cores (e.g., 1, 2, 0.5)
  memory   - Memory in MB (e.g., 512, 1024)
  files    - File handles (e.g., 100, 500)

Priority Levels:
  high     - Will queue if resources unavailable
  normal   - Standard priority (default)
  low      - May be throttled under pressure

Examples:
  # Allocate resources for agent
  $0 allocate 12345 "build_analyzer" 2 1024 200 high
  
  # Check if resources available
  $0 check 4 2048 500
  
  # Monitor resources
  $0 monitor
EOF
            ;;
    esac
}

# Export functions
export -f check_resource_availability
export -f allocate_resources
export -f release_resources

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi