#!/bin/bash

# Direct test to fix CS8618 error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/home/ooples/AiDotNet"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

echo -e "${BOLD}${CYAN}=== Direct CS8618 Fix Test ===${NC}"

# Target file with CS8618 error
TARGET_FILE="/home/ooples/AiDotNet/src/Compression/Quantization/QuantizedParameter.cs"

echo -e "\n${YELLOW}Checking target file...${NC}"
if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}Target file not found!${NC}"
    exit 1
fi

# Get initial error count for this file
echo -e "\n${YELLOW}Initial CS8618 errors in file:${NC}"
initial_cs8618=$(cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep "$TARGET_FILE" | grep -c "CS8618" || true)
echo -e "CS8618 errors: ${RED}$initial_cs8618${NC}"

# Show the specific errors
echo -e "\n${YELLOW}Specific CS8618 errors:${NC}"
cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep "$TARGET_FILE" | grep "CS8618" | head -2

# Apply fix: Make properties nullable
echo -e "\n${YELLOW}Applying fix: Making properties nullable...${NC}"

# Fix ChannelScales property
sed -i 's/public IReadOnlyList<double> ChannelScales { get; }/public IReadOnlyList<double>? ChannelScales { get; }/' "$TARGET_FILE"

# Fix ChannelZeroPoints property  
sed -i 's/public IReadOnlyList<int> ChannelZeroPoints { get; }/public IReadOnlyList<int>? ChannelZeroPoints { get; }/' "$TARGET_FILE"

echo -e "✅ Applied nullable fixes"

# Check if errors are fixed
echo -e "\n${YELLOW}Checking if errors are fixed...${NC}"
new_cs8618=$(cd "$PROJECT_DIR" && dotnet build --no-restore 2>&1 | grep "$TARGET_FILE" | grep -c "CS8618" || true)
echo -e "CS8618 errors after fix: ${RED}$new_cs8618${NC}"

if [[ $new_cs8618 -lt $initial_cs8618 ]]; then
    echo -e "\n${GREEN}✅ SUCCESS! Fixed $(($initial_cs8618 - $new_cs8618)) CS8618 errors!${NC}"
    echo -e "${GREEN}BuildFixAgents CAN fix C# errors!${NC}"
    
    # Show the changes
    echo -e "\n${YELLOW}Changes made:${NC}"
    git diff "$TARGET_FILE" | grep "^[+-]" | grep -E "ChannelScales|ChannelZeroPoints" | head -10
else
    echo -e "\n${RED}❌ Errors were not fixed${NC}"
fi