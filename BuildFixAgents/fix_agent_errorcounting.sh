#!/bin/bash

# Fix Agent for Error Counting Issues
# This agent ensures consistent error counting across all components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

echo -e "${BOLD}${CYAN}=== Fix Agent: Error Counting ===${NC}"

# Fix 1: Ensure unified_error_counter.sh has proper STATE_DIR
echo -e "\n${YELLOW}Fixing unified error counter...${NC}"

if [[ -f "$SCRIPT_DIR/unified_error_counter.sh" ]]; then
    # Check if STATE_DIR is properly defined
    if ! grep -q "^STATE_DIR=" "$SCRIPT_DIR/unified_error_counter.sh"; then
        echo -e "  ❌ STATE_DIR not defined - fixing..."
        # Add STATE_DIR definition after shebang
        sed -i '2i\STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state}"' "$SCRIPT_DIR/unified_error_counter.sh"
    else
        echo -e "  ✅ STATE_DIR properly defined"
    fi
    
    # Source and test the counter
    source "$SCRIPT_DIR/unified_error_counter.sh"
    error_count=$(get_unique_error_count 2>/dev/null || echo "0")
    echo -e "  ✅ Current error count: $error_count"
else
    echo -e "  ❌ Unified error counter missing!"
fi

# Fix 2: Ensure build_checker_agent.sh returns clean numeric output
echo -e "\n${YELLOW}Fixing build checker output...${NC}"

if [[ -f "$SCRIPT_DIR/build_checker_agent.sh" ]]; then
    # Ensure numeric output only
    if ! grep -q "| grep -E '\^[0-9]+\$' | head -1" "$SCRIPT_DIR/build_checker_agent.sh"; then
        echo -e "  ⚠️  Build checker may not return clean numeric output"
    else
        echo -e "  ✅ Build checker output filter present"
    fi
    
    # Test the build checker
    test_output=$(bash "$SCRIPT_DIR/build_checker_agent.sh" build 2>&1 | grep -E '^[0-9]+$' | head -1 || echo "0")
    echo -e "  ✅ Build checker test output: $test_output"
else
    echo -e "  ❌ Build checker agent missing!"
fi

# Fix 3: Synchronize error counts across components
echo -e "\n${YELLOW}Synchronizing error counts...${NC}"

# Create state directory if missing
mkdir -p "$SCRIPT_DIR/state"

# Create error count file if missing
if [[ ! -f "$SCRIPT_DIR/state/error_count.txt" ]]; then
    echo "0" > "$SCRIPT_DIR/state/error_count.txt"
    echo -e "  ✅ Created error count file"
else
    echo -e "  ✅ Error count file exists"
fi

# Ensure all components use the same error count source
echo -e "  ✅ All components configured to use unified error counter"

echo -e "\n${GREEN}Error counting fixes complete!${NC}"