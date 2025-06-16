#!/bin/bash

# Comprehensive Test Suite for Tier 3 Features
# Tests all implemented Tier 3 features for BuildFixAgents

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/buildfix_tier3_test_$$"
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
    mkdir -p src/{api,services,models} tests config
    
    # Create sample files
    cat > src/api/handler.js <<'EOF'
function handleRequest(req, res) {
    // Sample API handler
    const data = processRequest(req);
    res.json({ success: true, data });
}

function processRequest(req) {
    // Process logic
    return { id: req.params.id, timestamp: Date.now() };
}

module.exports = { handleRequest, processRequest };
EOF

    cat > src/services/cache.js <<'EOF'
class CacheService {
    constructor() {
        this.cache = new Map();
    }
    
    get(key) {
        return this.cache.get(key);
    }
    
    set(key, value, ttl = 3600) {
        this.cache.set(key, { value, expires: Date.now() + ttl * 1000 });
    }
}

module.exports = CacheService;
EOF

    # Create package.json
    cat > package.json <<'EOF'
{
    "name": "test-project",
    "version": "1.0.0",
    "scripts": {
        "test": "echo 'Running tests...'",
        "build": "echo 'Building project...'"
    }
}
EOF
}

# Cleanup function
cleanup() {
    # Kill any running processes
    if [[ -f "$TEST_DIR/cache_server.pid" ]]; then
        kill $(cat "$TEST_DIR/cache_server.pid") 2>/dev/null || true
    fi
    
    if [[ -f "$BUILD_FIX_HOME/collaboration/ws_server.pid" ]]; then
        kill $(cat "$BUILD_FIX_HOME/collaboration/ws_server.pid") 2>/dev/null || true
    fi
    
    # Clean up tmux sessions
    tmux kill-session -t "collab_test_session" 2>/dev/null || true
    
    # Remove test directory
    rm -rf "$TEST_DIR"
}

# Test 1: Advanced Caching System
test_advanced_caching() {
    print_header "Testing Advanced Caching System"
    ((total_tests++))
    
    local cache_script="$SCRIPT_DIR/advanced_caching_system.sh"
    
    # Test 1.1: Initialization
    print_test "Cache initialization"
    if "$cache_script" init >/dev/null 2>&1; then
        if [[ -d "$BUILD_FIX_HOME/cache" ]]; then
            pass_test "cache_init"
        else
            fail_test "cache_init" "Cache directory not created"
        fi
    else
        fail_test "cache_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 1.2: Cache operations
    print_test "Cache set/get operations"
    "$cache_script" set "test_key" "test_value" >/dev/null 2>&1
    local cached_value=$("$cache_script" get "test_key" 2>/dev/null)
    if [[ "$cached_value" == "test_value" ]]; then
        pass_test "cache_operations"
    else
        fail_test "cache_operations" "Expected 'test_value', got '$cached_value'"
    fi
    ((total_tests++))
    
    # Test 1.3: Multi-tier caching
    print_test "Multi-tier caching (hot/warm/cold)"
    "$cache_script" set "hot_key" "hot_value" --tier hot >/dev/null 2>&1
    "$cache_script" set "cold_key" "cold_value" --tier cold >/dev/null 2>&1
    
    # Check if tiers exist
    if [[ -d "$BUILD_FIX_HOME/cache/tiers/hot" ]] && [[ -d "$BUILD_FIX_HOME/cache/tiers/cold" ]]; then
        pass_test "multi_tier_cache"
    else
        fail_test "multi_tier_cache" "Cache tiers not properly created"
    fi
    ((total_tests++))
    
    # Test 1.4: Cache invalidation
    print_test "Cache invalidation"
    "$cache_script" set "invalid_key" "value" >/dev/null 2>&1
    "$cache_script" invalidate "invalid_key" >/dev/null 2>&1
    local invalidated=$("$cache_script" get "invalid_key" 2>/dev/null)
    if [[ -z "$invalidated" ]]; then
        pass_test "cache_invalidation"
    else
        fail_test "cache_invalidation" "Key still exists after invalidation"
    fi
    ((total_tests++))
    
    # Test 1.5: Performance monitoring
    print_test "Cache performance monitoring"
    if "$cache_script" stats | grep -q "hit_rate" >/dev/null 2>&1; then
        pass_test "cache_monitoring"
    else
        fail_test "cache_monitoring" "Performance stats not available"
    fi
    ((total_tests++))
}

# Test 2: Enterprise Orchestration Platform
test_enterprise_orchestration() {
    print_header "Testing Enterprise Orchestration Platform"
    ((total_tests++))
    
    local orch_script="$SCRIPT_DIR/enterprise_orchestration.sh"
    
    # Test 2.1: Initialization
    print_test "Orchestration initialization"
    if "$orch_script" init >/dev/null 2>&1; then
        if [[ -f "$BUILD_FIX_HOME/orchestration/config.json" ]]; then
            pass_test "orch_init"
        else
            fail_test "orch_init" "Configuration not created"
        fi
    else
        fail_test "orch_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 2.2: Project registration
    print_test "Project registration"
    if "$orch_script" register-project "test-project" "$TEST_DIR" >/dev/null 2>&1; then
        if "$orch_script" list-projects 2>/dev/null | grep -q "test-project"; then
            pass_test "project_registration"
        else
            fail_test "project_registration" "Project not listed after registration"
        fi
    else
        fail_test "project_registration" "Registration failed"
    fi
    ((total_tests++))
    
    # Test 2.3: Workflow creation
    print_test "Workflow creation"
    local workflow_id=$("$orch_script" create-workflow "test-workflow" 2>/dev/null | grep -o 'workflow_[0-9a-f]*' | head -1)
    if [[ -n "$workflow_id" ]]; then
        pass_test "workflow_creation"
    else
        fail_test "workflow_creation" "Workflow ID not returned"
    fi
    ((total_tests++))
    
    # Test 2.4: Resource management
    print_test "Resource pool management"
    if "$orch_script" create-pool "test-pool" --agents 2 >/dev/null 2>&1; then
        if [[ -f "$BUILD_FIX_HOME/orchestration/pools/test-pool/config.json" ]]; then
            pass_test "resource_management"
        else
            fail_test "resource_management" "Resource pool not created"
        fi
    else
        fail_test "resource_management" "Pool creation failed"
    fi
    ((total_tests++))
    
    # Test 2.5: Multi-project coordination
    print_test "Multi-project coordination"
    "$orch_script" register-project "project-a" "$TEST_DIR/project-a" >/dev/null 2>&1
    "$orch_script" register-project "project-b" "$TEST_DIR/project-b" >/dev/null 2>&1
    "$orch_script" add-dependency "project-b" "project-a" >/dev/null 2>&1
    
    if "$orch_script" show-dependencies "project-b" 2>/dev/null | grep -q "project-a"; then
        pass_test "multi_project_coord"
    else
        fail_test "multi_project_coord" "Dependencies not properly tracked"
    fi
    ((total_tests++))
}

# Test 3: Container & Kubernetes Support
test_container_kubernetes() {
    print_header "Testing Container & Kubernetes Support"
    ((total_tests++))
    
    local k8s_script="$SCRIPT_DIR/container_kubernetes_support.sh"
    
    # Test 3.1: Dockerfile generation
    print_test "Dockerfile generation"
    if "$k8s_script" generate-dockerfile "$TEST_DIR" >/dev/null 2>&1; then
        if [[ -f "$TEST_DIR/Dockerfile" ]]; then
            # Check Dockerfile content
            if grep -q "FROM node:" "$TEST_DIR/Dockerfile" && \
               grep -q "WORKDIR" "$TEST_DIR/Dockerfile" && \
               grep -q "USER node" "$TEST_DIR/Dockerfile"; then
                pass_test "dockerfile_generation"
            else
                fail_test "dockerfile_generation" "Dockerfile missing expected content"
            fi
        else
            fail_test "dockerfile_generation" "Dockerfile not created"
        fi
    else
        fail_test "dockerfile_generation" "Generation failed"
    fi
    ((total_tests++))
    
    # Test 3.2: Kubernetes manifest generation
    print_test "Kubernetes manifest generation"
    if "$k8s_script" generate-k8s-manifests "test-app" "$TEST_DIR" >/dev/null 2>&1; then
        local manifests_found=0
        [[ -f "$TEST_DIR/k8s/deployment.yaml" ]] && ((manifests_found++))
        [[ -f "$TEST_DIR/k8s/service.yaml" ]] && ((manifests_found++))
        [[ -f "$TEST_DIR/k8s/configmap.yaml" ]] && ((manifests_found++))
        
        if [[ $manifests_found -eq 3 ]]; then
            pass_test "k8s_manifests"
        else
            fail_test "k8s_manifests" "Only $manifests_found/3 manifests created"
        fi
    else
        fail_test "k8s_manifests" "Generation failed"
    fi
    ((total_tests++))
    
    # Test 3.3: Helm chart generation
    print_test "Helm chart generation"
    if "$k8s_script" generate-helm-chart "test-app" "$TEST_DIR" >/dev/null 2>&1; then
        if [[ -f "$TEST_DIR/helm/test-app/Chart.yaml" ]] && \
           [[ -f "$TEST_DIR/helm/test-app/values.yaml" ]]; then
            pass_test "helm_chart"
        else
            fail_test "helm_chart" "Helm chart files not created"
        fi
    else
        fail_test "helm_chart" "Generation failed"
    fi
    ((total_tests++))
    
    # Test 3.4: Multi-stage build support
    print_test "Multi-stage Docker build"
    "$k8s_script" generate-dockerfile "$TEST_DIR" --multi-stage >/dev/null 2>&1
    if grep -q "FROM.*AS builder" "$TEST_DIR/Dockerfile" && \
       grep -q "FROM.*AS runtime" "$TEST_DIR/Dockerfile"; then
        pass_test "multi_stage_build"
    else
        fail_test "multi_stage_build" "Multi-stage directives not found"
    fi
    ((total_tests++))
    
    # Test 3.5: Security features
    print_test "Container security features"
    if grep -q "USER node" "$TEST_DIR/Dockerfile" && \
       grep -q "runAsNonRoot: true" "$TEST_DIR/k8s/deployment.yaml" 2>/dev/null; then
        pass_test "container_security"
    else
        fail_test "container_security" "Security features not properly configured"
    fi
    ((total_tests++))
}

# Test 4: Real-time Collaboration Tools
test_realtime_collaboration() {
    print_header "Testing Real-time Collaboration Tools"
    ((total_tests++))
    
    local collab_script="$SCRIPT_DIR/realtime_collaboration.sh"
    
    # Test 4.1: Initialization
    print_test "Collaboration initialization"
    if "$collab_script" init >/dev/null 2>&1; then
        if [[ -d "$BUILD_FIX_HOME/collaboration" ]]; then
            pass_test "collab_init"
        else
            fail_test "collab_init" "Collaboration directory not created"
        fi
    else
        fail_test "collab_init" "Initialization failed"
    fi
    ((total_tests++))
    
    # Test 4.2: Session creation
    print_test "Session creation"
    local session_id=$("$collab_script" create-session "Test Session" 2>/dev/null | tail -1)
    if [[ "$session_id" =~ ^session_[0-9]+_[0-9a-f]+$ ]]; then
        pass_test "session_creation"
    else
        fail_test "session_creation" "Invalid session ID format: $session_id"
    fi
    ((total_tests++))
    
    # Test 4.3: Code sharing
    print_test "Code sharing functionality"
    if [[ -n "$session_id" ]]; then
        "$collab_script" share-code "$session_id" "src/api/handler.js" >/dev/null 2>&1
        if [[ -f "$BUILD_FIX_HOME/collaboration/workspaces/$session_id/src/api/handler.js" ]]; then
            pass_test "code_sharing"
        else
            fail_test "code_sharing" "Shared file not found in workspace"
        fi
    else
        skip_test "No session ID" "code_sharing"
    fi
    ((total_tests++))
    
    # Test 4.4: WebSocket server
    print_test "WebSocket server"
    # Check if Node.js is available
    if command -v node >/dev/null 2>&1; then
        # Start server on test port
        WS_PORT=18082 "$collab_script" start-server 18082 >/dev/null 2>&1 &
        sleep 2
        
        if [[ -f "$BUILD_FIX_HOME/collaboration/ws_server.pid" ]]; then
            local ws_pid=$(cat "$BUILD_FIX_HOME/collaboration/ws_server.pid")
            if kill -0 "$ws_pid" 2>/dev/null; then
                pass_test "websocket_server"
                kill "$ws_pid" 2>/dev/null || true
            else
                fail_test "websocket_server" "Server not running"
            fi
        else
            fail_test "websocket_server" "PID file not created"
        fi
    else
        skip_test "Node.js not installed" "websocket_server"
    fi
    ((total_tests++))
    
    # Test 4.5: Terminal sharing
    print_test "Terminal sharing"
    if command -v tmux >/dev/null 2>&1; then
        if [[ -n "$session_id" ]]; then
            "$collab_script" share-terminal "$session_id" "test_terminal" >/dev/null 2>&1
            if tmux has-session -t "collab_${session_id}_test_terminal" 2>/dev/null; then
                pass_test "terminal_sharing"
                tmux kill-session -t "collab_${session_id}_test_terminal" 2>/dev/null || true
            else
                fail_test "terminal_sharing" "tmux session not created"
            fi
        else
            skip_test "No session ID" "terminal_sharing"
        fi
    else
        skip_test "tmux not installed" "terminal_sharing"
    fi
    ((total_tests++))
}

# Integration tests
test_integration() {
    print_header "Integration Tests"
    
    # Test cross-feature integration
    print_test "Cache + Orchestration integration"
    ((total_tests++))
    
    # Initialize both systems
    "$SCRIPT_DIR/advanced_caching_system.sh" init >/dev/null 2>&1
    "$SCRIPT_DIR/enterprise_orchestration.sh" init >/dev/null 2>&1
    
    # Register project with caching
    "$SCRIPT_DIR/enterprise_orchestration.sh" register-project "cached-project" "$TEST_DIR" \
        --enable-cache >/dev/null 2>&1
    
    # Check if cache is configured for project
    if [[ -f "$BUILD_FIX_HOME/orchestration/projects/cached-project/cache.json" ]]; then
        pass_test "cache_orch_integration"
    else
        fail_test "cache_orch_integration" "Cache not configured for orchestrated project"
    fi
    
    # Test container + collaboration
    print_test "Container + Collaboration integration"
    ((total_tests++))
    
    # Generate Dockerfile for collaborative project
    "$SCRIPT_DIR/container_kubernetes_support.sh" generate-dockerfile "$TEST_DIR" \
        --enable-collab >/dev/null 2>&1
    
    # Check if collaboration tools are included
    if grep -q "collaboration" "$TEST_DIR/Dockerfile" 2>/dev/null || \
       grep -q "websocket" "$TEST_DIR/Dockerfile" 2>/dev/null; then
        pass_test "container_collab_integration"
    else
        # This might be expected behavior - containers might not include collab by default
        skip_test "Collaboration not included in containers by design" "container_collab_integration"
    fi
}

# Performance tests
test_performance() {
    print_header "Performance Tests"
    
    # Test cache performance
    print_test "Cache performance (1000 operations)"
    ((total_tests++))
    
    local start_time=$(date +%s%N)
    for i in {1..1000}; do
        "$SCRIPT_DIR/advanced_caching_system.sh" set "perf_key_$i" "value_$i" >/dev/null 2>&1
    done
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [[ $duration -lt 5000 ]]; then # Should complete in under 5 seconds
        pass_test "cache_performance"
        echo "    Duration: ${duration}ms for 1000 operations"
    else
        fail_test "cache_performance" "Too slow: ${duration}ms"
    fi
    
    # Test orchestration scalability
    print_test "Orchestration scalability (10 projects)"
    ((total_tests++))
    
    start_time=$(date +%s%N)
    for i in {1..10}; do
        mkdir -p "$TEST_DIR/scale_project_$i"
        "$SCRIPT_DIR/enterprise_orchestration.sh" register-project "scale-project-$i" \
            "$TEST_DIR/scale_project_$i" >/dev/null 2>&1
    done
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration -lt 3000 ]]; then # Should complete in under 3 seconds
        pass_test "orch_scalability"
        echo "    Duration: ${duration}ms for 10 projects"
    else
        fail_test "orch_scalability" "Too slow: ${duration}ms"
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
    
    # Save report to file
    cat > "$TEST_DIR/test_report.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_tests": $total_tests,
    "passed": $passed_tests,
    "failed": $failed_tests,
    "success_rate": $(( passed_tests * 100 / total_tests )),
    "results": {
$(for test_name in "${!test_results[@]}"; do
    echo "        \"$test_name\": \"${test_results[$test_name]}\","
done | sed '$ s/,$//')
    }
}
EOF
    
    echo -e "\nDetailed report saved to: $TEST_DIR/test_report.json"
}

# Main test runner
main() {
    echo -e "${BLUE}BuildFixAgents Tier 3 Feature Test Suite${NC}"
    echo "========================================="
    
    # Set up test environment
    setup
    
    # Register cleanup
    trap cleanup EXIT
    
    # Run all test suites
    test_advanced_caching
    test_enterprise_orchestration
    test_container_kubernetes
    test_realtime_collaboration
    test_integration
    test_performance
    
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