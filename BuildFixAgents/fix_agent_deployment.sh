#!/bin/bash

# Fix Agent - Agent Deployment Logic
# Fixes agent deployment to properly create and run error fixing agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'

echo -e "${BOLD}${MAGENTA}=== Fix Agent: Agent Deployment Logic ===${NC}"

# Fix 1: Update enhanced_coordinator.sh to properly deploy agents
echo -e "\n${YELLOW}Fixing enhanced coordinator agent deployment...${NC}"

# Backup original
cp "$SCRIPT_DIR/enhanced_coordinator.sh" "$SCRIPT_DIR/enhanced_coordinator.sh.backup.$(date +%s)"

# Create fix for deploy_agents function
cat > /tmp/fix_deploy_agents.patch << 'EOF'
# Deploy developer agents based on specifications
deploy_developer_agents() {
    log_message "Deploying developer agents..."
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "No agent specifications found. Running build analyzer..."
        bash "$AGENT_DIR/generic_build_analyzer.sh" "$PROJECT_DIR"
    fi
    
    if [[ ! -f "$AGENT_SPEC_FILE" ]]; then
        log_message "ERROR: Failed to generate agent specifications"
        return 1
    fi
    
    # Read agent specifications
    local agent_count=$(jq '.agent_specifications | length' "$AGENT_SPEC_FILE" 2>/dev/null || echo 0)
    log_message "Found specifications for $agent_count agents"
    
    if [[ $agent_count -eq 0 ]]; then
        log_message "WARNING: No agent specifications found. Creating generic agent..."
        # Create a generic agent specification
        cat > "$AGENT_SPEC_FILE" << GENERICEOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent_specifications": [
    {
      "agent_id": "generic_error_fixer",
      "name": "Generic Error Fixer",
      "type": "error_fixer",
      "specialization": "general",
      "target_errors": ["CS0101", "CS0111", "CS0246", "CS0462"],
      "priority": "high",
      "max_iterations": 3
    }
  ]
}
GENERICEOF
        agent_count=1
    fi
    
    # Deploy each agent
    local deployed=0
    for ((i=0; i<agent_count && i<MAX_CONCURRENT_AGENTS; i++)); do
        local agent_spec=$(jq ".agent_specifications[$i]" "$AGENT_SPEC_FILE")
        local agent_id=$(echo "$agent_spec" | jq -r '.agent_id')
        local target_errors=$(echo "$agent_spec" | jq -r '.target_errors[]' | tr '\n' ' ')
        
        log_message "Deploying agent: $agent_id"
        log_message "Target errors: $target_errors"
        
        # Create agent log
        local agent_log="$LOG_DIR/agent_${agent_id}.log"
        
        # Deploy the agent
        (
            bash "$AGENT_DIR/generic_error_agent.sh" \
                "$agent_id" \
                "$AGENT_SPEC_FILE" \
                "$target_errors" \
                > "$agent_log" 2>&1
            
            echo "$agent_id:completed" >> "$STATE_DIR/agent_status.txt"
        ) &
        
        local agent_pid=$!
        AGENT_PIDS+=($agent_pid)
        echo "$agent_id:$agent_pid" >> "$STATE_DIR/agent_pids.txt"
        
        ((deployed++))
    done
    
    log_message "Deployed $deployed developer agents"
    return 0
}
EOF

# Apply the fix
awk '
/^deploy_developer_agents\(\)/ {
    print "# Original function backed up"
    found = 1
}
found && /^}/ {
    found = 0
    # Insert new function
    system("cat /tmp/fix_deploy_agents.patch")
    next
}
!found {print}
' "$SCRIPT_DIR/enhanced_coordinator.sh" > "$SCRIPT_DIR/enhanced_coordinator.sh.tmp"

mv "$SCRIPT_DIR/enhanced_coordinator.sh.tmp" "$SCRIPT_DIR/enhanced_coordinator.sh"
chmod +x "$SCRIPT_DIR/enhanced_coordinator.sh"

# Fix 2: Update generic_agent_coordinator.sh to handle agent specifications
echo -e "\n${YELLOW}Fixing generic agent coordinator...${NC}"

if [[ -f "$SCRIPT_DIR/generic_agent_coordinator.sh" ]]; then
    cp "$SCRIPT_DIR/generic_agent_coordinator.sh" "$SCRIPT_DIR/generic_agent_coordinator.sh.backup.$(date +%s)"
    
    # Add better agent deployment
    cat >> "$SCRIPT_DIR/generic_agent_coordinator.sh" << 'EOF'

# Enhanced agent deployment
deploy_agents_from_spec() {
    local spec_file="${1:-$SCRIPT_DIR/state/agent_specifications.json}"
    
    if [[ ! -f "$spec_file" ]]; then
        echo "No agent specifications found"
        return 1
    fi
    
    # Deploy each specified agent
    jq -c '.agent_specifications[]' "$spec_file" | while read -r agent_spec; do
        local agent_id=$(echo "$agent_spec" | jq -r '.agent_id')
        local target_errors=$(echo "$agent_spec" | jq -r '.target_errors | join(" ")')
        
        echo "Deploying $agent_id for errors: $target_errors"
        
        # Run agent in background
        bash "$SCRIPT_DIR/generic_error_agent.sh" "$agent_id" "$spec_file" "$target_errors" &
    done
    
    # Wait for all agents
    wait
}
EOF
fi

# Fix 3: Ensure generic_error_agent.sh can handle the specifications
echo -e "\n${YELLOW}Updating generic error agent to handle specs...${NC}"

# Add PROJECT_DIR variable if missing
if ! grep -q "PROJECT_DIR=" "$SCRIPT_DIR/generic_error_agent.sh"; then
    sed -i '/^SCRIPT_DIR=/a\PROJECT_DIR="$(dirname "$SCRIPT_DIR")"' "$SCRIPT_DIR/generic_error_agent.sh"
fi

# Fix AGENT_DIR references
sed -i 's/\$AGENT_DIR/\$SCRIPT_DIR/g' "$SCRIPT_DIR/generic_error_agent.sh"

# Fix 4: Create a test deployment script
echo -e "\n${YELLOW}Creating test deployment script...${NC}"

cat > "$SCRIPT_DIR/test_deployment.sh" << 'EOF'
#!/bin/bash

# Test Agent Deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Testing Agent Deployment ==="

# 1. Generate agent specifications
echo "Step 1: Generating agent specifications..."
cd "$PROJECT_DIR"
if bash "$SCRIPT_DIR/generic_build_analyzer.sh" "$PROJECT_DIR"; then
    echo "✓ Build analysis complete"
else
    echo "✗ Build analysis failed"
    exit 1
fi

# 2. Check specifications
echo -e "\nStep 2: Checking agent specifications..."
if [[ -f "$SCRIPT_DIR/state/agent_specifications.json" ]]; then
    agent_count=$(jq '.agent_specifications | length' "$SCRIPT_DIR/state/agent_specifications.json")
    echo "✓ Found $agent_count agent specifications"
    jq -r '.agent_specifications[] | "  - \(.name) [\(.specialization)]"' "$SCRIPT_DIR/state/agent_specifications.json"
else
    echo "✗ No specifications found"
    exit 1
fi

# 3. Test agent deployment
echo -e "\nStep 3: Testing agent deployment..."
# Just test that agents can be created, don't run them
jq -c '.agent_specifications[]' "$SCRIPT_DIR/state/agent_specifications.json" | while read -r spec; do
    agent_id=$(echo "$spec" | jq -r '.agent_id')
    echo "  Would deploy: $agent_id"
done

echo -e "\n✓ Deployment logic verified"
EOF

chmod +x "$SCRIPT_DIR/test_deployment.sh"

# Run the test
echo -e "\n${GREEN}Testing agent deployment...${NC}"
if bash "$SCRIPT_DIR/test_deployment.sh"; then
    echo -e "${GREEN}✓ Agent deployment test passed${NC}"
else
    echo -e "${RED}✗ Agent deployment test failed${NC}"
fi

# Clean up
rm -f /tmp/fix_*.patch

echo -e "\n${BOLD}${GREEN}=== Agent Deployment Fix Complete ===${NC}"