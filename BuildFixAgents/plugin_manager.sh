#!/bin/bash

# Plugin Manager for Build Fix Agents
# Enables custom agent development and third-party extensions

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
PLUGINS_DIR="$AGENT_DIR/plugins"
PLUGIN_CONFIG="$AGENT_DIR/config/plugins.yml"
PLUGIN_REGISTRY="$AGENT_DIR/state/plugin_registry.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Initialize
mkdir -p "$PLUGINS_DIR" "$PLUGINS_DIR/available" "$PLUGINS_DIR/enabled"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[$timestamp] PLUGIN_MANAGER${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/plugin_manager.log"
}

# Create default plugin configuration
create_default_config() {
    if [[ ! -f "$PLUGIN_CONFIG" ]]; then
        cat > "$PLUGIN_CONFIG" << 'EOF'
# Plugin Configuration
plugins:
  enabled: true
  auto_load: true
  security_mode: "sandboxed"  # strict, sandboxed, trusted
  
  # Plugin directories
  directories:
    - "./plugins/enabled"
    - "~/.buildfix/plugins"
    - "/usr/local/share/buildfix/plugins"
    
  # Plugin capabilities
  capabilities:
    file_access: "restricted"  # none, restricted, full
    network_access: false
    system_commands: false
    agent_control: true
    
  # Plugin lifecycle
  lifecycle:
    timeout: 300  # seconds
    max_memory_mb: 512
    max_cpu_percent: 50
    
  # Plugin API
  api:
    version: "1.0"
    endpoints:
      - "/api/v1/agents"
      - "/api/v1/metrics"
      - "/api/v1/tasks"
      
  # Security
  security:
    require_signature: false
    allowed_domains:
      - "github.com"
      - "gitlab.com"
    blocked_patterns:
      - "rm -rf"
      - "sudo"
      - "> /dev/null"
EOF
        log_message "Created default plugin configuration"
    fi
}

# Initialize plugin registry
init_plugin_registry() {
    if [[ ! -f "$PLUGIN_REGISTRY" ]]; then
        cat > "$PLUGIN_REGISTRY" << EOF
{
  "version": "1.0",
  "plugins": {},
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    fi
}

# Create plugin template
create_plugin_template() {
    local plugin_name="${1:-my_plugin}"
    local plugin_dir="$PLUGINS_DIR/available/$plugin_name"
    
    log_message "Creating plugin template: $plugin_name"
    
    mkdir -p "$plugin_dir"
    
    # Plugin manifest
    cat > "$plugin_dir/plugin.json" << EOF
{
  "name": "$plugin_name",
  "version": "1.0.0",
  "description": "Custom Build Fix Agent Plugin",
  "author": "Your Name",
  "license": "MIT",
  "main": "plugin.sh",
  "type": "agent",
  "capabilities": {
    "error_types": ["CS0000"],
    "file_patterns": ["*.cs"],
    "priority": 10
  },
  "requirements": {
    "min_version": "2.0.0",
    "dependencies": []
  },
  "hooks": {
    "on_load": "init",
    "on_error": "handle_error",
    "on_complete": "cleanup"
  }
}
EOF
    
    # Plugin main script
    cat > "$plugin_dir/plugin.sh" << 'EOF'
#!/bin/bash

# Plugin: Custom Build Fix Agent
# This is a template for creating custom agents

set -euo pipefail

# Plugin metadata
PLUGIN_NAME="my_plugin"
PLUGIN_VERSION="1.0.0"

# Source plugin API
source "${PLUGIN_API_PATH:-/dev/null}" 2>/dev/null || {
    echo "Plugin API not available"
    exit 1
}

# Initialize plugin
init() {
    plugin_log "Initializing $PLUGIN_NAME v$PLUGIN_VERSION"
    
    # Register capabilities
    register_capability "error_handler" "CS0000" "handle_cs0000_error"
    register_capability "file_processor" "*.cs" "process_cs_file"
    
    # Set up plugin state
    plugin_state_set "initialized" "true"
    plugin_state_set "errors_fixed" "0"
}

# Handle specific error type
handle_cs0000_error() {
    local error_file="$1"
    local error_line="$2"
    local error_message="$3"
    
    plugin_log "Handling CS0000 error in $error_file at line $error_line"
    
    # Implement your fix logic here
    if fix_error "$error_file" "$error_line"; then
        plugin_metric "errors_fixed" "increment"
        return 0
    else
        plugin_log "Failed to fix error" "ERROR"
        return 1
    fi
}

# Process file
process_cs_file() {
    local file_path="$1"
    
    plugin_log "Processing file: $file_path"
    
    # Implement file processing logic
    # Example: Check for common issues
    if grep -q "TODO:" "$file_path"; then
        plugin_event "todo_found" "$file_path" "info"
    fi
}

# Fix error implementation
fix_error() {
    local file="$1"
    local line="$2"
    
    # Example fix implementation
    # This is where you implement your custom fix logic
    
    # Use plugin API to safely modify files
    if plugin_file_read "$file" > /tmp/plugin_temp.txt; then
        # Modify the file content
        # ...
        
        # Write back using plugin API
        if plugin_file_write "$file" < /tmp/plugin_temp.txt; then
            plugin_log "Successfully fixed error in $file"
            return 0
        fi
    fi
    
    return 1
}

# Handle errors
handle_error() {
    local error_code="$1"
    local error_message="$2"
    
    plugin_log "Error occurred: $error_message (code: $error_code)" "ERROR"
    plugin_state_set "last_error" "$error_message"
}

# Cleanup
cleanup() {
    plugin_log "Cleaning up $PLUGIN_NAME"
    
    # Report final statistics
    local errors_fixed=$(plugin_state_get "errors_fixed")
    plugin_metric "total_errors_fixed" "$errors_fixed"
    
    # Clean up temporary files
    rm -f /tmp/plugin_temp.txt
}

# Main execution
main() {
    local action="${1:-run}"
    
    case "$action" in
        "init")
            init
            ;;
        "run")
            # Main plugin logic
            plugin_log "Running $PLUGIN_NAME"
            
            # Get tasks from plugin API
            while plugin_task_get task; do
                local task_type=$(echo "$task" | jq -r '.type')
                local task_data=$(echo "$task" | jq -r '.data')
                
                case "$task_type" in
                    "fix_error")
                        handle_cs0000_error "$task_data"
                        ;;
                    "process_file")
                        process_cs_file "$task_data"
                        ;;
                    *)
                        plugin_log "Unknown task type: $task_type" "WARN"
                        ;;
                esac
                
                plugin_task_complete "$task"
            done
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            plugin_log "Unknown action: $action" "ERROR"
            exit 1
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
    
    chmod +x "$plugin_dir/plugin.sh"
    
    # Plugin README
    cat > "$plugin_dir/README.md" << EOF
# $plugin_name Plugin

## Description
This is a custom Build Fix Agent plugin.

## Installation
\`\`\`bash
./plugin_manager.sh install $plugin_name
\`\`\`

## Configuration
Edit the plugin.json file to configure:
- Error types to handle
- File patterns to process
- Priority level

## Development
1. Modify plugin.sh to implement your fix logic
2. Test using: \`./plugin_manager.sh test $plugin_name\`
3. Enable using: \`./plugin_manager.sh enable $plugin_name\`

## API Reference
The plugin has access to these API functions:
- \`plugin_log\` - Write to plugin log
- \`plugin_metric\` - Record metrics
- \`plugin_event\` - Send events
- \`plugin_file_read\` - Read files safely
- \`plugin_file_write\` - Write files safely
- \`plugin_state_get/set\` - Manage plugin state
- \`plugin_task_get/complete\` - Handle tasks
EOF
    
    log_message "Plugin template created: $plugin_dir"
}

# Install plugin
install_plugin() {
    local plugin_source="$1"
    
    log_message "Installing plugin from: $plugin_source"
    
    # Determine plugin type
    if [[ -d "$plugin_source" ]]; then
        # Local directory
        install_local_plugin "$plugin_source"
    elif [[ "$plugin_source" =~ ^https?:// ]]; then
        # Remote URL
        install_remote_plugin "$plugin_source"
    elif [[ -f "$plugin_source" ]] && [[ "$plugin_source" =~ \.zip$ ]]; then
        # Zip file
        install_zip_plugin "$plugin_source"
    else
        log_message "Unknown plugin source type: $plugin_source" "ERROR"
        return 1
    fi
}

# Install local plugin
install_local_plugin() {
    local plugin_dir="$1"
    
    # Validate plugin
    if [[ ! -f "$plugin_dir/plugin.json" ]]; then
        log_message "Invalid plugin: missing plugin.json" "ERROR"
        return 1
    fi
    
    # Read plugin metadata
    local plugin_name=$(jq -r '.name' "$plugin_dir/plugin.json")
    local plugin_version=$(jq -r '.version' "$plugin_dir/plugin.json")
    
    # Copy to available plugins
    local dest_dir="$PLUGINS_DIR/available/$plugin_name"
    cp -r "$plugin_dir" "$dest_dir"
    
    # Register plugin
    register_plugin "$plugin_name" "$plugin_version" "$dest_dir"
    
    log_message "Plugin installed: $plugin_name v$plugin_version"
}

# Install remote plugin
install_remote_plugin() {
    local plugin_url="$1"
    
    log_message "Downloading plugin from: $plugin_url"
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    
    # Download plugin
    if command -v git &> /dev/null && [[ "$plugin_url" =~ \.git$ ]]; then
        # Git repository
        git clone "$plugin_url" "$temp_dir/plugin" || {
            log_message "Failed to clone plugin repository" "ERROR"
            rm -rf "$temp_dir"
            return 1
        }
        install_local_plugin "$temp_dir/plugin"
    else
        # Direct download
        curl -sL "$plugin_url" -o "$temp_dir/plugin.zip" || {
            log_message "Failed to download plugin" "ERROR"
            rm -rf "$temp_dir"
            return 1
        }
        install_zip_plugin "$temp_dir/plugin.zip"
    fi
    
    rm -rf "$temp_dir"
}

# Install zip plugin
install_zip_plugin() {
    local zip_file="$1"
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    
    # Extract plugin
    unzip -q "$zip_file" -d "$temp_dir" || {
        log_message "Failed to extract plugin" "ERROR"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Find plugin.json
    local plugin_json=$(find "$temp_dir" -name "plugin.json" | head -1)
    if [[ -z "$plugin_json" ]]; then
        log_message "Invalid plugin: missing plugin.json" "ERROR"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local plugin_dir=$(dirname "$plugin_json")
    install_local_plugin "$plugin_dir"
    
    rm -rf "$temp_dir"
}

# Register plugin
register_plugin() {
    local plugin_name="$1"
    local plugin_version="$2"
    local plugin_path="$3"
    
    # Update registry
    local temp_file=$(mktemp)
    jq ".plugins[\"$plugin_name\"] = {
        \"version\": \"$plugin_version\",
        \"path\": \"$plugin_path\",
        \"enabled\": false,
        \"installed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" "$PLUGIN_REGISTRY" > "$temp_file"
    
    mv "$temp_file" "$PLUGIN_REGISTRY"
    
    log_message "Plugin registered: $plugin_name"
}

# Enable plugin
enable_plugin() {
    local plugin_name="$1"
    
    log_message "Enabling plugin: $plugin_name"
    
    # Check if plugin is installed
    local plugin_path=$(jq -r ".plugins[\"$plugin_name\"].path" "$PLUGIN_REGISTRY" 2>/dev/null)
    if [[ -z "$plugin_path" ]] || [[ "$plugin_path" == "null" ]]; then
        log_message "Plugin not installed: $plugin_name" "ERROR"
        return 1
    fi
    
    # Create symlink in enabled directory
    ln -sf "$plugin_path" "$PLUGINS_DIR/enabled/$plugin_name"
    
    # Update registry
    local temp_file=$(mktemp)
    jq ".plugins[\"$plugin_name\"].enabled = true" "$PLUGIN_REGISTRY" > "$temp_file"
    mv "$temp_file" "$PLUGIN_REGISTRY"
    
    # Initialize plugin
    run_plugin_hook "$plugin_name" "on_load"
    
    log_message "Plugin enabled: $plugin_name"
}

# Disable plugin
disable_plugin() {
    local plugin_name="$1"
    
    log_message "Disabling plugin: $plugin_name"
    
    # Remove symlink
    rm -f "$PLUGINS_DIR/enabled/$plugin_name"
    
    # Update registry
    local temp_file=$(mktemp)
    jq ".plugins[\"$plugin_name\"].enabled = false" "$PLUGIN_REGISTRY" > "$temp_file"
    mv "$temp_file" "$PLUGIN_REGISTRY"
    
    log_message "Plugin disabled: $plugin_name"
}

# List plugins
list_plugins() {
    echo -e "${BLUE}=== Installed Plugins ===${NC}\n"
    
    if [[ ! -f "$PLUGIN_REGISTRY" ]]; then
        echo "No plugins installed"
        return
    fi
    
    # Parse registry and display
    jq -r '.plugins | to_entries[] | "\(.key)|\(.value.version)|\(.value.enabled)"' "$PLUGIN_REGISTRY" | \
    while IFS='|' read -r name version enabled; do
        local status_icon="○"
        local status_color="$YELLOW"
        
        if [[ "$enabled" == "true" ]]; then
            status_icon="●"
            status_color="$GREEN"
        fi
        
        echo -e "${status_color}${status_icon}${NC} $name (v$version)"
    done
}

# Run plugin
run_plugin() {
    local plugin_name="$1"
    shift || true
    
    log_message "Running plugin: $plugin_name"
    
    # Check if enabled
    if [[ ! -L "$PLUGINS_DIR/enabled/$plugin_name" ]]; then
        log_message "Plugin not enabled: $plugin_name" "ERROR"
        return 1
    fi
    
    # Get plugin path
    local plugin_path=$(readlink "$PLUGINS_DIR/enabled/$plugin_name")
    local plugin_script="$plugin_path/plugin.sh"
    
    if [[ ! -x "$plugin_script" ]]; then
        log_message "Plugin script not executable: $plugin_script" "ERROR"
        return 1
    fi
    
    # Set up plugin environment
    export PLUGIN_API_PATH="$AGENT_DIR/plugin_api.sh"
    export PLUGIN_NAME="$plugin_name"
    export PLUGIN_DIR="$plugin_path"
    export PLUGIN_STATE_DIR="$AGENT_DIR/state/plugins/$plugin_name"
    export PLUGIN_LOG_FILE="$AGENT_DIR/logs/plugins/${plugin_name}.log"
    
    mkdir -p "$PLUGIN_STATE_DIR" "$(dirname "$PLUGIN_LOG_FILE")"
    
    # Create plugin API
    create_plugin_api
    
    # Run plugin with sandboxing
    if [[ "${PLUGIN_SECURITY_MODE:-sandboxed}" == "strict" ]]; then
        # Run in restricted environment
        firejail --quiet --private="$plugin_path" --read-only="$PROJECT_DIR" \
            "$plugin_script" "$@" 2>&1 | tee -a "$PLUGIN_LOG_FILE"
    else
        # Run normally
        "$plugin_script" "$@" 2>&1 | tee -a "$PLUGIN_LOG_FILE"
    fi
}

# Create plugin API
create_plugin_api() {
    cat > "$PLUGIN_API_PATH" << 'EOF'
#!/bin/bash

# Plugin API - Available functions for plugins

# Logging
plugin_log() {
    local message="$1"
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$PLUGIN_NAME] [$level] $message" >> "$PLUGIN_LOG_FILE"
}

# Metrics
plugin_metric() {
    local metric_name="$1"
    local value="$2"
    local timestamp=$(date +%s)
    
    echo "$timestamp|plugin_${PLUGIN_NAME}_${metric_name}|$value" >> "$AGENT_DIR/state/plugin_metrics.txt"
}

# Events
plugin_event() {
    local event_type="$1"
    local event_data="$2"
    local severity="${3:-info}"
    
    local event_file="$AGENT_DIR/state/plugin_events.json"
    cat >> "$event_file" << JSON
{"timestamp":$(date +%s),"plugin":"$PLUGIN_NAME","type":"$event_type","data":"$event_data","severity":"$severity"}
JSON
}

# State management
plugin_state_get() {
    local key="$1"
    local state_file="$PLUGIN_STATE_DIR/state.json"
    
    if [[ -f "$state_file" ]]; then
        jq -r ".$key // empty" "$state_file" 2>/dev/null
    fi
}

plugin_state_set() {
    local key="$1"
    local value="$2"
    local state_file="$PLUGIN_STATE_DIR/state.json"
    
    if [[ ! -f "$state_file" ]]; then
        echo "{}" > "$state_file"
    fi
    
    local temp_file=$(mktemp)
    jq ".$key = \"$value\"" "$state_file" > "$temp_file"
    mv "$temp_file" "$state_file"
}

# File operations (sandboxed)
plugin_file_read() {
    local file="$1"
    
    # Validate file path
    if [[ ! "$file" =~ ^$PROJECT_DIR ]]; then
        plugin_log "Access denied: $file" "ERROR"
        return 1
    fi
    
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        return 1
    fi
}

plugin_file_write() {
    local file="$1"
    
    # Validate file path
    if [[ ! "$file" =~ ^$PROJECT_DIR ]]; then
        plugin_log "Access denied: $file" "ERROR"
        return 1
    fi
    
    # Read from stdin and write to file
    cat > "$file"
}

# Task management
plugin_task_get() {
    local var_name="$1"
    local task_file="$PLUGIN_STATE_DIR/tasks.json"
    
    if [[ -f "$task_file" ]] && [[ -s "$task_file" ]]; then
        local task=$(jq -r '.[0]' "$task_file" 2>/dev/null)
        if [[ "$task" != "null" ]] && [[ -n "$task" ]]; then
            eval "$var_name='$task'"
            
            # Remove task from queue
            local temp_file=$(mktemp)
            jq '.[1:]' "$task_file" > "$temp_file"
            mv "$temp_file" "$task_file"
            
            return 0
        fi
    fi
    
    return 1
}

plugin_task_complete() {
    local task="$1"
    local task_id=$(echo "$task" | jq -r '.id')
    
    plugin_log "Task completed: $task_id"
    plugin_metric "tasks_completed" "increment"
}

# Capability registration
register_capability() {
    local capability_type="$1"
    local capability_value="$2"
    local handler_function="$3"
    
    local cap_file="$PLUGIN_STATE_DIR/capabilities.json"
    if [[ ! -f "$cap_file" ]]; then
        echo "[]" > "$cap_file"
    fi
    
    local temp_file=$(mktemp)
    jq ". += [{\"type\": \"$capability_type\", \"value\": \"$capability_value\", \"handler\": \"$handler_function\"}]" "$cap_file" > "$temp_file"
    mv "$temp_file" "$cap_file"
}

# Export functions
export -f plugin_log
export -f plugin_metric
export -f plugin_event
export -f plugin_state_get
export -f plugin_state_set
export -f plugin_file_read
export -f plugin_file_write
export -f plugin_task_get
export -f plugin_task_complete
export -f register_capability
EOF
    
    chmod +x "$PLUGIN_API_PATH"
}

# Run plugin hook
run_plugin_hook() {
    local plugin_name="$1"
    local hook_name="$2"
    
    local plugin_path=$(jq -r ".plugins[\"$plugin_name\"].path" "$PLUGIN_REGISTRY" 2>/dev/null)
    if [[ -z "$plugin_path" ]] || [[ "$plugin_path" == "null" ]]; then
        return 1
    fi
    
    local plugin_manifest="$plugin_path/plugin.json"
    local hook_handler=$(jq -r ".hooks[\"$hook_name\"]" "$plugin_manifest" 2>/dev/null)
    
    if [[ -n "$hook_handler" ]] && [[ "$hook_handler" != "null" ]]; then
        run_plugin "$plugin_name" "$hook_handler"
    fi
}

# Test plugin
test_plugin() {
    local plugin_name="$1"
    
    log_message "Testing plugin: $plugin_name"
    
    # Create test environment
    local test_dir=$(mktemp -d)
    mkdir -p "$test_dir/src"
    
    # Create test file with error
    cat > "$test_dir/src/Test.cs" << 'EOF'
using System;

namespace TestNamespace
{
    public class TestClass
    {
        // This will trigger CS0000 error
        public void TestMethod()
        {
            // Test code
        }
    }
}
EOF
    
    # Run plugin in test mode
    export PROJECT_DIR="$test_dir"
    run_plugin "$plugin_name" "test"
    
    # Check results
    if [[ -f "$PLUGIN_STATE_DIR/state.json" ]]; then
        local errors_fixed=$(plugin_state_get "errors_fixed")
        echo -e "\n${CYAN}Test Results:${NC}"
        echo "  Errors fixed: $errors_fixed"
        echo "  Test directory: $test_dir"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}

# Create plugin marketplace integration
create_marketplace_integration() {
    local marketplace_file="$AGENT_DIR/state/marketplace.json"
    
    cat > "$marketplace_file" << 'EOF'
{
  "repositories": [
    {
      "name": "official",
      "url": "https://github.com/buildfix/plugins",
      "type": "git"
    },
    {
      "name": "community", 
      "url": "https://plugins.buildfix.io/registry.json",
      "type": "registry"
    }
  ],
  "featured_plugins": [
    {
      "name": "typescript-fixer",
      "description": "Fixes TypeScript compilation errors",
      "stars": 234,
      "downloads": 5621
    },
    {
      "name": "security-scanner",
      "description": "Enhanced security scanning",
      "stars": 189,
      "downloads": 3847
    },
    {
      "name": "performance-optimizer",
      "description": "Optimizes build performance",
      "stars": 156,
      "downloads": 2934
    }
  ]
}
EOF
}

# Search marketplace
search_marketplace() {
    local query="$1"
    
    echo -e "${BLUE}Searching plugin marketplace for: $query${NC}\n"
    
    # This is a mock search - in production, would query actual marketplace
    echo "Available plugins matching '$query':"
    echo "  - error-fixer-pro: Professional error fixing (★★★★★)"
    echo "  - $query-helper: Helps with $query issues (★★★★☆)"
    echo "  - universal-fixer: Fixes multiple error types (★★★☆☆)"
    echo ""
    echo "To install: ./plugin_manager.sh install <plugin-name>"
}

# Main menu
main() {
    local command="${1:-help}"
    shift || true
    
    # Initialize
    create_default_config
    init_plugin_registry
    
    case "$command" in
        "create")
            local name="${1:-my_plugin}"
            create_plugin_template "$name"
            ;;
            
        "install")
            local source="${1:-}"
            if [[ -z "$source" ]]; then
                echo "Usage: $0 install <source>"
                exit 1
            fi
            install_plugin "$source"
            ;;
            
        "enable")
            local name="${1:-}"
            if [[ -z "$name" ]]; then
                echo "Usage: $0 enable <plugin-name>"
                exit 1
            fi
            enable_plugin "$name"
            ;;
            
        "disable")
            local name="${1:-}"
            if [[ -z "$name" ]]; then
                echo "Usage: $0 disable <plugin-name>"
                exit 1
            fi
            disable_plugin "$name"
            ;;
            
        "list")
            list_plugins
            ;;
            
        "run")
            local name="${1:-}"
            if [[ -z "$name" ]]; then
                echo "Usage: $0 run <plugin-name> [args]"
                exit 1
            fi
            shift || true
            run_plugin "$name" "$@"
            ;;
            
        "test")
            local name="${1:-}"
            if [[ -z "$name" ]]; then
                echo "Usage: $0 test <plugin-name>"
                exit 1
            fi
            test_plugin "$name"
            ;;
            
        "search")
            local query="${1:-}"
            if [[ -z "$query" ]]; then
                echo "Usage: $0 search <query>"
                exit 1
            fi
            search_marketplace "$query"
            ;;
            
        *)
            echo -e "${BLUE}Build Fix Agent - Plugin Manager${NC}"
            echo -e "${YELLOW}================================${NC}\n"
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  create <name>    - Create new plugin template"
            echo "  install <source> - Install plugin from directory/URL"
            echo "  enable <name>    - Enable installed plugin"
            echo "  disable <name>   - Disable plugin"
            echo "  list             - List all plugins"
            echo "  run <name>       - Run plugin manually"
            echo "  test <name>      - Test plugin functionality"
            echo "  search <query>   - Search plugin marketplace"
            echo ""
            echo "Examples:"
            echo "  $0 create my_error_fixer"
            echo "  $0 install ./my_plugin_dir"
            echo "  $0 install https://github.com/user/plugin.git"
            echo "  $0 enable my_error_fixer"
            echo "  $0 test my_error_fixer"
            echo ""
            echo "Plugin Directory: $PLUGINS_DIR"
            ;;
    esac
}

# Execute
main "$@"