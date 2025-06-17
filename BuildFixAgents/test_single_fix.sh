#!/bin/bash

# Test if BuildFixAgents can fix a single C# error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/home/ooples/AiDotNet"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

echo -e "${BOLD}${CYAN}=== Testing Single Error Fix ===${NC}"

# Get initial error count
echo -e "\n${YELLOW}Getting initial error count...${NC}"
initial_errors=$(cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep -c "error CS" || true)
echo -e "Initial errors: ${RED}$initial_errors${NC}"

# Get first CS8618 error
echo -e "\n${YELLOW}Finding first CS8618 error to fix...${NC}"
error_info=$(cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep "error CS8618" | head -1)
echo -e "Target error: ${CYAN}$error_info${NC}"

# Extract file path
error_file=$(echo "$error_info" | sed 's/^\([^(]*\)(.*/\1/')
echo -e "Target file: ${CYAN}$error_file${NC}"

# Create a simple fix agent specification for CS8618
echo -e "\n${YELLOW}Creating agent specification for CS8618...${NC}"
cat > "$SCRIPT_DIR/state/single_fix_spec.json" << EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent_specifications": [
    {
      "agent_id": "cs8618_fixer",
      "name": "CS8618 Nullable Property Fixer",
      "type": "error_fixer", 
      "specialization": "cs8618",
      "target_errors": ["CS8618"],
      "target_files": ["$error_file"],
      "priority": "high",
      "max_iterations": 1
    }
  ]
}
EOF

echo -e "✅ Agent specification created"

# Run the generic error agent directly
echo -e "\n${YELLOW}Running CS8618 fix agent...${NC}"
cd "$SCRIPT_DIR"
bash generic_error_agent.sh "cs8618_fixer" "$SCRIPT_DIR/state/single_fix_spec.json" "CS8618" 2>&1 | tee single_fix_output.log

# Check if error was fixed
echo -e "\n${YELLOW}Checking if error was fixed...${NC}"
new_errors=$(cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep -c "error CS" || true)
echo -e "New error count: ${RED}$new_errors${NC}"

if [[ $new_errors -lt $initial_errors ]]; then
    echo -e "\n${GREEN}✅ SUCCESS! BuildFixAgents fixed at least one error!${NC}"
    echo -e "Errors reduced from $initial_errors to $new_errors"
else
    echo -e "\n${RED}❌ No errors were fixed${NC}"
    
    # Check if file was modified
    if git diff --name-only | grep -q "$(basename "$error_file")"; then
        echo -e "${YELLOW}File was modified but error persists${NC}"
    else
        echo -e "${RED}File was not modified${NC}"
    fi
fi