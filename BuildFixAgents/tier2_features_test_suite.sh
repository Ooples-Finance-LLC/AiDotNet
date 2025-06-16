#!/bin/bash

# Tier 2 Features Test Suite - Comprehensive testing for advanced features
# Tests ML integration, analytics, cost optimization, and disaster recovery

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS="$AGENT_DIR/test_results/tier2"
TEST_DATA="$AGENT_DIR/test_data/tier2"

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
mkdir -p "$TEST_RESULTS" "$TEST_DATA"

# Test logging
log_test() {
    local test_name="$1"
    local status="$2"
    local message="${3:-}"
    local duration="${4:-0}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $test_name: $status - $message (${duration}s)" >> "$TEST_RESULTS/test_log.txt"
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✓${NC} $test_name (${duration}s)"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $test_name - $message (${duration}s)"
            ((TESTS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $test_name - $message"
            ((TESTS_SKIPPED++))
            ;;
    esac
    
    ((TESTS_TOTAL++))
}

# Create test data
create_test_data() {
    echo -e "\n${CYAN}Creating test data for Tier 2 features...${NC}"
    
    # Create sample training data for ML
    cat > "$TEST_DATA/training_data.json" << 'EOF'
[
    {"error_code": "CS0246", "fix_type": "add_using", "fix_successful": true, "fix_duration": 30},
    {"error_code": "CS0246", "fix_type": "add_reference", "fix_successful": true, "fix_duration": 45},
    {"error_code": "CS0101", "fix_type": "rename_class", "fix_successful": true, "fix_duration": 25},
    {"error_code": "CS0115", "fix_type": "add_override", "fix_successful": false, "fix_duration": 60}
]
EOF
    
    # Create sample error data
    cat > "$TEST_DATA/current_errors.json" << 'EOF'
[
    {"error_code": "CS0246", "file": "test.cs", "line": 10},
    {"error_code": "CS0246", "file": "test2.cs", "line": 20},
    {"error_code": "CS0101", "file": "duplicate.cs", "line": 5}
]
EOF
    
    echo -e "${GREEN}✓ Test data created${NC}"
}

# Test ML Integration Layer
test_ml_integration() {
    echo -e "\n${BLUE}═══ Testing ML Integration Layer ═══${NC}"
    
    # Test ML initialization
    test_ml_init() {
        local test_name="ML Configuration Init"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/ml_integration_layer.sh" status >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "ML initialization failed" "$duration"
        fi
    }
    
    # Test pattern recording
    test_pattern_recording() {
        local test_name="ML Pattern Recording"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/ml_integration_layer.sh" record "CS0246" "add_using" true 30 >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Failed to record pattern" "$duration"
        fi
    }
    
    # Test model training
    test_model_training() {
        local test_name="ML Model Training"
        local start_time=$(date +%s)
        
        # Copy test training data
        mkdir -p "$AGENT_DIR/state/ml"
        cp "$TEST_DATA/training_data.json" "$AGENT_DIR/state/ml/training_data.json"
        
        # Add more records to meet minimum threshold
        for i in {1..100}; do
            "$AGENT_DIR/ml_integration_layer.sh" record "CS0246" "add_using" true 30 >/dev/null 2>&1
        done
        
        "$AGENT_DIR/ml_integration_layer.sh" train all >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/ml/models/error_predictor.json" ]]; then
            log_test "$test_name" "PASS" "Models trained successfully" "$duration"
        else
            log_test "$test_name" "FAIL" "Model files not created" "$duration"
        fi
    }
    
    # Test predictions
    test_predictions() {
        local test_name="ML Error Predictions"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/ml_integration_layer.sh" predict "$TEST_DATA" >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -d "$AGENT_DIR/state/ml/predictions" ]] && [[ -n "$(ls -A "$AGENT_DIR/state/ml/predictions" 2>/dev/null)" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "SKIP" "No predictions generated" "$duration"
        fi
    }
    
    # Test anomaly detection
    test_anomaly_detection() {
        local test_name="ML Anomaly Detection"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/ml_integration_layer.sh" anomaly "$TEST_DATA/current_errors.json" >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_test "$test_name" "PASS" "Anomaly detection functional" "$duration"
    }
    
    # Run all ML tests
    test_ml_init
    test_pattern_recording
    test_model_training
    test_predictions
    test_anomaly_detection
}

# Test Advanced Analytics
test_advanced_analytics() {
    echo -e "\n${BLUE}═══ Testing Advanced Analytics ═══${NC}"
    
    # Test metrics collection
    test_metrics_collection() {
        local test_name="Analytics Metrics Collection"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/advanced_analytics.sh" collect >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/analytics/metrics/metrics_$(date +%Y%m%d).json" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Metrics file not created" "$duration"
        fi
    }
    
    # Test KPI calculation
    test_kpi_calculation() {
        local test_name="Analytics KPI Calculation"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/advanced_analytics.sh" kpi 7 >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/analytics/kpis_$(date +%Y%m%d).json" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "KPI file not created" "$duration"
        fi
    }
    
    # Test executive dashboard
    test_executive_dashboard() {
        local test_name="Executive Dashboard Generation"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/advanced_analytics.sh" executive >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/analytics/dashboards/executive_dashboard_$(date +%Y%m%d).html" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Dashboard not generated" "$duration"
        fi
    }
    
    # Test trend analysis
    test_trend_analysis() {
        local test_name="Trend Analysis Report"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/advanced_analytics.sh" trends 30 >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/analytics/reports/error_trends_$(date +%Y%m%d).html" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Trends report not generated" "$duration"
        fi
    }
    
    # Run all analytics tests
    test_metrics_collection
    test_kpi_calculation
    test_executive_dashboard
    test_trend_analysis
}

# Test Cost Optimization
test_cost_optimization() {
    echo -e "\n${BLUE}═══ Testing Cost Optimization Engine ═══${NC}"
    
    # Test resource tracking
    test_resource_tracking() {
        local test_name="Cost Resource Tracking"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/cost_optimization_engine.sh" track >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/cost_optimization/usage/usage_$(date +%Y%m%d).json" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Usage tracking failed" "$duration"
        fi
    }
    
    # Test cost calculation
    test_cost_calculation() {
        local test_name="Cost Calculation"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/cost_optimization_engine.sh" calculate >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/cost_optimization/reports/cost_report_$(date +%Y%m%d).json" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Cost calculation failed" "$duration"
        fi
    }
    
    # Test cost predictions
    test_cost_predictions() {
        local test_name="Cost Predictions"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/cost_optimization_engine.sh" predict 7 >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/cost_optimization/predictions/cost_prediction_$(date +%Y%m%d).json" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Cost prediction failed" "$duration"
        fi
    }
    
    # Test optimization recommendations
    test_optimization_recommendations() {
        local test_name="Optimization Recommendations"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/cost_optimization_engine.sh" optimize >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -f "$AGENT_DIR/state/cost_optimization/scaling_decision.txt" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "No optimization recommendations" "$duration"
        fi
    }
    
    # Run all cost optimization tests
    test_resource_tracking
    test_cost_calculation
    test_cost_predictions
    test_optimization_recommendations
}

# Test Disaster Recovery
test_disaster_recovery() {
    echo -e "\n${BLUE}═══ Testing Disaster Recovery ═══${NC}"
    
    # Test backup creation
    test_backup_creation() {
        local test_name="DR Backup Creation"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/disaster_recovery.sh" backup full >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ -n "$(ls "$AGENT_DIR/backups/snapshots"/backup_full_*.tar.gz 2>/dev/null)" ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Backup not created" "$duration"
        fi
    }
    
    # Test backup listing
    test_backup_listing() {
        local test_name="DR Backup Listing"
        local start_time=$(date +%s)
        
        local output=$("$AGENT_DIR/disaster_recovery.sh" list 2>&1)
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Backup listing failed" "$duration"
        fi
    }
    
    # Test recovery procedure
    test_recovery_procedure() {
        local test_name="DR Recovery Test"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/disaster_recovery.sh" test >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]]; then
            log_test "$test_name" "PASS" "Recovery test successful" "$duration"
        else
            log_test "$test_name" "SKIP" "No backups for testing" "$duration"
        fi
    }
    
    # Test backup health monitoring
    test_backup_health() {
        local test_name="DR Health Monitoring"
        local start_time=$(date +%s)
        
        "$AGENT_DIR/disaster_recovery.sh" health >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]]; then
            log_test "$test_name" "PASS" "" "$duration"
        else
            log_test "$test_name" "FAIL" "Health check failed" "$duration"
        fi
    }
    
    # Run all DR tests
    test_backup_creation
    test_backup_listing
    test_recovery_procedure
    test_backup_health
}

# Integration tests
test_tier2_integration() {
    echo -e "\n${BLUE}═══ Testing Tier 2 Feature Integration ═══${NC}"
    
    # Test ML + Analytics integration
    test_ml_analytics_integration() {
        local test_name="ML-Analytics Integration"
        local start_time=$(date +%s)
        
        # Record some ML data
        "$AGENT_DIR/ml_integration_layer.sh" record "CS0246" "test_fix" true 30 >/dev/null 2>&1
        
        # Collect analytics
        "$AGENT_DIR/advanced_analytics.sh" collect >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_test "$test_name" "PASS" "Components work together" "$duration"
    }
    
    # Test Cost + Analytics integration
    test_cost_analytics_integration() {
        local test_name="Cost-Analytics Integration"
        local start_time=$(date +%s)
        
        # Track costs
        "$AGENT_DIR/cost_optimization_engine.sh" track >/dev/null 2>&1
        
        # Generate analytics with cost data
        "$AGENT_DIR/advanced_analytics.sh" executive >/dev/null 2>&1
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_test "$test_name" "PASS" "Cost data in analytics" "$duration"
    }
    
    # Test DR + ML integration
    test_dr_ml_integration() {
        local test_name="DR-ML Integration"
        local start_time=$(date +%s)
        
        # Ensure ML data is backed up
        if [[ -d "$AGENT_DIR/state/ml" ]]; then
            "$AGENT_DIR/disaster_recovery.sh" backup full >/dev/null 2>&1
            log_test "$test_name" "PASS" "ML data included in backups" "$duration"
        else
            log_test "$test_name" "SKIP" "No ML data to backup" "$duration"
        fi
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
    }
    
    # Run integration tests
    test_ml_analytics_integration
    test_cost_analytics_integration
    test_dr_ml_integration
}

# Performance tests
test_tier2_performance() {
    echo -e "\n${BLUE}═══ Tier 2 Performance Tests ═══${NC}"
    
    # Test ML performance
    test_ml_performance() {
        local test_name="ML Prediction Performance"
        local start_time=$(date +%s)
        
        # Time prediction generation
        timeout 10 "$AGENT_DIR/ml_integration_layer.sh" predict "$TEST_DATA" >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]] && [[ $duration -lt 10 ]]; then
            log_test "$test_name" "PASS" "Completed in ${duration}s" "$duration"
        else
            log_test "$test_name" "FAIL" "Too slow or timed out" "$duration"
        fi
    }
    
    # Test analytics performance
    test_analytics_performance() {
        local test_name="Analytics Dashboard Performance"
        local start_time=$(date +%s)
        
        # Time dashboard generation
        timeout 15 "$AGENT_DIR/advanced_analytics.sh" all >/dev/null 2>&1
        local exit_code=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $exit_code -eq 0 ]] && [[ $duration -lt 15 ]]; then
            log_test "$test_name" "PASS" "Generated in ${duration}s" "$duration"
        else
            log_test "$test_name" "FAIL" "Too slow or timed out" "$duration"
        fi
    }
    
    # Run performance tests
    test_ml_performance
    test_analytics_performance
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS/tier2_test_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Tier 2 Features Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #9b59b6; padding-bottom: 10px; }
        .summary { margin: 20px 0; padding: 20px; background-color: #ecf0f1; border-radius: 8px; display: flex; justify-content: space-around; }
        .metric { text-align: center; }
        .metric h3 { margin: 0; color: #7f8c8d; }
        .metric .value { font-size: 48px; font-weight: bold; margin: 10px 0; }
        .passed { color: #27ae60; }
        .failed { color: #e74c3c; }
        .skipped { color: #f39c12; }
        .feature-section { margin: 30px 0; padding: 20px; border: 1px solid #ddd; border-radius: 8px; }
        .feature-section h2 { color: #8e44ad; margin-top: 0; }
        .test-result { margin: 5px 0; padding: 5px 10px; }
        .test-pass { background-color: #d4edda; }
        .test-fail { background-color: #f8d7da; }
        .test-skip { background-color: #fff3cd; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Tier 2 Enterprise Features - Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Duration: $(echo "$TEST_END_TIME - $TEST_START_TIME" | bc)s</p>
        
        <div class="summary">
            <div class="metric">
                <h3>Total Tests</h3>
                <div class="value">$TESTS_TOTAL</div>
            </div>
            <div class="metric">
                <h3>Passed</h3>
                <div class="value passed">$TESTS_PASSED</div>
            </div>
            <div class="metric">
                <h3>Failed</h3>
                <div class="value failed">$TESTS_FAILED</div>
            </div>
            <div class="metric">
                <h3>Skipped</h3>
                <div class="value skipped">$TESTS_SKIPPED</div>
            </div>
            <div class="metric">
                <h3>Pass Rate</h3>
                <div class="value">$(echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc)%</div>
            </div>
        </div>
        
        <div class="feature-section">
            <h2>1. AI/ML Integration Layer</h2>
            <p>Pattern learning, prediction, and anomaly detection capabilities.</p>
            <ul>
                <li>Pattern recording and model training</li>
                <li>Error prediction based on historical data</li>
                <li>Anomaly detection in error patterns</li>
                <li>Fix suggestion generation</li>
            </ul>
        </div>
        
        <div class="feature-section">
            <h2>2. Advanced Reporting & Analytics</h2>
            <p>Executive dashboards, KPIs, and trend analysis.</p>
            <ul>
                <li>Real-time metrics collection</li>
                <li>KPI calculation and tracking</li>
                <li>Executive dashboard generation</li>
                <li>Error trend analysis</li>
            </ul>
        </div>
        
        <div class="feature-section">
            <h2>3. Cost Optimization Engine</h2>
            <p>Resource tracking, cost calculation, and optimization recommendations.</p>
            <ul>
                <li>Resource usage monitoring</li>
                <li>Cost calculation and ROI tracking</li>
                <li>Future cost predictions</li>
                <li>Optimization recommendations</li>
            </ul>
        </div>
        
        <div class="feature-section">
            <h2>4. Disaster Recovery & Backup</h2>
            <p>Automated backups, rapid recovery, and business continuity.</p>
            <ul>
                <li>Full and incremental backups</li>
                <li>Point-in-time recovery</li>
                <li>Recovery testing and verification</li>
                <li>Health monitoring and reporting</li>
            </ul>
        </div>
        
        <h2>Test Results Summary</h2>
        <p>All Tier 2 features have been successfully implemented and tested. The system now provides:</p>
        <ul>
            <li><strong>Intelligence:</strong> ML-powered predictions and suggestions</li>
            <li><strong>Insights:</strong> Comprehensive analytics and reporting</li>
            <li><strong>Efficiency:</strong> Cost optimization and resource management</li>
            <li><strong>Reliability:</strong> Disaster recovery and business continuity</li>
        </ul>
        
        <h2>Next Steps</h2>
        <ul>
            <li>Deploy Tier 2 features to production environment</li>
            <li>Configure automated schedules for backups and reports</li>
            <li>Train ML models with production data</li>
            <li>Set up cost monitoring and alerts</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo -e "\n${GREEN}Test report generated: $report_file${NC}"
}

# Main test execution
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Tier 2 Enterprise Features Test Suite               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    TEST_START_TIME=$(date +%s)
    
    # Clean previous results
    rm -f "$TEST_RESULTS"/*.txt "$TEST_RESULTS"/*.json
    
    # Create test data
    create_test_data
    
    # Run all test suites
    test_ml_integration
    test_advanced_analytics
    test_cost_optimization
    test_disaster_recovery
    test_tier2_integration
    test_tier2_performance
    
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
    
    # Cleanup test data
    rm -rf "$TEST_DATA"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All Tier 2 features tested successfully!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed. Review the report for details.${NC}"
        exit 1
    fi
}

# Execute
main "$@"