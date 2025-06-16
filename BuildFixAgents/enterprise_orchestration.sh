#!/bin/bash

# Enterprise Orchestration Platform - Multi-project management and coordination
# Handles complex workflows, dependencies, and resource pooling across projects

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATION_DIR="$AGENT_DIR/state/orchestration"
PROJECTS_DIR="$ORCHESTRATION_DIR/projects"
WORKFLOWS_DIR="$ORCHESTRATION_DIR/workflows"
POOLS_DIR="$ORCHESTRATION_DIR/pools"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create directories
mkdir -p "$PROJECTS_DIR" "$WORKFLOWS_DIR" "$POOLS_DIR"

# Initialize orchestration configuration
init_orchestration_config() {
    local config_file="$AGENT_DIR/config/orchestration_config.yml"
    mkdir -p "$(dirname "$config_file")"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# Enterprise Orchestration Configuration
orchestration:
  enabled: true
  
  resource_pools:
    default:
      min_agents: 2
      max_agents: 20
      scale_factor: 1.5
      
    high_priority:
      min_agents: 5
      max_agents: 50
      scale_factor: 2.0
      
    batch:
      min_agents: 1
      max_agents: 10
      scale_factor: 1.2
      
  scheduling:
    algorithm: "priority_weighted"  # fifo, priority_weighted, fair_share
    max_concurrent_projects: 10
    max_queue_size: 100
    
  dependencies:
    resolution_strategy: "automatic"
    max_depth: 5
    circular_check: true
    
  workflows:
    templates:
      - name: "standard_fix"
        steps: ["analyze", "fix", "test", "report"]
        
      - name: "full_pipeline"
        steps: ["analyze", "security_scan", "fix", "test", "deploy"]
        
      - name: "emergency_fix"
        steps: ["quick_fix", "notify", "validate"]
        
  monitoring:
    health_check_interval: 60
    metrics_collection: true
    alert_thresholds:
      queue_size: 50
      wait_time: 300
      failure_rate: 0.1
      
  integration:
    project_discovery:
      - type: "git"
        scan_paths: ["./", "../"]
      - type: "config"
        config_file: "projects.json"
EOF
        echo -e "${GREEN}Created orchestration configuration${NC}"
    fi
}

# Register project
register_project() {
    local project_name="$1"
    local project_path="$2"
    local priority="${3:-normal}"
    local dependencies="${4:-}"
    
    echo -e "${BLUE}Registering project: $project_name${NC}"
    
    local project_id=$(echo -n "$project_name" | sha256sum | cut -c1-16)
    local project_file="$PROJECTS_DIR/${project_id}.json"
    
    # Create project metadata
    cat > "$project_file" << EOF
{
    "id": "$project_id",
    "name": "$project_name",
    "path": "$project_path",
    "priority": "$priority",
    "status": "registered",
    "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "dependencies": $(echo "$dependencies" | jq -R 'split(",") | map(select(length > 0))' 2>/dev/null || echo '[]'),
    "metadata": {
        "language": "unknown",
        "size": "unknown",
        "last_build": null
    },
    "resources": {
        "assigned_agents": 0,
        "cpu_quota": 1.0,
        "memory_quota": 1024
    }
}
EOF
    
    # Analyze project
    if [[ -d "$project_path" ]]; then
        # Detect language
        local language="unknown"
        if [[ -f "$project_path/package.json" ]]; then
            language="javascript"
        elif [[ -f "$project_path/requirements.txt" ]]; then
            language="python"
        elif find "$project_path" -name "*.csproj" | head -1 | grep -q .; then
            language="csharp"
        fi
        
        # Calculate size
        local size=$(du -sh "$project_path" 2>/dev/null | cut -f1 || echo "unknown")
        
        # Update metadata
        jq --arg lang "$language" --arg size "$size" \
            '.metadata.language = $lang | .metadata.size = $size' \
            "$project_file" > "$project_file.tmp" && mv "$project_file.tmp" "$project_file"
    fi
    
    echo -e "${GREEN}Project registered: $project_id${NC}"
    echo "$project_id"
}

# Create workflow
create_workflow() {
    local workflow_name="$1"
    local project_ids="$2"  # Comma-separated
    local template="${3:-standard_fix}"
    
    echo -e "${BLUE}Creating workflow: $workflow_name${NC}"
    
    local workflow_id=$(date +%s)-$$
    local workflow_file="$WORKFLOWS_DIR/workflow_${workflow_id}.json"
    
    # Define workflow steps based on template
    local steps='[]'
    case "$template" in
        standard_fix)
            steps='["analyze", "fix", "test", "report"]'
            ;;
        full_pipeline)
            steps='["analyze", "security_scan", "fix", "test", "deploy", "report"]'
            ;;
        emergency_fix)
            steps='["quick_fix", "notify", "validate"]'
            ;;
        custom)
            steps='["analyze", "fix"]'
            ;;
    esac
    
    # Create workflow definition
    cat > "$workflow_file" << EOF
{
    "id": "$workflow_id",
    "name": "$workflow_name",
    "template": "$template",
    "projects": $(echo "$project_ids" | jq -R 'split(",")'),
    "steps": $steps,
    "status": "created",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "started_at": null,
    "completed_at": null,
    "current_step": 0,
    "results": {},
    "config": {
        "parallel": true,
        "continue_on_error": false,
        "timeout_minutes": 60,
        "notifications": true
    }
}
EOF
    
    echo -e "${GREEN}Workflow created: $workflow_id${NC}"
    echo "$workflow_id"
}

# Execute workflow
execute_workflow() {
    local workflow_id="$1"
    local workflow_file="$WORKFLOWS_DIR/workflow_${workflow_id}.json"
    
    if [[ ! -f "$workflow_file" ]]; then
        echo -e "${RED}Workflow not found: $workflow_id${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Executing workflow: $workflow_id${NC}"
    
    # Update status
    jq '.status = "running" | .started_at = now | strftime("%Y-%m-%dT%H:%M:%SZ")' \
        "$workflow_file" > "$workflow_file.tmp" && mv "$workflow_file.tmp" "$workflow_file"
    
    # Get workflow details
    local workflow_name=$(jq -r '.name' "$workflow_file")
    local projects=$(jq -r '.projects[]' "$workflow_file")
    local steps=$(jq -r '.steps[]' "$workflow_file")
    local parallel=$(jq -r '.config.parallel' "$workflow_file")
    
    # Execute each step
    local step_index=0
    for step in $steps; do
        echo -e "\n${CYAN}Step $((step_index + 1)): $step${NC}"
        
        # Update current step
        jq --argjson idx "$step_index" '.current_step = $idx' \
            "$workflow_file" > "$workflow_file.tmp" && mv "$workflow_file.tmp" "$workflow_file"
        
        # Execute step for each project
        if [[ "$parallel" == "true" ]]; then
            # Parallel execution
            for project_id in $projects; do
                execute_workflow_step "$workflow_id" "$project_id" "$step" &
            done
            wait
        else
            # Sequential execution
            for project_id in $projects; do
                execute_workflow_step "$workflow_id" "$project_id" "$step"
            done
        fi
        
        ((step_index++))
    done
    
    # Update completion status
    jq '.status = "completed" | .completed_at = now | strftime("%Y-%m-%dT%H:%M:%SZ")' \
        "$workflow_file" > "$workflow_file.tmp" && mv "$workflow_file.tmp" "$workflow_file"
    
    echo -e "\n${GREEN}Workflow completed: $workflow_id${NC}"
}

# Execute workflow step
execute_workflow_step() {
    local workflow_id="$1"
    local project_id="$2"
    local step="$3"
    
    local project_file="$PROJECTS_DIR/${project_id}.json"
    if [[ ! -f "$project_file" ]]; then
        echo -e "${RED}Project not found: $project_id${NC}"
        return 1
    fi
    
    local project_path=$(jq -r '.path' "$project_file")
    local project_name=$(jq -r '.name' "$project_file")
    
    echo -e "  ${project_name}: Executing $step..."
    
    # Execute step based on type
    case "$step" in
        analyze)
            cd "$project_path" && "$AGENT_DIR/run_build_fix.sh" analyze >/dev/null 2>&1
            ;;
        fix)
            cd "$project_path" && "$AGENT_DIR/multi_language_fix_agent.sh" . >/dev/null 2>&1
            ;;
        test)
            # Run tests if available
            if [[ -f "$project_path/package.json" ]] && grep -q "test" "$project_path/package.json"; then
                cd "$project_path" && npm test >/dev/null 2>&1 || true
            fi
            ;;
        security_scan)
            "$AGENT_DIR/advanced_security_suite.sh" scan all "$project_path" >/dev/null 2>&1
            ;;
        quick_fix)
            cd "$project_path" && timeout 60 "$AGENT_DIR/run_build_fix.sh" fix >/dev/null 2>&1
            ;;
        notify)
            if [[ -f "$AGENT_DIR/integration_hub.sh" ]]; then
                "$AGENT_DIR/integration_hub.sh" notify general \
                    "Workflow: $step completed" "Project: $project_name" info >/dev/null 2>&1
            fi
            ;;
        report)
            "$AGENT_DIR/advanced_analytics.sh" collect >/dev/null 2>&1
            ;;
    esac
    
    echo -e "  ${project_name}: $step completed"
}

# Manage resource pools
manage_resource_pool() {
    local action="$1"
    local pool_name="${2:-default}"
    
    local pool_file="$POOLS_DIR/${pool_name}.json"
    
    case "$action" in
        create)
            if [[ ! -f "$pool_file" ]]; then
                cat > "$pool_file" << EOF
{
    "name": "$pool_name",
    "agents": [],
    "capacity": {
        "current": 0,
        "min": 2,
        "max": 20
    },
    "utilization": 0,
    "projects_assigned": []
}
EOF
                echo -e "${GREEN}Resource pool created: $pool_name${NC}"
            fi
            ;;
            
        scale)
            local target="${3:-}"
            if [[ -z "$target" ]]; then
                # Auto-scale based on utilization
                local utilization=$(jq -r '.utilization' "$pool_file" 2>/dev/null || echo 0)
                local current=$(jq -r '.capacity.current' "$pool_file" 2>/dev/null || echo 0)
                
                if (( $(echo "$utilization > 80" | bc -l) )); then
                    target=$((current * 2))
                elif (( $(echo "$utilization < 20" | bc -l) )); then
                    target=$((current / 2))
                else
                    target=$current
                fi
            fi
            
            # Update capacity
            jq --argjson target "$target" '.capacity.current = $target' \
                "$pool_file" > "$pool_file.tmp" && mv "$pool_file.tmp" "$pool_file"
            
            echo -e "${GREEN}Scaled pool $pool_name to $target agents${NC}"
            ;;
            
        assign)
            local project_id="${3:-}"
            if [[ -n "$project_id" ]]; then
                jq --arg pid "$project_id" '.projects_assigned += [$pid]' \
                    "$pool_file" > "$pool_file.tmp" && mv "$pool_file.tmp" "$pool_file"
                echo -e "${GREEN}Assigned project $project_id to pool $pool_name${NC}"
            fi
            ;;
    esac
}

# Monitor orchestration
monitor_orchestration() {
    echo -e "${BLUE}Orchestration Monitor${NC}"
    
    # Count projects
    local total_projects=$(ls "$PROJECTS_DIR"/*.json 2>/dev/null | wc -l)
    local active_workflows=$(find "$WORKFLOWS_DIR" -name "*.json" -exec \
        jq -r 'select(.status == "running") | .id' {} \; 2>/dev/null | wc -l)
    
    echo -e "\n${CYAN}System Overview:${NC}"
    echo -e "  Registered projects: $total_projects"
    echo -e "  Active workflows: $active_workflows"
    
    # Show resource pools
    echo -e "\n${CYAN}Resource Pools:${NC}"
    for pool_file in "$POOLS_DIR"/*.json; do
        if [[ -f "$pool_file" ]]; then
            local name=$(jq -r '.name' "$pool_file")
            local current=$(jq -r '.capacity.current' "$pool_file")
            local utilization=$(jq -r '.utilization' "$pool_file")
            echo -e "  $name: $current agents (${utilization}% utilized)"
        fi
    done
    
    # Show recent workflows
    echo -e "\n${CYAN}Recent Workflows:${NC}"
    find "$WORKFLOWS_DIR" -name "*.json" -mtime -1 -exec \
        jq -r '"\(.id): \(.name) - \(.status)"' {} \; 2>/dev/null | tail -5
    
    # Show project dependencies
    echo -e "\n${CYAN}Project Dependencies:${NC}"
    for project_file in "$PROJECTS_DIR"/*.json; do
        if [[ -f "$project_file" ]]; then
            local name=$(jq -r '.name' "$project_file")
            local deps=$(jq -r '.dependencies | join(", ")' "$project_file")
            if [[ -n "$deps" ]]; then
                echo -e "  $name → $deps"
            fi
        fi
    done
}

# Dependency resolver
resolve_dependencies() {
    local project_id="$1"
    local resolved=()
    local visited=()
    
    resolve_deps_recursive() {
        local pid="$1"
        local depth="${2:-0}"
        
        # Check for circular dependencies
        if [[ " ${visited[@]} " =~ " $pid " ]]; then
            echo -e "${RED}Circular dependency detected: $pid${NC}" >&2
            return 1
        fi
        
        visited+=("$pid")
        
        # Get dependencies
        local project_file="$PROJECTS_DIR/${pid}.json"
        if [[ -f "$project_file" ]]; then
            local deps=$(jq -r '.dependencies[]' "$project_file" 2>/dev/null)
            
            # Resolve each dependency first
            for dep in $deps; do
                if [[ ! " ${resolved[@]} " =~ " $dep " ]]; then
                    resolve_deps_recursive "$dep" $((depth + 1))
                fi
            done
        fi
        
        # Add to resolved list
        resolved+=("$pid")
    }
    
    echo -e "${BLUE}Resolving dependencies for: $project_id${NC}"
    resolve_deps_recursive "$project_id"
    
    echo -e "${GREEN}Resolution order:${NC}"
    for pid in "${resolved[@]}"; do
        local name=$(jq -r '.name' "$PROJECTS_DIR/${pid}.json" 2>/dev/null || echo "$pid")
        echo -e "  → $name"
    done
}

# Generate orchestration report
generate_orchestration_report() {
    local report_file="$ORCHESTRATION_DIR/orchestration_report_$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}Generating orchestration report...${NC}"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Enterprise Orchestration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 2px solid #9b59b6; }
        .project-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .project-card { background-color: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #9b59b6; }
        .workflow { background-color: #e8f5e9; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .dependency-graph { margin: 20px 0; padding: 20px; background-color: #f8f9fa; border-radius: 8px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #9b59b6; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Enterprise Orchestration Report</h1>
        <p>Generated: EOF
    echo -n "$(date)" >> "$report_file"
    cat >> "$report_file" << 'EOF'</p>
        
        <h2>Registered Projects</h2>
        <div class="project-grid">
EOF
    
    # Add projects to report
    for project_file in "$PROJECTS_DIR"/*.json; do
        if [[ -f "$project_file" ]]; then
            local name=$(jq -r '.name' "$project_file")
            local language=$(jq -r '.metadata.language' "$project_file")
            local priority=$(jq -r '.priority' "$project_file")
            local deps_count=$(jq -r '.dependencies | length' "$project_file")
            
            cat >> "$report_file" << EOF
            <div class="project-card">
                <h3>$name</h3>
                <p>Language: $language</p>
                <p>Priority: $priority</p>
                <p>Dependencies: $deps_count</p>
            </div>
EOF
        fi
    done
    
    cat >> "$report_file" << 'EOF'
        </div>
        
        <h2>Workflow History</h2>
        <table>
            <tr>
                <th>Workflow</th>
                <th>Template</th>
                <th>Projects</th>
                <th>Status</th>
                <th>Duration</th>
            </tr>
EOF
    
    # Add workflow history
    find "$WORKFLOWS_DIR" -name "*.json" -mtime -7 | while read workflow_file; do
        local name=$(jq -r '.name' "$workflow_file")
        local template=$(jq -r '.template' "$workflow_file")
        local project_count=$(jq -r '.projects | length' "$workflow_file")
        local status=$(jq -r '.status' "$workflow_file")
        
        cat >> "$report_file" << EOF
            <tr>
                <td>$name</td>
                <td>$template</td>
                <td>$project_count</td>
                <td>$status</td>
                <td>-</td>
            </tr>
EOF
    done
    
    cat >> "$report_file" << 'EOF'
        </table>
        
        <h2>Resource Utilization</h2>
        <p>Resource pools and their current utilization levels.</p>
        
        <h2>Recommendations</h2>
        <ul>
            <li>Consider grouping related projects for batch processing</li>
            <li>Define clear dependency chains to optimize workflow execution</li>
            <li>Monitor resource pool utilization for scaling decisions</li>
            <li>Implement priority queues for critical projects</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}Orchestration report generated: $report_file${NC}"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    init_orchestration_config
    
    case "$command" in
        register)
            local name="${2:-}"
            local path="${3:-}"
            local priority="${4:-normal}"
            local deps="${5:-}"
            
            if [[ -z "$name" ]] || [[ -z "$path" ]]; then
                echo "Usage: $0 register <name> <path> [priority] [dependencies]"
                exit 1
            fi
            
            register_project "$name" "$path" "$priority" "$deps"
            ;;
            
        workflow)
            case "${2:-create}" in
                create)
                    local name="${3:-}"
                    local projects="${4:-}"
                    local template="${5:-standard_fix}"
                    
                    if [[ -z "$name" ]] || [[ -z "$projects" ]]; then
                        echo "Usage: $0 workflow create <name> <project_ids> [template]"
                        exit 1
                    fi
                    
                    create_workflow "$name" "$projects" "$template"
                    ;;
                    
                execute)
                    local workflow_id="${3:-}"
                    if [[ -z "$workflow_id" ]]; then
                        echo "Usage: $0 workflow execute <workflow_id>"
                        exit 1
                    fi
                    
                    execute_workflow "$workflow_id"
                    ;;
                    
                list)
                    echo -e "${CYAN}Workflows:${NC}"
                    find "$WORKFLOWS_DIR" -name "*.json" -exec \
                        jq -r '"\(.id): \(.name) (\(.template)) - \(.status)"' {} \; 2>/dev/null
                    ;;
            esac
            ;;
            
        pool)
            local action="${2:-create}"
            local pool="${3:-default}"
            manage_resource_pool "$action" "$pool" "${4:-}"
            ;;
            
        deps)
            local project_id="${2:-}"
            if [[ -z "$project_id" ]]; then
                echo "Usage: $0 deps <project_id>"
                exit 1
            fi
            
            resolve_dependencies "$project_id"
            ;;
            
        monitor)
            monitor_orchestration
            ;;
            
        report)
            generate_orchestration_report
            ;;
            
        list)
            echo -e "${CYAN}Registered Projects:${NC}"
            for project_file in "$PROJECTS_DIR"/*.json; do
                if [[ -f "$project_file" ]]; then
                    jq -r '"\(.id): \(.name) (\(.metadata.language)) - \(.priority)"' "$project_file"
                fi
            done
            ;;
            
        *)
            cat << EOF
Enterprise Orchestration Platform - Multi-project management

Usage: $0 {command} [options]

Commands:
    register    Register a project
                Usage: register <name> <path> [priority] [deps]
                
    workflow    Manage workflows
                create <name> <project_ids> [template]
                execute <workflow_id>
                list
                
    pool        Manage resource pools
                Usage: pool <create|scale|assign> <pool_name> [value]
                
    deps        Resolve project dependencies
                Usage: deps <project_id>
                
    monitor     Monitor orchestration system
    
    report      Generate orchestration report
    
    list        List registered projects

Workflow Templates:
    standard_fix    - Analyze, fix, test, report
    full_pipeline   - Full CI/CD pipeline with security
    emergency_fix   - Quick fix with notifications
    custom         - Basic analyze and fix

Examples:
    $0 register "WebApp" "/path/to/webapp" high "SharedLib"
    $0 workflow create "Fix All" "proj1,proj2,proj3" standard_fix
    $0 workflow execute 1234567890
    $0 pool scale high_priority 10
    $0 deps project_abc123
EOF
            ;;
    esac
}

# Execute
main "$@"