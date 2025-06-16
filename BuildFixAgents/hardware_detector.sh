#!/bin/bash

# Hardware Detection and Agent Scaling System
# Dynamically adjusts agent count based on available resources

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDWARE_PROFILE="$AGENT_DIR/state/hardware_profile.json"

# Detect CPU information
detect_cpu() {
    local cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    local cpu_model="Unknown"
    
    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    elif command -v sysctl &> /dev/null; then
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    fi
    
    echo "$cpu_count|$cpu_model"
}

# Detect memory
detect_memory() {
    local total_mem=0
    local available_mem=0
    
    if [[ -f /proc/meminfo ]]; then
        total_mem=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
        available_mem=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
    elif command -v vm_stat &> /dev/null; then
        # macOS
        local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
        local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        available_mem=$((pages_free * page_size / 1024 / 1024))
        total_mem=$(($(sysctl -n hw.memsize) / 1024 / 1024))
    else
        total_mem=4096
        available_mem=2048
    fi
    
    echo "$total_mem|$available_mem"
}

# Detect system load
detect_load() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    echo "${load_avg:-1.0}"
}

# Calculate optimal agent count
calculate_agent_count() {
    local cpu_count=$1
    local available_mem=$2
    local load_avg=$3
    
    # Base calculation on CPU cores
    local base_agents=$((cpu_count / 2))
    [[ $base_agents -lt 1 ]] && base_agents=1
    
    # Adjust based on memory (need at least 512MB per agent)
    local mem_agents=$((available_mem / 512))
    [[ $mem_agents -lt 1 ]] && mem_agents=1
    
    # Adjust based on load
    if (( $(echo "$load_avg > $cpu_count" | bc -l) )); then
        # System is already loaded, reduce agents
        base_agents=$((base_agents / 2))
        [[ $base_agents -lt 1 ]] && base_agents=1
    fi
    
    # Take minimum of CPU and memory based calculations
    local optimal_agents=$base_agents
    [[ $mem_agents -lt $optimal_agents ]] && optimal_agents=$mem_agents
    
    # Set reasonable limits
    [[ $optimal_agents -gt 8 ]] && optimal_agents=8
    [[ $optimal_agents -lt 1 ]] && optimal_agents=1
    
    echo "$optimal_agents"
}

# Generate hardware profile
generate_profile() {
    local cpu_info=$(detect_cpu)
    local cpu_count=$(echo "$cpu_info" | cut -d'|' -f1)
    local cpu_model=$(echo "$cpu_info" | cut -d'|' -f2)
    
    local mem_info=$(detect_memory)
    local total_mem=$(echo "$mem_info" | cut -d'|' -f1)
    local available_mem=$(echo "$mem_info" | cut -d'|' -f2)
    
    local load_avg=$(detect_load)
    
    local optimal_agents=$(calculate_agent_count "$cpu_count" "$available_mem" "$load_avg")
    
    # Determine performance tier
    local tier="standard"
    if [[ $cpu_count -ge 16 ]] && [[ $total_mem -ge 32768 ]]; then
        tier="high"
    elif [[ $cpu_count -ge 8 ]] && [[ $total_mem -ge 16384 ]]; then
        tier="medium"
    elif [[ $cpu_count -le 2 ]] || [[ $total_mem -le 4096 ]]; then
        tier="low"
    fi
    
    # Create profile
    cat > "$HARDWARE_PROFILE" << EOF
{
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cpu": {
    "cores": $cpu_count,
    "model": "$cpu_model"
  },
  "memory": {
    "total_mb": $total_mem,
    "available_mb": $available_mem
  },
  "system": {
    "load_average": $load_avg,
    "platform": "$(uname -s)",
    "architecture": "$(uname -m)"
  },
  "recommendations": {
    "optimal_agents": $optimal_agents,
    "performance_tier": "$tier",
    "max_concurrent_builds": $(( cpu_count > 4 ? 2 : 1 )),
    "enable_parallel_tests": $([ $cpu_count -ge 4 ] && echo "true" || echo "false"),
    "enable_performance_monitoring": $([ $total_mem -ge 8192 ] && echo "true" || echo "false")
  },
  "agent_limits": {
    "developer_agents": $optimal_agents,
    "tester_agents": $([ "$tier" = "high" ] && echo 2 || echo 1),
    "performance_agents": $([ "$tier" != "low" ] && echo 1 || echo 0),
    "max_total_agents": $(( optimal_agents + 2 ))
  }
}
EOF
    
    echo "Hardware profile generated: $HARDWARE_PROFILE"
}

# Get specific recommendation
get_recommendation() {
    local key="$1"
    
    if [[ ! -f "$HARDWARE_PROFILE" ]]; then
        generate_profile >&2
    fi
    
    # Extract value from JSON (simple grep for now)
    grep "\"$key\":" "$HARDWARE_PROFILE" | head -1 | cut -d: -f2 | tr -d ' ",' | xargs
}

# Show hardware summary
show_summary() {
    if [[ ! -f "$HARDWARE_PROFILE" ]]; then
        generate_profile
    fi
    
    echo "=== Hardware Profile Summary ==="
    echo ""
    echo "CPU Cores: $(get_recommendation "cores")"
    echo "Total Memory: $(get_recommendation "total_mb") MB"
    echo "Available Memory: $(get_recommendation "available_mb") MB"
    echo "Performance Tier: $(get_recommendation "performance_tier")"
    echo ""
    echo "=== Recommendations ==="
    echo "Optimal Developer Agents: $(get_recommendation "developer_agents")"
    echo "Tester Agents: $(get_recommendation "tester_agents")"
    echo "Performance Agents: $(get_recommendation "performance_agents")"
    echo "Max Total Agents: $(get_recommendation "max_total_agents")"
}

# Main execution
case "${1:-generate}" in
    "generate")
        generate_profile
        ;;
    "get")
        get_recommendation "${2:-optimal_agents}"
        ;;
    "summary")
        show_summary
        ;;
    *)
        echo "Usage: $0 {generate|get <key>|summary}"
        ;;
esac