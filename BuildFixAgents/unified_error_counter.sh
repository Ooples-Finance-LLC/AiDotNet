#!/bin/bash

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$SCRIPT_DIR/state}"

# Unified Error Counter
# Provides consistent error counting across all BuildFixAgents components

# Get the true unique error count
get_unique_error_count() {
    local project_dir="${1:-/home/ooples/AiDotNet}"
    
    # Run build and extract unique errors (file + error code combination)
    cd "$project_dir" 2>/dev/null || return 1
    
    # Count unique combinations of file path and error code
    # This handles multi-target builds by deduplicating
    local count=$(timeout 20s dotnet build --no-restore 2>&1 | \
        grep "error CS" | \
        sed 's/\[[^]]*\]$//' | \
        awk -F'[(:)]' '{
            # Extract file and error code
            file = $1
            for (i = 1; i <= NF; i++) {
                if ($i ~ /error CS[0-9]+/) {
                    code = $i
                    gsub(/.*error /, "", code)
                    gsub(/[: ].*/, "", code)
                    if (code ~ /^CS[0-9]+$/) {
                        print file ":" code
                    }
                    break
                }
            }
        }' | \
        sort -u | \
        wc -l || echo 0)
    
    echo "$count"
}

# Get error count by type
get_error_count_by_type() {
    local project_dir="${1:-/home/ooples/AiDotNet}"
    
    cd "$project_dir" 2>/dev/null || return 1
    
    # Count each error type
    timeout 20s dotnet build --no-restore 2>&1 | \
        grep -o "error CS[0-9]\+" | \
        sort | uniq -c | \
        awk '{print $2 ":" $1}'
}

# Export functions
export -f get_unique_error_count get_error_count_by_type
