#!/bin/bash

# Quick Tier 1 Features Test - Simplified version for validation

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$AGENT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══ Quick Tier 1 Features Test ═══${NC}\n"

# Test 1: Multi-Language Support
echo -e "${CYAN}1. Testing Multi-Language Support${NC}"
if [[ -f "language_detector.sh" ]] && [[ -f "multi_language_fix_agent.sh" ]]; then
    # Create a simple TypeScript test file
    mkdir -p test_quick/ts
    echo '{"name": "test"}' > test_quick/ts/package.json
    echo '{}' > test_quick/ts/tsconfig.json
    
    # Test detection
    if ./language_detector.sh detect test_quick/ts 2>/dev/null | grep -q "typescript"; then
        echo -e "${GREEN}✓ Language detection works${NC}"
    else
        echo -e "${RED}✗ Language detection failed${NC}"
    fi
    
    echo -e "${GREEN}✓ Multi-language scripts exist${NC}"
else
    echo -e "${RED}✗ Multi-language scripts missing${NC}"
fi

# Test 2: Integration Hub
echo -e "\n${CYAN}2. Testing Integration Hub${NC}"
if [[ -f "integration_hub.sh" ]]; then
    # Initialize config
    ./integration_hub.sh init >/dev/null 2>&1
    
    if [[ -f "config/integrations.yml" ]]; then
        echo -e "${GREEN}✓ Integration hub initialized${NC}"
    else
        echo -e "${RED}✗ Integration hub initialization failed${NC}"
    fi
else
    echo -e "${RED}✗ Integration hub script missing${NC}"
fi

# Test 3: Compliance & Audit Framework
echo -e "\n${CYAN}3. Testing Compliance & Audit Framework${NC}"
if [[ -f "compliance_audit_framework.sh" ]]; then
    # Create audit entry
    ./compliance_audit_framework.sh audit test action "Test" >/dev/null 2>&1
    
    if find state/audit -name "*.jsonl" -mmin -1 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✓ Audit trail working${NC}"
    else
        echo -e "${RED}✗ Audit trail not working${NC}"
    fi
else
    echo -e "${RED}✗ Compliance framework script missing${NC}"
fi

# Test 4: Advanced Security Suite
echo -e "\n${CYAN}4. Testing Advanced Security Suite${NC}"
if [[ -f "advanced_security_suite.sh" ]]; then
    # Create test file with secret
    mkdir -p test_quick/security
    echo 'password = "test123"' > test_quick/security/test.py
    
    # Run scan
    ./advanced_security_suite.sh scan secrets test_quick/security >/dev/null 2>&1 || true
    
    if find state/security/reports -name "secrets_scan_*.json" -mmin -1 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✓ Security scanning works${NC}"
    else
        echo -e "${RED}✗ Security scanning failed${NC}"
    fi
else
    echo -e "${RED}✗ Security suite script missing${NC}"
fi

# Test 5: Test Suite
echo -e "\n${CYAN}5. Testing Test Suite${NC}"
if [[ -f "tier1_features_test_suite.sh" ]]; then
    echo -e "${GREEN}✓ Test suite exists${NC}"
else
    echo -e "${RED}✗ Test suite missing${NC}"
fi

# Test 6: Enterprise Launcher v2
echo -e "\n${CYAN}6. Testing Enterprise Launcher v2${NC}"
if [[ -f "enterprise_launcher_v2.sh" ]]; then
    echo -e "${GREEN}✓ Enterprise launcher v2 exists${NC}"
else
    echo -e "${RED}✗ Enterprise launcher v2 missing${NC}"
fi

# Cleanup
rm -rf test_quick

echo -e "\n${BLUE}═══ Test Complete ═══${NC}"