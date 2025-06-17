#!/bin/bash
# Safe agent testing script - tests without executing agent logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/test_results/agent_test_report_$(date +%Y%m%d_%H%M%S).md"
mkdir -p "$(dirname "$REPORT_FILE")"

# Initialize report
{
    echo "# BuildFix Agents Test Report"
    echo "Generated: $(date)"
    echo ""
    echo "## Test Overview"
    echo "This report validates the existence and basic structure of all BuildFix agents."
    echo ""
} > "$REPORT_FILE"

TOTAL=0
VALID=0
MISSING=0
ISSUES=0

# Test function
check_agent() {
    local script="$1"
    local description="$2"
    local category="$3"
    
    ((TOTAL++))
    
    local status="❌ Missing"
    local details=""
    
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            # Check basic structure
            if grep -q "#!/bin/bash" "$SCRIPT_DIR/$script"; then
                status="✅ Valid"
                ((VALID++))
            else
                status="⚠️ No shebang"
                ((ISSUES++))
            fi
        else
            chmod +x "$SCRIPT_DIR/$script" 2>/dev/null && {
                status="✅ Valid (made executable)"
                ((VALID++))
            } || {
                status="⚠️ Not executable"
                ((ISSUES++))
            }
        fi
        
        # Get file size
        local size=$(stat -c%s "$SCRIPT_DIR/$script" 2>/dev/null || stat -f%z "$SCRIPT_DIR/$script" 2>/dev/null || echo "0")
        details="$(( size / 1024 ))KB"
    else
        ((MISSING++))
    fi
    
    echo "| $script | $description | $status | $details |" >> "$REPORT_FILE"
}

# Write category header
write_category() {
    echo "" >> "$REPORT_FILE"
    echo "### $1" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| Agent Script | Description | Status | Size |" >> "$REPORT_FILE"
    echo "|--------------|-------------|--------|------|" >> "$REPORT_FILE"
}

# Core Build Fix Agents
write_category "Core Build Fix Agents"
check_agent "master_fix_coordinator.sh" "Main coordinator for build fixes" "core"
check_agent "generic_agent_coordinator.sh" "Generic agent coordination" "core"
check_agent "generic_build_analyzer.sh" "Analyzes build output" "core"
check_agent "generic_error_agent.sh" "Generic error handling" "core"
check_agent "unified_error_counter.sh" "Counts and tracks errors" "core"
check_agent "fix_agent_buildanalyzer.sh" "Build analysis specialist" "core"
check_agent "fix_agent_errorcounting.sh" "Error counting specialist" "core"
check_agent "autofix.sh" "Automatic fix execution" "core"

# Development Agents
write_category "Development Agents"
check_agent "dev_agent_core_fix.sh" "Core development fixes" "dev"
check_agent "dev_agent_integration.sh" "Integration development" "dev"
check_agent "dev_agent_patterns.sh" "Pattern-based development" "dev"
check_agent "dev_agent_state.sh" "State management for dev" "dev"
check_agent "codegen_developer_agent.sh" "Code generation" "dev"
check_agent "architect_agent.sh" "Architecture decisions" "dev"
check_agent "architect_agent_v2.sh" "Enhanced architecture agent" "dev"

# Specialized Fix Agents
write_category "Specialized Fix Agents"
check_agent "agent1_duplicate_resolver.sh" "Resolves duplicate definitions" "fix"
check_agent "agent2_constraints_specialist.sh" "Handles constraint issues" "fix"
check_agent "agent3_inheritance_specialist.sh" "Fixes inheritance problems" "fix"
check_agent "multi_language_fix_agent.sh" "Multi-language support" "fix"
check_agent "ai_powered_fixer.sh" "AI-enhanced fixing" "fix"

# Quality Assurance Agents
write_category "Quality Assurance Agents"
check_agent "qa_agent_final.sh" "Final QA validation" "qa"
check_agent "qa_automation_agent.sh" "Automated testing" "qa"
check_agent "qa_test_manager.sh" "Test management" "qa"
check_agent "tester_agent.sh" "Basic testing agent" "qa"
check_agent "testing_agent_v2.sh" "Enhanced testing" "qa"

# Project Management Agents
write_category "Project Management Agents"
check_agent "project_manager_agent.sh" "Project coordination" "pm"
check_agent "scrum_master_agent.sh" "Scrum process management" "pm"
check_agent "product_owner_agent.sh" "Product ownership tasks" "pm"
check_agent "business_analyst_agent.sh" "Business analysis" "pm"
check_agent "sprint_planning_agent.sh" "Sprint planning" "pm"
check_agent "user_story_agent.sh" "User story management" "pm"
check_agent "roadmap_agent.sh" "Product roadmap" "pm"
check_agent "requirements_agent.sh" "Requirements gathering" "pm"

# Infrastructure Agents
write_category "Infrastructure Agents"
check_agent "deployment_agent.sh" "Deployment automation" "infra"
check_agent "database_agent.sh" "Database operations" "infra"
check_agent "container_kubernetes_support.sh" "Container orchestration" "infra"
check_agent "hardware_detector.sh" "Hardware detection" "infra"
check_agent "distributed_coordinator.sh" "Distributed systems" "infra"

# Feature Implementation Agents
write_category "Feature Implementation Agents"
check_agent "feature_implementation_agent.sh" "Feature development" "feature"
check_agent "api_design_agent.sh" "API design and docs" "feature"
check_agent "frontend_agent.sh" "Frontend development" "feature"
check_agent "documentation_agent.sh" "Documentation generation" "feature"
check_agent "refactoring_agent.sh" "Code refactoring" "feature"

# Analysis and Monitoring Agents
write_category "Analysis & Monitoring Agents"
check_agent "analysis_agent.sh" "Code analysis" "monitor"
check_agent "monitoring_agent.sh" "System monitoring" "monitor"
check_agent "performance_agent.sh" "Performance analysis" "monitor"
check_agent "performance_agent_v2.sh" "Enhanced performance" "monitor"
check_agent "metrics_collector_agent.sh" "Metrics collection" "monitor"
check_agent "build_checker_agent.sh" "Build validation" "monitor"

# Security and Compliance Agents
write_category "Security & Compliance Agents"
check_agent "security_agent.sh" "Security scanning" "security"
check_agent "advanced_security_suite.sh" "Advanced security" "security"
check_agent "quantum_resistant_security.sh" "Quantum-safe security" "security"
check_agent "compliance_audit_framework.sh" "Compliance auditing" "security"

# AI and Learning Agents
write_category "AI & Learning Agents"
check_agent "learning_agent.sh" "Machine learning integration" "ai"
check_agent "pattern_learner.sh" "Pattern recognition" "ai"
check_agent "pattern_generator.sh" "Pattern generation" "ai"
check_agent "pattern_validator.sh" "Pattern validation" "ai"
check_agent "ai_integration.sh" "AI system integration" "ai"
check_agent "ml_integration_layer.sh" "ML layer integration" "ai"
check_agent "feedback_loop_agent.sh" "Learning feedback loops" "ai"

# System Integration Agents
write_category "System Integration Agents"
check_agent "integration_hub.sh" "Central integration hub" "integration"
check_agent "git_integration.sh" "Git operations" "integration"
check_agent "ide_integration.sh" "IDE integration" "integration"
check_agent "claude_code_integration.sh" "Claude Code integration" "integration"
check_agent "plugin_manager.sh" "Plugin management" "integration"
check_agent "config_manager.sh" "Configuration management" "integration"

# Advanced Feature Agents
write_category "Advanced Feature Agents"
check_agent "advanced_analytics.sh" "Advanced analytics" "advanced"
check_agent "advanced_caching_system.sh" "Caching system" "advanced"
check_agent "advanced_pattern_engine.sh" "Pattern engine" "advanced"
check_agent "knowledge_management_system.sh" "Knowledge base" "advanced"
check_agent "realtime_collaboration.sh" "Real-time collab" "advanced"
check_agent "edge_computing_support.sh" "Edge computing" "advanced"

# Optimization and Cost Agents
write_category "Optimization Agents"
check_agent "cost_optimization_agent.sh" "Cost optimization" "optimize"
check_agent "cost_optimization_engine.sh" "Cost engine" "optimize"
check_agent "dependency_agent.sh" "Dependency management" "optimize"
check_agent "accessibility_agent.sh" "Accessibility checks" "optimize"

# Enterprise and Production Agents
write_category "Enterprise Agents"
check_agent "enterprise_launcher.sh" "Enterprise launcher v1" "enterprise"
check_agent "enterprise_launcher_v2.sh" "Enterprise launcher v2" "enterprise"
check_agent "enterprise_launcher_v3.sh" "Enterprise launcher v3" "enterprise"
check_agent "enterprise_orchestration.sh" "Enterprise orchestration" "enterprise"
check_agent "production_features.sh" "Production features" "enterprise"

# Visionary and Strategic Agents
write_category "Visionary Agents"
check_agent "visionary_agent.sh" "Strategic vision" "vision"
check_agent "visionary_agent_buildfix.sh" "BuildFix vision" "vision"

# Utility and Support Agents
write_category "Utility Agents"
check_agent "notification_system.sh" "Notifications" "utility"
check_agent "telemetry_collector.sh" "Telemetry collection" "utility"
check_agent "language_detector.sh" "Language detection" "utility"
check_agent "pattern_database_manager.sh" "Pattern DB management" "utility"
check_agent "project_generator_agent.sh" "Project generation" "utility"

# Dashboard and Web Agents
write_category "Dashboard & Web Agents"
check_agent "dashboard.sh" "CLI Dashboard" "web"
check_agent "web_dashboard.sh" "Web Dashboard" "web"
check_agent "ab_testing_framework.sh" "A/B Testing" "web"

# Special Purpose Agents
write_category "Special Purpose Agents"
check_agent "god_mode_controller.sh" "Master control" "special"
check_agent "disaster_recovery.sh" "Disaster recovery" "special"
check_agent "enhanced_logging_system.sh" "Enhanced logging" "special"

# Write summary
{
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Count | Percentage |"
    echo "|--------|-------|------------|"
    echo "| Total Agents | $TOTAL | 100% |"
    echo "| ✅ Valid | $VALID | $(( VALID * 100 / TOTAL ))% |"
    echo "| ⚠️ Issues | $ISSUES | $(( ISSUES * 100 / TOTAL ))% |"
    echo "| ❌ Missing | $MISSING | $(( MISSING * 100 / TOTAL ))% |"
    echo ""
    echo "## Test Execution Notes"
    echo ""
    echo "- This test validates agent existence and basic structure only"
    echo "- Agents were not executed to avoid unintended side effects"
    echo "- For functional testing, use dedicated test environments"
    echo ""
    echo "## Recommendations"
    echo ""
    if [[ $MISSING -gt 0 ]]; then
        echo "- $MISSING agents are missing and should be investigated"
    fi
    if [[ $ISSUES -gt 0 ]]; then
        echo "- $ISSUES agents have minor issues (permissions, shebang)"
    fi
    echo "- All valid agents should be tested in isolated environments"
    echo "- Consider implementing a test mode flag for safe agent testing"
} >> "$REPORT_FILE"

# Display summary
echo "BuildFix Agent Validation Complete"
echo "=================================="
echo "Total Agents: $TOTAL"
echo "Valid: $VALID ($(( VALID * 100 / TOTAL ))%)"
echo "Issues: $ISSUES ($(( ISSUES * 100 / TOTAL ))%)"
echo "Missing: $MISSING ($(( MISSING * 100 / TOTAL ))%)"
echo ""
echo "Full report saved to: $REPORT_FILE"

# Also create a quick summary file
SUMMARY_FILE="$SCRIPT_DIR/test_results/agent_summary_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "AGENT TEST SUMMARY - $(date)"
    echo "=========================="
    echo "Total: $TOTAL"
    echo "Valid: $VALID"
    echo "Issues: $ISSUES"
    echo "Missing: $MISSING"
    echo ""
    echo "Success Rate: $(( VALID * 100 / TOTAL ))%"
} > "$SUMMARY_FILE"

echo "Summary saved to: $SUMMARY_FILE"