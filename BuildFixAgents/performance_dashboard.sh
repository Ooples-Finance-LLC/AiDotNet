#!/bin/bash

# Performance Dashboard - Real-time monitoring and visualization
# Provides comprehensive performance metrics and insights

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/dashboard"
METRICS_DIR="$STATE_DIR/metrics"
REPORTS_DIR="$STATE_DIR/reports"
DASHBOARD_FILE="$STATE_DIR/dashboard.html"
API_PORT=${API_PORT:-8080}

# Configuration
UPDATE_INTERVAL=${UPDATE_INTERVAL:-5}
RETENTION_HOURS=${RETENTION_HOURS:-24}
ENABLE_ALERTS=${ENABLE_ALERTS:-true}
ALERT_THRESHOLD_CPU=${ALERT_THRESHOLD_CPU:-80}
ALERT_THRESHOLD_MEMORY=${ALERT_THRESHOLD_MEMORY:-85}
ALERT_THRESHOLD_ERRORS=${ALERT_THRESHOLD_ERRORS:-50}

# Create directories
mkdir -p "$STATE_DIR" "$METRICS_DIR" "$REPORTS_DIR"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize dashboard data
init_dashboard() {
    if [[ ! -f "$STATE_DIR/dashboard_config.json" ]]; then
        cat > "$STATE_DIR/dashboard_config.json" << EOF
{
    "version": "1.0",
    "update_interval": $UPDATE_INTERVAL,
    "retention_hours": $RETENTION_HOURS,
    "alerts": {
        "enabled": $ENABLE_ALERTS,
        "thresholds": {
            "cpu": $ALERT_THRESHOLD_CPU,
            "memory": $ALERT_THRESHOLD_MEMORY,
            "errors": $ALERT_THRESHOLD_ERRORS
        }
    },
    "widgets": [
        "system_overview",
        "agent_performance",
        "error_analysis",
        "cache_efficiency",
        "resource_usage",
        "timeline"
    ]
}
EOF
    fi
}

# Collect all metrics
collect_metrics() {
    local timestamp=$(date -Iseconds)
    local metrics_file="$METRICS_DIR/metrics_$(date +%Y%m%d_%H%M%S).json"
    
    echo "[DASHBOARD] Collecting metrics at $timestamp"
    
    # Start metrics collection
    cat > "$metrics_file" << EOF
{
    "timestamp": "$timestamp",
    "system": $(collect_system_metrics),
    "agents": $(collect_agent_metrics),
    "errors": $(collect_error_metrics),
    "cache": $(collect_cache_metrics),
    "pools": $(collect_pool_metrics),
    "performance": $(collect_performance_metrics)
}
EOF
    
    # Clean old metrics
    find "$METRICS_DIR" -name "metrics_*.json" -mmin +$((RETENTION_HOURS * 60)) -delete
}

# Collect system metrics
collect_system_metrics() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_used=$(free -m | awk '/^Mem:/{print $3}')
    local memory_total=$(free -m | awk '/^Mem:/{print $2}')
    local memory_percent=$(echo "scale=2; $memory_used * 100 / $memory_total" | bc)
    local disk_usage=$(df -BG "$SCRIPT_DIR" | awk 'NR==2{print $5}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
    
    cat << EOF
{
    "cpu_percent": $cpu_usage,
    "memory": {
        "used_mb": $memory_used,
        "total_mb": $memory_total,
        "percent": $memory_percent
    },
    "disk_percent": $disk_usage,
    "load_average": "$load_avg",
    "processes": $(ps aux | wc -l)
}
EOF
}

# Collect agent metrics
collect_agent_metrics() {
    local coordinator_state="$SCRIPT_DIR/state/ultimate_coordinator/coordinator_state.json"
    local factory_metrics="$SCRIPT_DIR/state/factory/metrics.json"
    
    local total_agents=0
    local active_agents=0
    local completed_agents=0
    local failed_agents=0
    
    if [[ -f "$coordinator_state" ]]; then
        total_agents=$(jq -r '.metrics.total_agents // 0' "$coordinator_state")
        completed_agents=$(jq -r '.metrics.completed // 0' "$coordinator_state")
        failed_agents=$(jq -r '.metrics.failed // 0' "$coordinator_state")
    fi
    
    if [[ -f "$factory_metrics" ]]; then
        active_agents=$(jq -r '.active_agents // 0' "$factory_metrics")
    fi
    
    # Get agent execution times
    local avg_duration=0
    if [[ -d "$SCRIPT_DIR/state/ultimate_coordinator/metrics" ]]; then
        avg_duration=$(find "$SCRIPT_DIR/state/ultimate_coordinator/metrics" -name "agent_metrics.jsonl" -exec cat {} \; | \
            jq -s 'map(.duration) | add / length' 2>/dev/null || echo 0)
    fi
    
    cat << EOF
{
    "total": $total_agents,
    "active": $active_agents,
    "completed": $completed_agents,
    "failed": $failed_agents,
    "success_rate": $(echo "scale=2; $completed_agents * 100 / ($completed_agents + $failed_agents + 0.01)" | bc),
    "average_duration_seconds": $avg_duration
}
EOF
}

# Collect error metrics
collect_error_metrics() {
    local error_analysis="$SCRIPT_DIR/state/error_analysis.json"
    local total_errors=0
    local error_types=0
    local top_errors="[]"
    
    if [[ -f "$error_analysis" ]]; then
        total_errors=$(jq -r '.total_errors // 0' "$error_analysis")
        error_types=$(jq -r '.error_summary | length // 0' "$error_analysis")
        top_errors=$(jq -c '[.error_summary | to_entries | sort_by(-.value) | .[:5] | .[] | {code: .key, count: .value}]' "$error_analysis" 2>/dev/null || echo "[]")
    fi
    
    cat << EOF
{
    "total_errors": $total_errors,
    "unique_error_types": $error_types,
    "top_errors": $top_errors,
    "errors_per_minute": 0
}
EOF
}

# Collect cache metrics
collect_cache_metrics() {
    local cache_stats="$SCRIPT_DIR/state/cache/cache_stats.json"
    local cache_hits=0
    local cache_misses=0
    local hit_rate=0
    local cache_size_mb=0
    
    if [[ -f "$cache_stats" ]]; then
        cache_hits=$(jq -r '.cache_hits // 0' "$cache_stats")
        cache_misses=$(jq -r '.cache_misses // 0' "$cache_stats")
        
        if [[ $((cache_hits + cache_misses)) -gt 0 ]]; then
            hit_rate=$(echo "scale=2; $cache_hits * 100 / ($cache_hits + $cache_misses)" | bc)
        fi
    fi
    
    if [[ -d "$SCRIPT_DIR/state/cache" ]]; then
        cache_size_mb=$(du -sm "$SCRIPT_DIR/state/cache" 2>/dev/null | cut -f1)
    fi
    
    cat << EOF
{
    "hits": $cache_hits,
    "misses": $cache_misses,
    "hit_rate": $hit_rate,
    "size_mb": $cache_size_mb,
    "entries": $(find "$SCRIPT_DIR/state/cache" -type f 2>/dev/null | wc -l)
}
EOF
}

# Collect connection pool metrics
collect_pool_metrics() {
    local pools_file="$SCRIPT_DIR/state/connection_pool/pools.json"
    local pool_metrics="$SCRIPT_DIR/state/connection_pool/pool_metrics.json"
    
    if [[ -f "$pool_metrics" ]]; then
        cat "$pool_metrics"
    else
        echo '{"total_connections": 0, "active_connections": 0, "pool_efficiency": 0}'
    fi
}

# Collect performance metrics
collect_performance_metrics() {
    local build_time=0
    local fix_time=0
    local total_time=0
    
    # Get timing from various sources
    if [[ -f "$SCRIPT_DIR/state/ultimate_coordinator/coordinator_state.json" ]]; then
        local start_time=$(jq -r '.start_time' "$SCRIPT_DIR/state/ultimate_coordinator/coordinator_state.json")
        if [[ -n "$start_time" ]] && [[ "$start_time" != "null" ]]; then
            total_time=$(( $(date +%s) - $(date -d "$start_time" +%s) ))
        fi
    fi
    
    # Calculate throughput
    local errors_fixed=0
    local throughput=0
    
    if [[ $total_time -gt 0 ]]; then
        throughput=$(echo "scale=2; $errors_fixed * 60 / $total_time" | bc)
    fi
    
    cat << EOF
{
    "build_analysis_time": $build_time,
    "fix_application_time": $fix_time,
    "total_execution_time": $total_time,
    "errors_fixed": $errors_fixed,
    "throughput_per_minute": $throughput
}
EOF
}

# Generate terminal dashboard
generate_terminal_dashboard() {
    clear
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               BuildFixAgents Performance Dashboard                 ║${NC}"
    echo -e "${CYAN}║                    $(date '+%Y-%m-%d %H:%M:%S')                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    
    # Get latest metrics
    local latest_metrics=$(find "$METRICS_DIR" -name "metrics_*.json" -type f -printf '%T@ %p\n' | \
        sort -nr | head -1 | cut -d' ' -f2-)
    
    if [[ -z "$latest_metrics" ]]; then
        echo -e "${RED}No metrics available${NC}"
        return
    fi
    
    local metrics=$(cat "$latest_metrics")
    
    # System Overview
    echo -e "\n${GREEN}System Overview:${NC}"
    echo -e "  CPU Usage: $(echo "$metrics" | jq -r '.system.cpu_percent')%"
    echo -e "  Memory: $(echo "$metrics" | jq -r '.system.memory.percent')% ($(echo "$metrics" | jq -r '.system.memory.used_mb')MB/$(echo "$metrics" | jq -r '.system.memory.total_mb')MB)"
    echo -e "  Load Average: $(echo "$metrics" | jq -r '.system.load_average')"
    
    # Agent Performance
    echo -e "\n${GREEN}Agent Performance:${NC}"
    echo -e "  Active Agents: $(echo "$metrics" | jq -r '.agents.active')"
    echo -e "  Completed: $(echo "$metrics" | jq -r '.agents.completed')"
    echo -e "  Failed: $(echo "$metrics" | jq -r '.agents.failed')"
    echo -e "  Success Rate: $(echo "$metrics" | jq -r '.agents.success_rate')%"
    echo -e "  Avg Duration: $(echo "$metrics" | jq -r '.agents.average_duration_seconds')s"
    
    # Error Analysis
    echo -e "\n${GREEN}Error Analysis:${NC}"
    echo -e "  Total Errors: $(echo "$metrics" | jq -r '.errors.total_errors')"
    echo -e "  Unique Types: $(echo "$metrics" | jq -r '.errors.unique_error_types')"
    echo -e "  Top Errors:"
    echo "$metrics" | jq -r '.errors.top_errors[] | "    \(.code): \(.count)"' 2>/dev/null || echo "    None"
    
    # Cache Performance
    echo -e "\n${GREEN}Cache Performance:${NC}"
    echo -e "  Hit Rate: $(echo "$metrics" | jq -r '.cache.hit_rate')%"
    echo -e "  Hits/Misses: $(echo "$metrics" | jq -r '.cache.hits')/$(echo "$metrics" | jq -r '.cache.misses')"
    echo -e "  Cache Size: $(echo "$metrics" | jq -r '.cache.size_mb')MB"
    
    # Connection Pools
    echo -e "\n${GREEN}Connection Pools:${NC}"
    echo -e "  Total Connections: $(echo "$metrics" | jq -r '.pools.total_connections')"
    echo -e "  Active: $(echo "$metrics" | jq -r '.pools.active_connections')"
    echo -e "  Efficiency: $(echo "$metrics" | jq -r '.pools.pool_efficiency')%"
    
    # Alerts
    check_alerts "$metrics"
}

# Check for alerts
check_alerts() {
    local metrics="$1"
    
    if [[ "$ENABLE_ALERTS" != "true" ]]; then
        return
    fi
    
    local alerts=()
    
    # CPU alert
    local cpu=$(echo "$metrics" | jq -r '.system.cpu_percent')
    if (( $(echo "$cpu > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        alerts+=("HIGH CPU USAGE: ${cpu}%")
    fi
    
    # Memory alert
    local memory=$(echo "$metrics" | jq -r '.system.memory.percent')
    if (( $(echo "$memory > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        alerts+=("HIGH MEMORY USAGE: ${memory}%")
    fi
    
    # Error rate alert
    local error_rate=$(echo "$metrics" | jq -r '.agents.failed')
    if [[ $error_rate -gt $ALERT_THRESHOLD_ERRORS ]]; then
        alerts+=("HIGH ERROR RATE: $error_rate failures")
    fi
    
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo -e "\n${RED}═══ ALERTS ═══${NC}"
        for alert in "${alerts[@]}"; do
            echo -e "${RED}⚠ $alert${NC}"
        done
    fi
}

# Generate HTML dashboard
generate_html_dashboard() {
    echo "[DASHBOARD] Generating HTML dashboard..."
    
    # Get all recent metrics
    local metrics_data="[]"
    local charts_data="{}"
    
    # Collect last hour of metrics
    local hour_ago=$(date -d '1 hour ago' +%s)
    
    while IFS= read -r metric_file; do
        if [[ -f "$metric_file" ]]; then
            local file_time=$(stat -c %Y "$metric_file" 2>/dev/null || stat -f %m "$metric_file" 2>/dev/null)
            if [[ $file_time -gt $hour_ago ]]; then
                metrics_data=$(echo "$metrics_data" | jq --slurpfile new "[$metric_file]" '. + $new[0]')
            fi
        fi
    done < <(find "$METRICS_DIR" -name "metrics_*.json" -type f | sort)
    
    # Generate HTML
    cat > "$DASHBOARD_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BuildFixAgents Performance Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0d1117;
            color: #c9d1d9;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: #161b22;
            border-radius: 8px;
            border: 1px solid #30363d;
        }
        h1 { color: #58a6ff; margin-bottom: 10px; }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .widget {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 20px;
        }
        .widget h2 {
            color: #58a6ff;
            margin-bottom: 15px;
            font-size: 18px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #21262d;
        }
        .metric:last-child { border-bottom: none; }
        .metric-value {
            font-weight: bold;
            color: #7ee83f;
        }
        .metric-value.warning { color: #ffa657; }
        .metric-value.error { color: #f85149; }
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #21262d;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 5px;
        }
        .progress-fill {
            height: 100%;
            background: #7ee83f;
            transition: width 0.3s ease;
        }
        .progress-fill.warning { background: #ffa657; }
        .progress-fill.error { background: #f85149; }
        .chart-container {
            height: 200px;
            margin-top: 15px;
        }
        .alert {
            background: #f85149;
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .timestamp {
            text-align: center;
            color: #8b949e;
            font-size: 14px;
            margin-top: 20px;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-indicator.healthy { background: #7ee83f; }
        .status-indicator.warning { background: #ffa657; }
        .status-indicator.error { background: #f85149; }
    </style>
</head>
<body>
    <div class="header">
        <h1>BuildFixAgents Performance Dashboard</h1>
        <div id="last-update"></div>
    </div>
    
    <div id="alerts"></div>
    
    <div class="dashboard">
        <!-- System Overview -->
        <div class="widget">
            <h2>System Overview</h2>
            <div class="metric">
                <span>CPU Usage</span>
                <span class="metric-value" id="cpu-usage">-</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="cpu-progress"></div>
            </div>
            <div class="metric">
                <span>Memory Usage</span>
                <span class="metric-value" id="memory-usage">-</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="memory-progress"></div>
            </div>
            <div class="metric">
                <span>Load Average</span>
                <span class="metric-value" id="load-avg">-</span>
            </div>
        </div>
        
        <!-- Agent Performance -->
        <div class="widget">
            <h2>Agent Performance</h2>
            <div class="metric">
                <span>Active Agents</span>
                <span class="metric-value" id="active-agents">-</span>
            </div>
            <div class="metric">
                <span>Success Rate</span>
                <span class="metric-value" id="success-rate">-</span>
            </div>
            <div class="metric">
                <span>Average Duration</span>
                <span class="metric-value" id="avg-duration">-</span>
            </div>
            <div class="metric">
                <span>Total Processed</span>
                <span class="metric-value" id="total-processed">-</span>
            </div>
        </div>
        
        <!-- Error Analysis -->
        <div class="widget">
            <h2>Error Analysis</h2>
            <div class="metric">
                <span>Total Errors</span>
                <span class="metric-value" id="total-errors">-</span>
            </div>
            <div class="metric">
                <span>Unique Types</span>
                <span class="metric-value" id="error-types">-</span>
            </div>
            <div id="top-errors"></div>
        </div>
        
        <!-- Cache Performance -->
        <div class="widget">
            <h2>Cache Performance</h2>
            <div class="metric">
                <span>Hit Rate</span>
                <span class="metric-value" id="cache-hit-rate">-</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" id="cache-progress"></div>
            </div>
            <div class="metric">
                <span>Cache Size</span>
                <span class="metric-value" id="cache-size">-</span>
            </div>
            <div class="metric">
                <span>Total Entries</span>
                <span class="metric-value" id="cache-entries">-</span>
            </div>
        </div>
        
        <!-- Resource Usage Timeline -->
        <div class="widget" style="grid-column: 1 / -1;">
            <h2>Resource Usage Timeline</h2>
            <div class="chart-container" id="timeline-chart">
                <canvas id="timeline-canvas"></canvas>
            </div>
        </div>
    </div>
    
    <div class="timestamp" id="timestamp"></div>
    
    <script>
        // Dashboard data placeholder
        const dashboardData = DASHBOARD_DATA_PLACEHOLDER;
        
        // Update dashboard
        function updateDashboard(data) {
            if (!data || !data.system) return;
            
            // Update system metrics
            document.getElementById('cpu-usage').textContent = data.system.cpu_percent + '%';
            document.getElementById('cpu-progress').style.width = data.system.cpu_percent + '%';
            setProgressClass('cpu-progress', data.system.cpu_percent, 60, 80);
            
            document.getElementById('memory-usage').textContent = data.system.memory.percent + '%';
            document.getElementById('memory-progress').style.width = data.system.memory.percent + '%';
            setProgressClass('memory-progress', data.system.memory.percent, 70, 85);
            
            document.getElementById('load-avg').textContent = data.system.load_average;
            
            // Update agent metrics
            document.getElementById('active-agents').textContent = data.agents.active;
            document.getElementById('success-rate').textContent = data.agents.success_rate + '%';
            document.getElementById('avg-duration').textContent = data.agents.average_duration_seconds + 's';
            document.getElementById('total-processed').textContent = data.agents.completed + data.agents.failed;
            
            // Update error metrics
            document.getElementById('total-errors').textContent = data.errors.total_errors;
            document.getElementById('error-types').textContent = data.errors.unique_error_types;
            
            // Update top errors
            const topErrorsDiv = document.getElementById('top-errors');
            topErrorsDiv.innerHTML = '';
            data.errors.top_errors.forEach(error => {
                const metric = document.createElement('div');
                metric.className = 'metric';
                metric.innerHTML = `<span>${error.code}</span><span class="metric-value">${error.count}</span>`;
                topErrorsDiv.appendChild(metric);
            });
            
            // Update cache metrics
            document.getElementById('cache-hit-rate').textContent = data.cache.hit_rate + '%';
            document.getElementById('cache-progress').style.width = data.cache.hit_rate + '%';
            document.getElementById('cache-size').textContent = data.cache.size_mb + 'MB';
            document.getElementById('cache-entries').textContent = data.cache.entries;
            
            // Update timestamp
            document.getElementById('timestamp').textContent = 'Last updated: ' + new Date(data.timestamp).toLocaleString();
            document.getElementById('last-update').textContent = new Date(data.timestamp).toLocaleString();
        }
        
        function setProgressClass(elementId, value, warningThreshold, errorThreshold) {
            const element = document.getElementById(elementId);
            element.classList.remove('warning', 'error');
            if (value >= errorThreshold) {
                element.classList.add('error');
            } else if (value >= warningThreshold) {
                element.classList.add('warning');
            }
        }
        
        // Check for alerts
        function checkAlerts(data) {
            const alertsDiv = document.getElementById('alerts');
            alertsDiv.innerHTML = '';
            
            const alerts = [];
            
            if (data.system.cpu_percent > 80) {
                alerts.push(`⚠ High CPU usage: ${data.system.cpu_percent}%`);
            }
            if (data.system.memory.percent > 85) {
                alerts.push(`⚠ High memory usage: ${data.system.memory.percent}%`);
            }
            if (data.agents.failed > 50) {
                alerts.push(`⚠ High failure rate: ${data.agents.failed} failed agents`);
            }
            
            alerts.forEach(alert => {
                const alertDiv = document.createElement('div');
                alertDiv.className = 'alert';
                alertDiv.textContent = alert;
                alertsDiv.appendChild(alertDiv);
            });
        }
        
        // Initialize dashboard
        if (dashboardData && dashboardData.length > 0) {
            const latestData = dashboardData[dashboardData.length - 1];
            updateDashboard(latestData);
            checkAlerts(latestData);
        }
        
        // Auto-refresh every 5 seconds
        setInterval(() => {
            location.reload();
        }, 5000);
    </script>
</body>
</html>
EOF
    
    # Replace placeholder with actual data
    local latest_metrics=$(find "$METRICS_DIR" -name "metrics_*.json" -type f -printf '%T@ %p\n' | \
        sort -nr | head -1 | cut -d' ' -f2-)
    
    if [[ -n "$latest_metrics" ]]; then
        local metrics_json=$(cat "$latest_metrics")
        sed -i "s/DASHBOARD_DATA_PLACEHOLDER/[$metrics_json]/" "$DASHBOARD_FILE"
    else
        sed -i "s/DASHBOARD_DATA_PLACEHOLDER/[]/" "$DASHBOARD_FILE"
    fi
    
    echo "[DASHBOARD] HTML dashboard generated: $DASHBOARD_FILE"
}

# Start web server for dashboard
start_web_server() {
    echo "[DASHBOARD] Starting web server on port $API_PORT..."
    
    # Check if Python is available
    if command -v python3 >/dev/null 2>&1; then
        cd "$STATE_DIR"
        python3 -m http.server "$API_PORT" --bind 127.0.0.1 &
        local server_pid=$!
        echo $server_pid > "$STATE_DIR/.server.pid"
        echo "[DASHBOARD] Dashboard available at http://localhost:$API_PORT/dashboard.html"
    else
        echo "[DASHBOARD] Python3 not available, cannot start web server"
    fi
}

# Stop web server
stop_web_server() {
    if [[ -f "$STATE_DIR/.server.pid" ]]; then
        local pid=$(cat "$STATE_DIR/.server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "[DASHBOARD] Web server stopped"
        fi
        rm -f "$STATE_DIR/.server.pid"
    fi
}

# Monitor loop
monitor_loop() {
    echo "[DASHBOARD] Starting monitor loop (interval: ${UPDATE_INTERVAL}s)..."
    
    while true; do
        collect_metrics
        generate_html_dashboard
        
        if [[ "${TERMINAL_MODE:-false}" == "true" ]]; then
            generate_terminal_dashboard
        fi
        
        sleep "$UPDATE_INTERVAL"
    done
}

# Generate performance report
generate_report() {
    local report_file="$REPORTS_DIR/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    echo "[DASHBOARD] Generating performance report..."
    
    # Get aggregated metrics for the past hour
    local metrics_files=$(find "$METRICS_DIR" -name "metrics_*.json" -mmin -60 -type f | sort)
    
    if [[ -z "$metrics_files" ]]; then
        echo "[DASHBOARD] No metrics available for report"
        return
    fi
    
    # Generate report
    cat > "$report_file" << EOF
# BuildFixAgents Performance Report
Generated: $(date)

## Executive Summary
This report provides performance insights for the BuildFixAgents system over the past hour.

## System Performance
EOF
    
    # Calculate averages
    local avg_cpu=$(echo "$metrics_files" | xargs cat | jq -s 'map(.system.cpu_percent) | add / length')
    local avg_memory=$(echo "$metrics_files" | xargs cat | jq -s 'map(.system.memory.percent) | add / length')
    local max_cpu=$(echo "$metrics_files" | xargs cat | jq -s 'map(.system.cpu_percent) | max')
    local max_memory=$(echo "$metrics_files" | xargs cat | jq -s 'map(.system.memory.percent) | max')
    
    cat >> "$report_file" << EOF

### Resource Usage
- **Average CPU**: ${avg_cpu}%
- **Peak CPU**: ${max_cpu}%
- **Average Memory**: ${avg_memory}%
- **Peak Memory**: ${max_memory}%

## Agent Performance
EOF
    
    # Agent statistics
    local total_completed=$(echo "$metrics_files" | xargs cat | jq -s 'map(.agents.completed) | max')
    local total_failed=$(echo "$metrics_files" | xargs cat | jq -s 'map(.agents.failed) | max')
    local avg_success_rate=$(echo "$metrics_files" | xargs cat | jq -s 'map(.agents.success_rate) | add / length')
    
    cat >> "$report_file" << EOF

- **Total Agents Completed**: $total_completed
- **Total Agents Failed**: $total_failed
- **Average Success Rate**: ${avg_success_rate}%

## Cache Performance
EOF
    
    # Cache statistics
    local avg_hit_rate=$(echo "$metrics_files" | xargs cat | jq -s 'map(.cache.hit_rate) | add / length')
    local total_hits=$(echo "$metrics_files" | xargs cat | jq -s 'map(.cache.hits) | max')
    local total_misses=$(echo "$metrics_files" | xargs cat | jq -s 'map(.cache.misses) | max')
    
    cat >> "$report_file" << EOF

- **Average Hit Rate**: ${avg_hit_rate}%
- **Total Cache Hits**: $total_hits
- **Total Cache Misses**: $total_misses

## Recommendations
EOF
    
    # Generate recommendations based on metrics
    if (( $(echo "$avg_cpu > 70" | bc -l) )); then
        echo "- Consider increasing the number of worker processes to distribute CPU load" >> "$report_file"
    fi
    
    if (( $(echo "$avg_memory > 80" | bc -l) )); then
        echo "- Memory usage is high. Consider enabling more aggressive caching eviction" >> "$report_file"
    fi
    
    if (( $(echo "$avg_hit_rate < 50" | bc -l) )); then
        echo "- Cache hit rate is low. Consider adjusting cache TTL or preloading common data" >> "$report_file"
    fi
    
    echo "[DASHBOARD] Report generated: $report_file"
    cat "$report_file"
}

# Export metrics to JSON
export_metrics() {
    local output_file="${1:-$STATE_DIR/metrics_export.json}"
    
    echo "[DASHBOARD] Exporting metrics to $output_file..."
    
    # Collect all metrics
    local all_metrics=$(find "$METRICS_DIR" -name "metrics_*.json" -type f -exec cat {} \; | jq -s .)
    
    echo "$all_metrics" > "$output_file"
    echo "[DASHBOARD] Exported $(echo "$all_metrics" | jq length) metric samples"
}

# Main function
main() {
    init_dashboard
    
    case "${1:-help}" in
        start)
            collect_metrics
            generate_html_dashboard
            start_web_server
            monitor_loop
            ;;
        terminal)
            TERMINAL_MODE=true
            monitor_loop
            ;;
        once)
            collect_metrics
            if [[ "${2:-}" == "terminal" ]]; then
                generate_terminal_dashboard
            else
                generate_html_dashboard
            fi
            ;;
        server)
            start_web_server
            ;;
        stop)
            stop_web_server
            ;;
        report)
            generate_report
            ;;
        export)
            export_metrics "${2:-}"
            ;;
        clean)
            echo "[DASHBOARD] Cleaning old metrics..."
            find "$METRICS_DIR" -name "metrics_*.json" -mtime +1 -delete
            echo "[DASHBOARD] Cleanup complete"
            ;;
        test)
            echo "[DASHBOARD] Running dashboard test..."
            
            # Generate test metrics
            collect_metrics
            
            # Generate dashboards
            generate_terminal_dashboard
            generate_html_dashboard
            
            # Show status
            echo -e "\n[DASHBOARD] Test complete"
            echo "Terminal dashboard displayed above"
            echo "HTML dashboard: $DASHBOARD_FILE"
            ;;
        *)
            cat << EOF
Performance Dashboard - Real-time monitoring and visualization

Usage: $0 <command> [options]

Commands:
  start       - Start dashboard with web server and monitoring
  terminal    - Start terminal-only dashboard
  once        - Generate dashboard once and exit
  server      - Start web server only
  stop        - Stop web server
  report      - Generate performance report
  export      - Export metrics to JSON
  clean       - Clean old metrics
  test        - Run dashboard test

Options:
  once terminal - Show terminal dashboard once

Environment Variables:
  UPDATE_INTERVAL=5         - Update interval in seconds
  API_PORT=8080            - Web server port
  RETENTION_HOURS=24       - Metric retention period
  ENABLE_ALERTS=true       - Enable performance alerts

Examples:
  # Start full dashboard with web interface
  $0 start
  
  # Terminal dashboard only
  $0 terminal
  
  # Generate one-time report
  $0 report
  
  # Export metrics for analysis
  $0 export metrics_backup.json

Web Interface:
  Once started, access the dashboard at:
  http://localhost:8080/dashboard.html
EOF
            ;;
    esac
}

# Handle signals
trap 'stop_web_server; exit 0' EXIT INT TERM

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi