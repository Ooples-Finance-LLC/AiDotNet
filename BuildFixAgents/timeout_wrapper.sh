#!/bin/bash

# Timeout wrapper for commands
# Usage: timeout_wrapper.sh <timeout_seconds> <command> [args...]

set -euo pipefail

TIMEOUT="${1:-60}"
shift

# Function to run command with timeout
run_with_timeout() {
    local timeout=$1
    shift
    
    # Start the command in background
    "$@" &
    local pid=$!
    
    # Start timeout counter
    (
        sleep "$timeout"
        if kill -0 $pid 2>/dev/null; then
            echo "Command timed out after ${timeout}s, terminating..." >&2
            kill -TERM $pid 2>/dev/null || true
            sleep 2
            kill -KILL $pid 2>/dev/null || true
        fi
    ) &
    local timeout_pid=$!
    
    # Wait for command to complete
    if wait $pid; then
        local exit_code=$?
        kill $timeout_pid 2>/dev/null || true
        return $exit_code
    else
        local exit_code=$?
        kill $timeout_pid 2>/dev/null || true
        return $exit_code
    fi
}

# Run the command with timeout
run_with_timeout "$TIMEOUT" "$@"