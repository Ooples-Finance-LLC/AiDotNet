#!/bin/bash

# Debug Utilities - Shared debugging functions for all BuildFixAgents scripts
# Source this file to enable debug, verbose, and timing features

# Debug mode environment variables
DEBUG="${DEBUG:-false}"
VERBOSE="${VERBOSE:-false}"
TIMING="${TIMING:-false}"

# Colors (in case not already defined)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Debug functions
debug() {
    [[ "$DEBUG" == "true" ]] && echo -e "${YELLOW}[DEBUG $(date +%H:%M:%S)]${NC} $*" >&2
}

verbose() {
    [[ "$VERBOSE" == "true" || "$DEBUG" == "true" ]] && echo -e "${CYAN}[VERBOSE]${NC} $*" >&2
}

trace() {
    [[ "$DEBUG" == "true" ]] && echo -e "${GRAY}[TRACE]${NC} ${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]} ${FUNCNAME[2]}() $*" >&2
}

# Timing functions
declare -A TIMINGS
SCRIPT_START_TIME=$(date +%s.%N)

start_timer() {
    local name="$1"
    if [[ "$TIMING" == "true" ]]; then
        TIMINGS["${name}_start"]=$(date +%s.%N)
        debug "Timer started: $name"
    fi
}

end_timer() {
    local name="$1"
    if [[ "$TIMING" == "true" ]]; then
        local start="${TIMINGS["${name}_start"]}"
        if [[ -n "$start" ]]; then
            local end=$(date +%s.%N)
            local duration=$(echo "$end - $start" | bc)
            echo -e "${MAGENTA}[TIMING]${NC} $name: ${duration}s" >&2
            TIMINGS["${name}_duration"]="$duration"
            
            # Warn if operation took too long
            if (( $(echo "$duration > 30" | bc -l) )); then
                echo -e "${RED}[WARNING]${NC} $name took longer than 30s!" >&2
            fi
        else
            debug "No start time found for timer: $name"
        fi
    fi
}

print_timing_summary() {
    if [[ "$TIMING" == "true" ]]; then
        echo -e "\n${MAGENTA}=== Timing Summary ===${NC}" >&2
        local total_time=$(echo "$(date +%s.%N) - $SCRIPT_START_TIME" | bc)
        echo -e "Total execution time: ${total_time}s" >&2
        
        # Sort timings by duration
        local sorted_timings=()
        for key in "${!TIMINGS[@]}"; do
            if [[ "$key" == *"_duration" ]]; then
                local name="${key%_duration}"
                sorted_timings+=("${TIMINGS[$key]}:$name")
            fi
        done
        
        # Print sorted timings
        if [[ ${#sorted_timings[@]} -gt 0 ]]; then
            echo -e "\nDetailed timings:" >&2
            printf '%s\n' "${sorted_timings[@]}" | sort -rn | while IFS=: read -r duration name; do
                printf "  %-30s %6.2fs" "$name:" "$duration" >&2
                
                # Show percentage of total time
                local percent=$(echo "scale=1; $duration * 100 / $total_time" | bc)
                echo -e " (${percent}%)" >&2
            done
        fi
        
        # Memory usage if available
        if command -v free &> /dev/null; then
            echo -e "\nMemory usage:" >&2
            free -h | grep -E "^Mem:" | awk '{print "  Used: "$3" / "$2" ("$3" of "$2")"}' >&2
        fi
    fi
}

# Error tracking
declare -i ERROR_COUNT=0
declare -a ERROR_MESSAGES=()

track_error() {
    local error_msg="$1"
    ERROR_COUNT+=1
    ERROR_MESSAGES+=("$error_msg")
    debug "Error tracked (#$ERROR_COUNT): $error_msg"
}

print_error_summary() {
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo -e "\n${RED}=== Error Summary ===${NC}" >&2
        echo -e "Total errors encountered: $ERROR_COUNT" >&2
        if [[ "$VERBOSE" == "true" || "$DEBUG" == "true" ]]; then
            echo -e "\nError details:" >&2
            for i in "${!ERROR_MESSAGES[@]}"; do
                echo -e "  $((i+1)). ${ERROR_MESSAGES[$i]}" >&2
            done
        fi
    fi
}

# Performance monitoring
check_system_resources() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "\n${GRAY}=== System Resources ===${NC}" >&2
        
        # CPU load
        if [[ -f /proc/loadavg ]]; then
            local load=$(cat /proc/loadavg | cut -d' ' -f1-3)
            echo -e "  CPU Load: $load" >&2
        fi
        
        # Memory
        if command -v free &> /dev/null; then
            local mem_available=$(free -m | grep "^Mem:" | awk '{print $7}')
            echo -e "  Memory Available: ${mem_available}MB" >&2
        fi
        
        # Disk space
        local disk_available=$(df -h "$PWD" | tail -1 | awk '{print $4}')
        echo -e "  Disk Available: $disk_available" >&2
    fi
}

# Initialize debug mode message
show_debug_status() {
    if [[ "$DEBUG" == "true" || "$VERBOSE" == "true" || "$TIMING" == "true" ]]; then
        echo -e "${YELLOW}Debug modes active:${NC}" >&2
        [[ "$DEBUG" == "true" ]] && echo "  - DEBUG (detailed logging)" >&2
        [[ "$VERBOSE" == "true" ]] && echo "  - VERBOSE (extra output)" >&2
        [[ "$TIMING" == "true" ]] && echo "  - TIMING (performance metrics)" >&2
        echo "" >&2
    fi
}

# Cleanup function to be called at script exit
debug_cleanup() {
    if [[ "$TIMING" == "true" ]]; then
        print_timing_summary
    fi
    
    if [[ "$DEBUG" == "true" ]]; then
        print_error_summary
        check_system_resources
    fi
}

# Set trap for cleanup (scripts should still set their own traps and call this)
# trap debug_cleanup EXIT

# Export functions for use in subshells
export -f debug verbose trace start_timer end_timer track_error