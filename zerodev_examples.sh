#!/bin/bash
# ZeroDev Examples - Showcase the power of AI-driven development

set -euo pipefail

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}${PURPLE}ZeroDev Examples - See What's Possible${NC}\n"

echo -e "${BOLD}${CYAN}1. Create a Complete REST API${NC}"
echo -e "${GREEN}Command:${NC} zerodev new \"Create a REST API for a bookstore with inventory management\""
echo -e "${YELLOW}Creates:${NC}"
echo "  ✓ Express.js API with proper structure"
echo "  ✓ Book CRUD operations"
echo "  ✓ Inventory tracking"
echo "  ✓ User authentication"
echo "  ✓ API documentation"
echo "  ✓ Database models"
echo "  ✓ Docker setup"
echo ""

echo -e "${BOLD}${CYAN}2. Add Authentication to Existing Project${NC}"
echo -e "${GREEN}Command:${NC} zerodev add \"Add JWT authentication with refresh tokens\""
echo -e "${YELLOW}Implements:${NC}"
echo "  ✓ JWT token generation"
echo "  ✓ Refresh token system"
echo "  ✓ Auth middleware"
echo "  ✓ User registration/login"
echo "  ✓ Password hashing"
echo "  ✓ Protected routes"
echo ""

echo -e "${BOLD}${CYAN}3. Build Full Application${NC}"
echo -e "${GREEN}Command:${NC} zerodev develop \"Create a project management tool like Jira\""
echo -e "${YELLOW}Delivers:${NC}"
echo "  ✓ Complete project structure"
echo "  ✓ Task management system"
echo "  ✓ User roles and permissions"
echo "  ✓ Sprint planning features"
echo "  ✓ Kanban board UI"
echo "  ✓ Real-time updates"
echo "  ✓ Reporting dashboard"
echo ""

echo -e "${BOLD}${CYAN}4. Enhance Existing Code${NC}"
echo -e "${GREEN}Command:${NC} zerodev enhance --performance"
echo -e "${YELLOW}Optimizes:${NC}"
echo "  ✓ Database queries"
echo "  ✓ Caching implementation"
echo "  ✓ Code splitting"
echo "  ✓ Lazy loading"
echo "  ✓ Performance monitoring"
echo ""

echo -e "${BOLD}${CYAN}5. Interactive Development${NC}"
echo -e "${GREEN}Command:${NC} zerodev chat"
echo -e "${YELLOW}Example conversation:${NC}"
echo "  > I want to build a chat application"
echo "  > It should support multiple rooms"
echo "  > Add video calling feature"
echo "  > Deploy it to AWS"
echo ""

echo -e "${BOLD}${PURPLE}Try These Examples:${NC}"
echo -e "1. ${GREEN}cd /tmp && zerodev new \"Create a simple todo API\"${NC}"
echo -e "2. ${GREEN}zerodev fix${NC} (in any project with build errors)"
echo -e "3. ${GREEN}zerodev analyze${NC} (understand your current project)"
echo ""

echo -e "${YELLOW}Ready to start? Run:${NC} ${GREEN}zerodev --help${NC}"