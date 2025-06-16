#!/bin/bash

# State Synchronization System
# Ensures all agents have consistent view of state

STATE_LOCK="$STATE_DIR/.state.lock"
STATE_VERSION="$STATE_DIR/.state.version"

# Acquire state lock
acquire_state_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ -f "$STATE_LOCK" ]] && [[ $elapsed -lt $timeout ]]; do
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        # Force unlock if stale
        local lock_age=$(find "$STATE_LOCK" -mmin +2 2>/dev/null | wc -l)
        if [[ $lock_age -gt 0 ]]; then
            rm -f "$STATE_LOCK"
        else
            return 1
        fi
    fi
    
    echo "$$" > "$STATE_LOCK"
    return 0
}

# Release state lock
release_state_lock() {
    rm -f "$STATE_LOCK"
}

# Read state with lock
read_state() {
    local state_file="$1"
    
    if acquire_state_lock; then
        if [[ -f "$state_file" ]]; then
            cat "$state_file"
        fi
        release_state_lock
    else
        echo "ERROR: Could not acquire state lock" >&2
        return 1
    fi
}

# Write state with lock
write_state() {
    local state_file="$1"
    local content="$2"
    
    if acquire_state_lock; then
        echo "$content" > "$state_file"
        # Update version
        date +%s > "$STATE_VERSION"
        release_state_lock
    else
        echo "ERROR: Could not acquire state lock" >&2
        return 1
    fi
}

# Check if state is stale
is_state_stale() {
    local state_file="$1"
    local max_age="${2:-300}"  # 5 minutes default
    
    if [[ ! -f "$state_file" ]]; then
        return 0  # No state is stale state
    fi
    
    local file_age=$(find "$state_file" -mmin +$((max_age/60)) 2>/dev/null | wc -l)
    [[ $file_age -gt 0 ]]
}

export -f acquire_state_lock release_state_lock read_state write_state is_state_stale
