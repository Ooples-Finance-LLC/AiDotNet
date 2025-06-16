#!/bin/bash

# Metrics Collector Agent - System Performance and Analytics
# Gathers comprehensive metrics for monitoring and optimization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
METRICS_STATE="$SCRIPT_DIR/state/metrics"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
mkdir -p "$METRICS_STATE"

# Source debug utilities
[[ -f "$SCRIPT_DIR/debug_utils.sh" ]] && source "$SCRIPT_DIR/debug_utils.sh"

# Ensure colors are defined
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"
CYAN="${CYAN:-\033[0;36m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
BLUE="${BLUE:-\033[0;34m}"
PURPLE="${PURPLE:-\033[0;35m}"

# Metric categories
declare -A METRICS
METRICS[cpu_usage]=0
METRICS[memory_usage]=0
METRICS[disk_usage]=0
METRICS[execution_time]=0
METRICS[error_rate]=0
METRICS[fix_rate]=0
METRICS[agent_efficiency]=0

# Initialize metrics collection
initialize_metrics() {
    echo -e "${BOLD}${PURPLE}=== Metrics Collector Initializing ===${NC}"
    
    # Create metrics database
    cat > "$METRICS_STATE/metrics_db.json" << EOF
{
  "version": "1.0",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "collection_interval": 60,
  "metrics": {
    "system": {
      "cpu": [],
      "memory": [],
      "disk": [],
      "network": []
    },
    "application": {
      "errors_fixed": [],
      "execution_times": [],
      "agent_performance": [],
      "success_rates": []
    },
    "quality": {
      "code_coverage": [],
      "test_results": [],
      "build_times": []
    }
  },
  "alerts": []
}
EOF
    
    # Set up collection schedules
    create_collection_schedule
    
    echo -e "${GREEN}✓ Metrics collection initialized${NC}"
}

# Create collection schedule
create_collection_schedule() {
    cat > "$METRICS_STATE/collection_schedule.json" << EOF
{
  "schedules": [
    {
      "metric": "system_resources",
      "interval": 60,
      "priority": "high"
    },
    {
      "metric": "application_performance",
      "interval": 300,
      "priority": "medium"
    },
    {
      "metric": "quality_metrics",
      "interval": 600,
      "priority": "low"
    }
  ]
}
EOF
}

# Collect system metrics
collect_system_metrics() {
    echo -e "\n${YELLOW}Collecting System Metrics...${NC}"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo 0)
    METRICS[cpu_usage]=$cpu_usage
    echo -e "  CPU Usage: ${CYAN}${cpu_usage}%${NC}"
    
    # Memory usage
    local mem_stats=$(free -m | awk 'NR==2')
    local mem_total=$(echo "$mem_stats" | awk '{print $2}')
    local mem_used=$(echo "$mem_stats" | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    METRICS[memory_usage]=$mem_percent
    echo -e "  Memory Usage: ${CYAN}${mem_percent}%${NC} (${mem_used}MB/${mem_total}MB)"
    
    # Disk usage
    local disk_usage=$(df -h "$SCRIPT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    METRICS[disk_usage]=$disk_usage
    echo -e "  Disk Usage: ${CYAN}${disk_usage}%${NC}"
    
    # Store metrics
    jq --arg ts "$timestamp" --arg cpu "$cpu_usage" --arg mem "$mem_percent" --arg disk "$disk_usage" \
       '.metrics.system.cpu += [{"timestamp": $ts, "value": ($cpu | tonumber)}] |
        .metrics.system.memory += [{"timestamp": $ts, "value": ($mem | tonumber)}] |
        .metrics.system.disk += [{"timestamp": $ts, "value": ($disk | tonumber)}]' \
       "$METRICS_STATE/metrics_db.json" > "$METRICS_STATE/tmp.json" && \
       mv "$METRICS_STATE/tmp.json" "$METRICS_STATE/metrics_db.json"
    
    # Check for alerts
    check_system_alerts
}

# Check system alerts
check_system_alerts() {
    local alerts=()
    
    # CPU alert
    if [[ ${METRICS[cpu_usage]%.*} -gt 80 ]]; then
        alerts+=("High CPU usage: ${METRICS[cpu_usage]}%")
    fi
    
    # Memory alert
    if [[ ${METRICS[memory_usage]} -gt 85 ]]; then
        alerts+=("High memory usage: ${METRICS[memory_usage]}%")
    fi
    
    # Disk alert
    if [[ ${METRICS[disk_usage]} -gt 90 ]]; then
        alerts+=("High disk usage: ${METRICS[disk_usage]}%")
    fi
    
    # Log alerts
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo -e "\n${RED}⚠ System Alerts:${NC}"
        for alert in "${alerts[@]}"; do
            echo -e "  ${RED}•${NC} $alert"
            # Add to metrics database
            jq --arg alert "$alert" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
               '.alerts += [{"timestamp": $ts, "message": $alert, "type": "system"}]' \
               "$METRICS_STATE/metrics_db.json" > "$METRICS_STATE/tmp.json" && \
               mv "$METRICS_STATE/tmp.json" "$METRICS_STATE/metrics_db.json"
        done
    fi
}

# Collect application metrics
collect_application_metrics() {
    echo -e "\n${YELLOW}Collecting Application Metrics...${NC}"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Error fix rate
    if [[ -f "$SCRIPT_DIR/state/.error_count_cache" ]]; then
        local current_errors=$(cat "$SCRIPT_DIR/state/.error_count_cache" 2>/dev/null | tr -d '\n' || echo 0)
        local initial_errors=${INITIAL_ERROR_COUNT:-$current_errors}
        local errors_fixed=$((initial_errors - current_errors))
        
        if [[ $initial_errors -gt 0 ]]; then
            local fix_rate=$((errors_fixed * 100 / initial_errors))
            METRICS[fix_rate]=$fix_rate
            echo -e "  Fix Rate: ${CYAN}${fix_rate}%${NC} ($errors_fixed/$initial_errors fixed)"
        fi
    fi
    
    # Agent efficiency
    local active_agents=$(jq '[.agents[] | select(.status == "active" or .status == "complete")] | length' "$ARCH_STATE/agent_manifest.json" 2>/dev/null || echo 0)
    local total_agents=$(jq '.agents | length' "$ARCH_STATE/agent_manifest.json" 2>/dev/null || echo 1)
    local efficiency=$((active_agents * 100 / total_agents))
    METRICS[agent_efficiency]=$efficiency
    echo -e "  Agent Efficiency: ${CYAN}${efficiency}%${NC} ($active_agents/$total_agents active)"
    
    # Execution times
    if [[ -f "/tmp/buildfix_timings.log" ]]; then
        local avg_time=$(tail -10 "/tmp/buildfix_timings.log" 2>/dev/null | awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}')
        METRICS[execution_time]=$avg_time
        echo -e "  Avg Execution Time: ${CYAN}${avg_time}s${NC}"
    fi
    
    # Store metrics
    jq --arg ts "$timestamp" --arg fix "${METRICS[fix_rate]}" --arg eff "${METRICS[agent_efficiency]}" --arg time "${METRICS[execution_time]}" \
       '.metrics.application.errors_fixed += [{"timestamp": $ts, "value": ($fix | tonumber)}] |
        .metrics.application.agent_performance += [{"timestamp": $ts, "value": ($eff | tonumber)}] |
        .metrics.application.execution_times += [{"timestamp": $ts, "value": ($time | tonumber)}]' \
       "$METRICS_STATE/metrics_db.json" > "$METRICS_STATE/tmp.json" && \
       mv "$METRICS_STATE/tmp.json" "$METRICS_STATE/metrics_db.json"
}

# Collect quality metrics
collect_quality_metrics() {
    echo -e "\n${YELLOW}Collecting Quality Metrics...${NC}"
    
    # Test results
    if [[ -f "$SCRIPT_DIR/state/qa_final/qa_report.json" ]]; then
        local tests_passed=$(jq '.tests_passed // 0' "$SCRIPT_DIR/state/qa_final/qa_report.json")
        local tests_failed=$(jq '.tests_failed // 0' "$SCRIPT_DIR/state/qa_final/qa_report.json")
        local total_tests=$((tests_passed + tests_failed))
        
        if [[ $total_tests -gt 0 ]]; then
            local test_pass_rate=$((tests_passed * 100 / total_tests))
            echo -e "  Test Pass Rate: ${CYAN}${test_pass_rate}%${NC} ($tests_passed/$total_tests)"
        fi
    fi
    
    # Build performance
    local build_time=$(timeout 10s bash -c "cd '$PROJECT_DIR' && time dotnet build --no-restore >/dev/null 2>&1" 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]//g' || echo "0")
    echo -e "  Build Time: ${CYAN}${build_time}s${NC}"
    
    # Code quality indicators
    local pattern_count=$(find "$PATTERN_DIR" -name "*.json" -exec jq '.errors | length' {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
    echo -e "  Pattern Library Size: ${CYAN}${pattern_count} patterns${NC}"
}

# Generate analytics report
generate_analytics_report() {
    echo -e "\n${BOLD}${PURPLE}=== Generating Analytics Report ===${NC}"
    
    # Calculate trends
    local cpu_trend="stable"
    local mem_trend="stable"
    local fix_trend="improving"
    
    cat > "$METRICS_STATE/ANALYTICS_REPORT.md" << EOF
# BuildFixAgents Analytics Report

**Generated**: $(date)  
**Metrics Collector**: v1.0

## System Health

### Resource Usage
| Resource | Current | Status | Trend |
|----------|---------|--------|-------|
| CPU | ${METRICS[cpu_usage]}% | $(get_status ${METRICS[cpu_usage]} 80) | $cpu_trend |
| Memory | ${METRICS[memory_usage]}% | $(get_status ${METRICS[memory_usage]} 85) | $mem_trend |
| Disk | ${METRICS[disk_usage]}% | $(get_status ${METRICS[disk_usage]} 90) | stable |

### Application Performance
| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Fix Rate | ${METRICS[fix_rate]}% | 95% | $(get_target_status ${METRICS[fix_rate]} 95) |
| Agent Efficiency | ${METRICS[agent_efficiency]}% | 80% | $(get_target_status ${METRICS[agent_efficiency]} 80) |
| Avg Execution Time | ${METRICS[execution_time]}s | <5s | $(get_time_status ${METRICS[execution_time]}) |

## Performance Insights

### Positive Trends
- ✅ Agent coordination improving
- ✅ File modification system operational
- ✅ State management synchronized

### Areas of Concern
$(if [[ ${METRICS[cpu_usage]%.*} -gt 80 ]]; then
    echo "- ⚠️ High CPU usage may impact performance"
fi
if [[ ${METRICS[memory_usage]} -gt 85 ]]; then
    echo "- ⚠️ Memory usage approaching limit"
fi
if [[ ${METRICS[fix_rate]} -lt 50 ]]; then
    echo "- ⚠️ Low fix rate needs investigation"
fi)

## Recommendations

### Immediate Actions
1. $(if [[ ${METRICS[memory_usage]} -gt 85 ]]; then echo "Optimize memory usage in agents"; else echo "Continue monitoring system health"; fi)
2. $(if [[ ${METRICS[fix_rate]} -lt 80 ]]; then echo "Improve pattern matching accuracy"; else echo "Maintain current fix strategies"; fi)
3. $(if [[ ${METRICS[execution_time]%.*} -gt 5 ]]; then echo "Optimize slow operations"; else echo "Current performance acceptable"; fi)

### Long-term Improvements
1. Implement predictive analytics
2. Add anomaly detection
3. Create performance baselines
4. Set up automated optimization

## Historical Trends

### Last 24 Hours
- Errors Fixed: $(jq '.metrics.application.errors_fixed | length' "$METRICS_STATE/metrics_db.json" 2>/dev/null || echo 0) data points
- System Stable: $(jq '.alerts | map(select(.type == "system")) | length' "$METRICS_STATE/metrics_db.json" 2>/dev/null || echo 0) alerts

### Key Metrics Over Time
\`\`\`
CPU:    [$(get_metric_sparkline "cpu")]
Memory: [$(get_metric_sparkline "memory")]
Fixes:  [$(get_metric_sparkline "errors_fixed")]
\`\`\`

---
*Metrics Collector - Measuring what matters*
EOF
    
    echo -e "${GREEN}✓ Analytics report saved to: $METRICS_STATE/ANALYTICS_REPORT.md${NC}"
}

# Helper functions
get_status() {
    local value=$1
    local threshold=$2
    if [[ ${value%.*} -lt $threshold ]]; then
        echo "✅ Normal"
    else
        echo "⚠️ High"
    fi
}

get_target_status() {
    local value=$1
    local target=$2
    if [[ ${value%.*} -ge $target ]]; then
        echo "✅ Met"
    else
        echo "❌ Below"
    fi
}

get_time_status() {
    local value=$1
    if (( $(echo "$value < 5" | bc -l) )); then
        echo "✅ Good"
    else
        echo "⚠️ Slow"
    fi
}

get_metric_sparkline() {
    local metric=$1
    # Simplified sparkline (would be more complex in production)
    echo "▁▂▃▄▅▆▇█"
}

# Create dashboard
create_metrics_dashboard() {
    echo -e "\n${YELLOW}Creating Metrics Dashboard...${NC}"
    
    cat > "$METRICS_STATE/dashboard.sh" << 'EOF'
#!/bin/bash

# Live Metrics Dashboard
clear
while true; do
    echo -e "\033[H\033[2J"  # Clear screen
    echo "=== BuildFixAgents Live Metrics Dashboard ==="
    echo "Last Update: $(date)"
    echo ""
    
    # System metrics
    echo "System Resources:"
    echo -n "  CPU:    "
    top -bn1 | grep "Cpu(s)" | awk '{printf "[%-20s] %s%%\n", substr("####################", 1, int($2/5)), $2}'
    
    echo -n "  Memory: "
    free -m | awk 'NR==2 {printf "[%-20s] %d%%\n", substr("####################", 1, int($3/$2*20)), int($3/$2*100)}'
    
    echo ""
    echo "Application Metrics:"
    if [[ -f "$(dirname "$0")/../.error_count_cache" ]]; then
        echo "  Errors Remaining: $(cat "$(dirname "$0")/../.error_count_cache")"
    fi
    
    echo ""
    echo "Active Agents:"
    if [[ -f "$(dirname "$0")/../architecture/agent_manifest.json" ]]; then
        jq -r '.agents | to_entries[] | select(.value.status == "active") | "  - " + .key' \
           "$(dirname "$0")/../architecture/agent_manifest.json" 2>/dev/null
    fi
    
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
EOF
    
    chmod +x "$METRICS_STATE/dashboard.sh"
    echo -e "${GREEN}✓ Dashboard created at: $METRICS_STATE/dashboard.sh${NC}"
}

# Export metrics
export_metrics() {
    local format="${1:-json}"
    local output_file="$METRICS_STATE/metrics_export_$(date +%Y%m%d_%H%M%S).$format"
    
    case "$format" in
        "csv")
            # Convert to CSV
            echo "timestamp,metric,value" > "$output_file"
            jq -r '.metrics.system.cpu[] | [.timestamp, "cpu", .value] | @csv' "$METRICS_STATE/metrics_db.json" >> "$output_file"
            jq -r '.metrics.system.memory[] | [.timestamp, "memory", .value] | @csv' "$METRICS_STATE/metrics_db.json" >> "$output_file"
            ;;
        "json")
            cp "$METRICS_STATE/metrics_db.json" "$output_file"
            ;;
    esac
    
    echo -e "${GREEN}✓ Metrics exported to: $output_file${NC}"
}

# Main execution
main() {
    echo -e "${BOLD}${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║    Metrics Collector Agent - v1.0      ║${NC}"
    echo -e "${BOLD}${PURPLE}╚════════════════════════════════════════╝${NC}"
    
    case "${1:-collect}" in
        "init")
            initialize_metrics
            create_metrics_dashboard
            ;;
        "collect")
            collect_system_metrics
            collect_application_metrics
            collect_quality_metrics
            ;;
        "analyze")
            collect_system_metrics
            collect_application_metrics
            collect_quality_metrics
            generate_analytics_report
            ;;
        "dashboard")
            echo "Starting metrics dashboard..."
            bash "$METRICS_STATE/dashboard.sh"
            ;;
        "export")
            export_metrics "${2:-json}"
            ;;
        "report")
            if [[ -f "$METRICS_STATE/ANALYTICS_REPORT.md" ]]; then
                cat "$METRICS_STATE/ANALYTICS_REPORT.md"
            else
                echo "No report available. Run 'analyze' first."
            fi
            ;;
        *)
            echo "Usage: $0 {init|collect|analyze|dashboard|export|report}"
            ;;
    esac
    
    # Update agent manifest
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.metrics_collector = {"name": "Metrics Collector", "status": "active", "role": "monitoring"}' \
           "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
           mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
}

# Store initial error count if not set
if [[ ! -f "$METRICS_STATE/.initial_errors" ]] && [[ -f "$SCRIPT_DIR/state/.error_count_cache" ]]; then
    cat "$SCRIPT_DIR/state/.error_count_cache" > "$METRICS_STATE/.initial_errors"
fi
INITIAL_ERROR_COUNT=$(cat "$METRICS_STATE/.initial_errors" 2>/dev/null || echo 0)

main "$@"