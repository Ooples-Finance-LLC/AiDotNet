#!/bin/bash

# Distributed Agent Coordinator
# Manages remote agents across multiple machines for scalable build fixes

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
DIST_CONFIG="$AGENT_DIR/config/distributed.yml"
DIST_STATE="$AGENT_DIR/state/distributed"
DIST_LOGS="$AGENT_DIR/logs/distributed"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Initialize
mkdir -p "$DIST_STATE" "$DIST_LOGS"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[$timestamp] DISTRIBUTED${NC} [${level}]: $message" | tee -a "$DIST_LOGS/coordinator.log"
}

# Create default distributed configuration
create_default_config() {
    if [[ ! -f "$DIST_CONFIG" ]]; then
        cat > "$DIST_CONFIG" << 'EOF'
# Distributed Agent Configuration
distributed:
  enabled: true
  mode: "hybrid"  # local, remote, hybrid
  
  # Coordinator settings
  coordinator:
    host: "localhost"
    port: 8888
    api_key: "change-me-in-production"
    heartbeat_interval: 30
    task_timeout: 600
    
  # Worker nodes
  workers:
    - name: "local"
      host: "localhost"
      capacity: 4
      tags: ["primary", "fast"]
      
    # Example remote workers (uncomment to use)
    # - name: "worker1"
    #   host: "192.168.1.100"
    #   port: 8889
    #   capacity: 8
    #   tags: ["remote", "high-memory"]
    #   ssh_key: "~/.ssh/id_rsa"
    
  # Load balancing
  load_balancing:
    strategy: "round_robin"  # round_robin, least_loaded, tagged
    max_retries: 3
    retry_delay: 5
    
  # Task distribution
  task_distribution:
    batch_size: 10
    priority_queue: true
    affinity_enabled: true  # Keep related tasks on same worker
    
  # Network settings
  network:
    compression: true
    encryption: true
    max_concurrent_transfers: 5
    chunk_size_mb: 10
    
  # Monitoring
  monitoring:
    enabled: true
    metrics_port: 9090
    export_interval: 60
EOF
        log_message "Created default distributed configuration"
    fi
}

# Start coordinator service
start_coordinator() {
    log_message "Starting distributed coordinator..."
    
    # Create coordinator state file
    cat > "$DIST_STATE/coordinator.json" << EOF
{
  "status": "running",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pid": $$,
  "workers": [],
  "tasks": {
    "queued": 0,
    "running": 0,
    "completed": 0,
    "failed": 0
  }
}
EOF
    
    # Start coordinator API (simplified - in production use proper web server)
    start_coordinator_api &
    local api_pid=$!
    echo "$api_pid" > "$DIST_STATE/coordinator.pid"
    
    log_message "Coordinator started (PID: $api_pid)"
}

# Coordinator API server (simplified)
start_coordinator_api() {
    local port="${COORDINATOR_PORT:-8888}"
    
    # Create API response handler
    while true; do
        # This is a simplified example - in production use a proper HTTP server
        {
            echo -e "HTTP/1.1 200 OK\r\n"
            echo -e "Content-Type: application/json\r\n"
            echo -e "Access-Control-Allow-Origin: *\r\n"
            echo -e "\r\n"
            
            if [[ -f "$DIST_STATE/coordinator.json" ]]; then
                cat "$DIST_STATE/coordinator.json"
            else
                echo '{"status": "not_initialized"}'
            fi
        } | nc -l -p "$port" -q 1 >/dev/null 2>&1 || true
        
        sleep 0.1
    done
}

# Register worker node
register_worker() {
    local worker_name="$1"
    local worker_host="${2:-localhost}"
    local worker_capacity="${3:-4}"
    local worker_tags="${4:-local}"
    
    log_message "Registering worker: $worker_name ($worker_host)"
    
    # Create worker state
    local worker_id=$(uuidgen 2>/dev/null || echo "${worker_name}_$(date +%s)")
    local worker_file="$DIST_STATE/workers/${worker_id}.json"
    
    mkdir -p "$DIST_STATE/workers"
    cat > "$worker_file" << EOF
{
  "id": "$worker_id",
  "name": "$worker_name",
  "host": "$worker_host",
  "capacity": $worker_capacity,
  "tags": ["$worker_tags"],
  "status": "active",
  "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tasks": {
    "assigned": 0,
    "completed": 0,
    "failed": 0
  },
  "resources": {
    "cpu_percent": 0,
    "memory_mb": 0,
    "disk_free_gb": 0
  }
}
EOF
    
    # Update coordinator state
    update_coordinator_workers
    
    log_message "Worker registered: $worker_id"
    echo "$worker_id"
}

# Update coordinator with current workers
update_coordinator_workers() {
    local workers_json="["
    local first=true
    
    for worker_file in "$DIST_STATE/workers"/*.json; do
        [[ -f "$worker_file" ]] || continue
        
        if [[ "$first" != "true" ]]; then
            workers_json+=","
        fi
        first=false
        
        workers_json+=$(cat "$worker_file")
    done
    
    workers_json+="]"
    
    # Update coordinator state
    if [[ -f "$DIST_STATE/coordinator.json" ]]; then
        local temp_file=$(mktemp)
        jq ".workers = $workers_json" "$DIST_STATE/coordinator.json" > "$temp_file"
        mv "$temp_file" "$DIST_STATE/coordinator.json"
    fi
}

# Distribute tasks to workers
distribute_tasks() {
    local task_file="$1"
    
    log_message "Distributing tasks from: $task_file"
    
    # Load tasks
    if [[ ! -f "$task_file" ]]; then
        log_message "Task file not found: $task_file" "ERROR"
        return 1
    fi
    
    # Get available workers
    local workers=()
    for worker_file in "$DIST_STATE/workers"/*.json; do
        [[ -f "$worker_file" ]] || continue
        
        local worker_status=$(jq -r '.status' "$worker_file")
        if [[ "$worker_status" == "active" ]]; then
            workers+=("$worker_file")
        fi
    done
    
    if [[ ${#workers[@]} -eq 0 ]]; then
        log_message "No active workers available" "ERROR"
        return 1
    fi
    
    # Distribute tasks round-robin (simplified)
    local task_count=0
    local worker_index=0
    
    while IFS= read -r task; do
        [[ -z "$task" ]] && continue
        
        local worker_file="${workers[$worker_index]}"
        local worker_id=$(jq -r '.id' "$worker_file")
        local worker_host=$(jq -r '.host' "$worker_file")
        
        # Create task assignment
        local task_id="task_$(date +%s)_${task_count}"
        create_task_assignment "$task_id" "$worker_id" "$task"
        
        # Deploy task to worker
        if [[ "$worker_host" == "localhost" ]]; then
            deploy_local_task "$task_id" "$task"
        else
            deploy_remote_task "$task_id" "$worker_host" "$task"
        fi
        
        ((task_count++))
        ((worker_index++))
        [[ $worker_index -ge ${#workers[@]} ]] && worker_index=0
    done < "$task_file"
    
    log_message "Distributed $task_count tasks to ${#workers[@]} workers"
}

# Create task assignment
create_task_assignment() {
    local task_id="$1"
    local worker_id="$2"
    local task_content="$3"
    
    local task_file="$DIST_STATE/tasks/${task_id}.json"
    mkdir -p "$DIST_STATE/tasks"
    
    cat > "$task_file" << EOF
{
  "id": "$task_id",
  "worker_id": "$worker_id",
  "content": "$task_content",
  "status": "assigned",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "assigned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "completed_at": null,
  "result": null
}
EOF
}

# Deploy task to local worker
deploy_local_task() {
    local task_id="$1"
    local task_content="$2"
    
    log_message "Deploying local task: $task_id"
    
    # Execute task in background
    (
        # Simulate task execution
        case "$task_content" in
            *"fix_error"*)
                "$AGENT_DIR/generic_error_agent.sh" "$task_content" &
                ;;
            *"security_scan"*)
                "$AGENT_DIR/security_agent.sh" &
                ;;
            *"architect"*)
                "$AGENT_DIR/architect_agent.sh" &
                ;;
            *)
                log_message "Unknown task type: $task_content" "WARN"
                ;;
        esac
        
        # Update task status
        update_task_status "$task_id" "completed"
    ) &
}

# Deploy task to remote worker
deploy_remote_task() {
    local task_id="$1"
    local worker_host="$2"
    local task_content="$3"
    
    log_message "Deploying remote task: $task_id to $worker_host"
    
    # Package task
    local task_package="$DIST_STATE/packages/${task_id}.tar.gz"
    mkdir -p "$DIST_STATE/packages"
    
    # Create task package
    local temp_dir=$(mktemp -d)
    echo "$task_content" > "$temp_dir/task.sh"
    cp -r "$AGENT_DIR"/*.sh "$temp_dir/"
    
    tar -czf "$task_package" -C "$temp_dir" .
    rm -rf "$temp_dir"
    
    # Transfer to remote worker (requires SSH setup)
    if command -v ssh &> /dev/null; then
        # Transfer package
        scp -q "$task_package" "${worker_host}:/tmp/${task_id}.tar.gz" || {
            log_message "Failed to transfer task to $worker_host" "ERROR"
            update_task_status "$task_id" "failed"
            return 1
        }
        
        # Execute remotely
        ssh "$worker_host" "
            mkdir -p /tmp/$task_id
            tar -xzf /tmp/${task_id}.tar.gz -C /tmp/$task_id
            cd /tmp/$task_id && ./task.sh
            rm -rf /tmp/$task_id /tmp/${task_id}.tar.gz
        " &
        
        update_task_status "$task_id" "running"
    else
        log_message "SSH not available for remote deployment" "ERROR"
        update_task_status "$task_id" "failed"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    local result="${3:-}"
    
    local task_file="$DIST_STATE/tasks/${task_id}.json"
    if [[ -f "$task_file" ]]; then
        local temp_file=$(mktemp)
        jq ".status = \"$status\" | .updated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$task_file" > "$temp_file"
        
        if [[ "$status" == "completed" ]]; then
            jq ".completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$temp_file" > "${temp_file}.2"
            mv "${temp_file}.2" "$temp_file"
        fi
        
        if [[ -n "$result" ]]; then
            jq ".result = \"$result\"" "$temp_file" > "${temp_file}.2"
            mv "${temp_file}.2" "$temp_file"
        fi
        
        mv "$temp_file" "$task_file"
    fi
}

# Monitor worker health
monitor_workers() {
    log_message "Starting worker health monitoring..."
    
    while true; do
        for worker_file in "$DIST_STATE/workers"/*.json; do
            [[ -f "$worker_file" ]] || continue
            
            local worker_id=$(jq -r '.id' "$worker_file")
            local worker_host=$(jq -r '.host' "$worker_file")
            local last_heartbeat=$(jq -r '.last_heartbeat' "$worker_file")
            
            # Check heartbeat age
            local heartbeat_age=$(( $(date +%s) - $(date -d "$last_heartbeat" +%s 2>/dev/null || echo 0) ))
            
            if [[ $heartbeat_age -gt 120 ]]; then
                log_message "Worker $worker_id is unresponsive (last seen: ${heartbeat_age}s ago)" "WARN"
                update_worker_status "$worker_id" "inactive"
            else
                # Check worker health
                if [[ "$worker_host" == "localhost" ]]; then
                    check_local_worker_health "$worker_id"
                else
                    check_remote_worker_health "$worker_id" "$worker_host"
                fi
            fi
        done
        
        sleep 30
    done
}

# Check local worker health
check_local_worker_health() {
    local worker_id="$1"
    
    # Get system resources
    local cpu_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_mb=$(free -m | awk 'NR==2{print $3}')
    local disk_free_gb=$(df -BG "$AGENT_DIR" | awk 'NR==2{print $4}' | cut -d'G' -f1)
    
    # Update worker state
    local worker_file="$DIST_STATE/workers/${worker_id}.json"
    local temp_file=$(mktemp)
    
    jq ".last_heartbeat = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" |
        .resources.cpu_percent = $cpu_percent |
        .resources.memory_mb = $memory_mb |
        .resources.disk_free_gb = $disk_free_gb" "$worker_file" > "$temp_file"
    
    mv "$temp_file" "$worker_file"
}

# Check remote worker health
check_remote_worker_health() {
    local worker_id="$1"
    local worker_host="$2"
    
    # Ping remote worker
    if command -v ssh &> /dev/null; then
        if ssh -o ConnectTimeout=5 "$worker_host" "echo 'alive'" >/dev/null 2>&1; then
            update_worker_heartbeat "$worker_id"
        else
            log_message "Cannot reach worker $worker_id at $worker_host" "WARN"
            update_worker_status "$worker_id" "unreachable"
        fi
    fi
}

# Update worker heartbeat
update_worker_heartbeat() {
    local worker_id="$1"
    local worker_file="$DIST_STATE/workers/${worker_id}.json"
    
    if [[ -f "$worker_file" ]]; then
        local temp_file=$(mktemp)
        jq ".last_heartbeat = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$worker_file" > "$temp_file"
        mv "$temp_file" "$worker_file"
    fi
}

# Update worker status
update_worker_status() {
    local worker_id="$1"
    local status="$2"
    local worker_file="$DIST_STATE/workers/${worker_id}.json"
    
    if [[ -f "$worker_file" ]]; then
        local temp_file=$(mktemp)
        jq ".status = \"$status\"" "$worker_file" > "$temp_file"
        mv "$temp_file" "$worker_file"
    fi
}

# Show distributed status
show_distributed_status() {
    echo -e "${BLUE}=== Distributed Agent Status ===${NC}\n"
    
    # Coordinator status
    if [[ -f "$DIST_STATE/coordinator.json" ]]; then
        local coord_status=$(jq -r '.status' "$DIST_STATE/coordinator.json")
        local task_stats=$(jq -r '.tasks' "$DIST_STATE/coordinator.json")
        
        echo -e "${CYAN}Coordinator:${NC}"
        echo "  Status: $coord_status"
        echo "  Tasks: $task_stats"
    else
        echo -e "${YELLOW}Coordinator not running${NC}"
    fi
    
    # Worker status
    echo -e "\n${CYAN}Workers:${NC}"
    for worker_file in "$DIST_STATE/workers"/*.json; do
        [[ -f "$worker_file" ]] || continue
        
        local worker_name=$(jq -r '.name' "$worker_file")
        local worker_status=$(jq -r '.status' "$worker_file")
        local worker_host=$(jq -r '.host' "$worker_file")
        local worker_capacity=$(jq -r '.capacity' "$worker_file")
        
        local status_color="$GREEN"
        [[ "$worker_status" != "active" ]] && status_color="$RED"
        
        echo -e "  ${status_color}●${NC} $worker_name ($worker_host) - Capacity: $worker_capacity"
    done
    
    # Task summary
    echo -e "\n${CYAN}Task Summary:${NC}"
    local total_tasks=$(find "$DIST_STATE/tasks" -name "*.json" 2>/dev/null | wc -l)
    local completed_tasks=$(grep -l '"status": "completed"' "$DIST_STATE/tasks"/*.json 2>/dev/null | wc -l)
    local failed_tasks=$(grep -l '"status": "failed"' "$DIST_STATE/tasks"/*.json 2>/dev/null | wc -l)
    
    echo "  Total: $total_tasks"
    echo "  Completed: $completed_tasks"
    echo "  Failed: $failed_tasks"
    echo "  Pending: $((total_tasks - completed_tasks - failed_tasks))"
}

# Setup remote worker
setup_remote_worker() {
    local worker_host="$1"
    local worker_name="${2:-remote_worker}"
    
    log_message "Setting up remote worker on $worker_host..."
    
    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 "$worker_host" "echo 'connected'" >/dev/null 2>&1; then
        log_message "Cannot connect to $worker_host via SSH" "ERROR"
        echo "Please ensure:"
        echo "  1. SSH is configured for passwordless access"
        echo "  2. The host is reachable"
        echo "  3. Your SSH key is added to the remote host"
        return 1
    fi
    
    # Create remote directory
    ssh "$worker_host" "mkdir -p ~/build_fix_worker"
    
    # Copy agent files
    log_message "Copying agent files to remote worker..."
    scp -r "$AGENT_DIR"/*.sh "${worker_host}:~/build_fix_worker/" || {
        log_message "Failed to copy files to remote worker" "ERROR"
        return 1
    }
    
    # Start worker service
    ssh "$worker_host" "
        cd ~/build_fix_worker
        chmod +x *.sh
        nohup ./worker_service.sh > worker.log 2>&1 &
        echo \$! > worker.pid
    "
    
    # Register worker
    register_worker "$worker_name" "$worker_host" 8 "remote,high-capacity"
    
    log_message "Remote worker setup complete"
}

# Create worker service script
create_worker_service() {
    cat > "$AGENT_DIR/worker_service.sh" << 'EOF'
#!/bin/bash

# Worker Service - Runs on remote workers
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_ID="${HOSTNAME}_$$"

# Start worker loop
while true; do
    # Check for tasks
    if [[ -f "$WORKER_DIR/current_task.sh" ]]; then
        # Execute task
        bash "$WORKER_DIR/current_task.sh"
        rm -f "$WORKER_DIR/current_task.sh"
    fi
    
    # Send heartbeat
    echo "heartbeat" > "$WORKER_DIR/heartbeat.txt"
    
    sleep 5
done
EOF
    chmod +x "$AGENT_DIR/worker_service.sh"
}

# Main menu
main() {
    local command="${1:-help}"
    shift || true
    
    # Initialize
    create_default_config
    create_worker_service
    
    case "$command" in
        "start")
            start_coordinator
            # Register local worker by default
            register_worker "local" "localhost" 4 "local,primary"
            # Start monitoring in background
            monitor_workers &
            echo $! > "$DIST_STATE/monitor.pid"
            log_message "Distributed system started"
            ;;
            
        "stop")
            log_message "Stopping distributed system..."
            # Stop coordinator
            if [[ -f "$DIST_STATE/coordinator.pid" ]]; then
                kill $(cat "$DIST_STATE/coordinator.pid") 2>/dev/null || true
                rm -f "$DIST_STATE/coordinator.pid"
            fi
            # Stop monitor
            if [[ -f "$DIST_STATE/monitor.pid" ]]; then
                kill $(cat "$DIST_STATE/monitor.pid") 2>/dev/null || true
                rm -f "$DIST_STATE/monitor.pid"
            fi
            log_message "Distributed system stopped"
            ;;
            
        "status")
            show_distributed_status
            ;;
            
        "register")
            local name="${1:-worker}"
            local host="${2:-localhost}"
            local capacity="${3:-4}"
            register_worker "$name" "$host" "$capacity"
            ;;
            
        "setup-remote")
            local host="${1:-}"
            if [[ -z "$host" ]]; then
                echo "Usage: $0 setup-remote <host>"
                exit 1
            fi
            setup_remote_worker "$host"
            ;;
            
        "distribute")
            local task_file="${1:-}"
            if [[ -z "$task_file" ]]; then
                echo "Usage: $0 distribute <task_file>"
                exit 1
            fi
            distribute_tasks "$task_file"
            ;;
            
        *)
            echo -e "${BLUE}Distributed Agent Coordinator${NC}"
            echo -e "${YELLOW}=============================${NC}\n"
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  start          - Start coordinator and local worker"
            echo "  stop           - Stop distributed system"
            echo "  status         - Show system status"
            echo "  register <name> <host> <capacity> - Register a worker"
            echo "  setup-remote <host> - Setup remote worker via SSH"
            echo "  distribute <file> - Distribute tasks from file"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 register worker1 192.168.1.100 8"
            echo "  $0 setup-remote user@remote-host"
            echo "  $0 distribute tasks.txt"
            ;;
    esac
}

# Execute
main "$@"