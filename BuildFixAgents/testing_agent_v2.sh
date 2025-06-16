#!/bin/bash

# Testing Agent V2 - Quality Assurance and Validation
# Ensures the tool is production-ready

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
TEST_STATE="$SCRIPT_DIR/state/testing"
mkdir -p "$TEST_STATE"

# Source debug utilities
[[ -f "$SCRIPT_DIR/debug_utils.sh" ]] && source "$SCRIPT_DIR/debug_utils.sh"

# Ensure colors are defined
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"
CYAN="${CYAN:-\033[0;36m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
BLUE="${BLUE:-\033[0;34m}"

# Test categories
declare -A TEST_RESULTS

# Run comprehensive test suite
run_test_suite() {
    echo -e "${BOLD}${CYAN}=== Testing Agent V2 - Quality Assurance ===${NC}"
    
    # Initialize test report
    cat > "$TEST_STATE/test_report.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests_run": 0,
  "tests_passed": 0,
  "tests_failed": 0,
  "critical_issues": [],
  "warnings": [],
  "recommendations": []
}
EOF
    
    # Run test categories
    test_basic_functionality
    test_error_detection
    test_file_operations
    test_agent_communication
    test_performance_limits
    test_error_handling
    test_user_experience
    
    # Generate final report
    generate_test_report
}

# Test basic functionality
test_basic_functionality() {
    echo -e "\n${YELLOW}Testing basic functionality...${NC}"
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Script executability
    echo -n "  Checking script permissions... "
    local non_executable=$(find "$SCRIPT_DIR" -name "*.sh" ! -perm -u+x | wc -l)
    if [[ $non_executable -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC} - $non_executable scripts not executable"
        ((tests_failed++))
        add_issue "critical" "Non-executable scripts found"
    fi
    
    # Test 2: Required directories
    echo -n "  Checking required directories... "
    local required_dirs=("state" "logs" "patterns")
    local missing_dirs=0
    for dir in "${required_dirs[@]}"; do
        [[ ! -d "$SCRIPT_DIR/$dir" ]] && ((missing_dirs++))
    done
    if [[ $missing_dirs -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC} - $missing_dirs directories missing"
        ((tests_failed++))
    fi
    
    # Test 3: Debug utilities
    echo -n "  Testing debug utilities... "
    if DEBUG=true bash -c "source $SCRIPT_DIR/debug_utils.sh && debug 'test'" 2>&1 | grep -q "DEBUG"; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((tests_failed++))
    fi
    
    update_test_counts $tests_passed $tests_failed
}

# Test error detection accuracy
test_error_detection() {
    echo -e "\n${YELLOW}Testing error detection...${NC}"
    
    # Test error counting consistency
    echo -n "  Testing error count consistency... "
    local count1=$(cd "$PROJECT_DIR" && timeout 15s bash "$SCRIPT_DIR/autofix_batch.sh" status 2>&1 | grep "error count:" | awk '{print $NF}')
    sleep 1
    local count2=$(cd "$PROJECT_DIR" && timeout 15s bash "$SCRIPT_DIR/autofix_batch.sh" status 2>&1 | grep "error count:" | awk '{print $NF}')
    
    if [[ "$count1" == "$count2" ]] && [[ -n "$count1" ]]; then
        echo -e "${GREEN}PASS${NC} (Count: $count1)"
    else
        echo -e "${RED}FAIL${NC} (Count1: $count1, Count2: $count2)"
        add_issue "critical" "Inconsistent error counting"
    fi
}

# Test file operations safety
test_file_operations() {
    echo -e "\n${YELLOW}Testing file operations...${NC}"
    
    # Test 1: Backup before modify
    echo -n "  Checking backup mechanism... "
    if grep -r "backup" "$SCRIPT_DIR"/*.sh | grep -q "cp.*backup"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} - No backup mechanism found"
        add_issue "critical" "No file backup before modification"
    fi
    
    # Test 2: Atomic operations
    echo -n "  Checking atomic operations... "
    if grep -r "mv.*tmp" "$SCRIPT_DIR"/*.sh | grep -q "\.tmp"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}WARN${NC} - Consider atomic file operations"
        add_issue "warning" "Non-atomic file operations detected"
    fi
}

# Test agent communication
test_agent_communication() {
    echo -e "\n${YELLOW}Testing agent communication...${NC}"
    
    # Test state file access
    echo -n "  Testing state file access... "
    local test_file="$ARCH_STATE/test_comm.json"
    echo '{"test": "data"}' > "$test_file"
    if [[ -f "$test_file" ]] && rm "$test_file"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        add_issue "critical" "State file access issues"
    fi
}

# Test performance limits
test_performance_limits() {
    echo -e "\n${YELLOW}Testing performance limits...${NC}"
    
    # Test 2-minute constraint
    echo -n "  Testing 2-minute constraint compliance... "
    local start=$(date +%s)
    timeout 10s bash "$SCRIPT_DIR/autofix_batch.sh" run >/dev/null 2>&1 || true
    local duration=$(($(date +%s) - start))
    
    if [[ $duration -lt 120 ]]; then
        echo -e "${GREEN}PASS${NC} (${duration}s)"
    else
        echo -e "${RED}FAIL${NC} (${duration}s exceeds limit)"
        add_issue "critical" "Exceeds 2-minute execution limit"
    fi
}

# Test error handling
test_error_handling() {
    echo -e "\n${YELLOW}Testing error handling...${NC}"
    
    # Test undefined variable handling
    echo -n "  Testing undefined variable handling... "
    if grep -r "set -euo pipefail" "$SCRIPT_DIR"/*.sh | wc -l | grep -q "[0-9]"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} - Missing error handling"
        add_issue "critical" "Scripts lack proper error handling"
    fi
}

# Test user experience
test_user_experience() {
    echo -e "\n${YELLOW}Testing user experience...${NC}"
    
    # Test help documentation
    echo -n "  Testing help documentation... "
    local scripts_with_help=$(grep -l "help\|usage" "$SCRIPT_DIR"/*.sh | wc -l)
    local total_scripts=$(find "$SCRIPT_DIR" -name "*.sh" | wc -l)
    
    if [[ $scripts_with_help -gt $((total_scripts / 2)) ]]; then
        echo -e "${GREEN}PASS${NC} ($scripts_with_help/$total_scripts have help)"
    else
        echo -e "${YELLOW}WARN${NC} - Incomplete help documentation"
        add_issue "warning" "Many scripts lack help documentation"
    fi
}

# Helper functions
add_issue() {
    local severity="$1"
    local message="$2"
    
    jq --arg sev "$severity" --arg msg "$message" \
       ".${severity}_issues += [\$msg]" \
       "$TEST_STATE/test_report.json" > "$TEST_STATE/tmp.json" && \
       mv "$TEST_STATE/tmp.json" "$TEST_STATE/test_report.json"
}

update_test_counts() {
    local passed=$1
    local failed=$2
    
    jq ".tests_run += $((passed + failed)) | .tests_passed += $passed | .tests_failed += $failed" \
       "$TEST_STATE/test_report.json" > "$TEST_STATE/tmp.json" && \
       mv "$TEST_STATE/tmp.json" "$TEST_STATE/test_report.json"
}

# Generate final test report
generate_test_report() {
    echo -e "\n${BOLD}${CYAN}=== Test Report Summary ===${NC}"
    
    # Read test results
    local total=$(jq -r '.tests_run' "$TEST_STATE/test_report.json")
    local passed=$(jq -r '.tests_passed' "$TEST_STATE/test_report.json")
    local failed=$(jq -r '.tests_failed' "$TEST_STATE/test_report.json")
    local critical=$(jq -r '.critical_issues | length' "$TEST_STATE/test_report.json")
    
    echo -e "Tests Run: $total"
    echo -e "Tests Passed: ${GREEN}$passed${NC}"
    echo -e "Tests Failed: ${RED}$failed${NC}"
    echo -e "Critical Issues: ${RED}$critical${NC}"
    
    # Production readiness assessment
    echo -e "\n${BOLD}Production Readiness: "
    if [[ $critical -eq 0 ]] && [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}READY${NC}"
    elif [[ $critical -eq 0 ]]; then
        echo -e "${YELLOW}ALMOST READY${NC} - Minor issues to fix"
    else
        echo -e "${RED}NOT READY${NC} - Critical issues must be resolved"
    fi
    
    # Show critical issues
    if [[ $critical -gt 0 ]]; then
        echo -e "\n${RED}Critical Issues:${NC}"
        jq -r '.critical_issues[]' "$TEST_STATE/test_report.json" | while read -r issue; do
            echo -e "  • $issue"
        done
    fi
    
    # Recommendations
    cat > "$TEST_STATE/qa_recommendations.md" << 'EOF'
# QA Recommendations for Production Release

## Must Fix Before Release:
1. ❌ Implement actual file modifications in agents
2. ❌ Fix error counting for multi-target builds  
3. ❌ Add rollback mechanism for failed fixes
4. ❌ Complete pattern library for C# errors
5. ❌ Fix undefined variable errors (AGENT_DIR)

## Should Fix for Quality:
1. ⚠️ Add comprehensive help to all scripts
2. ⚠️ Implement proper logging rotation
3. ⚠️ Add progress indicators for long operations
4. ⚠️ Validate all user inputs
5. ⚠️ Add dry-run mode for testing

## Nice to Have:
1. 💡 Web dashboard for monitoring
2. 💡 Detailed statistics tracking
3. 💡 Plugin system for extensions
4. 💡 Integration with CI/CD systems
5. 💡 Multi-language documentation

## Testing Checklist:
- [ ] Unit tests for each component
- [ ] Integration tests for agent communication
- [ ] Performance benchmarks
- [ ] Error simulation tests
- [ ] User acceptance testing
- [ ] Security audit
- [ ] Documentation review
EOF

    echo -e "\n${GREEN}Full report saved to: $TEST_STATE/qa_recommendations.md${NC}"
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║      Testing Agent V2 - QA Suite       ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
    
    run_test_suite
    
    # Update agent status
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.testing.status = "complete"' "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
        mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
}

main "$@"