#!/bin/bash

# Simple Test Runner for Tier 3 Features
# Tests each feature with basic functionality

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test directory
TEST_DIR="/tmp/tier3_simple_test_$$"
export BUILD_FIX_HOME="$TEST_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create test environment
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Cleanup on exit
cleanup() {
    cd /
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}=== Testing Tier 3 Features ===${NC}\n"

# Test 1: Advanced Caching System
echo -e "${BLUE}1. Advanced Caching System${NC}"
echo -n "   Initializing... "
if "$SCRIPT_DIR/advanced_caching_system.sh" init >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Setting cache value... "
if "$SCRIPT_DIR/advanced_caching_system.sh" set "test_key" "test_value" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Getting cache value... "
value=$("$SCRIPT_DIR/advanced_caching_system.sh" get "test_key" 2>/dev/null || echo "")
if [[ "$value" == "test_value" ]]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (got: $value)${NC}"
fi

echo -n "   Cache stats... "
if "$SCRIPT_DIR/advanced_caching_system.sh" stats >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test 2: Enterprise Orchestration
echo -e "\n${BLUE}2. Enterprise Orchestration Platform${NC}"
echo -n "   Initializing... "
if "$SCRIPT_DIR/enterprise_orchestration.sh" init >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Creating test project... "
mkdir -p test_project
echo '{"name": "test"}' > test_project/package.json
echo -e "${GREEN}✓${NC}"

echo -n "   Registering project... "
if "$SCRIPT_DIR/enterprise_orchestration.sh" register-project "test-proj" "$TEST_DIR/test_project" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Creating workflow... "
workflow_output=$("$SCRIPT_DIR/enterprise_orchestration.sh" create-workflow "test-workflow" 2>&1 || echo "FAILED")
if [[ "$workflow_output" != "FAILED" ]] && [[ "$workflow_output" == *"workflow_"* ]]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test 3: Container & Kubernetes Support
echo -e "\n${BLUE}3. Container & Kubernetes Support${NC}"

echo -n "   Creating sample Node.js project... "
mkdir -p k8s_test
cat > k8s_test/package.json <<EOF
{
  "name": "test-app",
  "version": "1.0.0",
  "main": "index.js"
}
EOF
cat > k8s_test/index.js <<EOF
console.log('Hello World');
EOF
echo -e "${GREEN}✓${NC}"

echo -n "   Generating Dockerfile... "
if "$SCRIPT_DIR/container_kubernetes_support.sh" generate-dockerfile "$TEST_DIR/k8s_test" >/dev/null 2>&1; then
    if [[ -f "$TEST_DIR/k8s_test/Dockerfile" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (file not created)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Generating K8s manifests... "
if "$SCRIPT_DIR/container_kubernetes_support.sh" generate-k8s-manifests "test-app" "$TEST_DIR/k8s_test" >/dev/null 2>&1; then
    if [[ -d "$TEST_DIR/k8s_test/k8s" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (directory not created)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Generating Helm chart... "
if "$SCRIPT_DIR/container_kubernetes_support.sh" generate-helm-chart "test-app" "$TEST_DIR/k8s_test" >/dev/null 2>&1; then
    if [[ -d "$TEST_DIR/k8s_test/helm" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (directory not created)${NC}"
    fi
else
    echo -e "${RED}✗${NC}"
fi

# Test 4: Real-time Collaboration
echo -e "\n${BLUE}4. Real-time Collaboration Tools${NC}"
echo -n "   Initializing... "
if "$SCRIPT_DIR/realtime_collaboration.sh" init >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "   Creating session... "
session_output=$("$SCRIPT_DIR/realtime_collaboration.sh" create-session "Test Session" 2>/dev/null || echo "FAILED")
if [[ "$session_output" != "FAILED" ]] && [[ "$session_output" == *"session_"* ]]; then
    echo -e "${GREEN}✓${NC}"
    session_id=$(echo "$session_output" | tail -1)
else
    echo -e "${RED}✗${NC}"
    session_id=""
fi

if [[ -n "$session_id" ]]; then
    echo -n "   Sharing code... "
    echo "test code" > test_file.js
    if "$SCRIPT_DIR/realtime_collaboration.sh" share-code "$session_id" "test_file.js" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
fi

echo -n "   Listing sessions... "
if "$SCRIPT_DIR/realtime_collaboration.sh" list >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo "All basic functionality tests completed."
echo "Check the output above for any failures (✗)."
echo -e "\n${GREEN}Note:${NC} Some features may show as skipped if dependencies are missing."