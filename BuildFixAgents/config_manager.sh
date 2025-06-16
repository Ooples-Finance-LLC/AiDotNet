#!/bin/bash

# Configuration Management System for Build Fix Agents
# Handles project-specific settings, agent configurations, and runtime parameters

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
CONFIG_DIR="$AGENT_DIR/config"
DEFAULT_CONFIG="$CONFIG_DIR/default_config.yml"
PROJECT_CONFIG="$CONFIG_DIR/project_config.yml"
AGENT_CONFIGS="$CONFIG_DIR/agents"
RUNTIME_CONFIG="$AGENT_DIR/state/runtime_config.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize directories
mkdir -p "$CONFIG_DIR" "$AGENT_CONFIGS"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] CONFIG_MANAGER${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/config_manager.log"
}

# Create default configuration
create_default_config() {
    log_message "Creating default configuration..."
    
    cat > "$DEFAULT_CONFIG" << 'EOF'
# Default Configuration for Build Fix Agent System
# This file contains default settings that can be overridden by project-specific config

# General Settings
general:
  project_name: "Auto-detected"
  dotnet_version: "auto"  # auto, net6.0, net7.0, net8.0, netcoreapp3.1, net462
  max_concurrent_agents: 3
  timeout_minutes: 30
  auto_commit: false
  auto_pr: false
  
# Build Settings
build:
  configuration: "Debug"  # Debug, Release
  verbosity: "minimal"    # quiet, minimal, normal, detailed, diagnostic
  restore_packages: true
  clean_before_build: false
  parallel_build: true
  treat_warnings_as_errors: false
  
# Agent Configuration
agents:
  error_fix:
    enabled: true
    max_retries: 3
    batch_size: 10
    priority_errors:
      - "CS0246"  # Type or namespace not found
      - "CS0103"  # Name does not exist
      - "CS1061"  # Does not contain definition
  
  tester:
    enabled: true
    run_unit_tests: true
    run_integration_tests: false
    test_timeout: 300
    continue_on_failure: true
    
  performance:
    enabled: false
    profile_duration: 60
    memory_threshold_mb: 1000
    cpu_threshold_percent: 80
    
  architect:
    enabled: false
    analyze_patterns: true
    suggest_refactoring: true
    check_dependencies: true
    
  security:
    enabled: false
    scan_secrets: true
    check_vulnerabilities: true
    audit_dependencies: true
    
# Error Handling
error_handling:
  backup_before_fix: true
  rollback_on_failure: true
  max_file_backups: 5
  ignore_patterns:
    - "*/bin/*"
    - "*/obj/*"
    - "*/packages/*"
    - "*/node_modules/*"
    
# Notifications
notifications:
  enabled: false
  channels:
    - type: "console"
      level: "info"  # debug, info, warning, error
    - type: "file"
      path: "logs/notifications.log"
      level: "debug"
      
# Performance Tuning
performance:
  hardware_detection: true
  dynamic_scaling: true
  memory_limit_percent: 80
  cpu_cores_limit: 0  # 0 means use all available
  
# Git Integration
git:
  enabled: true
  branch_prefix: "buildfix"
  commit_prefix: "🔧 [BuildFix]"
  auto_stage: true
  push_to_remote: false
  create_pr_draft: true
  
# Telemetry
telemetry:
  enabled: false
  anonymous: true
  metrics:
    - "build_time"
    - "errors_fixed"
    - "agent_performance"
EOF
    
    log_message "Default configuration created: $DEFAULT_CONFIG"
}

# Load configuration
load_config() {
    local config_file="${1:-$PROJECT_CONFIG}"
    
    if [[ ! -f "$config_file" ]]; then
        if [[ "$config_file" == "$PROJECT_CONFIG" ]]; then
            # Create project config from default
            create_project_config
        else
            log_message "Config file not found: $config_file" "ERROR"
            return 1
        fi
    fi
    
    # For bash, we'll parse simple key-value pairs
    # In production, you'd use a proper YAML parser
    log_message "Loading configuration from: $config_file"
    
    # Export configuration as environment variables
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract key-value pairs (simplified)
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Convert to uppercase and prefix with CONFIG_
            export "CONFIG_${key^^}=${value//\"/}"
        fi
    done < "$config_file"
    
    log_message "Configuration loaded successfully"
}

# Create project-specific configuration
create_project_config() {
    log_message "Creating project-specific configuration..."
    
    # Detect project details
    local project_name=$(basename "$PROJECT_DIR")
    local dotnet_version="auto"
    
    # Try to detect .NET version from project files
    if command -v dotnet &> /dev/null; then
        local detected_version=$(dotnet --list-sdks | tail -1 | cut -d' ' -f1 | cut -d'.' -f1,2)
        [[ -n "$detected_version" ]] && dotnet_version="net${detected_version}"
    fi
    
    # Copy default config and customize
    cp "$DEFAULT_CONFIG" "$PROJECT_CONFIG"
    
    # Update project-specific values
    sed -i "s/project_name: \"Auto-detected\"/project_name: \"$project_name\"/" "$PROJECT_CONFIG"
    sed -i "s/dotnet_version: \"auto\"/dotnet_version: \"$dotnet_version\"/" "$PROJECT_CONFIG"
    
    log_message "Project configuration created: $PROJECT_CONFIG"
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    local section="${3:-}"
    
    # Load config if not already loaded
    if [[ ! -f "$RUNTIME_CONFIG" ]]; then
        load_config
        export_runtime_config
    fi
    
    # Try to get from runtime config
    local value=$(jq -r ".$key // empty" "$RUNTIME_CONFIG" 2>/dev/null)
    
    if [[ -z "$value" ]]; then
        # Try environment variable
        local env_key="CONFIG_${key^^}"
        value="${!env_key:-$default}"
    fi
    
    echo "$value"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    local persist="${3:-false}"
    
    # Update runtime config
    if [[ -f "$RUNTIME_CONFIG" ]]; then
        jq ".$key = \"$value\"" "$RUNTIME_CONFIG" > "$RUNTIME_CONFIG.tmp" && mv "$RUNTIME_CONFIG.tmp" "$RUNTIME_CONFIG"
    fi
    
    # Update environment
    export "CONFIG_${key^^}=$value"
    
    # Persist to project config if requested
    if [[ "$persist" == "true" ]]; then
        # This is simplified - in production, use proper YAML tools
        if grep -q "^[[:space:]]*$key:" "$PROJECT_CONFIG"; then
            sed -i "s/^[[:space:]]*$key:.*/$key: \"$value\"/" "$PROJECT_CONFIG"
        else
            echo "$key: \"$value\"" >> "$PROJECT_CONFIG"
        fi
        log_message "Configuration persisted: $key=$value"
    fi
}

# Export runtime configuration
export_runtime_config() {
    log_message "Exporting runtime configuration..."
    
    # Create a JSON version for easier access
    cat > "$RUNTIME_CONFIG" << EOF
{
  "project_name": "${CONFIG_PROJECT_NAME:-Unknown}",
  "dotnet_version": "${CONFIG_DOTNET_VERSION:-auto}",
  "max_concurrent_agents": ${CONFIG_MAX_CONCURRENT_AGENTS:-3},
  "timeout_minutes": ${CONFIG_TIMEOUT_MINUTES:-30},
  "build_configuration": "${CONFIG_CONFIGURATION:-Debug}",
  "build_verbosity": "${CONFIG_VERBOSITY:-minimal}",
  "auto_commit": ${CONFIG_AUTO_COMMIT:-false},
  "auto_pr": ${CONFIG_AUTO_PR:-false},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Validate configuration
validate_config() {
    log_message "Validating configuration..."
    
    local errors=0
    
    # Check required settings
    if [[ -z "${CONFIG_PROJECT_NAME:-}" ]]; then
        log_message "Missing required config: project_name" "ERROR"
        ((errors++))
    fi
    
    # Validate numeric values
    if ! [[ "${CONFIG_MAX_CONCURRENT_AGENTS:-3}" =~ ^[0-9]+$ ]]; then
        log_message "Invalid max_concurrent_agents value" "ERROR"
        ((errors++))
    fi
    
    # Validate build configuration
    local valid_configs=("Debug" "Release")
    if [[ ! " ${valid_configs[@]} " =~ " ${CONFIG_CONFIGURATION:-Debug} " ]]; then
        log_message "Invalid build configuration: ${CONFIG_CONFIGURATION}" "ERROR"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_message "Configuration validation failed with $errors errors" "ERROR"
        return 1
    fi
    
    log_message "Configuration validation passed"
    return 0
}

# Create agent-specific configuration
create_agent_config() {
    local agent_name="$1"
    local agent_config="$AGENT_CONFIGS/${agent_name}_config.yml"
    
    log_message "Creating configuration for agent: $agent_name"
    
    case "$agent_name" in
        "error_fix")
            cat > "$agent_config" << 'EOF'
# Error Fix Agent Configuration
agent:
  name: "error_fix"
  type: "worker"
  priority: 1
  
settings:
  max_retries: 3
  retry_delay: 5
  batch_size: 10
  parallel_fixes: false
  
error_patterns:
  - pattern: "CS0246"
    description: "Type or namespace not found"
    fix_strategy: "add_using"
    priority: 1
  - pattern: "CS0103" 
    description: "Name does not exist"
    fix_strategy: "resolve_reference"
    priority: 1
  - pattern: "CS1061"
    description: "Does not contain definition" 
    fix_strategy: "add_member"
    priority: 2
    
fix_strategies:
  add_using:
    search_assemblies: true
    search_nuget: false
    common_namespaces:
      - "System"
      - "System.Collections.Generic"
      - "System.Linq"
      - "System.Threading.Tasks"
EOF
            ;;
            
        "tester")
            cat > "$agent_config" << 'EOF'
# Tester Agent Configuration  
agent:
  name: "tester"
  type: "quality"
  priority: 2
  
settings:
  test_frameworks:
    - "MSTest"
    - "NUnit"
    - "xUnit"
  parallel_execution: true
  stop_on_failure: false
  
test_discovery:
  patterns:
    - "*Test.dll"
    - "*Tests.dll" 
    - "*Spec.dll"
  exclude:
    - "*.Integration.Tests.dll"
    
coverage:
  enabled: true
  minimum_percent: 80
  exclude_patterns:
    - "*/Migrations/*"
    - "*/Generated/*"
EOF
            ;;
            
        "security")
            cat > "$agent_config" << 'EOF'
# Security Agent Configuration
agent:
  name: "security"
  type: "scanner"
  priority: 3
  
scanning:
  secret_detection:
    enabled: true
    patterns:
      - "password"
      - "apikey"
      - "secret"
      - "token"
      - "connectionstring"
    exclude_files:
      - "*.md"
      - "*.txt"
      
  vulnerability_scan:
    enabled: true
    check_dependencies: true
    check_code_patterns: true
    severity_threshold: "medium"
    
  compliance:
    enabled: false
    standards:
      - "OWASP"
      - "CWE"
      
reports:
  format: "json"
  output_dir: "security_reports"
  include_recommendations: true
EOF
            ;;
            
        *)
            # Generic agent config
            cat > "$agent_config" << EOF
# $agent_name Agent Configuration
agent:
  name: "$agent_name"
  type: "custom"
  priority: 10
  
settings:
  enabled: true
  timeout: 300
  
# Add agent-specific settings here
EOF
            ;;
    esac
    
    log_message "Agent configuration created: $agent_config"
}

# Interactive configuration wizard
config_wizard() {
    log_message "Starting configuration wizard..."
    
    echo -e "${BLUE}Build Fix Agent Configuration Wizard${NC}"
    echo -e "${YELLOW}=====================================${NC}\n"
    
    # Project name
    local current_project=$(get_config "project_name" "Unknown")
    read -p "Project name [$current_project]: " project_name
    [[ -n "$project_name" ]] && set_config "project_name" "$project_name" true
    
    # .NET version
    local current_version=$(get_config "dotnet_version" "auto")
    echo -e "\n${CYAN}Available .NET versions:${NC}"
    echo "  1) auto (detect automatically)"
    echo "  2) net8.0"
    echo "  3) net7.0"
    echo "  4) net6.0"
    echo "  5) netcoreapp3.1"
    echo "  6) net462 (Framework 4.6.2)"
    read -p "Select .NET version [1]: " version_choice
    
    case "$version_choice" in
        2) set_config "dotnet_version" "net8.0" true ;;
        3) set_config "dotnet_version" "net7.0" true ;;
        4) set_config "dotnet_version" "net6.0" true ;;
        5) set_config "dotnet_version" "netcoreapp3.1" true ;;
        6) set_config "dotnet_version" "net462" true ;;
        *) set_config "dotnet_version" "auto" true ;;
    esac
    
    # Build configuration
    echo -e "\n${CYAN}Build configuration:${NC}"
    echo "  1) Debug"
    echo "  2) Release"
    read -p "Select configuration [1]: " build_choice
    
    case "$build_choice" in
        2) set_config "build_configuration" "Release" true ;;
        *) set_config "build_configuration" "Debug" true ;;
    esac
    
    # Agent settings
    echo -e "\n${CYAN}Agent configuration:${NC}"
    read -p "Enable automatic commits? (y/N): " auto_commit
    [[ "$auto_commit" =~ ^[Yy]$ ]] && set_config "auto_commit" "true" true
    
    read -p "Enable automatic pull requests? (y/N): " auto_pr
    [[ "$auto_pr" =~ ^[Yy]$ ]] && set_config "auto_pr" "true" true
    
    read -p "Maximum concurrent agents [3]: " max_agents
    [[ -n "$max_agents" ]] && set_config "max_concurrent_agents" "$max_agents" true
    
    # Additional agents
    echo -e "\n${CYAN}Additional agents:${NC}"
    read -p "Enable security scanning? (y/N): " enable_security
    if [[ "$enable_security" =~ ^[Yy]$ ]]; then
        sed -i '/security:/,/enabled:/ s/enabled: false/enabled: true/' "$PROJECT_CONFIG"
        create_agent_config "security"
    fi
    
    read -p "Enable performance profiling? (y/N): " enable_perf
    if [[ "$enable_perf" =~ ^[Yy]$ ]]; then
        sed -i '/performance:/,/enabled:/ s/enabled: false/enabled: true/' "$PROJECT_CONFIG"
    fi
    
    read -p "Enable architecture analysis? (y/N): " enable_arch
    if [[ "$enable_arch" =~ ^[Yy]$ ]]; then
        sed -i '/architect:/,/enabled:/ s/enabled: false/enabled: true/' "$PROJECT_CONFIG"
    fi
    
    echo -e "\n${GREEN}✓ Configuration complete!${NC}"
    echo -e "${BLUE}Configuration saved to: $PROJECT_CONFIG${NC}"
    
    # Validate the configuration
    validate_config
}

# Show current configuration
show_config() {
    log_message "Current configuration:"
    
    if [[ ! -f "$PROJECT_CONFIG" ]]; then
        log_message "No project configuration found. Using defaults." "WARN"
        create_project_config
    fi
    
    echo -e "\n${CYAN}=== Project Configuration ===${NC}"
    echo -e "${YELLOW}Location: $PROJECT_CONFIG${NC}\n"
    
    # Load and display config
    load_config
    export_runtime_config
    
    # Display in a nice format
    jq -C '.' "$RUNTIME_CONFIG" 2>/dev/null || cat "$RUNTIME_CONFIG"
    
    # Show enabled agents
    echo -e "\n${CYAN}=== Enabled Agents ===${NC}"
    local agents=("error_fix" "tester" "performance" "architect" "security")
    for agent in "${agents[@]}"; do
        local enabled=$(grep -A1 "^[[:space:]]*$agent:" "$PROJECT_CONFIG" | grep "enabled:" | grep -o "true\|false" || echo "false")
        if [[ "$enabled" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $agent"
        else
            echo -e "  ${RED}✗${NC} $agent"
        fi
    done
    
    # Show agent configs
    echo -e "\n${CYAN}=== Agent Configurations ===${NC}"
    for config in "$AGENT_CONFIGS"/*_config.yml; do
        [[ -f "$config" ]] && echo "  - $(basename "$config")"
    done
}

# Reset configuration
reset_config() {
    log_message "Resetting configuration..."
    
    read -p "Are you sure you want to reset all configurations? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$PROJECT_CONFIG" "$RUNTIME_CONFIG"
        rm -f "$AGENT_CONFIGS"/*_config.yml
        log_message "Configuration reset complete"
        echo -e "${GREEN}✓ Configuration has been reset${NC}"
    else
        echo -e "${YELLOW}Reset cancelled${NC}"
    fi
}

# Main menu
main() {
    local action="${1:-show}"
    
    case "$action" in
        "init")
            # Initialize configuration
            if [[ ! -f "$DEFAULT_CONFIG" ]]; then
                create_default_config
            fi
            if [[ ! -f "$PROJECT_CONFIG" ]]; then
                create_project_config
            fi
            # Create default agent configs
            for agent in error_fix tester security; do
                [[ ! -f "$AGENT_CONFIGS/${agent}_config.yml" ]] && create_agent_config "$agent"
            done
            log_message "Configuration initialized"
            ;;
            
        "wizard")
            config_wizard
            ;;
            
        "show")
            show_config
            ;;
            
        "get")
            local key="${2:-}"
            if [[ -z "$key" ]]; then
                echo "Usage: $0 get <key>"
                exit 1
            fi
            get_config "$key"
            ;;
            
        "set")
            local key="${2:-}"
            local value="${3:-}"
            if [[ -z "$key" || -z "$value" ]]; then
                echo "Usage: $0 set <key> <value>"
                exit 1
            fi
            set_config "$key" "$value" true
            echo -e "${GREEN}✓ Set $key = $value${NC}"
            ;;
            
        "validate")
            validate_config
            ;;
            
        "reset")
            reset_config
            ;;
            
        *)
            echo -e "${BLUE}Configuration Manager for Build Fix Agents${NC}"
            echo -e "${YELLOW}=========================================${NC}\n"
            echo "Usage: $0 [command] [args]"
            echo ""
            echo "Commands:"
            echo "  init      - Initialize configuration"
            echo "  wizard    - Run configuration wizard"  
            echo "  show      - Show current configuration"
            echo "  get <key> - Get a configuration value"
            echo "  set <key> <value> - Set a configuration value"
            echo "  validate  - Validate configuration"
            echo "  reset     - Reset all configurations"
            echo ""
            echo "Examples:"
            echo "  $0 wizard"
            echo "  $0 get max_concurrent_agents"
            echo "  $0 set auto_commit true"
            ;;
    esac
}

# Execute
main "$@"