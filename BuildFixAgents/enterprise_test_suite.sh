#!/bin/bash

# Enterprise Test Suite - Comprehensive testing for all Build Fix Agent features
# Validates functionality, performance, and integration of all components

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
TEST_RESULTS="$AGENT_DIR/test_results"
TEST_PROJECT="$AGENT_DIR/test_project"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Initialize
mkdir -p "$TEST_RESULTS"

# Test result logging
log_test() {
    local test_name="$1"
    local status="$2"
    local message="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $test_name: $status - $message" >> "$TEST_RESULTS/test_log.txt"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✓${NC} $test_name"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $test_name - $message"
            ((TESTS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $test_name - $message"
            ((TESTS_SKIPPED++))
            ;;
    esac
    
    ((TESTS_TOTAL++))
}

# Create test project with various error types
create_test_project() {
    echo -e "\n${CYAN}Creating test project...${NC}"
    
    rm -rf "$TEST_PROJECT"
    mkdir -p "$TEST_PROJECT/src" "$TEST_PROJECT/tests"
    
    # Create project file
    cat > "$TEST_PROJECT/TestProject.csproj" << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
EOF
    
    # Create files with various errors
    
    # CS0101: Duplicate class
    cat > "$TEST_PROJECT/src/Duplicate.cs" << 'EOF'
namespace TestProject;

public class DuplicateClass
{
    public void Method1() { }
}

public class DuplicateClass  // CS0101
{
    public void Method2() { }
}
EOF
    
    # CS0246: Type not found
    cat > "$TEST_PROJECT/src/MissingType.cs" << 'EOF'
namespace TestProject;

public class MissingTypeExample
{
    private NonExistentType field;  // CS0246
    
    public void UseType()
    {
        var x = new AnotherMissingType();  // CS0246
    }
}
EOF
    
    # CS0115: No suitable method to override
    cat > "$TEST_PROJECT/src/Override.cs" << 'EOF'
namespace TestProject;

public class BaseClass
{
    public virtual void Method1() { }
}

public class DerivedClass : BaseClass
{
    public override void Method2() { }  // CS0115
}
EOF
    
    # Security vulnerability
    cat > "$TEST_PROJECT/src/Security.cs" << 'EOF'
using System.Data.SqlClient;

namespace TestProject;

public class SecurityIssue
{
    private string connectionString = "Server=localhost;Database=test;User Id=sa;Password=MyPassword123!";  // Hardcoded password
    
    public void SqlInjection(string input)
    {
        string query = "SELECT * FROM Users WHERE Name = '" + input + "'";  // SQL injection
        // Execute query
    }
}
EOF
    
    # Performance issue
    cat > "$TEST_PROJECT/src/Performance.cs" << 'EOF'
namespace TestProject;

public class PerformanceIssue
{
    public void InefficientLoop()
    {
        var list = new List<int>();
        for (int i = 0; i < 1000000; i++)
        {
            if (list.Any(x => x == i))  // O(n) inside O(n) loop
            {
                // Do something
            }
        }
    }
}
EOF
    
    echo -e "${GREEN}✓ Test project created${NC}"
}

# Test Categories
run_phase1_tests() {
    echo -e "\n${BLUE}═══ Phase 1: Production Features Tests ═══${NC}"
    
    # Test Configuration Management
    test_configuration_management() {
        local test_name="Configuration Management"
        
        # Test init
        if "$AGENT_DIR/config_manager.sh" init >/dev/null 2>&1; then
            # Test set/get
            "$AGENT_DIR/config_manager.sh" set test_key test_value >/dev/null 2>&1
            local value=$("$AGENT_DIR/config_manager.sh" get test_key 2>/dev/null)
            
            if [[ "$value" == "test_value" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Set/Get mismatch"
            fi
        else
            log_test "$test_name" "FAIL" "Init failed"
        fi
    }
    
    # Test Git Integration
    test_git_integration() {
        local test_name="Git Integration"
        
        if command -v git &> /dev/null; then
            cd "$TEST_PROJECT"
            git init >/dev/null 2>&1
            
            if "$AGENT_DIR/git_integration.sh" setup >/dev/null 2>&1; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Setup failed"
            fi
            
            cd - >/dev/null
        else
            log_test "$test_name" "SKIP" "Git not available"
        fi
    }
    
    # Test Security Scanner
    test_security_scanner() {
        local test_name="Security Scanner"
        
        cd "$TEST_PROJECT"
        if "$AGENT_DIR/security_agent.sh" >/dev/null 2>&1; then
            # Check if vulnerabilities were found
            if [[ -d "$AGENT_DIR/state/security_reports" ]]; then
                local reports=$(ls "$AGENT_DIR/state/security_reports"/*.json 2>/dev/null | wc -l)
                if [[ $reports -gt 0 ]]; then
                    log_test "$test_name" "PASS"
                else
                    log_test "$test_name" "FAIL" "No reports generated"
                fi
            else
                log_test "$test_name" "FAIL" "No reports directory"
            fi
        else
            log_test "$test_name" "FAIL" "Scanner failed"
        fi
        cd - >/dev/null
    }
    
    # Test Notification System
    test_notification_system() {
        local test_name="Notification System"
        
        if "$AGENT_DIR/notification_system.sh" test >/dev/null 2>&1; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Test notifications failed"
        fi
    }
    
    # Test Architect Agent
    test_architect_agent() {
        local test_name="Architect Agent"
        
        cd "$TEST_PROJECT"
        if timeout 30 "$AGENT_DIR/architect_agent.sh" >/dev/null 2>&1; then
            if [[ -d "$AGENT_DIR/state/architectural_proposals" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "No proposals generated"
            fi
        else
            log_test "$test_name" "FAIL" "Agent timeout or error"
        fi
        cd - >/dev/null
    }
    
    # Run all Phase 1 tests
    test_configuration_management
    test_git_integration
    test_security_scanner
    test_notification_system
    test_architect_agent
}

run_phase2_tests() {
    echo -e "\n${BLUE}═══ Phase 2: Advanced Infrastructure Tests ═══${NC}"
    
    # Test Distributed Coordinator
    test_distributed_coordinator() {
        local test_name="Distributed Coordinator"
        
        # Start coordinator
        if "$AGENT_DIR/distributed_coordinator.sh" start >/dev/null 2>&1; then
            sleep 2
            
            # Check status
            if "$AGENT_DIR/distributed_coordinator.sh" status >/dev/null 2>&1; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Status check failed"
            fi
            
            # Stop coordinator
            "$AGENT_DIR/distributed_coordinator.sh" stop >/dev/null 2>&1
        else
            log_test "$test_name" "FAIL" "Failed to start"
        fi
    }
    
    # Test Telemetry Collector
    test_telemetry_collector() {
        local test_name="Telemetry Collector"
        
        # Start telemetry
        if "$AGENT_DIR/telemetry_collector.sh" start >/dev/null 2>&1; then
            sleep 5  # Let it collect some metrics
            
            # Check for metrics
            if [[ -f "$AGENT_DIR/state/metrics/metrics.db" ]] || [[ -f "$AGENT_DIR/state/metrics/metrics_$(date +%Y%m%d).json" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "No metrics collected"
            fi
            
            # Stop telemetry
            "$AGENT_DIR/telemetry_collector.sh" stop >/dev/null 2>&1
        else
            log_test "$test_name" "FAIL" "Failed to start"
        fi
    }
    
    # Run all Phase 2 tests
    test_distributed_coordinator
    test_telemetry_collector
}

run_phase3_tests() {
    echo -e "\n${BLUE}═══ Phase 3: Enterprise Features Tests ═══${NC}"
    
    # Test Plugin Manager
    test_plugin_manager() {
        local test_name="Plugin Manager"
        
        # Create test plugin
        if "$AGENT_DIR/plugin_manager.sh" create test_plugin >/dev/null 2>&1; then
            # Check if plugin was created
            if [[ -d "$AGENT_DIR/plugins/available/test_plugin" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Plugin not created"
            fi
        else
            log_test "$test_name" "FAIL" "Create command failed"
        fi
    }
    
    # Test A/B Testing Framework
    test_ab_testing() {
        local test_name="A/B Testing Framework"
        
        # Create experiment
        local exp_id=$("$AGENT_DIR/ab_testing_framework.sh" create "Test Experiment" "Test hypothesis" 2>/dev/null)
        
        if [[ -n "$exp_id" ]]; then
            # Check if experiment was created
            if [[ -d "$AGENT_DIR/state/ab_testing/experiments/$exp_id" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Experiment directory not found"
            fi
        else
            log_test "$test_name" "FAIL" "Failed to create experiment"
        fi
    }
    
    # Test Web Dashboard
    test_web_dashboard() {
        local test_name="Web Dashboard"
        
        # Check if web files exist
        if [[ -f "$AGENT_DIR/web/index.html" ]] && [[ -f "$AGENT_DIR/web/static/app.js" ]]; then
            # Try to start server
            if "$AGENT_DIR/web_dashboard.sh" start >/dev/null 2>&1; then
                sleep 2
                
                # Check if server is running
                if curl -s http://localhost:8080 >/dev/null 2>&1; then
                    log_test "$test_name" "PASS"
                else
                    log_test "$test_name" "FAIL" "Server not responding"
                fi
                
                # Stop server
                "$AGENT_DIR/web_dashboard.sh" stop >/dev/null 2>&1
            else
                log_test "$test_name" "FAIL" "Failed to start server"
            fi
        else
            log_test "$test_name" "FAIL" "Web files missing"
        fi
    }
    
    # Test God Mode Controller
    test_god_mode() {
        local test_name="God Mode Controller"
        
        # Check if god mode can initialize
        if [[ -f "$AGENT_DIR/god_mode_controller.sh" ]]; then
            # Test state file creation
            timeout 2 bash -c "source $AGENT_DIR/god_mode_controller.sh && init_god_mode_state" >/dev/null 2>&1
            
            if [[ -f "$AGENT_DIR/state/god_mode.json" ]]; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "State file not created"
            fi
        else
            log_test "$test_name" "FAIL" "Script not found"
        fi
    }
    
    # Run all Phase 3 tests
    test_plugin_manager
    test_ab_testing
    test_web_dashboard
    test_god_mode
}

run_integration_tests() {
    echo -e "\n${BLUE}═══ Integration Tests ═══${NC}"
    
    # Test Full Workflow
    test_full_workflow() {
        local test_name="Full Build Fix Workflow"
        
        cd "$TEST_PROJECT"
        
        # Run the basic fix workflow
        if timeout 60 "$AGENT_DIR/autofix.sh" >/dev/null 2>&1; then
            # Check if errors were reduced
            local final_errors=$(dotnet build 2>&1 | grep -c "error CS" || echo 0)
            
            if [[ $final_errors -lt 5 ]]; then  # Started with more errors
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Errors not reduced"
            fi
        else
            log_test "$test_name" "FAIL" "Workflow timeout or error"
        fi
        
        cd - >/dev/null
    }
    
    # Test Enterprise Launcher
    test_enterprise_launcher() {
        local test_name="Enterprise Launcher"
        
        if "$AGENT_DIR/enterprise_launcher.sh" status >/dev/null 2>&1; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Status command failed"
        fi
    }
    
    # Test Production Features Integration
    test_production_integration() {
        local test_name="Production Features Integration"
        
        if "$AGENT_DIR/production_features.sh" check >/dev/null 2>&1; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Check failed"
        fi
    }
    
    # Run all integration tests
    test_full_workflow
    test_enterprise_launcher
    test_production_integration
}

run_performance_tests() {
    echo -e "\n${BLUE}═══ Performance Tests ═══${NC}"
    
    # Test Agent Startup Time
    test_agent_startup() {
        local test_name="Agent Startup Time"
        
        local start_time=$(date +%s.%N)
        timeout 5 "$AGENT_DIR/generic_error_agent.sh" >/dev/null 2>&1 &
        local pid=$!
        
        # Wait for agent to start
        sleep 0.5
        
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null || true
            local end_time=$(date +%s.%N)
            local startup_time=$(echo "$end_time - $start_time" | bc)
            
            if (( $(echo "$startup_time < 1.0" | bc -l) )); then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Slow startup: ${startup_time}s"
            fi
        else
            log_test "$test_name" "FAIL" "Agent failed to start"
        fi
    }
    
    # Test Concurrent Agent Handling
    test_concurrent_agents() {
        local test_name="Concurrent Agent Handling"
        
        # Start multiple agents
        local pids=()
        for i in {1..5}; do
            timeout 10 "$AGENT_DIR/generic_error_agent.sh" >/dev/null 2>&1 &
            pids+=($!)
        done
        
        sleep 2
        
        # Check how many are running
        local running=0
        for pid in "${pids[@]}"; do
            ps -p $pid > /dev/null 2>&1 && ((running++))
        done
        
        # Kill remaining agents
        for pid in "${pids[@]}"; do
            kill $pid 2>/dev/null || true
        done
        
        if [[ $running -ge 3 ]]; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Only $running/5 agents running"
        fi
    }
    
    # Run all performance tests
    test_agent_startup
    test_concurrent_agents
}

run_stress_tests() {
    echo -e "\n${BLUE}═══ Stress Tests ═══${NC}"
    
    # Test Large Project Handling
    test_large_project() {
        local test_name="Large Project Handling"
        
        # Create many files with errors
        mkdir -p "$TEST_PROJECT/stress"
        for i in {1..50}; do
            cat > "$TEST_PROJECT/stress/File$i.cs" << EOF
namespace TestProject;
public class Class$i
{
    private MissingType$i field;  // Error
}
EOF
        done
        
        # Test if system can handle it
        cd "$TEST_PROJECT"
        if timeout 120 "$AGENT_DIR/run_build_fix.sh" analyze >/dev/null 2>&1; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Timeout or crash"
        fi
        cd - >/dev/null
        
        # Cleanup
        rm -rf "$TEST_PROJECT/stress"
    }
    
    # Test Memory Usage
    test_memory_usage() {
        local test_name="Memory Usage"
        
        # This is a simple check - in production, use proper profiling
        local mem_before=$(free -m | awk 'NR==2{print $3}')
        
        # Run some agents
        timeout 10 "$AGENT_DIR/autofix.sh" >/dev/null 2>&1 || true
        
        local mem_after=$(free -m | awk 'NR==2{print $3}')
        local mem_increase=$((mem_after - mem_before))
        
        if [[ $mem_increase -lt 500 ]]; then  # Less than 500MB increase
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "High memory usage: ${mem_increase}MB"
        fi
    }
    
    # Run all stress tests
    test_large_project
    test_memory_usage
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS/test_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Build Fix Agent - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; }
        .summary { margin: 20px 0; padding: 20px; background-color: #ecf0f1; border-radius: 8px; }
        .passed { color: #27ae60; }
        .failed { color: #e74c3c; }
        .skipped { color: #f39c12; }
        .test-category { margin: 20px 0; }
        .test-category h2 { color: #34495e; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #34495e; color: white; }
        .footer { margin-top: 40px; padding: 20px; background-color: #ecf0f1; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Build Fix Agent System - Test Report</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p>Total Tests: <strong>$TESTS_TOTAL</strong></p>
        <p class="passed">Passed: <strong>$TESTS_PASSED</strong></p>
        <p class="failed">Failed: <strong>$TESTS_FAILED</strong></p>
        <p class="skipped">Skipped: <strong>$TESTS_SKIPPED</strong></p>
        <p>Pass Rate: <strong>$(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc)%</strong></p>
    </div>
    
    <div class="test-results">
        <h2>Detailed Results</h2>
        <table>
            <tr>
                <th>Test Category</th>
                <th>Test Name</th>
                <th>Status</th>
                <th>Message</th>
            </tr>
EOF
    
    # Add test results from log
    if [[ -f "$TEST_RESULTS/test_log.txt" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \[(.*)\]\ (.*):(.*)-\ (.*) ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local test_name="${BASH_REMATCH[2]}"
                local status="${BASH_REMATCH[3]}"
                local message="${BASH_REMATCH[4]}"
                
                local status_class="passed"
                [[ "$status" == "FAIL" ]] && status_class="failed"
                [[ "$status" == "SKIP" ]] && status_class="skipped"
                
                cat >> "$report_file" << EOF
            <tr>
                <td>$(determine_category "$test_name")</td>
                <td>$test_name</td>
                <td class="$status_class">$status</td>
                <td>$message</td>
            </tr>
EOF
            fi
        done < "$TEST_RESULTS/test_log.txt"
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="footer">
        <h3>System Information</h3>
        <p>Platform: $(uname -s)</p>
        <p>Agent Version: 3.0.0</p>
        <p>Test Duration: $(echo "$TEST_END_TIME - $TEST_START_TIME" | bc)s</p>
    </div>
</body>
</html>
EOF
    
    echo -e "\n${GREEN}Test report generated: $report_file${NC}"
}

# Determine test category
determine_category() {
    local test_name="$1"
    
    case "$test_name" in
        *"Configuration"*|*"Git"*|*"Security"*|*"Notification"*|*"Architect"*)
            echo "Phase 1: Production"
            ;;
        *"Distributed"*|*"Telemetry"*)
            echo "Phase 2: Infrastructure"
            ;;
        *"Plugin"*|*"A/B"*|*"Dashboard"*|*"God Mode"*)
            echo "Phase 3: Enterprise"
            ;;
        *"Workflow"*|*"Launcher"*|*"Integration"*)
            echo "Integration"
            ;;
        *"Startup"*|*"Concurrent"*|*"Memory"*)
            echo "Performance"
            ;;
        *)
            echo "Other"
            ;;
    esac
}

# Main test execution
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Build Fix Agent System - Enterprise Test Suite        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    TEST_START_TIME=$(date +%s)
    
    # Clean previous results
    rm -f "$TEST_RESULTS"/*.txt "$TEST_RESULTS"/*.json
    
    # Create test project
    create_test_project
    
    # Run all test categories
    run_phase1_tests
    run_phase2_tests
    run_phase3_tests
    run_integration_tests
    run_performance_tests
    run_stress_tests
    
    TEST_END_TIME=$(date +%s)
    
    # Generate report
    generate_test_report
    
    # Summary
    echo -e "\n${CYAN}═══ Test Summary ═══${NC}"
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    
    local pass_rate=$(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc)
    echo -e "\nPass Rate: ${pass_rate}%"
    
    # Cleanup
    rm -rf "$TEST_PROJECT"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

# Execute
main "$@"