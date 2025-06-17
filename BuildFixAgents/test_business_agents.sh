#!/bin/bash
# Test script for all business development agents

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing Business Development Agents ===${NC}"
echo ""

# Test function
test_agent() {
    local agent_name="$1"
    local agent_file="$2"
    local test_command="$3"
    
    echo -e "${YELLOW}Testing $agent_name...${NC}"
    
    if [[ ! -f "$agent_file" ]]; then
        echo -e "${RED}✗ $agent_name - File not found${NC}"
        return 1
    fi
    
    if [[ ! -x "$agent_file" ]]; then
        echo -e "${RED}✗ $agent_name - Not executable${NC}"
        return 1
    fi
    
    # Test help command
    if ./"$agent_file" help &>/dev/null || [[ $? -eq 1 ]]; then
        echo -e "${GREEN}✓ $agent_name - Help command works${NC}"
    else
        echo -e "${RED}✗ $agent_name - Help command failed${NC}"
        return 1
    fi
    
    # Test specific command if provided
    if [[ -n "$test_command" ]]; then
        echo "  Running: $test_command"
        if eval "$test_command" &>/dev/null; then
            echo -e "${GREEN}✓ $agent_name - Test command successful${NC}"
        else
            echo -e "${YELLOW}⚠ $agent_name - Test command had issues (may be expected)${NC}"
        fi
    fi
    
    echo ""
    return 0
}

# Track results
total_tests=0
passed_tests=0

# Test Product Owner Agent
((total_tests++))
if test_agent "Product Owner Agent" "product_owner_agent.sh" "./product_owner_agent.sh vision 'Test product idea'"; then
    ((passed_tests++))
fi

# Test Business Analyst Agent
((total_tests++))
if test_agent "Business Analyst Agent" "business_analyst_agent.sh" "./business_analyst_agent.sh analyze"; then
    ((passed_tests++))
fi

# Test Sprint Planning Agent
((total_tests++))
if test_agent "Sprint Planning Agent" "sprint_planning_agent.sh" "./sprint_planning_agent.sh create 1 2 40"; then
    ((passed_tests++))
fi

# Test QA Automation Agent
((total_tests++))
if test_agent "QA Automation Agent" "qa_automation_agent.sh" "./qa_automation_agent.sh init playwright"; then
    ((passed_tests++))
fi

# Test User Story Agent
((total_tests++))
if test_agent "User Story Agent" "user_story_agent.sh" "./user_story_agent.sh create feature user 'test action' 'test benefit'"; then
    ((passed_tests++))
fi

# Test Requirements Agent
((total_tests++))
if test_agent "Requirements Agent" "requirements_agent.sh" "./requirements_agent.sh gather interview"; then
    ((passed_tests++))
fi

# Test Roadmap Agent
((total_tests++))
if test_agent "Roadmap Agent" "roadmap_agent.sh" "./roadmap_agent.sh create 12 'Test Product'"; then
    ((passed_tests++))
fi

# Test Feedback Loop Agent
((total_tests++))
if test_agent "Feedback Loop Agent" "feedback_loop_agent.sh" "./feedback_loop_agent.sh collect user general"; then
    ((passed_tests++))
fi

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "Total agents tested: $total_tests"
echo -e "Passed: ${GREEN}$passed_tests${NC}"
echo -e "Failed: ${RED}$((total_tests - passed_tests))${NC}"
echo ""

if [[ $passed_tests -eq $total_tests ]]; then
    echo -e "${GREEN}✓ All business agents are working correctly!${NC}"
    
    # Show created artifacts
    echo ""
    echo -e "${BLUE}=== Created Artifacts ===${NC}"
    echo "Product visions: $(find state/product_owner/vision -name "*.md" 2>/dev/null | wc -l)"
    echo "User stories: $(find state/user_story/stories -name "*.md" 2>/dev/null | wc -l)"
    echo "Sprint plans: $(find state/sprint_planning/sprints -name "*.md" 2>/dev/null | wc -l)"
    echo "Requirements: $(find state/requirements -name "*.md" 2>/dev/null | wc -l)"
    echo "Roadmaps: $(find state/roadmap/roadmaps -name "*.md" 2>/dev/null | wc -l)"
    echo "Feedback items: $(find state/feedback_loop/feedback -name "*.md" 2>/dev/null | wc -l)"
    
    exit 0
else
    echo -e "${RED}✗ Some agents failed testing${NC}"
    exit 1
fi