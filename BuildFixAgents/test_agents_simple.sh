#!/bin/bash
# Simple agent test script with quick validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS="$SCRIPT_DIR/test_results/simple_test_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$(dirname "$TEST_RESULTS")"

echo "BuildFix Agent Test Report - $(date)" > "$TEST_RESULTS"
echo "========================================" >> "$TEST_RESULTS"
echo "" >> "$TEST_RESULTS"

PASSED=0
FAILED=0

# Quick test function
test_agent() {
    local script="$1"
    local name="${script%.sh}"
    
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        echo "❌ $name - NOT FOUND" >> "$TEST_RESULTS"
        ((FAILED++))
        return
    fi
    
    # Make executable if needed
    chmod +x "$SCRIPT_DIR/$script" 2>/dev/null || true
    
    # Quick test - just check if it runs without major errors
    if timeout 5s bash "$SCRIPT_DIR/$script" --help >/dev/null 2>&1 || \
       timeout 5s bash "$SCRIPT_DIR/$script" help >/dev/null 2>&1 || \
       timeout 5s bash "$SCRIPT_DIR/$script" >/dev/null 2>&1; then
        echo "✅ $name - OK" >> "$TEST_RESULTS"
        ((PASSED++))
    else
        echo "❌ $name - FAILED" >> "$TEST_RESULTS"
        ((FAILED++))
    fi
}

echo "Testing agents..."

# List of all agents to test
agents=(
    "master_fix_coordinator.sh"
    "generic_agent_coordinator.sh"
    "generic_build_analyzer.sh"
    "generic_error_agent.sh"
    "unified_error_counter.sh"
    "fix_agent_buildanalyzer.sh"
    "fix_agent_errorcounting.sh"
    "autofix.sh"
    "dev_agent_core_fix.sh"
    "dev_agent_integration.sh"
    "dev_agent_patterns.sh"
    "dev_agent_state.sh"
    "codegen_developer_agent.sh"
    "architect_agent.sh"
    "architect_agent_v2.sh"
    "agent1_duplicate_resolver.sh"
    "agent2_constraints_specialist.sh"
    "agent3_inheritance_specialist.sh"
    "multi_language_fix_agent.sh"
    "ai_powered_fixer.sh"
    "qa_agent_final.sh"
    "qa_automation_agent.sh"
    "qa_test_manager.sh"
    "tester_agent.sh"
    "testing_agent_v2.sh"
    "project_manager_agent.sh"
    "scrum_master_agent.sh"
    "product_owner_agent.sh"
    "business_analyst_agent.sh"
    "sprint_planning_agent.sh"
    "user_story_agent.sh"
    "roadmap_agent.sh"
    "requirements_agent.sh"
    "deployment_agent.sh"
    "database_agent.sh"
    "container_kubernetes_support.sh"
    "hardware_detector.sh"
    "distributed_coordinator.sh"
    "feature_implementation_agent.sh"
    "api_design_agent.sh"
    "frontend_agent.sh"
    "documentation_agent.sh"
    "refactoring_agent.sh"
    "analysis_agent.sh"
    "monitoring_agent.sh"
    "performance_agent.sh"
    "performance_agent_v2.sh"
    "metrics_collector_agent.sh"
    "build_checker_agent.sh"
    "security_agent.sh"
    "advanced_security_suite.sh"
    "quantum_resistant_security.sh"
    "compliance_audit_framework.sh"
    "learning_agent.sh"
    "pattern_learner.sh"
    "pattern_generator.sh"
    "pattern_validator.sh"
    "ai_integration.sh"
    "ml_integration_layer.sh"
    "feedback_loop_agent.sh"
    "integration_hub.sh"
    "git_integration.sh"
    "ide_integration.sh"
    "claude_code_integration.sh"
    "plugin_manager.sh"
    "config_manager.sh"
    "advanced_analytics.sh"
    "advanced_caching_system.sh"
    "advanced_pattern_engine.sh"
    "knowledge_management_system.sh"
    "realtime_collaboration.sh"
    "edge_computing_support.sh"
    "cost_optimization_agent.sh"
    "cost_optimization_engine.sh"
    "dependency_agent.sh"
    "accessibility_agent.sh"
    "enterprise_launcher.sh"
    "enterprise_launcher_v2.sh"
    "enterprise_launcher_v3.sh"
    "enterprise_orchestration.sh"
    "production_features.sh"
    "visionary_agent.sh"
    "visionary_agent_buildfix.sh"
    "notification_system.sh"
    "telemetry_collector.sh"
    "language_detector.sh"
    "pattern_database_manager.sh"
    "project_generator_agent.sh"
    "dashboard.sh"
    "web_dashboard.sh"
    "ab_testing_framework.sh"
    "god_mode_controller.sh"
    "disaster_recovery.sh"
    "enhanced_logging_system.sh"
)

# Test each agent
for agent in "${agents[@]}"; do
    echo -n "Testing $agent... "
    test_agent "$agent"
    echo "done"
done

# Summary
echo "" >> "$TEST_RESULTS"
echo "SUMMARY" >> "$TEST_RESULTS"
echo "=======" >> "$TEST_RESULTS"
echo "Total agents: ${#agents[@]}" >> "$TEST_RESULTS"
echo "Passed: $PASSED" >> "$TEST_RESULTS"
echo "Failed: $FAILED" >> "$TEST_RESULTS"
echo "Success rate: $(( PASSED * 100 / ${#agents[@]} ))%" >> "$TEST_RESULTS"

# Display results
cat "$TEST_RESULTS"

echo ""
echo "Full results saved to: $TEST_RESULTS"

# Exit with appropriate code
[[ $FAILED -eq 0 ]] && exit 0 || exit 1