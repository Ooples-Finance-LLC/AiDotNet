#!/bin/bash

# Real-time Dashboard for Multi-Agent Build Fix System
# Shows live progress, agent status, and error breakdown

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REFRESH_RATE="${1:-2}"  # seconds

# Box drawing characters
BOX_H="═"
BOX_V="║"
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_T="╦"
BOX_B="╩"
BOX_L="╠"
BOX_R="╣"
BOX_X="╬"

# Get terminal dimensions
update_dimensions() {
    TERM_WIDTH=$(tput cols)
    TERM_HEIGHT=$(tput lines)
}

# Clear screen and reset cursor
clear_dashboard() {
    clear
    tput cup 0 0
}

# Draw a box
draw_box() {
    local title="$1"
    local x=$2
    local y=$3
    local width=$4
    local height=$5
    
    # Top border
    tput cup $y $x
    echo -ne "${CYAN}${BOX_TL}"
    for ((i=1; i<width-1; i++)); do echo -ne "${BOX_H}"; done
    echo -ne "${BOX_TR}${NC}"
    
    # Title
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local title_pos=$(((width - title_len - 2) / 2))
        tput cup $y $((x + title_pos))
        echo -ne "${CYAN}${BOX_R}${NC}${BOLD}${WHITE} $title ${NC}${CYAN}${BOX_L}${NC}"
    fi
    
    # Sides
    for ((i=1; i<height-1; i++)); do
        tput cup $((y + i)) $x
        echo -ne "${CYAN}${BOX_V}${NC}"
        tput cup $((y + i)) $((x + width - 1))
        echo -ne "${CYAN}${BOX_V}${NC}"
    done
    
    # Bottom border
    tput cup $((y + height - 1)) $x
    echo -ne "${CYAN}${BOX_BL}"
    for ((i=1; i<width-1; i++)); do echo -ne "${BOX_H}"; done
    echo -ne "${BOX_BR}${NC}"
}

# Get current statistics
get_stats() {
    # Error count
    if [[ -f "$AGENT_DIR/logs/build_output.txt" ]]; then
        TOTAL_ERRORS=$(grep -c 'error CS' "$AGENT_DIR/logs/build_output.txt" 2>/dev/null || echo "0")
        UNIQUE_ERRORS=$(grep -oE 'error CS[0-9]{4}' "$AGENT_DIR/logs/build_output.txt" 2>/dev/null | sort -u | wc -l || echo "0")
    else
        TOTAL_ERRORS=0
        UNIQUE_ERRORS=0
    fi
    
    # Active agents
    ACTIVE_AGENTS=$(pgrep -f "generic_error_agent.sh" | wc -l || echo "0")
    
    # Files being processed
    LOCKED_FILES=$(ls "$AGENT_DIR"/.lock_* 2>/dev/null | wc -l || echo "0")
    
    # Progress from state
    if [[ -f "$AGENT_DIR/state/.autofix_state" ]]; then
        source "$AGENT_DIR/state/.autofix_state"
        FIXED_COUNT="${TOTAL_FIXED:-0}"
        LAST_RUN="${LAST_RUN:-Never}"
    else
        FIXED_COUNT=0
        LAST_RUN="Never"
    fi
}

# Draw header
draw_header() {
    local header_text="Multi-Agent Build Fix Dashboard"
    local header_width=${#header_text}
    local header_x=$(((TERM_WIDTH - header_width) / 2))
    
    tput cup 1 $header_x
    echo -ne "${BOLD}${CYAN}$header_text${NC}"
    
    tput cup 2 0
    echo -ne "${GRAY}"
    for ((i=0; i<TERM_WIDTH; i++)); do echo -ne "─"; done
    echo -ne "${NC}"
}

# Draw status panel
draw_status_panel() {
    draw_box "System Status" 2 4 40 10
    
    local y=6
    tput cup $y 4
    echo -ne "Status: "
    if [[ $ACTIVE_AGENTS -gt 0 ]]; then
        echo -ne "${GREEN}${BOLD}ACTIVE${NC}"
    else
        echo -ne "${YELLOW}${BOLD}IDLE${NC}"
    fi
    
    tput cup $((y + 1)) 4
    echo -ne "Active Agents: ${BOLD}${GREEN}$ACTIVE_AGENTS${NC}"
    
    tput cup $((y + 2)) 4
    echo -ne "Files Processing: ${BOLD}${YELLOW}$LOCKED_FILES${NC}"
    
    tput cup $((y + 3)) 4
    echo -ne "Last Run: ${GRAY}$LAST_RUN${NC}"
}

# Draw error panel
draw_error_panel() {
    draw_box "Error Summary" 44 4 40 10
    
    local y=6
    tput cup $y 46
    echo -ne "Total Errors: ${BOLD}"
    if [[ $TOTAL_ERRORS -eq 0 ]]; then
        echo -ne "${GREEN}0${NC} ✓"
    else
        echo -ne "${RED}$TOTAL_ERRORS${NC}"
    fi
    
    tput cup $((y + 1)) 46
    echo -ne "Unique Types: ${BOLD}${YELLOW}$UNIQUE_ERRORS${NC}"
    
    tput cup $((y + 2)) 46
    echo -ne "Fixed So Far: ${BOLD}${GREEN}$FIXED_COUNT${NC}"
    
    # Progress bar
    if [[ $TOTAL_ERRORS -gt 0 ]] || [[ $FIXED_COUNT -gt 0 ]]; then
        local total=$((TOTAL_ERRORS + FIXED_COUNT))
        local percent=$((FIXED_COUNT * 100 / total))
        local bar_width=30
        local filled=$((bar_width * FIXED_COUNT / total))
        
        tput cup $((y + 4)) 46
        echo -ne "Progress: "
        echo -ne "${GREEN}"
        for ((i=0; i<filled; i++)); do echo -ne "█"; done
        echo -ne "${GRAY}"
        for ((i=filled; i<bar_width; i++)); do echo -ne "▒"; done
        echo -ne "${NC} ${percent}%"
    fi
}

# Draw agent activity panel
draw_activity_panel() {
    local panel_width=$((TERM_WIDTH - 4))
    local panel_height=$((TERM_HEIGHT - 17))
    
    draw_box "Agent Activity" 2 15 $panel_width $panel_height
    
    # Show recent log entries
    local y=17
    local max_lines=$((panel_height - 4))
    
    if [[ -f "$AGENT_DIR/logs/agent_coordination.log" ]]; then
        tail -$max_lines "$AGENT_DIR/logs/agent_coordination.log" | while IFS= read -r line; do
            if [[ $y -lt $((15 + panel_height - 2)) ]]; then
                tput cup $y 4
                
                # Color code based on content
                if [[ "$line" =~ "SUCCESS" ]] || [[ "$line" =~ "reduced errors" ]]; then
                    echo -ne "${GREEN}"
                elif [[ "$line" =~ "ERROR" ]] || [[ "$line" =~ "failed" ]]; then
                    echo -ne "${RED}"
                elif [[ "$line" =~ "Processing" ]] || [[ "$line" =~ "Analyzing" ]]; then
                    echo -ne "${YELLOW}"
                elif [[ "$line" =~ "AGENT" ]]; then
                    echo -ne "${CYAN}"
                else
                    echo -ne "${GRAY}"
                fi
                
                # Truncate if too long
                local max_width=$((panel_width - 6))
                if [[ ${#line} -gt $max_width ]]; then
                    echo -ne "${line:0:$max_width}..."
                else
                    echo -ne "$line"
                fi
                echo -ne "${NC}"
                
                y=$((y + 1))
            fi
        done
    else
        tput cup $y 4
        echo -ne "${GRAY}No activity yet...${NC}"
    fi
}

# Draw error breakdown if available
draw_error_breakdown() {
    if [[ -f "$AGENT_DIR/state/error_analysis.json" ]] && [[ $UNIQUE_ERRORS -gt 0 ]]; then
        local x=$((TERM_WIDTH - 42))
        draw_box "Error Breakdown" $x 4 40 10
        
        local y=6
        # Parse categories from JSON
        grep -A2 '"description"' "$AGENT_DIR/state/error_analysis.json" | grep -B1 '"count"' | \
            head -6 | while IFS= read -r line; do
                if [[ "$line" =~ \"(.+)\":\ \{ ]]; then
                    category="${BASH_REMATCH[1]//_/ }"
                elif [[ "$line" =~ \"count\":\ ([0-9]+) ]] && [[ $y -lt 12 ]]; then
                    count="${BASH_REMATCH[1]}"
                    tput cup $y $((x + 2))
                    printf "%-25s %5d" "$category:" "$count"
                    y=$((y + 1))
                fi
            done
    fi
}

# Main dashboard loop
main() {
    # Hide cursor
    tput civis
    
    # Trap to restore cursor on exit
    trap 'tput cnorm; clear' EXIT INT TERM
    
    while true; do
        update_dimensions
        get_stats
        
        clear_dashboard
        draw_header
        draw_status_panel
        draw_error_panel
        draw_activity_panel
        
        # Draw error breakdown if terminal is wide enough
        if [[ $TERM_WIDTH -gt 90 ]]; then
            draw_error_breakdown
        fi
        
        # Status line at bottom
        tput cup $((TERM_HEIGHT - 1)) 0
        echo -ne "${GRAY}Refreshing every ${REFRESH_RATE}s | Press Ctrl+C to exit${NC}"
        
        sleep $REFRESH_RATE
    done
}

# Run dashboard
main