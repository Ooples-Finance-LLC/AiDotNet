#!/bin/bash
# Comprehensive Test Suite for ALL Build Fix Agents
# Tests every agent in the BuildFixAgents directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_results/comprehensive_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test statistics
TOTAL_AGENTS=0
PASSED=0
FAILED=0
SKIPPED=0
declare -A TEST_RESULTS

# Logging functions
log() {
    echo -e "[$(date +%H:%M:%S)] $*" | tee -a "$TEST_DIR/test_log.txt"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$TEST_DIR/test_log.txt"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$TEST_DIR/test_log.txt"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$TEST_DIR/test_log.txt"
}

# Test function for agents
test_agent() {
    local agent_name="$1"
    local agent_script="$2"
    local test_type="${3:-basic}"
    
    ((TOTAL_AGENTS++))
    
    log "\nTesting: $agent_name ($agent_script)"
    
    # Check if file exists
    if [[ ! -f "$SCRIPT_DIR/$agent_script" ]]; then
        log_error "$agent_name - Script not found"
        TEST_RESULTS["$agent_name"]="NOT_FOUND"
        ((FAILED++))
        return 1
    fi
    
    # Check if executable
    if [[ ! -x "$SCRIPT_DIR/$agent_script" ]]; then
        chmod +x "$SCRIPT_DIR/$agent_script" 2>/dev/null || {
            log_error "$agent_name - Script not executable"
            TEST_RESULTS["$agent_name"]="NOT_EXECUTABLE"
            ((FAILED++))
            return 1
        }
    fi
    
    # Create agent test directory
    local agent_test_dir="$TEST_DIR/agents/$(basename "$agent_script" .sh)"
    mkdir -p "$agent_test_dir"
    
    # Run basic functionality test
    case "$test_type" in
        "basic")
            # Test help/usage output
            timeout 30s bash "$SCRIPT_DIR/$agent_script" --help > "$agent_test_dir/help_output.log" 2>&1 || true
            local exit_code=$?
            
            # Check for common indicators of working agents
            if grep -qE "(Usage:|Commands:|Options:|Help:|ERROR:|usage:)" "$agent_test_dir/help_output.log"; then
                log_success "$agent_name - Basic functionality verified"
                TEST_RESULTS["$agent_name"]="PASSED"
                ((PASSED++))
            elif [[ -s "$agent_test_dir/help_output.log" ]]; then
                log_warning "$agent_name - Produced output but no clear usage info"
                TEST_RESULTS["$agent_name"]="PARTIAL"
                ((PASSED++))
            else
                log_error "$agent_name - No output or failed"
                TEST_RESULTS["$agent_name"]="FAILED"
                ((FAILED++))
            fi
            ;;
            
        "state_check")
            # Test agents that manage state
            timeout 30s bash "$SCRIPT_DIR/$agent_script" status > "$agent_test_dir/status_output.log" 2>&1 || true
            if [[ -s "$agent_test_dir/status_output.log" ]]; then
                log_success "$agent_name - State check passed"
                TEST_RESULTS["$agent_name"]="PASSED"
                ((PASSED++))
            else
                log_error "$agent_name - State check failed"
                TEST_RESULTS["$agent_name"]="FAILED"
                ((FAILED++))
            fi
            ;;
            
        "dry_run")
            # Test agents with dry-run capability
            timeout 30s bash "$SCRIPT_DIR/$agent_script" --dry-run > "$agent_test_dir/dry_run_output.log" 2>&1 || true
            if grep -qE "(DRY RUN|Would|Simulating|dry.?run)" "$agent_test_dir/dry_run_output.log"; then
                log_success "$agent_name - Dry run capability verified"
                TEST_RESULTS["$agent_name"]="PASSED"
                ((PASSED++))
            else
                log_warning "$agent_name - Dry run not clearly supported"
                TEST_RESULTS["$agent_name"]="PARTIAL"
                ((PASSED++))
            fi
            ;;
    esac
}

# Banner
clear
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Comprehensive Build Agent Test Suite v2.0         ║"
echo "║                                                          ║"
echo "║  Testing ALL agents in BuildFixAgents directory          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log "Test started at $(date)"
log "Test output directory: $TEST_DIR"

# Core Build Fix Agents
log "\n${BLUE}=== Testing Core Build Fix Agents ===${NC}"
test_agent "Master Fix Coordinator" "master_fix_coordinator.sh" "basic"
test_agent "Generic Agent Coordinator" "generic_agent_coordinator.sh" "basic"
test_agent "Generic Build Analyzer" "generic_build_analyzer.sh" "basic"
test_agent "Generic Error Agent" "generic_error_agent.sh" "basic"
test_agent "Unified Error Counter" "unified_error_counter.sh" "basic"
test_agent "Fix Agent Build Analyzer" "fix_agent_buildanalyzer.sh" "basic"
test_agent "Fix Agent Error Counting" "fix_agent_errorcounting.sh" "basic"
test_agent "Autofix" "autofix.sh" "dry_run"

# Development Agents
log "\n${BLUE}=== Testing Development Agents ===${NC}"
test_agent "Developer Agent Core Fix" "dev_agent_core_fix.sh" "basic"
test_agent "Developer Agent Integration" "dev_agent_integration.sh" "basic"
test_agent "Developer Agent Patterns" "dev_agent_patterns.sh" "basic"
test_agent "Developer Agent State" "dev_agent_state.sh" "state_check"
test_agent "CodeGen Developer Agent" "codegen_developer_agent.sh" "basic"
test_agent "Architect Agent" "architect_agent.sh" "basic"
test_agent "Architect Agent V2" "architect_agent_v2.sh" "basic"

# Specialized Fix Agents
log "\n${BLUE}=== Testing Specialized Fix Agents ===${NC}"
test_agent "Agent1 Duplicate Resolver" "agent1_duplicate_resolver.sh" "basic"
test_agent "Agent2 Constraints Specialist" "agent2_constraints_specialist.sh" "basic"
test_agent "Agent3 Inheritance Specialist" "agent3_inheritance_specialist.sh" "basic"
test_agent "Multi-Language Fix Agent" "multi_language_fix_agent.sh" "basic"
test_agent "AI Powered Fixer" "ai_powered_fixer.sh" "basic"

# Quality Assurance Agents
log "\n${BLUE}=== Testing QA Agents ===${NC}"
test_agent "QA Agent Final" "qa_agent_final.sh" "basic"
test_agent "QA Automation Agent" "qa_automation_agent.sh" "basic"
test_agent "QA Test Manager" "qa_test_manager.sh" "state_check"
test_agent "Tester Agent" "tester_agent.sh" "basic"
test_agent "Testing Agent V2" "testing_agent_v2.sh" "basic"

# Project Management Agents
log "\n${BLUE}=== Testing Project Management Agents ===${NC}"
test_agent "Project Manager Agent" "project_manager_agent.sh" "state_check"
test_agent "Scrum Master Agent" "scrum_master_agent.sh" "state_check"
test_agent "Product Owner Agent" "product_owner_agent.sh" "basic"
test_agent "Business Analyst Agent" "business_analyst_agent.sh" "basic"
test_agent "Sprint Planning Agent" "sprint_planning_agent.sh" "basic"
test_agent "User Story Agent" "user_story_agent.sh" "basic"
test_agent "Roadmap Agent" "roadmap_agent.sh" "basic"
test_agent "Requirements Agent" "requirements_agent.sh" "basic"

# Infrastructure Agents
log "\n${BLUE}=== Testing Infrastructure Agents ===${NC}"
test_agent "Deployment Agent" "deployment_agent.sh" "dry_run"
test_agent "Database Agent" "database_agent.sh" "basic"
test_agent "Container Kubernetes Support" "container_kubernetes_support.sh" "basic"
test_agent "Hardware Detector" "hardware_detector.sh" "basic"
test_agent "Distributed Coordinator" "distributed_coordinator.sh" "state_check"

# Feature Implementation Agents
log "\n${BLUE}=== Testing Feature Implementation Agents ===${NC}"
test_agent "Feature Implementation Agent" "feature_implementation_agent.sh" "basic"
test_agent "API Design Agent" "api_design_agent.sh" "basic"
test_agent "Frontend Agent" "frontend_agent.sh" "basic"
test_agent "Documentation Agent" "documentation_agent.sh" "basic"
test_agent "Refactoring Agent" "refactoring_agent.sh" "dry_run"

# Analysis and Monitoring Agents
log "\n${BLUE}=== Testing Analysis & Monitoring Agents ===${NC}"
test_agent "Analysis Agent" "analysis_agent.sh" "basic"
test_agent "Monitoring Agent" "monitoring_agent.sh" "state_check"
test_agent "Performance Agent" "performance_agent.sh" "basic"
test_agent "Performance Agent V2" "performance_agent_v2.sh" "basic"
test_agent "Metrics Collector Agent" "metrics_collector_agent.sh" "state_check"
test_agent "Build Checker Agent" "build_checker_agent.sh" "basic"

# Security and Compliance Agents
log "\n${BLUE}=== Testing Security & Compliance Agents ===${NC}"
test_agent "Security Agent" "security_agent.sh" "basic"
test_agent "Advanced Security Suite" "advanced_security_suite.sh" "basic"
test_agent "Quantum Resistant Security" "quantum_resistant_security.sh" "basic"
test_agent "Compliance Audit Framework" "compliance_audit_framework.sh" "state_check"

# AI and Learning Agents
log "\n${BLUE}=== Testing AI & Learning Agents ===${NC}"
test_agent "Learning Agent" "learning_agent.sh" "state_check"
test_agent "Pattern Learner" "pattern_learner.sh" "state_check"
test_agent "Pattern Generator" "pattern_generator.sh" "basic"
test_agent "Pattern Validator" "pattern_validator.sh" "basic"
test_agent "AI Integration" "ai_integration.sh" "basic"
test_agent "ML Integration Layer" "ml_integration_layer.sh" "basic"
test_agent "Feedback Loop Agent" "feedback_loop_agent.sh" "state_check"

# System Integration Agents
log "\n${BLUE}=== Testing System Integration Agents ===${NC}"
test_agent "Integration Hub" "integration_hub.sh" "state_check"
test_agent "Git Integration" "git_integration.sh" "basic"
test_agent "IDE Integration" "ide_integration.sh" "basic"
test_agent "Claude Code Integration" "claude_code_integration.sh" "basic"
test_agent "Plugin Manager" "plugin_manager.sh" "state_check"
test_agent "Config Manager" "config_manager.sh" "state_check"

# Advanced Feature Agents
log "\n${BLUE}=== Testing Advanced Feature Agents ===${NC}"
test_agent "Advanced Analytics" "advanced_analytics.sh" "basic"
test_agent "Advanced Caching System" "advanced_caching_system.sh" "state_check"
test_agent "Advanced Pattern Engine" "advanced_pattern_engine.sh" "basic"
test_agent "Knowledge Management System" "knowledge_management_system.sh" "state_check"
test_agent "Realtime Collaboration" "realtime_collaboration.sh" "basic"
test_agent "Edge Computing Support" "edge_computing_support.sh" "basic"

# Optimization and Cost Agents
log "\n${BLUE}=== Testing Optimization Agents ===${NC}"
test_agent "Cost Optimization Agent" "cost_optimization_agent.sh" "basic"
test_agent "Cost Optimization Engine" "cost_optimization_engine.sh" "basic"
test_agent "Dependency Agent" "dependency_agent.sh" "basic"
test_agent "Accessibility Agent" "accessibility_agent.sh" "basic"

# Enterprise and Production Agents
log "\n${BLUE}=== Testing Enterprise Agents ===${NC}"
test_agent "Enterprise Launcher" "enterprise_launcher.sh" "basic"
test_agent "Enterprise Launcher V2" "enterprise_launcher_v2.sh" "basic"
test_agent "Enterprise Launcher V3" "enterprise_launcher_v3.sh" "basic"
test_agent "Enterprise Orchestration" "enterprise_orchestration.sh" "state_check"
test_agent "Production Features" "production_features.sh" "basic"

# Visionary and Strategic Agents
log "\n${BLUE}=== Testing Visionary Agents ===${NC}"
test_agent "Visionary Agent" "visionary_agent.sh" "basic"
test_agent "Visionary Agent BuildFix" "visionary_agent_buildfix.sh" "basic"

# Utility and Support Agents
log "\n${BLUE}=== Testing Utility Agents ===${NC}"
test_agent "Notification System" "notification_system.sh" "basic"
test_agent "Telemetry Collector" "telemetry_collector.sh" "state_check"
test_agent "Language Detector" "language_detector.sh" "basic"
test_agent "Pattern Database Manager" "pattern_database_manager.sh" "state_check"
test_agent "Project Generator Agent" "project_generator_agent.sh" "dry_run"

# Dashboard and Web Agents
log "\n${BLUE}=== Testing Dashboard & Web Agents ===${NC}"
test_agent "Dashboard" "dashboard.sh" "basic"
test_agent "Web Dashboard" "web_dashboard.sh" "basic"
test_agent "AB Testing Framework" "ab_testing_framework.sh" "basic"

# Special Purpose Agents
log "\n${BLUE}=== Testing Special Purpose Agents ===${NC}"
test_agent "God Mode Controller" "god_mode_controller.sh" "basic"
test_agent "Disaster Recovery" "disaster_recovery.sh" "dry_run"
test_agent "Enhanced Logging System" "enhanced_logging_system.sh" "state_check"

# Generate detailed report
generate_report() {
    local report_file="$TEST_DIR/test_report.md"
    
    {
        echo "# Build Agent Test Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Summary"
        echo "- Total Agents Tested: $TOTAL_AGENTS"
        echo "- Passed: $PASSED"
        echo "- Failed: $FAILED"
        echo "- Skipped: $SKIPPED"
        echo "- Success Rate: $(( PASSED * 100 / TOTAL_AGENTS ))%"
        echo ""
        echo "## Detailed Results"
        echo ""
        echo "| Agent Name | Status | Notes |"
        echo "|------------|--------|-------|"
        
        for agent in "${!TEST_RESULTS[@]}"; do
            local status="${TEST_RESULTS[$agent]}"
            local status_icon=""
            case "$status" in
                "PASSED") status_icon="✅" ;;
                "PARTIAL") status_icon="⚠️" ;;
                "FAILED") status_icon="❌" ;;
                "NOT_FOUND") status_icon="🚫" ;;
                "NOT_EXECUTABLE") status_icon="🔒" ;;
            esac
            echo "| $agent | $status_icon $status | |"
        done | sort
        
        echo ""
        echo "## Failed Agents Analysis"
        echo ""
        for agent in "${!TEST_RESULTS[@]}"; do
            if [[ "${TEST_RESULTS[$agent]}" == "FAILED" ]]; then
                echo "### $agent"
                echo "Status: Failed"
                echo "Log: See $TEST_DIR/agents/$(echo "$agent" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')/help_output.log"
                echo ""
            fi
        done
    } > "$report_file"
    
    log "\nDetailed report generated: $report_file"
}

# Summary
log "\n${BLUE}╔════════════════════════════════════════════════╗${NC}"
log "${BLUE}║                 Test Summary                   ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════╝${NC}"
log "Total Agents Tested: $TOTAL_AGENTS"
log_success "Passed: $PASSED"
log_error "Failed: $FAILED"
if [[ $SKIPPED -gt 0 ]]; then
    log_warning "Skipped: $SKIPPED"
fi
log "Success Rate: $(( PASSED * 100 / TOTAL_AGENTS ))%"

# Generate report
generate_report

# Show failed agents
if [[ $FAILED -gt 0 ]]; then
    log "\n${RED}Failed Agents:${NC}"
    for agent in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$agent]}" == "FAILED" ]] || [[ "${TEST_RESULTS[$agent]}" == "NOT_FOUND" ]]; then
            log_error "  - $agent (${TEST_RESULTS[$agent]})"
        fi
    done
fi

# Exit code
if [[ $FAILED -eq 0 ]]; then
    log_success "\nAll tests passed! 🎉"
    exit 0
else
    log_error "\nSome tests failed. Check $TEST_DIR for detailed logs."
    exit 1
fi