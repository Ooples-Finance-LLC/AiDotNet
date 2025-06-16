#!/bin/bash

# Comprehensive Test Suite for Tier 4 Features
# Tests Knowledge Management, Edge Computing, and Quantum-resistant Security

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/buildfix_tier4_test_$$"
export BUILD_FIX_HOME="$TEST_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test results tracking
declare -A test_results
total_tests=0
passed_tests=0
failed_tests=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test framework functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -n "  Testing $1... "
}

pass_test() {
    echo -e "${GREEN}PASSED${NC}"
    test_results["$1"]="PASSED"
    ((passed_tests++))
}

fail_test() {
    echo -e "${RED}FAILED${NC}"
    test_results["$1"]="FAILED: $2"
    ((failed_tests++))
}

skip_test() {
    echo -e "${YELLOW}SKIPPED${NC} ($1)"
    test_results["$2"]="SKIPPED: $1"
}

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create sample project structure
    mkdir -p src tests docs .git
    
    # Create sample files
    cat > src/main.js <<'EOF'
// Sample JavaScript file
const crypto = require('crypto');

function generateKey() {
    return crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
    });
}

module.exports = { generateKey };
EOF

    cat > build.log <<'EOF'
[2024-01-15 10:00:00] Build started
[2024-01-15 10:00:05] Error: Module not found: 'typescript'
[2024-01-15 10:00:06] Attempting to fix...
[2024-01-15 10:00:10] Fixed: Installed missing module
[2024-01-15 10:00:15] Build completed successfully
EOF

    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
}

# Cleanup function
cleanup() {
    cd /
    rm -rf "$TEST_DIR"
}

# Test 1: Knowledge Management System
test_knowledge_management() {
    print_header "Testing Knowledge Management System"
    ((total_tests++))
    
    local km_script="$SCRIPT_DIR/knowledge_management_system.sh"
    
    # Test 1.1: Initialization
    print_test "Knowledge system initialization"
    if "$km_script" init >/dev/null 2>&1; then
        if [[ -d "$BUILD_FIX_HOME/knowledge" ]]; then
            pass_test "km_init"
        else
            fail_test "km_init" "Knowledge directory not created"
        fi
    else
        fail_test "km_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 1.2: Capture knowledge
    print_test "Knowledge capture"
    if echo "Test knowledge content" | "$km_script" capture "Test Entry" "build_errors" "" "test,demo" >/dev/null 2>&1; then
        pass_test "km_capture"
    else
        fail_test "km_capture" "Failed to capture knowledge"
    fi
    ((total_tests++))
    
    # Test 1.3: Record solution
    print_test "Solution recording"
    if "$km_script" solution "Build fails with OOM" "Increase memory to 4GB" "build_errors" >/dev/null 2>&1; then
        pass_test "km_solution"
    else
        fail_test "km_solution" "Failed to record solution"
    fi
    ((total_tests++))
    
    # Test 1.4: Pattern identification
    print_test "Pattern identification"
    if "$km_script" pattern "Memory Error Pattern" "OOM errors during build" "build_errors" >/dev/null 2>&1; then
        pass_test "km_pattern"
    else
        fail_test "km_pattern" "Failed to identify pattern"
    fi
    ((total_tests++))
    
    # Test 1.5: Search functionality
    print_test "Knowledge search"
    local search_results=$("$km_script" search "memory" 2>&1)
    if echo "$search_results" | grep -q "OOM\|memory"; then
        pass_test "km_search"
    else
        fail_test "km_search" "Search did not return expected results"
    fi
    ((total_tests++))
    
    # Test 1.6: Learn from history
    print_test "Learning from build history"
    if "$km_script" learn "$TEST_DIR" "build.log" >/dev/null 2>&1; then
        pass_test "km_learn"
    else
        fail_test "km_learn" "Failed to learn from history"
    fi
    ((total_tests++))
    
    # Test 1.7: Export knowledge
    print_test "Knowledge export"
    if "$km_script" export "test_export.tar.gz" >/dev/null 2>&1; then
        if [[ -f "test_export.tar.gz" ]]; then
            pass_test "km_export"
        else
            fail_test "km_export" "Export file not created"
        fi
    else
        fail_test "km_export" "Export failed"
    fi
    ((total_tests++))
    
    # Test 1.8: Generate insights
    print_test "Knowledge insights"
    if "$km_script" insights >/dev/null 2>&1; then
        pass_test "km_insights"
    else
        fail_test "km_insights" "Failed to generate insights"
    fi
    ((total_tests++))
}

# Test 2: Edge Computing Support
test_edge_computing() {
    print_header "Testing Edge Computing Support"
    ((total_tests++))
    
    local edge_script="$SCRIPT_DIR/edge_computing_support.sh"
    
    # Test 2.1: Initialization
    print_test "Edge system initialization"
    if "$edge_script" init >/dev/null 2>&1; then
        if [[ -f "$BUILD_FIX_HOME/edge/config.json" ]]; then
            pass_test "edge_init"
        else
            fail_test "edge_init" "Configuration not created"
        fi
    else
        fail_test "edge_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 2.2: Node registration
    print_test "Edge node registration"
    if "$edge_script" register "test-edge-1" "device" "192.168.1.100" >/dev/null 2>&1; then
        local node_count=$(find "$BUILD_FIX_HOME/edge/nodes" -name "profile.json" | wc -l)
        if [[ $node_count -ge 2 ]]; then  # localhost + test-edge-1
            pass_test "edge_register"
        else
            fail_test "edge_register" "Node not properly registered"
        fi
    else
        fail_test "edge_register" "Registration failed"
    fi
    ((total_tests++))
    
    # Test 2.3: Job distribution
    print_test "Edge job distribution"
    local job_output=$("$edge_script" distribute "test-build" "build" '{"script":"echo test"}' 2>&1)
    if echo "$job_output" | grep -q "Job distributed"; then
        pass_test "edge_distribute"
    else
        fail_test "edge_distribute" "Job distribution failed"
    fi
    ((total_tests++))
    
    # Test 2.4: Edge monitoring
    print_test "Edge network monitoring"
    if "$edge_script" monitor >/dev/null 2>&1; then
        pass_test "edge_monitor"
    else
        fail_test "edge_monitor" "Monitoring failed"
    fi
    ((total_tests++))
    
    # Test 2.5: Resource constraints
    print_test "Resource constraint handling"
    local config_file="$BUILD_FIX_HOME/edge/config.json"
    if [[ -f "$config_file" ]]; then
        local min_memory=$(jq -r '.resource_constraints.min_memory_mb' "$config_file")
        if [[ "$min_memory" == "512" ]]; then
            pass_test "edge_constraints"
        else
            fail_test "edge_constraints" "Invalid resource constraints"
        fi
    else
        fail_test "edge_constraints" "Config file not found"
    fi
    ((total_tests++))
    
    # Test 2.6: Offline mode
    print_test "Offline mode support"
    local offline_enabled=$(jq -r '.connectivity.offline_mode' "$config_file" 2>/dev/null)
    if [[ "$offline_enabled" == "true" ]]; then
        pass_test "edge_offline"
    else
        fail_test "edge_offline" "Offline mode not enabled"
    fi
    ((total_tests++))
}

# Test 3: Quantum-resistant Security
test_quantum_security() {
    print_header "Testing Quantum-resistant Security"
    ((total_tests++))
    
    local quantum_script="$SCRIPT_DIR/quantum_resistant_security.sh"
    
    # Test 3.1: Initialization
    print_test "Quantum security initialization"
    if "$quantum_script" init >/dev/null 2>&1; then
        if [[ -f "$BUILD_FIX_HOME/quantum/config.json" ]]; then
            pass_test "quantum_init"
        else
            fail_test "quantum_init" "Configuration not created"
        fi
    else
        fail_test "quantum_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 3.2: Key generation
    print_test "PQC key generation"
    if "$quantum_script" generate-keys all test-project >/dev/null 2>&1; then
        local key_count=$(find "$BUILD_FIX_HOME/quantum/keys" -name "*.key" | wc -l)
        if [[ $key_count -gt 0 ]]; then
            pass_test "quantum_keygen"
        else
            fail_test "quantum_keygen" "No keys generated"
        fi
    else
        fail_test "quantum_keygen" "Key generation failed"
    fi
    ((total_tests++))
    
    # Test 3.3: Signing
    print_test "Quantum-resistant signing"
    echo "test data" > test_file.txt
    if "$quantum_script" sign test_file.txt test-project >/dev/null 2>&1; then
        if [[ -f "test_file.txt.dilithium3.sig" ]]; then
            pass_test "quantum_sign"
        else
            fail_test "quantum_sign" "Signature file not created"
        fi
    else
        fail_test "quantum_sign" "Signing failed"
    fi
    ((total_tests++))
    
    # Test 3.4: Encryption
    print_test "PQC encryption"
    if "$quantum_script" encrypt test_file.txt test_encrypted.qenc >/dev/null 2>&1; then
        if [[ -f "test_encrypted.qenc" ]]; then
            pass_test "quantum_encrypt"
        else
            fail_test "quantum_encrypt" "Encrypted file not created"
        fi
    else
        fail_test "quantum_encrypt" "Encryption failed"
    fi
    ((total_tests++))
    
    # Test 3.5: Vulnerability analysis
    print_test "Quantum vulnerability analysis"
    local analysis_output=$("$quantum_script" analyze "$TEST_DIR" 2>&1)
    if echo "$analysis_output" | grep -q "vulnerabilities"; then
        pass_test "quantum_analyze"
    else
        fail_test "quantum_analyze" "Analysis did not complete"
    fi
    ((total_tests++))
    
    # Test 3.6: Hybrid mode
    print_test "Hybrid cryptography support"
    local config_file="$BUILD_FIX_HOME/quantum/config.json"
    local hybrid_mode=$(jq -r '.migration.hybrid_mode' "$config_file" 2>/dev/null)
    if [[ "$hybrid_mode" == "true" ]]; then
        pass_test "quantum_hybrid"
    else
        fail_test "quantum_hybrid" "Hybrid mode not enabled"
    fi
    ((total_tests++))
    
    # Test 3.7: Threat monitoring
    print_test "Quantum threat monitoring"
    if "$quantum_script" monitor >/dev/null 2>&1; then
        if [[ -f "$BUILD_FIX_HOME/quantum/audit/quantum_threat_status.json" ]]; then
            pass_test "quantum_monitor"
        else
            fail_test "quantum_monitor" "Threat status not recorded"
        fi
    else
        fail_test "quantum_monitor" "Monitoring failed"
    fi
    ((total_tests++))
}

# Integration tests
test_integration() {
    print_header "Integration Tests"
    
    # Test Knowledge + Edge integration
    print_test "Knowledge Management + Edge Computing"
    ((total_tests++))
    
    # Capture knowledge from edge node
    "$SCRIPT_DIR/knowledge_management_system.sh" capture \
        "Edge Node Performance" "edge_computing" \
        "Edge nodes show 30% better performance for isolated builds" \
        "edge,performance" >/dev/null 2>&1
    
    # Search for edge-related knowledge
    local edge_knowledge=$("$SCRIPT_DIR/knowledge_management_system.sh" search "edge" 2>&1)
    if echo "$edge_knowledge" | grep -q "Edge Node Performance"; then
        pass_test "km_edge_integration"
    else
        fail_test "km_edge_integration" "Edge knowledge not found"
    fi
    
    # Test Edge + Quantum integration
    print_test "Edge Computing + Quantum Security"
    ((total_tests++))
    
    # Check if edge nodes support quantum security
    local edge_config="$BUILD_FIX_HOME/edge/config.json"
    local security_enabled=$(jq -r '.security.encryption' "$edge_config" 2>/dev/null)
    if [[ "$security_enabled" == "true" ]]; then
        pass_test "edge_quantum_integration"
    else
        fail_test "edge_quantum_integration" "Security not enabled on edge"
    fi
    
    # Test Knowledge + Quantum integration
    print_test "Knowledge Management + Quantum Security"
    ((total_tests++))
    
    # Analyze quantum vulnerabilities and capture as knowledge
    "$SCRIPT_DIR/quantum_resistant_security.sh" analyze "$TEST_DIR" >/dev/null 2>&1
    "$SCRIPT_DIR/knowledge_management_system.sh" capture \
        "Quantum Vulnerabilities Found" "security" \
        "RSA usage detected - migration to PQC required" \
        "quantum,security,vulnerability" >/dev/null 2>&1
    
    local quantum_knowledge=$("$SCRIPT_DIR/knowledge_management_system.sh" search "quantum" 2>&1)
    if echo "$quantum_knowledge" | grep -q "Quantum Vulnerabilities"; then
        pass_test "km_quantum_integration"
    else
        fail_test "km_quantum_integration" "Quantum knowledge not captured"
    fi
}

# Performance tests
test_performance() {
    print_header "Performance Tests"
    
    # Test knowledge indexing performance
    print_test "Knowledge indexing performance"
    ((total_tests++))
    
    local start_time=$(date +%s%N)
    
    # Create 100 knowledge entries
    for i in {1..100}; do
        echo "Entry $i" | "$SCRIPT_DIR/knowledge_management_system.sh" capture \
            "Test Entry $i" "performance" "" "test" >/dev/null 2>&1
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [[ $duration -lt 10000 ]]; then # Should complete in under 10 seconds
        pass_test "km_performance"
        echo "    Duration: ${duration}ms for 100 entries"
    else
        fail_test "km_performance" "Too slow: ${duration}ms"
    fi
    
    # Test edge job distribution performance
    print_test "Edge job distribution performance"
    ((total_tests++))
    
    start_time=$(date +%s%N)
    
    # Distribute 10 jobs
    for i in {1..10}; do
        "$SCRIPT_DIR/edge_computing_support.sh" distribute \
            "test-job-$i" "build" '{"script":"echo test"}' >/dev/null 2>&1
    done
    
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration -lt 5000 ]]; then # Should complete in under 5 seconds
        pass_test "edge_performance"
        echo "    Duration: ${duration}ms for 10 jobs"
    else
        fail_test "edge_performance" "Too slow: ${duration}ms"
    fi
}

# Stress tests
test_stress() {
    print_header "Stress Tests"
    
    # Test knowledge system under load
    print_test "Knowledge system stress test"
    ((total_tests++))
    
    # Create many concurrent knowledge entries
    local pids=()
    for i in {1..20}; do
        (echo "Stress test $i" | "$SCRIPT_DIR/knowledge_management_system.sh" capture \
            "Stress Entry $i" "stress_test" "" "stress" >/dev/null 2>&1) &
        pids+=($!)
    done
    
    # Wait for all to complete
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        pass_test "km_stress"
    else
        fail_test "km_stress" "$failed concurrent operations failed"
    fi
    
    # Test edge system with multiple nodes
    print_test "Edge system multi-node stress"
    ((total_tests++))
    
    # Register multiple edge nodes
    for i in {1..5}; do
        "$SCRIPT_DIR/edge_computing_support.sh" register \
            "stress-node-$i" "device" "192.168.1.$((100+i))" >/dev/null 2>&1
    done
    
    # Count registered nodes
    local node_count=$(find "$BUILD_FIX_HOME/edge/nodes" -name "profile.json" | wc -l)
    if [[ $node_count -ge 6 ]]; then # localhost + 5 stress nodes
        pass_test "edge_stress"
    else
        fail_test "edge_stress" "Only $node_count nodes registered"
    fi
}

# Generate test report
generate_report() {
    echo -e "\n${BLUE}=== Test Report ===${NC}"
    echo "Total Tests: $total_tests"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    echo -e "Success Rate: $(( passed_tests * 100 / total_tests ))%\n"
    
    if [[ $failed_tests -gt 0 ]]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test_name in "${!test_results[@]}"; do
            if [[ "${test_results[$test_name]}" =~ ^FAILED ]]; then
                echo "  - $test_name: ${test_results[$test_name]}"
            fi
        done
    fi
    
    # Feature summary
    echo -e "\n${BLUE}Feature Summary:${NC}"
    echo "1. Knowledge Management System:"
    echo "   - Captures and organizes build knowledge"
    echo "   - Learns from build history"
    echo "   - Provides intelligent search and insights"
    
    echo -e "\n2. Edge Computing Support:"
    echo "   - Distributes builds to edge devices"
    echo "   - Handles resource constraints"
    echo "   - Supports offline operation"
    
    echo -e "\n3. Quantum-resistant Security:"
    echo "   - Implements post-quantum cryptography"
    echo "   - Analyzes quantum vulnerabilities"
    echo "   - Provides migration tools"
    
    # Save report
    cat > "$TEST_DIR/tier4_test_report.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_tests": $total_tests,
    "passed": $passed_tests,
    "failed": $failed_tests,
    "success_rate": $(( passed_tests * 100 / total_tests )),
    "features_tested": [
        "Knowledge Management System",
        "Edge Computing Support",
        "Quantum-resistant Security"
    ],
    "results": {
$(for test_name in "${!test_results[@]}"; do
    echo "        \"$test_name\": \"${test_results[$test_name]}\","
done | sed '$ s/,$//')
    }
}
EOF
    
    echo -e "\nDetailed report saved to: $TEST_DIR/tier4_test_report.json"
}

# Main test runner
main() {
    echo -e "${BLUE}BuildFixAgents Tier 4 Feature Test Suite${NC}"
    echo "========================================="
    
    # Set up test environment
    setup
    
    # Register cleanup
    trap cleanup EXIT
    
    # Run all test suites
    test_knowledge_management
    test_edge_computing
    test_quantum_security
    test_integration
    test_performance
    test_stress
    
    # Generate report
    generate_report
    
    # Return appropriate exit code
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi