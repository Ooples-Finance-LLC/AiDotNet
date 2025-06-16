#!/bin/bash
# Test script for all new agents
# Verifies basic functionality of each agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_output"
mkdir -p "$TEST_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
AGENTS_TESTED=()

# Test function
test_agent() {
    local agent_name="$1"
    local agent_script="$2"
    local test_command="$3"
    
    echo -e "\n${YELLOW}Testing $agent_name...${NC}"
    
    if [[ ! -f "$SCRIPT_DIR/$agent_script" ]]; then
        echo -e "${RED}✗ $agent_name - Script not found: $agent_script${NC}"
        ((FAILED++))
        return 1
    fi
    
    if [[ ! -x "$SCRIPT_DIR/$agent_script" ]]; then
        echo -e "${RED}✗ $agent_name - Script not executable${NC}"
        ((FAILED++))
        return 1
    fi
    
    # Run the test command
    # For usage/help commands, we expect exit code 1
    bash "$SCRIPT_DIR/$agent_script" $test_command > "$TEST_DIR/${agent_name}_output.log" 2>&1
    local exit_code=$?
    
    # Check if output contains usage information (sign of working agent)
    if grep -q "Usage:" "$TEST_DIR/${agent_name}_output.log" || grep -q "Commands:" "$TEST_DIR/${agent_name}_output.log"; then
        echo -e "${GREEN}✓ $agent_name - Shows usage information (working)${NC}"
        ((PASSED++))
        AGENTS_TESTED+=("$agent_name: PASSED")
    elif [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $agent_name - Command executed successfully${NC}"
        ((PASSED++))
        AGENTS_TESTED+=("$agent_name: PASSED")
    else
        echo -e "${RED}✗ $agent_name - Test failed${NC}"
        echo "  Error output:"
        tail -n 5 "$TEST_DIR/${agent_name}_output.log" | sed 's/^/    /'
        ((FAILED++))
        AGENTS_TESTED+=("$agent_name: FAILED")
    fi
}

# Banner
echo "╔════════════════════════════════════════╗"
echo "║        Agent Test Suite v1.0           ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Testing all agents..."

# Test each agent with their default/safe commands
# Most agents will show usage when called without arguments
test_agent "Documentation Agent" "documentation_agent.sh" ""
test_agent "Database Agent" "database_agent.sh" ""
test_agent "API Design Agent" "api_design_agent.sh" ""
test_agent "Frontend Agent" "frontend_agent.sh" ""
test_agent "Deployment Agent" "deployment_agent.sh" ""
test_agent "Monitoring Agent" "monitoring_agent.sh" ""
test_agent "Refactoring Agent" "refactoring_agent.sh" ""
test_agent "Dependency Agent" "dependency_agent.sh" ""
test_agent "Accessibility Agent" "accessibility_agent.sh" ""
test_agent "Analysis Agent" "analysis_agent.sh" ""
test_agent "Cost Optimization Agent" "cost_optimization_agent.sh" ""

# Test agent generation capabilities (non-destructive)
echo -e "\n${YELLOW}Testing agent generation capabilities...${NC}"

# Create temporary test directory
TEMP_TEST_DIR="$TEST_DIR/generation_test"
mkdir -p "$TEMP_TEST_DIR"
cd "$TEMP_TEST_DIR"

# Test Documentation Agent - Generate README
if bash "$SCRIPT_DIR/documentation_agent.sh" readme "TestProject" "Test Description" > /dev/null 2>&1; then
    if [[ -f "README.md" ]]; then
        echo -e "${GREEN}✓ Documentation Agent - README generation working${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Documentation Agent - README not created${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Documentation Agent - Generation failed${NC}"
    ((FAILED++))
fi

# Test Database Agent - Generate schema
if bash "$SCRIPT_DIR/database_agent.sh" schema sqlite test_db "users,posts" > /dev/null 2>&1; then
    if [[ -f "$SCRIPT_DIR/state/database/schemas/test_db_schema.sql" ]]; then
        echo -e "${GREEN}✓ Database Agent - Schema generation working${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Database Agent - Schema not created${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Database Agent - Schema generation failed${NC}"
    ((FAILED++))
fi

# Test API Design Agent - Check if it can at least show help
if bash "$SCRIPT_DIR/api_design_agent.sh" help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API Design Agent - Help command working${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ API Design Agent - Help command failed${NC}"
    ((FAILED++))
fi

# Clean up
cd "$SCRIPT_DIR"
rm -rf "$TEMP_TEST_DIR"

# Summary
echo -e "\n╔════════════════════════════════════════╗"
echo -e "║           Test Summary                 ║"
echo -e "╚════════════════════════════════════════╝"
echo -e "Total Tests: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""
echo "Agent Status:"
for status in "${AGENTS_TESTED[@]}"; do
    if [[ "$status" == *"PASSED"* ]]; then
        echo -e "  ${GREEN}$status${NC}"
    else
        echo -e "  ${RED}$status${NC}"
    fi
done

# Exit code
if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Check $TEST_DIR for detailed logs.${NC}"
    exit 1
fi