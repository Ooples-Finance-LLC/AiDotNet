#!/bin/bash
# ZeroDev - AI-Powered Development System
# From idea to implementation with zero manual coding

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDFIX_DIR="$SCRIPT_DIR/BuildFixAgents"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${PURPLE}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ZeroDev - AI-Powered Development System                   ║
║     From Idea to Implementation                               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Help message
show_help() {
    cat << EOF
${BOLD}Usage:${NC} zerodev [command] [options]

${BOLD}Commands:${NC}
  ${GREEN}new${NC} "description"     Create a new project from description
  ${GREEN}add${NC} "feature"         Add feature to existing project
  ${GREEN}fix${NC}                   Fix build errors (classic mode)
  ${GREEN}develop${NC} "idea"        Full development from idea
  ${GREEN}enhance${NC} [type]        Enhance existing code
  ${GREEN}analyze${NC}               Analyze current project
  ${GREEN}chat${NC}                  Interactive development mode
  ${GREEN}status${NC}                Show system status

${BOLD}Options:${NC}
  --help, -h            Show this help
  --verbose, -v         Verbose output
  --dry-run             Show what would be done
  --framework [name]    Specify framework
  --language [name]     Specify language

${BOLD}Examples:${NC}
  zerodev new "Create a REST API for blog management"
  zerodev add "Add user authentication with OAuth"
  zerodev fix
  zerodev develop "Build a real-time chat application"
  zerodev enhance --security

${BOLD}Interactive Mode:${NC}
  zerodev chat
  > I want to build an e-commerce platform
  > Add product search functionality
  > Deploy to AWS

EOF
}

# Detect project context
detect_context() {
    echo -e "${CYAN}Analyzing project context...${NC}"
    
    local context=""
    
    # Check for existing project files
    if [[ -f "package.json" ]]; then
        context="node"
        echo -e "${GREEN}✓ Detected Node.js project${NC}"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        context="python"
        echo -e "${GREEN}✓ Detected Python project${NC}"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        context="java"
        echo -e "${GREEN}✓ Detected Java project${NC}"
    elif [[ -f "*.csproj" ]] || [[ -f "*.sln" ]]; then
        context="dotnet"
        echo -e "${GREEN}✓ Detected .NET project${NC}"
    elif [[ -f "go.mod" ]]; then
        context="go"
        echo -e "${GREEN}✓ Detected Go project${NC}"
    elif [[ -f "Cargo.toml" ]]; then
        context="rust"
        echo -e "${GREEN}✓ Detected Rust project${NC}"
    else
        context="new"
        echo -e "${YELLOW}No existing project detected - ready to create new${NC}"
    fi
    
    echo "$context"
}

# Create new project from description
create_new_project() {
    local description="$1"
    
    echo -e "\n${BOLD}${GREEN}Creating new project...${NC}"
    echo -e "${CYAN}Description:${NC} $description"
    
    # Call project generation agent
    bash "$BUILDFIX_DIR/project_generator_agent.sh" \
        --description "$description" \
        --output "." \
        --language "${LANGUAGE:-auto}" \
        --framework "${FRAMEWORK:-auto}"
    
    echo -e "\n${GREEN}✓ Project generated successfully!${NC}"
}

# Add feature to existing project
add_feature() {
    local feature="$1"
    local context=$(detect_context)
    
    echo -e "\n${BOLD}${GREEN}Adding feature to existing project...${NC}"
    echo -e "${CYAN}Feature:${NC} $feature"
    echo -e "${CYAN}Context:${NC} $context"
    
    # Call feature implementation agent
    bash "$BUILDFIX_DIR/feature_implementation_agent.sh" \
        --feature "$feature" \
        --context "$context" \
        --integrate true
    
    echo -e "\n${GREEN}✓ Feature added successfully!${NC}"
}

# Full development from idea
develop_from_idea() {
    local idea="$1"
    
    echo -e "\n${BOLD}${GREEN}Developing from idea...${NC}"
    echo -e "${CYAN}Idea:${NC} $idea"
    
    # Multi-phase development
    echo -e "\n${YELLOW}Phase 1: Requirements Analysis${NC}"
    bash "$BUILDFIX_DIR/requirements_analyzer.sh" --idea "$idea"
    
    echo -e "\n${YELLOW}Phase 2: Architecture Design${NC}"
    bash "$BUILDFIX_DIR/architect_agent_v2.sh" design --from-idea
    
    echo -e "\n${YELLOW}Phase 3: Implementation${NC}"
    bash "$BUILDFIX_DIR/enhanced_coordinator_v2.sh" implement
    
    echo -e "\n${YELLOW}Phase 4: Testing & Validation${NC}"
    bash "$BUILDFIX_DIR/testing_agent_v2.sh" validate
    
    echo -e "\n${GREEN}✓ Development completed!${NC}"
}

# Classic fix mode
fix_errors() {
    echo -e "\n${BOLD}${YELLOW}Running classic error fix mode...${NC}"
    bash "$BUILDFIX_DIR/start_self_improving_system.sh" auto
}

# Enhance existing code
enhance_project() {
    local enhance_type="${1:-general}"
    
    echo -e "\n${BOLD}${GREEN}Enhancing project...${NC}"
    echo -e "${CYAN}Enhancement type:${NC} $enhance_type"
    
    case "$enhance_type" in
        "--security")
            bash "$BUILDFIX_DIR/security_enhancement_agent.sh" scan-and-fix
            ;;
        "--performance")
            bash "$BUILDFIX_DIR/performance_agent_v2.sh" optimize
            ;;
        "--scale")
            bash "$BUILDFIX_DIR/scalability_agent.sh" enhance
            ;;
        "--quality")
            bash "$BUILDFIX_DIR/code_quality_agent.sh" improve
            ;;
        *)
            echo -e "${YELLOW}Running general enhancements...${NC}"
            bash "$BUILDFIX_DIR/enhancement_coordinator.sh" all
            ;;
    esac
}

# Interactive chat mode
interactive_chat() {
    echo -e "\n${BOLD}${PURPLE}Interactive Development Mode${NC}"
    echo -e "${CYAN}Type your requests naturally. Type 'exit' to quit.${NC}\n"
    
    while true; do
        echo -ne "${GREEN}> ${NC}"
        read -r user_input
        
        if [[ "$user_input" == "exit" ]]; then
            echo -e "${YELLOW}Exiting interactive mode...${NC}"
            break
        fi
        
        # Process natural language input
        bash "$BUILDFIX_DIR/nlp_processor.sh" \
            --input "$user_input" \
            --mode "interactive" \
            --execute true
        
        echo
    done
}

# Analyze current project
analyze_project() {
    echo -e "\n${BOLD}${CYAN}Analyzing current project...${NC}"
    
    local context=$(detect_context)
    
    # Run comprehensive analysis
    bash "$BUILDFIX_DIR/project_analyzer.sh" \
        --context "$context" \
        --comprehensive true \
        --report true
}

# Show system status
show_status() {
    echo -e "\n${BOLD}${CYAN}ZeroDev System Status${NC}"
    
    # Check agents
    echo -e "\n${YELLOW}Agent Status:${NC}"
    bash "$BUILDFIX_DIR/enhanced_coordinator_v2.sh" status
    
    # Check capabilities
    echo -e "\n${YELLOW}Available Capabilities:${NC}"
    echo -e "  ${GREEN}✓${NC} Project Generation"
    echo -e "  ${GREEN}✓${NC} Feature Addition"
    echo -e "  ${GREEN}✓${NC} Error Fixing"
    echo -e "  ${GREEN}✓${NC} Code Enhancement"
    echo -e "  ${GREEN}✓${NC} Interactive Development"
    
    # Check integrations
    echo -e "\n${YELLOW}Integrations:${NC}"
    [[ -f "$HOME/.zerodev/config" ]] && echo -e "  ${GREEN}✓${NC} User Config" || echo -e "  ${RED}✗${NC} User Config"
    command -v git &>/dev/null && echo -e "  ${GREEN}✓${NC} Git" || echo -e "  ${RED}✗${NC} Git"
    command -v docker &>/dev/null && echo -e "  ${GREEN}✓${NC} Docker" || echo -e "  ${RED}✗${NC} Docker"
}

# Main execution
main() {
    show_banner
    
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --verbose|-v)
                export VERBOSE=true
                shift
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --framework)
                export FRAMEWORK="$2"
                shift 2
                ;;
            --language)
                export LANGUAGE="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Handle commands
    case "${1:-help}" in
        new)
            shift
            create_new_project "$*"
            ;;
        add)
            shift
            add_feature "$*"
            ;;
        fix)
            fix_errors
            ;;
        develop)
            shift
            develop_from_idea "$*"
            ;;
        enhance)
            shift
            enhance_project "$@"
            ;;
        analyze)
            analyze_project
            ;;
        chat)
            interactive_chat
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo -e "Use 'zerodev --help' for usage information"
            exit 1
            ;;
    esac
}

# Run main
main "$@"