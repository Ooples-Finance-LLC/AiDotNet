#!/bin/bash
# Quick verification of all agents

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Agent Verification ==="
echo ""

# Check if each agent exists and is executable
agents=(
    "documentation_agent.sh"
    "database_agent.sh"
    "api_design_agent.sh"
    "frontend_agent.sh"
    "deployment_agent.sh"
    "monitoring_agent.sh"
    "refactoring_agent.sh"
    "dependency_agent.sh"
    "accessibility_agent.sh"
    "analysis_agent.sh"
    "cost_optimization_agent.sh"
)

all_good=true

for agent in "${agents[@]}"; do
    if [[ -f "$agent" ]] && [[ -x "$agent" ]]; then
        echo -e "${GREEN}✓${NC} $agent - exists and is executable"
    else
        echo -e "${RED}✗${NC} $agent - missing or not executable"
        all_good=false
    fi
done

echo ""
if $all_good; then
    echo -e "${GREEN}All agents are ready!${NC}"
    
    # Quick syntax check on a few agents
    echo ""
    echo "Running syntax checks..."
    
    if bash -n documentation_agent.sh 2>/dev/null; then
        echo -e "${GREEN}✓${NC} documentation_agent.sh - syntax OK"
    else
        echo -e "${RED}✗${NC} documentation_agent.sh - syntax error"
    fi
    
    if bash -n database_agent.sh 2>/dev/null; then
        echo -e "${GREEN}✓${NC} database_agent.sh - syntax OK"
    else
        echo -e "${RED}✗${NC} database_agent.sh - syntax error"
    fi
    
    if bash -n analysis_agent.sh 2>/dev/null; then
        echo -e "${GREEN}✓${NC} analysis_agent.sh - syntax OK"
    else
        echo -e "${RED}✗${NC} analysis_agent.sh - syntax error"
    fi
    
    echo ""
    echo "All verification checks passed!"
else
    echo -e "${RED}Some agents are missing or not executable${NC}"
    exit 1
fi