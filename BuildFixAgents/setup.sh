#!/bin/bash

# Setup script for first-time users
# Ensures everything is ready to go

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}
╔════════════════════════════════════════════════════════════════╗
║         Multi-Agent Build Fix System - Setup Wizard            ║
╚════════════════════════════════════════════════════════════════╝${NC}
"

echo -e "${YELLOW}Setting up the Build Fix System...${NC}\n"

# 1. Check prerequisites
echo -e "${BLUE}1. Checking prerequisites...${NC}"
if command -v dotnet &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} .NET SDK found: $(dotnet --version)"
else
    echo -e "  ${YELLOW}⚠${NC}  .NET SDK not found - please install it first"
    exit 1
fi

if command -v git &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Git found: $(git --version | head -1)"
else
    echo -e "  ${YELLOW}⚠${NC}  Git not found - some features may not work"
fi

# 2. Create necessary directories
echo -e "\n${BLUE}2. Creating directories...${NC}"
mkdir -p "$AGENT_DIR"/{logs,state,backups}
echo -e "  ${GREEN}✓${NC} Created logs, state, and backups directories"

# 3. Initialize pattern learning
echo -e "\n${BLUE}3. Initializing pattern learning...${NC}"
bash "$AGENT_DIR/learn_patterns.sh" init
echo -e "  ${GREEN}✓${NC} Pattern database initialized"

# 4. Create symlink for easy access
echo -e "\n${BLUE}4. Creating easy-access command...${NC}"
if [[ ! -f "$PROJECT_DIR/fix" ]]; then
    cat > "$PROJECT_DIR/fix" << 'EOF'
#!/bin/bash
# One-line fix command - just run: ./fix
exec "$(dirname "$0")/BuildFixAgents/autofix.sh" "$@"
EOF
    chmod +x "$PROJECT_DIR/fix"
    echo -e "  ${GREEN}✓${NC} Created './fix' command in project root"
else
    echo -e "  ${GREEN}✓${NC} './fix' command already exists"
fi

# 5. Test build
echo -e "\n${BLUE}5. Testing build system...${NC}"
cd "$PROJECT_DIR"
if dotnet build > "$AGENT_DIR/logs/setup_build.txt" 2>&1; then
    echo -e "  ${GREEN}✓${NC} Build successful - no errors found!"
    echo -e "  ${CYAN}ℹ${NC}  Nothing to fix right now"
else
    ERROR_COUNT=$(grep -c 'error CS' "$AGENT_DIR/logs/setup_build.txt" || echo "0")
    echo -e "  ${YELLOW}!${NC} Found ${ERROR_COUNT} build errors"
    echo -e "  ${GREEN}✓${NC} Perfect! The system can fix these for you"
fi

# 6. Show quick start guide
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${CYAN}🚀 Quick Start Commands:${NC}\n"

echo -e "  ${YELLOW}Fix all errors:${NC}"
echo -e "    ./fix\n"

echo -e "  ${YELLOW}Watch for errors continuously:${NC}"
echo -e "    ./fix watch\n"

echo -e "  ${YELLOW}See live progress:${NC}"
echo -e "    ./BuildFixAgents/dashboard.sh\n"

echo -e "  ${YELLOW}Safe mode (with backup):${NC}"
echo -e "    ./BuildFixAgents/safe_fix.sh\n"

echo -e "  ${YELLOW}Get help:${NC}"
echo -e "    ./fix help\n"

echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "  - Quick Start: BuildFixAgents/QUICKSTART.md"
echo -e "  - Full Guide:  BuildFixAgents/README.md"
echo -e "  - What's New:  BuildFixAgents/IMPROVEMENTS.md\n"

if [[ ${ERROR_COUNT:-0} -gt 0 ]]; then
    echo -e "${YELLOW}💡 Tip:${NC} You have $ERROR_COUNT errors. Run ${CYAN}./fix${NC} now to fix them automatically!\n"
fi

echo -e "${GREEN}Happy coding! 🎉${NC}"