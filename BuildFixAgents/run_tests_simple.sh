#!/bin/bash

# Simple test runner that continues through failures

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}Build Fix Agent System - Simple Test Runner${NC}\n"

# Test counters
PASS=0
FAIL=0
SKIP=0

# Test function
test_feature() {
    local name="$1"
    local command="$2"
    
    echo -n "Testing $name... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAIL++))
    fi
}

# Test if script exists
test_exists() {
    local name="$1"
    local file="$2"
    
    echo -n "Testing $name exists... "
    
    if [[ -f "$AGENT_DIR/$file" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAIL++))
    fi
}

echo -e "${CYAN}=== File Existence Tests ===${NC}"
test_exists "Config Manager" "config_manager.sh"
test_exists "Git Integration" "git_integration.sh"
test_exists "Security Agent" "security_agent.sh"
test_exists "Notification System" "notification_system.sh"
test_exists "Architect Agent" "architect_agent.sh"
test_exists "Code Generator" "codegen_developer_agent.sh"
test_exists "Distributed Coordinator" "distributed_coordinator.sh"
test_exists "Telemetry Collector" "telemetry_collector.sh"
test_exists "Plugin Manager" "plugin_manager.sh"
test_exists "A/B Testing" "ab_testing_framework.sh"
test_exists "Web Dashboard" "web_dashboard.sh"
test_exists "God Mode" "god_mode_controller.sh"
test_exists "Enterprise Launcher" "enterprise_launcher.sh"

echo -e "\n${CYAN}=== Basic Functionality Tests ===${NC}"

# Test basic commands
test_feature "Main Script Help" "./run_build_fix.sh help"
test_feature "Enterprise Launcher Help" "./enterprise_launcher.sh help"
test_feature "Config Manager Init" "./config_manager.sh init"
test_feature "Plugin Manager List" "./plugin_manager.sh list"
test_feature "Web Dashboard Status" "./web_dashboard.sh status"

# Test configuration
echo -e "\n${CYAN}=== Configuration Tests ===${NC}"
test_feature "Create Default Config" "./config_manager.sh init && [[ -f config/plugins.yml ]]"
test_feature "Show Config" "./config_manager.sh show"

# Test directory structure
echo -e "\n${CYAN}=== Directory Structure Tests ===${NC}"
test_feature "Logs Directory" "[[ -d logs ]]"
test_feature "State Directory" "[[ -d state ]]"
test_feature "Config Directory" "[[ -d config ]]"
test_feature "Web Directory" "[[ -d web ]]"
test_feature "Plugins Directory" "[[ -d plugins ]]"

# Test web files
echo -e "\n${CYAN}=== Web Dashboard Files ===${NC}"
test_feature "Web Index HTML" "[[ -f web/index.html ]]"
test_feature "Web CSS" "[[ -f web/static/style.css ]]"
test_feature "Web JavaScript" "[[ -f web/static/app.js ]]"
test_feature "API Server Script" "[[ -f web/api_server.js ]]"

# Summary
echo -e "\n${CYAN}=== Test Summary ===${NC}"
echo -e "Tests Passed: ${GREEN}$PASS${NC}"
echo -e "Tests Failed: ${RED}$FAIL${NC}"
echo -e "Tests Skipped: ${YELLOW}$SKIP${NC}"

TOTAL=$((PASS + FAIL + SKIP))
if [[ $TOTAL -gt 0 ]]; then
    PASS_RATE=$(echo "scale=2; $PASS * 100 / $TOTAL" | bc)
    echo -e "Pass Rate: ${PASS_RATE}%"
fi

# Create simple test report
cat > test_results/simple_test_report.txt << EOF
Build Fix Agent System - Test Report
Generated: $(date)

Test Summary:
- Total Tests: $TOTAL
- Passed: $PASS
- Failed: $FAIL
- Skipped: $SKIP
- Pass Rate: ${PASS_RATE}%

System Information:
- Platform: $(uname -s)
- Directory: $AGENT_DIR
- User: $(whoami)
EOF

echo -e "\n${GREEN}Test report saved to: test_results/simple_test_report.txt${NC}"

# Exit code based on failures
if [[ $FAIL -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi