#!/bin/bash

# Notification System for Build Fix Agents
# Handles alerts, progress updates, and reporting via multiple channels

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
NOTIFICATIONS_DIR="$AGENT_DIR/state/notifications"
NOTIFICATION_CONFIG="$AGENT_DIR/config/notifications.yml"
NOTIFICATION_LOG="$AGENT_DIR/logs/notifications.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize
mkdir -p "$NOTIFICATIONS_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] NOTIFICATION${NC} [${level}]: $message" | tee -a "$NOTIFICATION_LOG"
}

# Create default notification configuration
create_default_config() {
    if [[ ! -f "$NOTIFICATION_CONFIG" ]]; then
        cat > "$NOTIFICATION_CONFIG" << 'EOF'
# Notification Configuration
notifications:
  enabled: true
  
  # Notification channels
  channels:
    console:
      enabled: true
      min_level: info  # debug, info, warning, error, critical
      color_output: true
      
    file:
      enabled: true
      path: "logs/build_notifications.log"
      min_level: debug
      max_size_mb: 10
      rotate_count: 5
      
    email:
      enabled: false
      smtp_server: "smtp.gmail.com"
      smtp_port: 587
      use_tls: true
      from: "buildfix@example.com"
      to: ["dev-team@example.com"]
      min_level: error
      
    slack:
      enabled: false
      webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
      channel: "#build-notifications"
      username: "Build Fix Agent"
      min_level: warning
      
    teams:
      enabled: false
      webhook_url: "https://outlook.office.com/webhook/YOUR/WEBHOOK/URL"
      min_level: warning
      
    webhook:
      enabled: false
      url: "https://your-api.com/notifications"
      method: "POST"
      headers:
        Authorization: "Bearer YOUR_TOKEN"
      min_level: info
      
  # Notification rules
  rules:
    build_start:
      channels: [console, file]
      template: "Build fix process started for {project}"
      
    build_complete:
      channels: [console, file, slack]
      template: "Build fix completed: {errors_fixed} errors fixed in {duration}"
      
    build_failed:
      channels: [console, file, email, slack]
      template: "Build fix failed: {error_message}"
      
    security_alert:
      channels: [console, file, email, slack, teams]
      template: "Security issue detected: {issue_type} in {file}"
      
    performance_issue:
      channels: [console, file, slack]
      template: "Performance issue: {metric} exceeded threshold ({value} > {threshold})"
      
  # Rate limiting
  rate_limit:
    enabled: true
    max_per_minute: 10
    max_per_hour: 100
    
  # Aggregation
  aggregation:
    enabled: true
    window_minutes: 5
    min_occurrences: 3
EOF
        log_message "Created default notification configuration"
    fi
}

# Load notification configuration
load_config() {
    # For simplicity, we'll set some defaults
    # In production, use a proper YAML parser
    export NOTIFY_CONSOLE_ENABLED="${NOTIFY_CONSOLE_ENABLED:-true}"
    export NOTIFY_FILE_ENABLED="${NOTIFY_FILE_ENABLED:-true}"
    export NOTIFY_EMAIL_ENABLED="${NOTIFY_EMAIL_ENABLED:-false}"
    export NOTIFY_SLACK_ENABLED="${NOTIFY_SLACK_ENABLED:-false}"
    export NOTIFY_TEAMS_ENABLED="${NOTIFY_TEAMS_ENABLED:-false}"
    export NOTIFY_WEBHOOK_ENABLED="${NOTIFY_WEBHOOK_ENABLED:-false}"
}

# Send notification
send_notification() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="${4:-}"
    
    # Create notification object
    local notification_id=$(uuidgen 2>/dev/null || echo "$(date +%s)-$$")
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create notification file
    local notification_file="$NOTIFICATIONS_DIR/notification_${notification_id}.json"
    cat > "$notification_file" << EOF
{
  "id": "$notification_id",
  "timestamp": "$timestamp",
  "level": "$level",
  "event_type": "$event_type",
  "message": "$message",
  "details": $details,
  "project": "$PROJECT_DIR",
  "agent": "${AGENT_ID:-unknown}"
}
EOF
    
    # Send to enabled channels
    send_to_console "$level" "$event_type" "$message"
    send_to_file "$level" "$event_type" "$message" "$details"
    
    if [[ "$NOTIFY_EMAIL_ENABLED" == "true" ]]; then
        send_to_email "$level" "$event_type" "$message" "$details"
    fi
    
    if [[ "$NOTIFY_SLACK_ENABLED" == "true" ]]; then
        send_to_slack "$level" "$event_type" "$message" "$details"
    fi
    
    if [[ "$NOTIFY_TEAMS_ENABLED" == "true" ]]; then
        send_to_teams "$level" "$event_type" "$message" "$details"
    fi
    
    if [[ "$NOTIFY_WEBHOOK_ENABLED" == "true" ]]; then
        send_to_webhook "$level" "$event_type" "$message" "$details"
    fi
}

# Console notification
send_to_console() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    
    if [[ "$NOTIFY_CONSOLE_ENABLED" != "true" ]]; then
        return
    fi
    
    # Color based on level
    local color="$NC"
    local icon=""
    
    case "$level" in
        "debug") color="$CYAN"; icon="🔍" ;;
        "info") color="$BLUE"; icon="ℹ️" ;;
        "warning") color="$YELLOW"; icon="⚠️" ;;
        "error") color="$RED"; icon="❌" ;;
        "critical") color="$RED"; icon="🚨" ;;
    esac
    
    echo -e "${color}${icon} [$event_type] $message${NC}"
}

# File notification
send_to_file() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="$4"
    
    if [[ "$NOTIFY_FILE_ENABLED" != "true" ]]; then
        return
    fi
    
    local log_file="${NOTIFY_FILE_PATH:-$AGENT_DIR/logs/build_notifications.log}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$log_file")"
    
    # Write to log
    cat >> "$log_file" << EOF
[$timestamp] [$level] [$event_type] $message
Details: $details
---
EOF
    
    # Rotate log if too large
    rotate_log_if_needed "$log_file"
}

# Email notification
send_to_email() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="$4"
    
    # Check if we should send based on level
    if ! should_send_for_level "$level" "error"; then
        return
    fi
    
    log_message "Sending email notification..."
    
    # Create email content
    local email_body=$(cat << EOF
Build Fix Agent Notification

Event: $event_type
Level: $level
Time: $(date)
Project: $PROJECT_DIR

Message:
$message

Details:
$details

---
This is an automated notification from the Build Fix Agent System.
EOF
)
    
    # For demonstration, we'll just log it
    # In production, use mail, sendmail, or an SMTP library
    echo "$email_body" > "$NOTIFICATIONS_DIR/email_$(date +%s).txt"
    log_message "Email notification queued (demo mode)"
}

# Slack notification
send_to_slack() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="$4"
    
    # Check if we should send based on level
    if ! should_send_for_level "$level" "warning"; then
        return
    fi
    
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    if [[ -z "$webhook_url" ]]; then
        log_message "Slack webhook URL not configured" "WARN"
        return
    fi
    
    # Determine color based on level
    local color="good"
    case "$level" in
        "warning") color="warning" ;;
        "error"|"critical") color="danger" ;;
    esac
    
    # Create Slack payload
    local payload=$(cat << EOF
{
  "username": "Build Fix Agent",
  "icon_emoji": ":hammer_and_wrench:",
  "channel": "${SLACK_CHANNEL:-#build-notifications}",
  "attachments": [
    {
      "color": "$color",
      "title": "$event_type",
      "text": "$message",
      "fields": [
        {
          "title": "Project",
          "value": "$(basename "$PROJECT_DIR")",
          "short": true
        },
        {
          "title": "Level",
          "value": "$level",
          "short": true
        },
        {
          "title": "Time",
          "value": "$(date '+%Y-%m-%d %H:%M:%S')",
          "short": true
        }
      ],
      "footer": "Build Fix Agent",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
    
    # Send to Slack
    if command -v curl &> /dev/null; then
        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$webhook_url" \
            >/dev/null 2>&1 || log_message "Failed to send Slack notification" "ERROR"
    else
        echo "$payload" > "$NOTIFICATIONS_DIR/slack_$(date +%s).json"
        log_message "Slack notification queued (curl not available)"
    fi
}

# Microsoft Teams notification
send_to_teams() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="$4"
    
    # Check if we should send based on level
    if ! should_send_for_level "$level" "warning"; then
        return
    fi
    
    local webhook_url="${TEAMS_WEBHOOK_URL:-}"
    if [[ -z "$webhook_url" ]]; then
        log_message "Teams webhook URL not configured" "WARN"
        return
    fi
    
    # Determine color based on level
    local color="0072C6"  # Default blue
    case "$level" in
        "warning") color="FFA500" ;;  # Orange
        "error"|"critical") color="FF0000" ;;  # Red
    esac
    
    # Create Teams payload (Adaptive Card)
    local payload=$(cat << EOF
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "$color",
  "summary": "$event_type: $message",
  "sections": [
    {
      "activityTitle": "Build Fix Agent Notification",
      "activitySubtitle": "$event_type",
      "facts": [
        {
          "name": "Project:",
          "value": "$(basename "$PROJECT_DIR")"
        },
        {
          "name": "Level:",
          "value": "$level"
        },
        {
          "name": "Message:",
          "value": "$message"
        },
        {
          "name": "Time:",
          "value": "$(date '+%Y-%m-%d %H:%M:%S')"
        }
      ],
      "markdown": true
    }
  ]
}
EOF
)
    
    # Send to Teams
    if command -v curl &> /dev/null; then
        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$webhook_url" \
            >/dev/null 2>&1 || log_message "Failed to send Teams notification" "ERROR"
    else
        echo "$payload" > "$NOTIFICATIONS_DIR/teams_$(date +%s).json"
        log_message "Teams notification queued (curl not available)"
    fi
}

# Generic webhook notification
send_to_webhook() {
    local level="$1"
    local event_type="$2"
    local message="$3"
    local details="$4"
    
    local webhook_url="${WEBHOOK_URL:-}"
    if [[ -z "$webhook_url" ]]; then
        log_message "Webhook URL not configured" "WARN"
        return
    fi
    
    # Create generic webhook payload
    local payload=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "level": "$level",
  "event_type": "$event_type",
  "message": "$message",
  "details": $details,
  "source": {
    "agent": "build_fix_agent",
    "project": "$PROJECT_DIR",
    "host": "$(hostname)"
  }
}
EOF
)
    
    # Send webhook
    if command -v curl &> /dev/null; then
        curl -X "${WEBHOOK_METHOD:-POST}" \
            -H 'Content-type: application/json' \
            -H "${WEBHOOK_AUTH_HEADER:-Authorization: Bearer dummy}" \
            --data "$payload" \
            "$webhook_url" \
            >/dev/null 2>&1 || log_message "Failed to send webhook notification" "ERROR"
    else
        echo "$payload" > "$NOTIFICATIONS_DIR/webhook_$(date +%s).json"
        log_message "Webhook notification queued (curl not available)"
    fi
}

# Check if should send based on level
should_send_for_level() {
    local message_level="$1"
    local min_level="$2"
    
    # Define level priorities
    declare -A level_priority=(
        ["debug"]=0
        ["info"]=1
        ["warning"]=2
        ["error"]=3
        ["critical"]=4
    )
    
    local message_priority="${level_priority[$message_level]:-0}"
    local min_priority="${level_priority[$min_level]:-0}"
    
    [[ $message_priority -ge $min_priority ]]
}

# Rotate log file if needed
rotate_log_if_needed() {
    local log_file="$1"
    local max_size_mb="${LOG_MAX_SIZE_MB:-10}"
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    if [[ -f "$log_file" ]]; then
        local file_size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
        
        if [[ $file_size -gt $max_size_bytes ]]; then
            local timestamp=$(date +%Y%m%d_%H%M%S)
            mv "$log_file" "${log_file}.${timestamp}"
            
            # Keep only last N rotated files
            local rotate_count="${LOG_ROTATE_COUNT:-5}"
            ls -t "${log_file}".* 2>/dev/null | tail -n +$((rotate_count + 1)) | xargs rm -f
            
            log_message "Rotated log file: $log_file"
        fi
    fi
}

# Send build progress notification
notify_build_progress() {
    local phase="$1"
    local current="$2"
    local total="$3"
    local details="${4:-}"
    
    local percentage=$((current * 100 / total))
    local message="Build progress: $phase ($current/$total - $percentage%)"
    
    local details_json=$(cat << EOF
{
  "phase": "$phase",
  "current": $current,
  "total": $total,
  "percentage": $percentage,
  "details": "$details"
}
EOF
)
    
    send_notification "info" "build_progress" "$message" "$details_json"
}

# Send build completion notification
notify_build_complete() {
    local errors_fixed="$1"
    local duration="$2"
    local success="${3:-true}"
    
    local level="info"
    local event_type="build_complete"
    
    if [[ "$success" != "true" ]]; then
        level="error"
        event_type="build_failed"
    fi
    
    local message="Build fix completed: $errors_fixed errors fixed in ${duration}s"
    
    local details_json=$(cat << EOF
{
  "errors_fixed": $errors_fixed,
  "duration": $duration,
  "success": $success,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    send_notification "$level" "$event_type" "$message" "$details_json"
}

# Send security alert
notify_security_alert() {
    local issue_type="$1"
    local severity="$2"
    local file="$3"
    local description="${4:-}"
    
    local level="warning"
    [[ "$severity" == "critical" || "$severity" == "high" ]] && level="error"
    
    local message="Security issue detected: $issue_type in $(basename "$file")"
    
    local details_json=$(cat << EOF
{
  "issue_type": "$issue_type",
  "severity": "$severity",
  "file": "$file",
  "description": "$description"
}
EOF
)
    
    send_notification "$level" "security_alert" "$message" "$details_json"
}

# Send performance alert
notify_performance_alert() {
    local metric="$1"
    local value="$2"
    local threshold="$3"
    local unit="${4:-}"
    
    local message="Performance issue: $metric exceeded threshold ($value$unit > $threshold$unit)"
    
    local details_json=$(cat << EOF
{
  "metric": "$metric",
  "value": $value,
  "threshold": $threshold,
  "unit": "$unit",
  "exceeded_by": $(echo "$value - $threshold" | bc)
}
EOF
)
    
    send_notification "warning" "performance_issue" "$message" "$details_json"
}

# Generate summary report
generate_summary_report() {
    local report_file="$NOTIFICATIONS_DIR/summary_$(date +%Y%m%d_%H%M%S).html"
    
    log_message "Generating notification summary report..."
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Build Fix Agent - Notification Summary</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-card { flex: 1; padding: 20px; background-color: #f8f9fa; border-radius: 4px; text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; color: #007bff; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .level-debug { color: #6c757d; }
        .level-info { color: #0dcaf0; }
        .level-warning { color: #ffc107; }
        .level-error { color: #dc3545; }
        .level-critical { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Build Fix Agent - Notification Summary</h1>
        <p>Generated: <span id="generated-time"></span></p>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number" id="total-notifications">0</div>
                <div>Total Notifications</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="critical-count">0</div>
                <div>Critical Issues</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="error-count">0</div>
                <div>Errors</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="warning-count">0</div>
                <div>Warnings</div>
            </div>
        </div>
        
        <h2>Recent Notifications</h2>
        <table id="notifications-table">
            <thead>
                <tr>
                    <th>Time</th>
                    <th>Level</th>
                    <th>Event</th>
                    <th>Message</th>
                </tr>
            </thead>
            <tbody id="notifications-body">
            </tbody>
        </table>
    </div>
    
    <script>
        document.getElementById('generated-time').textContent = new Date().toLocaleString();
        
        // Load notifications
        // In production, this would fetch from an API
        const notifications = [
EOF
    
    # Add notification data
    local first=true
    for notification_file in "$NOTIFICATIONS_DIR"/notification_*.json; do
        [[ -f "$notification_file" ]] || continue
        
        if [[ "$first" != "true" ]]; then
            echo "," >> "$report_file"
        fi
        first=false
        
        cat "$notification_file" >> "$report_file"
    done
    
    cat >> "$report_file" << 'EOF'
        ];
        
        // Populate statistics
        let stats = { total: 0, critical: 0, error: 0, warning: 0 };
        notifications.forEach(n => {
            stats.total++;
            if (n.level === 'critical') stats.critical++;
            else if (n.level === 'error') stats.error++;
            else if (n.level === 'warning') stats.warning++;
        });
        
        document.getElementById('total-notifications').textContent = stats.total;
        document.getElementById('critical-count').textContent = stats.critical;
        document.getElementById('error-count').textContent = stats.error;
        document.getElementById('warning-count').textContent = stats.warning;
        
        // Populate table
        const tbody = document.getElementById('notifications-body');
        notifications.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        
        notifications.slice(0, 50).forEach(n => {
            const row = tbody.insertRow();
            row.innerHTML = `
                <td>${new Date(n.timestamp).toLocaleString()}</td>
                <td class="level-${n.level}">${n.level.toUpperCase()}</td>
                <td>${n.event_type}</td>
                <td>${n.message}</td>
            `;
        });
    </script>
</body>
</html>
EOF
    
    log_message "Summary report generated: $report_file"
}

# Main execution
main() {
    local action="${1:-help}"
    
    # Initialize
    create_default_config
    load_config
    
    case "$action" in
        "test")
            # Test notifications
            log_message "Testing notification system..."
            send_notification "info" "test" "This is a test notification" '{"test": true}'
            send_notification "warning" "test" "This is a warning test" '{"test": true}'
            send_notification "error" "test" "This is an error test" '{"test": true}'
            ;;
            
        "summary")
            generate_summary_report
            ;;
            
        "configure")
            echo "Edit configuration file: $NOTIFICATION_CONFIG"
            ;;
            
        *)
            echo -e "${BLUE}Build Fix Agent - Notification System${NC}"
            echo -e "${YELLOW}====================================${NC}\n"
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  test      - Send test notifications"
            echo "  summary   - Generate summary report"
            echo "  configure - Show configuration file location"
            echo ""
            echo "Configuration: $NOTIFICATION_CONFIG"
            ;;
    esac
}

# Export functions for use by other scripts
export -f send_notification
export -f notify_build_progress
export -f notify_build_complete
export -f notify_security_alert
export -f notify_performance_alert

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi