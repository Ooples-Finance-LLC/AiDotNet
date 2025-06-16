#!/bin/bash

# Fix Agent - Error Counting Consistency
# Ensures consistent error counting across all components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'

echo -e "${BOLD}${CYAN}=== Fix Agent: Error Counting Consistency ===${NC}"

# Fix 1: Update error count manager to properly set environment variables
echo -e "\n${YELLOW}Fixing error count manager environment...${NC}"

# Update the error_count_manager.sh
cat > "$SCRIPT_DIR/state/state_management/error_count_manager.sh" << 'EOF'
#!/bin/bash

# Error Count Management System
# Handles accurate error counting with proper caching

# Get fresh error count
get_error_count() {
    # Ensure STATE_DIR is set
    if [[ -z "${STATE_DIR:-}" ]]; then
        STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/state"
    fi
    if [[ -z "${BUILD_OUTPUT_FILE:-}" ]]; then
        BUILD_OUTPUT_FILE="$(dirname "$STATE_DIR")/build_output.txt"
    fi
    if [[ -z "${PROJECT_DIR:-}" ]]; then
        PROJECT_DIR="$(dirname "$(dirname "$STATE_DIR")")"
    fi
    
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
        # Count unique error instances (file + error code only, ignore line numbers)
        count=$(grep "error CS" "$BUILD_OUTPUT_FILE" | \
                awk -F'[(:)]' '{print $1":"$(NF-1)}' | \
                sed 's/\[[^]]*\]$//' | \
                sort -u | wc -l)
    else
        # No build output, run quick build to get count
        cd "$PROJECT_DIR" 2>/dev/null || cd /home/ooples/AiDotNet
        count=$(timeout 15s dotnet build --no-restore 2>&1 | \
                grep "error CS" | \
                awk -F'[(:)]' '{
                    # Extract file path and error code
                    file = $1
                    for (i = 2; i <= NF; i++) {
                        if ($i ~ /error CS[0-9]+/) {
                            gsub(/.*error /, "", $i)
                            gsub(/:.*/, "", $i)
                            print file ":" $i
                            break
                        }
                    }
                }' | \
                sort -u | wc -l || echo 0)
    fi
    
    # Cache the result
    mkdir -p "$STATE_DIR"
    echo "$count" > "$cache_file"
    date +%s > "$cache_time_file"
    
    echo "$count"
}

# Clear error count cache
clear_error_cache() {
    # Ensure STATE_DIR is set
    if [[ -z "${STATE_DIR:-}" ]]; then
        STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/state"
    fi
    rm -f "$STATE_DIR/.error_count_cache" "$STATE_DIR/.error_count_time"
}

# Update error count after fix
update_error_count() {
    # Ensure STATE_DIR is set
    if [[ -z "${STATE_DIR:-}" ]]; then
        STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/state"
    fi
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
EOF

chmod +x "$SCRIPT_DIR/state/state_management/error_count_manager.sh"

# Fix 2: Create a unified error counting function for all scripts
echo -e "\n${YELLOW}Creating unified error counter...${NC}"

cat > "$SCRIPT_DIR/unified_error_counter.sh" << 'EOF'
#!/bin/bash

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
EOF

chmod +x "$SCRIPT_DIR/unified_error_counter.sh"

# Fix 3: Update autofix.sh to use unified counter
echo -e "\n${YELLOW}Updating autofix.sh error counting...${NC}"

# Backup and update autofix.sh
cp "$SCRIPT_DIR/autofix.sh" "$SCRIPT_DIR/autofix.sh.backup.$(date +%s)"

# Add source for unified counter after debug utilities
sed -i '/source.*debug_utils.sh/a\
\
# Source unified error counter\
if [[ -f "$AGENT_DIR/unified_error_counter.sh" ]]; then\
    source "$AGENT_DIR/unified_error_counter.sh"\
fi' "$SCRIPT_DIR/autofix.sh"

# Replace get_error_count function
sed -i '/^get_error_count()/,/^}$/{
    s/^get_error_count().*{/get_error_count() {\
    debug "Getting error count for project: $PROJECT_DIR"\
    \
    # Use unified error counter\
    if command -v get_unique_error_count >/dev/null 2>\&1; then\
        get_unique_error_count "$PROJECT_DIR"\
    else\
        # Fallback to basic counting\
        cd "$PROJECT_DIR" 2>\/dev\/null || return 1\
        timeout 20s dotnet build --no-restore 2>\&1 | grep -c "error CS" || echo 0\
    fi/
}' "$SCRIPT_DIR/autofix.sh"

# Fix 4: Update autofix_batch.sh
echo -e "\n${YELLOW}Updating autofix_batch.sh error counting...${NC}"

# Update the get_error_count_fast function
sed -i '/^get_error_count_fast()/,/^}$/{
    s/^get_error_count_fast().*{/get_error_count_fast() {\
    # Use unified error counter if available\
    if [[ -f "$SCRIPT_DIR\/unified_error_counter.sh" ]]; then\
        source "$SCRIPT_DIR\/unified_error_counter.sh"\
        get_unique_error_count "$PROJECT_DIR"\
    else\
        # Fallback to state manager\
        source "$SCRIPT_DIR\/state\/state_management\/error_count_manager.sh"\
        get_error_count\
    fi/
}' "$SCRIPT_DIR/autofix_batch.sh"

# Fix 5: Test the unified counting
echo -e "\n${GREEN}Testing unified error counting...${NC}"

source "$SCRIPT_DIR/unified_error_counter.sh"

echo -n "Getting unique error count... "
count=$(get_unique_error_count)
echo -e "${CYAN}$count errors${NC}"

echo -e "\nError breakdown by type:"
get_error_count_by_type | while IFS=: read -r code count; do
    echo -e "  ${YELLOW}$code${NC}: $count occurrences"
done

# Update the cache with correct count
echo "$count" > "$SCRIPT_DIR/state/.error_count_cache"
date +%s > "$SCRIPT_DIR/state/.error_count_time"

echo -e "\n${BOLD}${GREEN}=== Error Counting Fix Complete ===${NC}"
echo -e "Unified error count: ${CYAN}$count${NC}"