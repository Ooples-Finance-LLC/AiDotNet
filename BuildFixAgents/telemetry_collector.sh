#!/bin/bash

# Telemetry and Metrics Collection System
# Collects, aggregates, and exports performance metrics from all agents

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
METRICS_DIR="$AGENT_DIR/state/metrics"
TELEMETRY_CONFIG="$AGENT_DIR/config/telemetry.yml"
EXPORT_DIR="$AGENT_DIR/state/exports"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize
mkdir -p "$METRICS_DIR" "$EXPORT_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] TELEMETRY${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/telemetry.log"
}

# Create default telemetry configuration
create_default_config() {
    if [[ ! -f "$TELEMETRY_CONFIG" ]]; then
        cat > "$TELEMETRY_CONFIG" << 'EOF'
# Telemetry Configuration
telemetry:
  enabled: true
  collection_interval: 60  # seconds
  retention_days: 30
  
  # Metrics to collect
  metrics:
    system:
      - cpu_usage
      - memory_usage
      - disk_usage
      - network_io
      
    agent:
      - execution_time
      - error_count
      - success_rate
      - files_processed
      - fixes_applied
      
    build:
      - build_duration
      - error_types
      - compilation_time
      - test_results
      
    performance:
      - response_time
      - throughput
      - queue_length
      - worker_utilization
      
  # Export targets
  exports:
    prometheus:
      enabled: false
      port: 9090
      path: "/metrics"
      
    json:
      enabled: true
      path: "state/exports/metrics.json"
      
    csv:
      enabled: true
      path: "state/exports/metrics.csv"
      
    influxdb:
      enabled: false
      url: "http://localhost:8086"
      database: "buildfix"
      token: "your-token-here"
      
  # Alerting thresholds
  alerts:
    high_cpu:
      threshold: 80
      duration: 300  # seconds
      
    high_memory:
      threshold: 90
      duration: 300
      
    long_build:
      threshold: 1800  # 30 minutes
      
    high_error_rate:
      threshold: 0.2  # 20% error rate
      duration: 600
      
  # Aggregation
  aggregation:
    intervals:
      - 1m   # 1 minute
      - 5m   # 5 minutes
      - 1h   # 1 hour
      - 1d   # 1 day
    functions:
      - avg
      - min
      - max
      - sum
      - count
      - p95  # 95th percentile
      - p99  # 99th percentile
EOF
        log_message "Created default telemetry configuration"
    fi
}

# Initialize metrics database
init_metrics_db() {
    local db_file="$METRICS_DIR/metrics.db"
    
    # Create SQLite database for metrics storage
    if command -v sqlite3 &> /dev/null; then
        sqlite3 "$db_file" << 'EOF'
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    labels TEXT,
    agent_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_metrics_agent ON metrics(agent_id);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    event_data TEXT,
    severity TEXT,
    agent_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
EOF
        log_message "Metrics database initialized"
    else
        log_message "SQLite not available, using file-based storage" "WARN"
    fi
}

# Collect system metrics
collect_system_metrics() {
    local timestamp=$(date +%s)
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo 0)
    record_metric "system_cpu_usage" "$cpu_usage" "$timestamp" "type=percent"
    
    # Memory usage
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc || echo 0)
    record_metric "system_memory_usage" "$mem_percent" "$timestamp" "type=percent"
    record_metric "system_memory_used_mb" "$mem_used" "$timestamp" "type=megabytes"
    
    # Disk usage
    local disk_usage=$(df -h "$AGENT_DIR" | awk 'NR==2{print $5}' | cut -d'%' -f1 || echo 0)
    record_metric "system_disk_usage" "$disk_usage" "$timestamp" "type=percent,path=$AGENT_DIR"
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' || echo 0)
    record_metric "system_load_average" "$load_avg" "$timestamp" "type=1min"
    
    # Process count
    local process_count=$(ps aux | grep -c "agent" || echo 0)
    record_metric "agent_process_count" "$process_count" "$timestamp" "type=count"
}

# Collect agent metrics
collect_agent_metrics() {
    local timestamp=$(date +%s)
    
    # Parse agent logs for metrics
    if [[ -d "$AGENT_DIR/logs" ]]; then
        # Count errors fixed
        local errors_fixed=$(grep -h "FIXED" "$AGENT_DIR/logs"/*.log 2>/dev/null | wc -l || echo 0)
        record_metric "agent_errors_fixed_total" "$errors_fixed" "$timestamp" "type=counter"
        
        # Count active agents
        local active_agents=$(ls "$AGENT_DIR"/.pid_* 2>/dev/null | wc -l || echo 0)
        record_metric "agent_active_count" "$active_agents" "$timestamp" "type=gauge"
        
        # Count failed fixes
        local failed_fixes=$(grep -h "FAILED" "$AGENT_DIR/logs"/*.log 2>/dev/null | wc -l || echo 0)
        record_metric "agent_fixes_failed_total" "$failed_fixes" "$timestamp" "type=counter"
        
        # Calculate success rate
        local total_attempts=$((errors_fixed + failed_fixes))
        if [[ $total_attempts -gt 0 ]]; then
            local success_rate=$(echo "scale=2; $errors_fixed * 100 / $total_attempts" | bc)
            record_metric "agent_success_rate" "$success_rate" "$timestamp" "type=percent"
        fi
    fi
    
    # Collect timing metrics from state files
    if [[ -f "$AGENT_DIR/state/timing_metrics.json" ]]; then
        while IFS= read -r line; do
            local metric_name=$(echo "$line" | jq -r '.metric' 2>/dev/null || continue)
            local metric_value=$(echo "$line" | jq -r '.value' 2>/dev/null || continue)
            [[ -n "$metric_name" && -n "$metric_value" ]] && \
                record_metric "agent_$metric_name" "$metric_value" "$timestamp" "type=duration_ms"
        done < "$AGENT_DIR/state/timing_metrics.json"
    fi
}

# Collect build metrics
collect_build_metrics() {
    local timestamp=$(date +%s)
    
    # Parse build output
    if [[ -f "$AGENT_DIR/logs/build_output.txt" ]]; then
        # Count error types
        local cs_errors=$(grep -c "error CS" "$AGENT_DIR/logs/build_output.txt" 2>/dev/null || echo 0)
        record_metric "build_cs_errors" "$cs_errors" "$timestamp" "type=count"
        
        # Count warning types
        local warnings=$(grep -c "warning" "$AGENT_DIR/logs/build_output.txt" 2>/dev/null || echo 0)
        record_metric "build_warnings" "$warnings" "$timestamp" "type=count"
        
        # Build duration (if available)
        if [[ -f "$AGENT_DIR/state/build_times.txt" ]]; then
            local last_build_time=$(tail -1 "$AGENT_DIR/state/build_times.txt" 2>/dev/null || echo 0)
            record_metric "build_duration_seconds" "$last_build_time" "$timestamp" "type=duration"
        fi
    fi
    
    # Project size metrics
    local cs_files=$(find "$PROJECT_DIR" -name "*.cs" ! -path "*/bin/*" ! -path "*/obj/*" | wc -l || echo 0)
    record_metric "project_cs_files" "$cs_files" "$timestamp" "type=count"
    
    local total_lines=$(find "$PROJECT_DIR" -name "*.cs" ! -path "*/bin/*" ! -path "*/obj/*" -exec wc -l {} + | tail -1 | awk '{print $1}' || echo 0)
    record_metric "project_lines_of_code" "$total_lines" "$timestamp" "type=count"
}

# Record metric
record_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local timestamp="${3:-$(date +%s)}"
    local labels="${4:-}"
    local agent_id="${AGENT_ID:-system}"
    
    # Store in SQLite if available
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 "$METRICS_DIR/metrics.db" << EOF
INSERT INTO metrics (timestamp, metric_name, metric_value, labels, agent_id)
VALUES ($timestamp, '$metric_name', $metric_value, '$labels', '$agent_id');
EOF
    fi
    
    # Also store in JSON format
    local metric_file="$METRICS_DIR/metrics_$(date +%Y%m%d).json"
    cat >> "$metric_file" << EOF
{"timestamp":$timestamp,"name":"$metric_name","value":$metric_value,"labels":"$labels","agent":"$agent_id"}
EOF
}

# Record event
record_event() {
    local event_type="$1"
    local event_data="$2"
    local severity="${3:-info}"
    local timestamp=$(date +%s)
    local agent_id="${AGENT_ID:-system}"
    
    # Store in SQLite if available
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 "$METRICS_DIR/metrics.db" << EOF
INSERT INTO events (timestamp, event_type, event_data, severity, agent_id)
VALUES ($timestamp, '$event_type', '$event_data', '$severity', '$agent_id');
EOF
    fi
    
    # Log event
    log_message "Event: $event_type - $event_data" "${severity^^}"
}

# Aggregate metrics
aggregate_metrics() {
    local interval="$1"  # 1m, 5m, 1h, 1d
    local timestamp=$(date +%s)
    
    log_message "Aggregating metrics for interval: $interval"
    
    # Calculate time window
    local window_seconds=60
    case "$interval" in
        "5m") window_seconds=300 ;;
        "1h") window_seconds=3600 ;;
        "1d") window_seconds=86400 ;;
    esac
    
    local start_time=$((timestamp - window_seconds))
    
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        # Aggregate using SQLite
        sqlite3 "$METRICS_DIR/metrics.db" << EOF
CREATE TEMPORARY TABLE aggregated_metrics AS
SELECT 
    metric_name,
    COUNT(*) as count,
    AVG(metric_value) as avg_value,
    MIN(metric_value) as min_value,
    MAX(metric_value) as max_value,
    SUM(metric_value) as sum_value
FROM metrics
WHERE timestamp >= $start_time AND timestamp <= $timestamp
GROUP BY metric_name;

-- Store aggregated results
INSERT INTO metrics (timestamp, metric_name, metric_value, labels, agent_id)
SELECT 
    $timestamp,
    metric_name || '_avg_' || '$interval',
    avg_value,
    'interval=$interval,aggregation=avg',
    'aggregator'
FROM aggregated_metrics;

DROP TABLE aggregated_metrics;
EOF
    fi
}

# Export metrics to Prometheus format
export_prometheus() {
    local export_file="$EXPORT_DIR/prometheus_metrics.txt"
    local timestamp=$(date +%s)000  # Convert to milliseconds
    
    log_message "Exporting metrics in Prometheus format"
    
    # Clear previous export
    > "$export_file"
    
    # Export from SQLite if available
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 "$METRICS_DIR/metrics.db" << EOF | while IFS='|' read -r name value labels; do
SELECT metric_name, metric_value, labels
FROM metrics
WHERE timestamp >= strftime('%s', 'now', '-5 minutes')
ORDER BY timestamp DESC;
EOF
            # Format for Prometheus
            if [[ -n "$labels" ]]; then
                echo "${name}{${labels}} ${value} ${timestamp}" >> "$export_file"
            else
                echo "${name} ${value} ${timestamp}" >> "$export_file"
            fi
        done
    fi
    
    log_message "Prometheus export complete: $export_file"
}

# Export metrics to JSON
export_json() {
    local export_file="$EXPORT_DIR/metrics_$(date +%Y%m%d_%H%M%S).json"
    
    log_message "Exporting metrics in JSON format"
    
    # Start JSON array
    echo "[" > "$export_file"
    
    local first=true
    
    # Export recent metrics
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 "$METRICS_DIR/metrics.db" << 'EOF' | while IFS='|' read -r line; do
SELECT json_object(
    'timestamp', timestamp,
    'name', metric_name,
    'value', metric_value,
    'labels', labels,
    'agent', agent_id
)
FROM metrics
WHERE timestamp >= strftime('%s', 'now', '-1 hour')
ORDER BY timestamp DESC
LIMIT 10000;
EOF
            if [[ "$first" != "true" ]]; then
                echo "," >> "$export_file"
            fi
            first=false
            echo -n "$line" >> "$export_file"
        done
    fi
    
    # Close JSON array
    echo -e "\n]" >> "$export_file"
    
    log_message "JSON export complete: $export_file"
}

# Export metrics to CSV
export_csv() {
    local export_file="$EXPORT_DIR/metrics_$(date +%Y%m%d_%H%M%S).csv"
    
    log_message "Exporting metrics in CSV format"
    
    # CSV header
    echo "timestamp,metric_name,value,labels,agent_id" > "$export_file"
    
    # Export data
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 -csv "$METRICS_DIR/metrics.db" << 'EOF' >> "$export_file"
SELECT timestamp, metric_name, metric_value, labels, agent_id
FROM metrics
WHERE timestamp >= strftime('%s', 'now', '-1 hour')
ORDER BY timestamp DESC
LIMIT 10000;
EOF
    fi
    
    log_message "CSV export complete: $export_file"
}

# Check alert conditions
check_alerts() {
    local timestamp=$(date +%s)
    
    # Check CPU usage
    local cpu_threshold=80
    local cpu_current=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT AVG(metric_value) FROM metrics WHERE metric_name='system_cpu_usage' AND timestamp >= $((timestamp - 300))" 2>/dev/null || echo 0)
    
    if (( $(echo "$cpu_current > $cpu_threshold" | bc -l) )); then
        record_event "high_cpu_alert" "CPU usage at ${cpu_current}% (threshold: ${cpu_threshold}%)" "warning"
    fi
    
    # Check memory usage
    local mem_threshold=90
    local mem_current=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT AVG(metric_value) FROM metrics WHERE metric_name='system_memory_usage' AND timestamp >= $((timestamp - 300))" 2>/dev/null || echo 0)
    
    if (( $(echo "$mem_current > $mem_threshold" | bc -l) )); then
        record_event "high_memory_alert" "Memory usage at ${mem_current}% (threshold: ${mem_threshold}%)" "warning"
    fi
    
    # Check error rate
    local error_rate=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT AVG(metric_value) FROM metrics WHERE metric_name='agent_success_rate' AND timestamp >= $((timestamp - 600))" 2>/dev/null || echo 100)
    local error_threshold=80
    
    if (( $(echo "$error_rate < $error_threshold" | bc -l) )); then
        record_event "high_error_rate" "Success rate at ${error_rate}% (threshold: ${error_threshold}%)" "error"
    fi
}

# Generate metrics dashboard
generate_dashboard() {
    local dashboard_file="$EXPORT_DIR/metrics_dashboard.html"
    
    log_message "Generating metrics dashboard"
    
    # Get current metrics
    local cpu_usage=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT metric_value FROM metrics WHERE metric_name='system_cpu_usage' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo 0)
    local mem_usage=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT metric_value FROM metrics WHERE metric_name='system_memory_usage' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo 0)
    local errors_fixed=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT metric_value FROM metrics WHERE metric_name='agent_errors_fixed_total' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo 0)
    local success_rate=$(sqlite3 "$METRICS_DIR/metrics.db" "SELECT metric_value FROM metrics WHERE metric_name='agent_success_rate' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null || echo 0)
    
    cat > "$dashboard_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Build Fix Agent - Metrics Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-value { font-size: 3em; font-weight: bold; margin: 10px 0; }
        .metric-label { color: #7f8c8d; font-size: 0.9em; }
        .chart-container { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; height: 400px; }
        .status-good { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-error { color: #e74c3c; }
        table { width: 100%; border-collapse: collapse; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ecf0f1; }
        th { background-color: #34495e; color: white; font-weight: normal; }
        tr:hover { background-color: #f8f9fa; }
        .refresh-time { text-align: right; color: #7f8c8d; font-size: 0.9em; margin-top: 20px; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Build Fix Agent - Metrics Dashboard</h1>
            <p>Real-time system and agent performance metrics</p>
        </div>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">CPU Usage</div>
                <div class="metric-value ${cpu_usage > 80 ? 'status-error' : cpu_usage > 60 ? 'status-warning' : 'status-good'}">${cpu_usage}%</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Memory Usage</div>
                <div class="metric-value ${mem_usage > 90 ? 'status-error' : mem_usage > 70 ? 'status-warning' : 'status-good'}">${mem_usage}%</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Errors Fixed</div>
                <div class="metric-value status-good">${errors_fixed}</div>
            </div>
            
            <div class="metric-card">
                <div class="metric-label">Success Rate</div>
                <div class="metric-value ${success_rate < 80 ? 'status-error' : success_rate < 90 ? 'status-warning' : 'status-good'}">${success_rate}%</div>
            </div>
        </div>
        
        <div class="chart-container">
            <canvas id="performanceChart"></canvas>
        </div>
        
        <h2>Recent Events</h2>
        <table>
            <thead>
                <tr>
                    <th>Time</th>
                    <th>Event Type</th>
                    <th>Description</th>
                    <th>Severity</th>
                </tr>
            </thead>
            <tbody id="eventsTable">
EOF
    
    # Add recent events
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        sqlite3 "$METRICS_DIR/metrics.db" << 'EOF' | while IFS='|' read -r timestamp event_type event_data severity; do
SELECT 
    datetime(timestamp, 'unixepoch', 'localtime'),
    event_type,
    event_data,
    severity
FROM events
ORDER BY timestamp DESC
LIMIT 10;
EOF
            local severity_class="status-good"
            [[ "$severity" == "warning" ]] && severity_class="status-warning"
            [[ "$severity" == "error" || "$severity" == "critical" ]] && severity_class="status-error"
            
            cat >> "$dashboard_file" << EOF
                <tr>
                    <td>$timestamp</td>
                    <td>$event_type</td>
                    <td>$event_data</td>
                    <td class="$severity_class">$severity</td>
                </tr>
EOF
        done
    fi
    
    cat >> "$dashboard_file" << 'EOF'
            </tbody>
        </table>
        
        <div class="refresh-time">Last updated: <span id="updateTime"></span></div>
    </div>
    
    <script>
        // Set update time
        document.getElementById('updateTime').textContent = new Date().toLocaleString();
        
        // Create performance chart
        const ctx = document.getElementById('performanceChart').getContext('2d');
        const chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CPU Usage',
                    data: [],
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1
                }, {
                    label: 'Memory Usage',
                    data: [],
                    borderColor: 'rgb(255, 99, 132)',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: 'System Performance Over Time'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100
                    }
                }
            }
        });
        
        // Auto-refresh every 30 seconds
        setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>
EOF
    
    log_message "Dashboard generated: $dashboard_file"
}

# Start telemetry collection
start_collection() {
    log_message "Starting telemetry collection..."
    
    # Initialize database
    init_metrics_db
    
    # Create PID file
    echo $$ > "$AGENT_DIR/state/telemetry.pid"
    
    # Collection loop
    while true; do
        # Collect metrics
        collect_system_metrics
        collect_agent_metrics
        collect_build_metrics
        
        # Check alerts
        check_alerts
        
        # Aggregate metrics every 5 minutes
        if [[ $(($(date +%s) % 300)) -lt 60 ]]; then
            aggregate_metrics "5m"
        fi
        
        # Export metrics every minute
        if [[ $(($(date +%s) % 60)) -lt 5 ]]; then
            export_json
            export_prometheus
            generate_dashboard
        fi
        
        # Sleep for collection interval
        sleep "${TELEMETRY_INTERVAL:-60}"
    done
}

# Stop telemetry collection
stop_collection() {
    log_message "Stopping telemetry collection..."
    
    if [[ -f "$AGENT_DIR/state/telemetry.pid" ]]; then
        local pid=$(cat "$AGENT_DIR/state/telemetry.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$AGENT_DIR/state/telemetry.pid"
    fi
    
    log_message "Telemetry collection stopped"
}

# Show metrics summary
show_metrics_summary() {
    echo -e "${BLUE}=== Metrics Summary ===${NC}\n"
    
    if command -v sqlite3 &> /dev/null && [[ -f "$METRICS_DIR/metrics.db" ]]; then
        echo -e "${CYAN}System Metrics:${NC}"
        sqlite3 "$METRICS_DIR/metrics.db" << 'EOF' | column -t -s '|'
SELECT 
    metric_name as 'Metric',
    ROUND(AVG(metric_value), 2) as 'Avg',
    ROUND(MIN(metric_value), 2) as 'Min',
    ROUND(MAX(metric_value), 2) as 'Max'
FROM metrics
WHERE metric_name LIKE 'system_%'
  AND timestamp >= strftime('%s', 'now', '-1 hour')
GROUP BY metric_name;
EOF
        
        echo -e "\n${CYAN}Agent Metrics:${NC}"
        sqlite3 "$METRICS_DIR/metrics.db" << 'EOF' | column -t -s '|'
SELECT 
    metric_name as 'Metric',
    ROUND(metric_value, 2) as 'Latest Value'
FROM metrics
WHERE metric_name LIKE 'agent_%'
ORDER BY timestamp DESC
LIMIT 10;
EOF
        
        echo -e "\n${CYAN}Recent Events:${NC}"
        sqlite3 "$METRICS_DIR/metrics.db" << 'EOF' | column -t -s '|'
SELECT 
    datetime(timestamp, 'unixepoch', 'localtime') as 'Time',
    event_type as 'Event',
    severity as 'Severity'
FROM events
ORDER BY timestamp DESC
LIMIT 5;
EOF
    else
        echo "No metrics data available"
    fi
}

# Main menu
main() {
    local command="${1:-help}"
    shift || true
    
    # Initialize
    create_default_config
    
    case "$command" in
        "start")
            start_collection &
            echo "Telemetry collection started (PID: $!)"
            ;;
            
        "stop")
            stop_collection
            ;;
            
        "status")
            if [[ -f "$AGENT_DIR/state/telemetry.pid" ]]; then
                echo -e "${GREEN}Telemetry collection is running${NC}"
            else
                echo -e "${YELLOW}Telemetry collection is not running${NC}"
            fi
            show_metrics_summary
            ;;
            
        "export")
            export_json
            export_csv
            export_prometheus
            generate_dashboard
            echo "Metrics exported to: $EXPORT_DIR"
            ;;
            
        "dashboard")
            generate_dashboard
            echo "Dashboard generated: $EXPORT_DIR/metrics_dashboard.html"
            if command -v xdg-open &> /dev/null; then
                xdg-open "$EXPORT_DIR/metrics_dashboard.html"
            fi
            ;;
            
        "query")
            local metric="${1:-}"
            if [[ -z "$metric" ]]; then
                echo "Usage: $0 query <metric_name>"
                exit 1
            fi
            sqlite3 "$METRICS_DIR/metrics.db" << EOF | column -t -s '|'
SELECT 
    datetime(timestamp, 'unixepoch', 'localtime') as 'Time',
    metric_value as 'Value',
    labels as 'Labels'
FROM metrics
WHERE metric_name = '$metric'
ORDER BY timestamp DESC
LIMIT 20;
EOF
            ;;
            
        *)
            echo -e "${BLUE}Telemetry and Metrics Collection${NC}"
            echo -e "${YELLOW}=================================${NC}\n"
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  start     - Start telemetry collection"
            echo "  stop      - Stop telemetry collection"
            echo "  status    - Show collection status and summary"
            echo "  export    - Export metrics in all formats"
            echo "  dashboard - Generate and open metrics dashboard"
            echo "  query <metric> - Query specific metric values"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 query system_cpu_usage"
            echo "  $0 dashboard"
            ;;
    esac
}

# Execute
main "$@"