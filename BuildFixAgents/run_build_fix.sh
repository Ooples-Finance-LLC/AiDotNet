#!/bin/bash

# Main Build Fix Launcher
# Single entry point for the multi-agent build error resolution system

set -euo pipefail

# Get the directory where this script is located
AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Configuration
MODE="${1:-help}"
SYSTEM="${2:-generic}"  # generic or legacy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Display help
show_help() {
    print_message "$BLUE" "
╔════════════════════════════════════════════════════════════════╗
║           Multi-Agent Build Error Resolution System            ║
╚════════════════════════════════════════════════════════════════╝"
    
    echo "
USAGE: $0 <command> [options]

COMMANDS:
    analyze     - Analyze build errors and generate agent specifications
    fix         - Run agents to fix errors (execute mode)
    simulate    - Simulate agent execution without making changes
    resume      - Resume from previous execution state
    status      - Show current build status and error count
    clean       - Clean up temporary files and locks
    help        - Show this help message

OPTIONS:
    --system <type>  - Use 'generic' (default) or 'legacy' system
    --verbose        - Enable verbose logging
    --dry-run        - Same as simulate mode

EXAMPLES:
    # Analyze current build errors
    $0 analyze

    # Fix errors using the generic system
    $0 fix

    # Simulate fixes without making changes
    $0 simulate

    # Use the legacy system
    $0 fix --system legacy

    # Check current status
    $0 status

WORKFLOW:
    1. Run 'analyze' to understand current errors
    2. Run 'simulate' to see what would be fixed
    3. Run 'fix' to actually fix the errors
    4. Run 'status' to verify results
"
}

# Change to project directory for builds
cd "$PROJECT_DIR"

# Ensure build output directory exists
mkdir -p "$AGENT_DIR/logs"
mkdir -p "$AGENT_DIR/state"

# Move log files to logs directory
setup_logs() {
    export LOG_FILE="$AGENT_DIR/logs/agent_coordination.log"
    export BUILD_OUTPUT_FILE="$AGENT_DIR/logs/build_output.txt"
    export ERROR_COUNT_FILE="$AGENT_DIR/state/build_error_count.txt"
    export COORDINATION_FILE="$AGENT_DIR/state/AGENT_COORDINATION.md"
    export ERROR_ANALYSIS_FILE="$AGENT_DIR/state/error_analysis.json"
    export AGENT_SPEC_FILE="$AGENT_DIR/state/agent_specifications.json"
}

# Run build and get error count
check_build_status() {
    print_message "$YELLOW" "Checking build status..."
    
    if dotnet build > "$AGENT_DIR/logs/build_output.txt" 2>&1; then
        print_message "$GREEN" "✓ Build successful - no errors!"
        return 0
    else
        local error_count=$(grep -c 'error CS' "$AGENT_DIR/logs/build_output.txt" || echo "0")
        local unique_errors=$(grep -oE 'error CS[0-9]{4}' "$AGENT_DIR/logs/build_output.txt" | sort -u | wc -l)
        
        print_message "$RED" "✗ Build failed"
        print_message "$YELLOW" "  Total error instances: $error_count"
        print_message "$YELLOW" "  Unique error types: $unique_errors"
        
        return 1
    fi
}

# Analyze errors
run_analysis() {
    print_message "$BLUE" "═══ Running Error Analysis ═══"
    
    setup_logs
    
    if [[ "$SYSTEM" == "generic" ]]; then
        bash "$AGENT_DIR/generic_build_analyzer.sh" main
    else
        bash "$AGENT_DIR/build_checker_agent.sh" main
    fi
    
    if [[ -f "$AGENT_DIR/state/error_analysis.json" ]]; then
        print_message "$GREEN" "✓ Analysis complete"
        
        # Show summary
        echo ""
        print_message "$BLUE" "Error Categories Found:"
        grep -A2 '"description"' "$AGENT_DIR/state/error_analysis.json" | grep -B1 '"count"' | \
            while IFS= read -r line; do
                if [[ "$line" =~ \"(.+)\":\ \{ ]]; then
                    category="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ \"count\":\ ([0-9]+) ]]; then
                    count="${BASH_REMATCH[1]}"
                    printf "  %-30s %d errors\n" "${category//_/ }:" "$count"
                fi
            done
    fi
}

# Run fix process
run_fix() {
    local mode="${1:-execute}"
    
    print_message "$BLUE" "═══ Running Build Fix ($mode mode) ═══"
    
    setup_logs
    
    # First analyze if needed
    if [[ ! -f "$AGENT_DIR/state/agent_specifications.json" ]]; then
        print_message "$YELLOW" "No agent specifications found - running analysis first..."
        run_analysis
    fi
    
    # Run the coordinator
    if [[ "$SYSTEM" == "generic" ]]; then
        bash "$AGENT_DIR/generic_agent_coordinator.sh" "$mode"
    else
        bash "$AGENT_DIR/multi_agent_coordinator.sh" "$mode"
    fi
}

# Show status
show_status() {
    print_message "$BLUE" "═══ Build Status ═══"
    
    check_build_status
    
    # Show recent agent activity
    if [[ -f "$AGENT_DIR/logs/agent_coordination.log" ]]; then
        echo ""
        print_message "$BLUE" "Recent Agent Activity:"
        tail -20 "$AGENT_DIR/logs/agent_coordination.log" | grep -E "(SUCCESS|ERROR|COMPLETE)" || true
    fi
    
    # Show current assignments
    if [[ -f "$AGENT_DIR/state/AGENT_COORDINATION.md" ]]; then
        echo ""
        print_message "$BLUE" "Current Assignments:"
        grep -A5 "CURRENT_ASSIGNMENTS:" "$AGENT_DIR/state/AGENT_COORDINATION.md" 2>/dev/null || echo "  No active assignments"
    fi
}

# Clean up files
clean_files() {
    print_message "$YELLOW" "Cleaning up temporary files..."
    
    # Remove lock files
    rm -f "$AGENT_DIR"/.lock_*
    rm -f "$AGENT_DIR"/.pid_*
    
    # Archive logs
    if [[ -d "$AGENT_DIR/logs" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        mkdir -p "$AGENT_DIR/logs/archive"
        
        if [[ -f "$AGENT_DIR/logs/agent_coordination.log" ]]; then
            mv "$AGENT_DIR/logs/agent_coordination.log" "$AGENT_DIR/logs/archive/agent_coordination_${timestamp}.log"
        fi
    fi
    
    print_message "$GREEN" "✓ Cleanup complete"
}

# Main command dispatcher
case "$MODE" in
    "analyze")
        run_analysis
        ;;
    "fix")
        run_fix "execute"
        ;;
    "simulate")
        run_fix "simulate"
        ;;
    "resume")
        run_fix "resume"
        ;;
    "status")
        show_status
        ;;
    "clean")
        clean_files
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        print_message "$RED" "Unknown command: $MODE"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac