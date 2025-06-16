#!/bin/bash

# Error Count Management System
# Handles accurate error counting with proper caching

# Get fresh error count
get_error_count() {
    local cache_file="$STATE_DIR/.error_count_cache"
    local cache_time_file="$STATE_DIR/.error_count_time"
    local max_cache_age=30  # seconds
    
    # Check cache validity
    if [[ -f "$cache_file" ]] && [[ -f "$cache_time_file" ]]; then
        local cache_time=$(cat "$cache_time_file")
        local current_time=$(date +%s)
        local cache_age=$((current_time - cache_time))
        
        if [[ $cache_age -lt $max_cache_age ]]; then
            # Cache is fresh
            cat "$cache_file" | tr -d '\n'
            return 0
        fi
    fi
    
    # Count errors (handling multi-target builds)
    local count=0
    if [[ -f "$BUILD_OUTPUT_FILE" ]]; then
        # Count unique error instances (file + line + error code)
        count=$(grep "error CS" "$BUILD_OUTPUT_FILE" | \
                awk -F'[(:)]' '{print $1":"$2":"$NF}' | \
                sort -u | wc -l)
    else
        # No build output, run quick build to get count
        count=$(timeout 15s dotnet build --no-restore 2>&1 | \
                grep "error CS" | \
                awk -F'[(:)]' '{print $1":"$2":"$NF}' | \
                sort -u | wc -l || echo 0)
    fi
    
    # Cache the result
    echo "$count" > "$cache_file"
    date +%s > "$cache_time_file"
    
    echo "$count"
}

# Clear error count cache
clear_error_cache() {
    rm -f "$STATE_DIR/.error_count_cache" "$STATE_DIR/.error_count_time"
}

# Update error count after fix
update_error_count() {
    local fixed_count="${1:-1}"
    local current=$(get_error_count)
    local new_count=$((current - fixed_count))
    
    if [[ $new_count -lt 0 ]]; then
        new_count=0
    fi
    
    echo "$new_count" > "$STATE_DIR/.error_count_cache"
    date +%s > "$STATE_DIR/.error_count_time"
}

export -f get_error_count clear_error_cache update_error_count
