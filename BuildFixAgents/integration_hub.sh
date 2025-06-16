#!/bin/bash

# Integration Hub - Central system for integrating with external tools
# Supports JIRA, Slack, Teams, Azure DevOps, GitHub, and more

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$AGENT_DIR/config/integrations.yml"
STATE_DIR="$AGENT_DIR/state/integrations"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create directories
mkdir -p "$STATE_DIR" "$(dirname "$CONFIG_FILE")"

# Initialize integration config if not exists
init_integration_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Integration Hub Configuration
integrations:
  jira:
    enabled: false
    url: ""
    username: ""
    api_token: ""
    project_key: ""
    issue_type: "Bug"
    
  slack:
    enabled: false
    webhook_url: ""
    channel: "#build-errors"
    username: "Build Fix Agent"
    icon_emoji: ":robot_face:"
    
  teams:
    enabled: false
    webhook_url: ""
    
  github:
    enabled: false
    token: ""
    repo: ""
    
  azure_devops:
    enabled: false
    organization: ""
    project: ""
    token: ""
    
  datadog:
    enabled: false
    api_key: ""
    app_key: ""
    
  pagerduty:
    enabled: false
    api_key: ""
    service_id: ""

notification_rules:
  - trigger: "build_failure"
    integrations: ["slack", "teams"]
    
  - trigger: "security_issue"
    integrations: ["slack", "pagerduty", "jira"]
    
  - trigger: "fix_completed"
    integrations: ["slack", "jira"]
EOF
        echo -e "${GREEN}Created default integration config: $CONFIG_FILE${NC}"
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # This is a simple parser - in production use proper YAML parser
        export JIRA_ENABLED=$(grep -A1 "jira:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
        export JIRA_URL=$(grep -A2 "jira:" "$CONFIG_FILE" | grep "url:" | awk '{print $2}' | tr -d '"')
        export JIRA_USERNAME=$(grep -A3 "jira:" "$CONFIG_FILE" | grep "username:" | awk '{print $2}' | tr -d '"')
        export JIRA_API_TOKEN=$(grep -A4 "jira:" "$CONFIG_FILE" | grep "api_token:" | awk '{print $2}' | tr -d '"')
        export JIRA_PROJECT=$(grep -A5 "jira:" "$CONFIG_FILE" | grep "project_key:" | awk '{print $2}' | tr -d '"')
        
        export SLACK_ENABLED=$(grep -A1 "slack:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
        export SLACK_WEBHOOK=$(grep -A2 "slack:" "$CONFIG_FILE" | grep "webhook_url:" | awk '{print $2}' | tr -d '"')
        
        export TEAMS_ENABLED=$(grep -A1 "teams:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
        export TEAMS_WEBHOOK=$(grep -A2 "teams:" "$CONFIG_FILE" | grep "webhook_url:" | awk '{print $2}' | tr -d '"')
    fi
}

# JIRA Integration
create_jira_issue() {
    local title="$1"
    local description="$2"
    local priority="${3:-Medium}"
    
    if [[ "$JIRA_ENABLED" != "true" ]]; then
        echo -e "${YELLOW}JIRA integration not enabled${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Creating JIRA issue...${NC}"
    
    local payload=$(cat << EOF
{
    "fields": {
        "project": {
            "key": "$JIRA_PROJECT"
        },
        "summary": "$title",
        "description": "$description",
        "issuetype": {
            "name": "Bug"
        },
        "priority": {
            "name": "$priority"
        }
    }
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Authorization: Basic $(echo -n "$JIRA_USERNAME:$JIRA_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$JIRA_URL/rest/api/2/issue")
    
    local issue_key=$(echo "$response" | jq -r '.key // empty')
    
    if [[ -n "$issue_key" ]]; then
        echo -e "${GREEN}Created JIRA issue: $issue_key${NC}"
        echo "$issue_key" > "$STATE_DIR/last_jira_issue.txt"
        return 0
    else
        echo -e "${RED}Failed to create JIRA issue${NC}"
        echo "$response"
        return 1
    fi
}

update_jira_issue() {
    local issue_key="$1"
    local comment="$2"
    
    if [[ "$JIRA_ENABLED" != "true" ]]; then
        return 1
    fi
    
    local payload=$(jq -n --arg comment "$comment" '{body: $comment}')
    
    curl -s -X POST \
        -H "Authorization: Basic $(echo -n "$JIRA_USERNAME:$JIRA_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$JIRA_URL/rest/api/2/issue/$issue_key/comment" > /dev/null
}

# Slack Integration
send_slack_message() {
    local message="$1"
    local color="${2:-#36a64f}"  # Default green
    
    if [[ "$SLACK_ENABLED" != "true" ]]; then
        echo -e "${YELLOW}Slack integration not enabled${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Sending Slack notification...${NC}"
    
    local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "Build Fix Agent Notification",
            "text": "$message",
            "footer": "Build Fix Agent",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$SLACK_WEBHOOK")
    
    if [[ "$response" == "ok" ]]; then
        echo -e "${GREEN}Slack notification sent${NC}"
        return 0
    else
        echo -e "${RED}Failed to send Slack notification: $response${NC}"
        return 1
    fi
}

# Teams Integration
send_teams_message() {
    local title="$1"
    local message="$2"
    local color="${3:-28a745}"  # Default green
    
    if [[ "$TEAMS_ENABLED" != "true" ]]; then
        echo -e "${YELLOW}Teams integration not enabled${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Sending Teams notification...${NC}"
    
    local payload=$(cat << EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$color",
    "summary": "$title",
    "sections": [{
        "activityTitle": "$title",
        "activitySubtitle": "Build Fix Agent",
        "activityImage": "https://adaptivecards.io/content/robot.png",
        "text": "$message",
        "facts": [{
            "name": "Timestamp",
            "value": "$(date)"
        }]
    }]
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$TEAMS_WEBHOOK")
    
    if [[ "$response" == "1" ]]; then
        echo -e "${GREEN}Teams notification sent${NC}"
        return 0
    else
        echo -e "${RED}Failed to send Teams notification${NC}"
        return 1
    fi
}

# Unified notification system
send_notification() {
    local event_type="$1"
    local title="$2"
    local message="$3"
    local severity="${4:-info}"  # info, warning, error, critical
    
    # Determine color based on severity
    local color_slack="#36a64f"  # green
    local color_teams="28a745"   # green
    
    case "$severity" in
        warning)
            color_slack="#ff9800"
            color_teams="ff9800"
            ;;
        error)
            color_slack="#f44336"
            color_teams="dc3545"
            ;;
        critical)
            color_slack="#d32f2f"
            color_teams="b71c1c"
            ;;
    esac
    
    # Send to appropriate integrations based on event type
    case "$event_type" in
        build_failure)
            send_slack_message "Build Failed: $message" "$color_slack"
            send_teams_message "Build Failure" "$message" "$color_teams"
            create_jira_issue "Build Failure: $title" "$message" "High"
            ;;
        security_issue)
            send_slack_message "Security Issue: $message" "$color_slack"
            create_jira_issue "Security: $title" "$message" "Critical"
            # TODO: Add PagerDuty integration
            ;;
        fix_completed)
            send_slack_message "Fix Completed: $message" "$color_slack"
            send_teams_message "Fix Completed" "$message" "$color_teams"
            # Update JIRA if we have an issue
            if [[ -f "$STATE_DIR/last_jira_issue.txt" ]]; then
                local issue_key=$(cat "$STATE_DIR/last_jira_issue.txt")
                update_jira_issue "$issue_key" "Fix completed: $message"
            fi
            ;;
        *)
            send_slack_message "$title: $message" "$color_slack"
            send_teams_message "$title" "$message" "$color_teams"
            ;;
    esac
}

# Create build error report
create_error_report() {
    local errors_file="$1"
    local report_file="$STATE_DIR/error_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Create detailed report
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "project": "$(basename "$(pwd)")",
    "total_errors": $(jq length "$errors_file" 2>/dev/null || echo 0),
    "errors": $(cat "$errors_file" 2>/dev/null || echo "[]"),
    "environment": {
        "os": "$(uname -s)",
        "agent_version": "1.0.0"
    }
}
EOF
    
    echo "$report_file"
}

# Integration test
test_integrations() {
    echo -e "${BLUE}Testing integrations...${NC}"
    
    load_config
    
    # Test Slack
    if [[ "$SLACK_ENABLED" == "true" ]]; then
        send_slack_message "Test message from Build Fix Agent" "#36a64f" && \
            echo -e "${GREEN}✓ Slack integration working${NC}" || \
            echo -e "${RED}✗ Slack integration failed${NC}"
    fi
    
    # Test Teams
    if [[ "$TEAMS_ENABLED" == "true" ]]; then
        send_teams_message "Test Message" "This is a test from Build Fix Agent" "28a745" && \
            echo -e "${GREEN}✓ Teams integration working${NC}" || \
            echo -e "${RED}✗ Teams integration failed${NC}"
    fi
    
    # Test JIRA
    if [[ "$JIRA_ENABLED" == "true" ]]; then
        create_jira_issue "Test Issue" "This is a test issue from Build Fix Agent" "Low" && \
            echo -e "${GREEN}✓ JIRA integration working${NC}" || \
            echo -e "${RED}✗ JIRA integration failed${NC}"
    fi
}

# Main command handler
main() {
    local command="${1:-help}"
    
    init_integration_config
    load_config
    
    case "$command" in
        init)
            echo -e "${GREEN}Integration hub initialized${NC}"
            ;;
        test)
            test_integrations
            ;;
        notify)
            local event_type="${2:-general}"
            local title="${3:-Notification}"
            local message="${4:-No message provided}"
            local severity="${5:-info}"
            send_notification "$event_type" "$title" "$message" "$severity"
            ;;
        jira)
            case "${2:-}" in
                create)
                    create_jira_issue "${3:-Build Error}" "${4:-Error detected by Build Fix Agent}" "${5:-Medium}"
                    ;;
                update)
                    update_jira_issue "${3:-}" "${4:-Updated by Build Fix Agent}"
                    ;;
                *)
                    echo "Usage: $0 jira {create|update} [args...]"
                    ;;
            esac
            ;;
        slack)
            send_slack_message "${2:-Test message}" "${3:-#36a64f}"
            ;;
        teams)
            send_teams_message "${2:-Test}" "${3:-Test message}" "${4:-28a745}"
            ;;
        config)
            echo -e "${CYAN}Edit configuration file: $CONFIG_FILE${NC}"
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        *)
            cat << EOF
Integration Hub - Connect Build Fix Agent to external tools

Usage: $0 {command} [options]

Commands:
    init        Initialize integration configuration
    test        Test all configured integrations
    notify      Send notification to configured channels
                Usage: notify <event_type> <title> <message> [severity]
    jira        JIRA operations
                create <title> <description> [priority]
                update <issue_key> <comment>
    slack       Send Slack message
                Usage: slack <message> [color]
    teams       Send Teams message
                Usage: teams <title> <message> [color]
    config      Edit integration configuration

Event Types:
    build_failure    Build has failed
    security_issue   Security vulnerability detected
    fix_completed    Error fix completed
    general         General notification

Severity Levels:
    info       Information (green)
    warning    Warning (orange)
    error      Error (red)
    critical   Critical (dark red)

Example:
    $0 notify build_failure "Build Failed" "5 errors detected" error
    $0 jira create "CS0101 Duplicate class" "Found duplicate class definition" High
EOF
            ;;
    esac
}

# Execute
main "$@"