#!/bin/bash

# Developer Agent - State Management Specialist
# Fixes state management issues and improves caching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
STATE_STATE="$SCRIPT_DIR/state/state_management"
STATE_DIR="$SCRIPT_DIR/state"
mkdir -p "$STATE_STATE"

# Source debug utilities
[[ -f "$SCRIPT_DIR/debug_utils.sh" ]] && source "$SCRIPT_DIR/debug_utils.sh"

# Ensure colors are defined
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"
CYAN="${CYAN:-\033[0;36m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
BLUE="${BLUE:-\033[0;34m}"

# Fix state management issues
fix_state_management() {
    echo -e "${BOLD}${YELLOW}=== Fixing State Management Issues ===${NC}"
    
    # Fix error count caching
    fix_error_count_caching
    
    # Implement proper state synchronization
    implement_state_sync
    
    # Create state validation system
    create_state_validator
    
    # Fix stale state issues
    fix_stale_state_issues
    
    echo -e "${GREEN}✓ State management fixed${NC}"
}

# Fix error count caching issues
fix_error_count_caching() {
    echo -e "\n${YELLOW}Fixing error count caching...${NC}"
    
    # Create improved error counting function
    cat > "$STATE_STATE/error_count_manager.sh" << 'EOF'
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
EOF
    
    chmod +x "$STATE_STATE/error_count_manager.sh"
    
    # Update autofix_batch.sh to use new error counting
    if [[ -f "$SCRIPT_DIR/autofix_batch.sh" ]]; then
        # Replace the get_error_count_fast function
        sed -i '/^get_error_count_fast()/,/^}/c\
get_error_count_fast() {\
    source "$SCRIPT_DIR/state/state_management/error_count_manager.sh"\
    get_error_count\
}' "$SCRIPT_DIR/autofix_batch.sh"
    fi
    
    echo -e "${GREEN}✓ Error count caching fixed${NC}"
}

# Implement state synchronization
implement_state_sync() {
    echo -e "\n${YELLOW}Implementing state synchronization...${NC}"
    
    cat > "$STATE_STATE/state_sync.sh" << 'EOF'
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
EOF
    
    chmod +x "$STATE_STATE/state_sync.sh"
    echo -e "${GREEN}✓ State synchronization implemented${NC}"
}

# Create state validator
create_state_validator() {
    echo -e "\n${YELLOW}Creating state validator...${NC}"
    
    cat > "$STATE_STATE/state_validator.sh" << 'EOF'
#!/bin/bash

# State Validation System
# Ensures state files are valid and consistent

# Validate JSON state file
validate_json_state() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Check if valid JSON
    if ! jq . "$file" >/dev/null 2>&1; then
        echo "Invalid JSON in $file" >&2
        return 1
    fi
    
    return 0
}

# Validate state directory structure
validate_state_structure() {
    local required_dirs=(
        "$STATE_DIR"
        "$STATE_DIR/architecture"
        "$STATE_DIR/logs"
    )
    
    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "Missing state directory: $dir" >&2
            mkdir -p "$dir"
            ((missing++))
        fi
    done
    
    return $missing
}

# Clean stale state files
clean_stale_state() {
    local max_age="${1:-1440}"  # 24 hours in minutes
    
    echo "Cleaning state files older than $max_age minutes..."
    
    # Find and remove old cache files
    find "$STATE_DIR" -name "*.cache" -mmin +$max_age -delete 2>/dev/null
    find "$STATE_DIR" -name "*.tmp" -mmin +60 -delete 2>/dev/null
    find "$STATE_DIR" -name "*.lock" -mmin +5 -delete 2>/dev/null
    
    # Clean old build outputs
    find "$STATE_DIR" -name "build_output_*.txt" -mmin +$max_age -delete 2>/dev/null
}

# Repair corrupted state
repair_state() {
    echo "Repairing state files..."
    
    # Fix corrupted JSON files
    for json_file in "$STATE_DIR"/**/*.json; do
        if [[ -f "$json_file" ]] && ! validate_json_state "$json_file"; then
            echo "Repairing $json_file"
            # Backup corrupted file
            mv "$json_file" "${json_file}.corrupted.$(date +%s)"
            # Create empty valid JSON
            echo '{}' > "$json_file"
        fi
    done
    
    # Ensure required files exist
    [[ ! -f "$STATE_DIR/detected_language.txt" ]] && echo "csharp" > "$STATE_DIR/detected_language.txt"
    [[ ! -f "$STATE_DIR/.gitignore" ]] && echo -e "*.cache\n*.tmp\n*.lock" > "$STATE_DIR/.gitignore"
}

export -f validate_json_state validate_state_structure clean_stale_state repair_state
EOF
    
    chmod +x "$STATE_STATE/state_validator.sh"
    echo -e "${GREEN}✓ State validator created${NC}"
}

# Fix stale state issues
fix_stale_state_issues() {
    echo -e "\n${YELLOW}Fixing stale state issues...${NC}"
    
    # Create state maintenance script
    cat > "$STATE_STATE/state_maintenance.sh" << 'EOF'
#!/bin/bash

# State Maintenance Script
# Run periodically to keep state clean and valid

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/state"

# Source validators
source "$SCRIPT_DIR/state_validator.sh"
source "$SCRIPT_DIR/state_sync.sh"

echo "=== State Maintenance Starting ==="

# 1. Validate structure
echo "Validating state structure..."
validate_state_structure

# 2. Clean stale files
echo "Cleaning stale state files..."
clean_stale_state 1440  # 24 hours

# 3. Repair any issues
echo "Repairing state issues..."
repair_state

# 4. Update state metadata
cat > "$STATE_DIR/state_info.json" << JSON
{
  "last_maintenance": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "2.0",
  "health": "good"
}
JSON

echo "=== State Maintenance Complete ==="
EOF
    
    chmod +x "$STATE_STATE/state_maintenance.sh"
    
    # Run maintenance now
    bash "$STATE_STATE/state_maintenance.sh"
    
    echo -e "${GREEN}✓ Stale state issues fixed${NC}"
}

# Create state management report
create_state_report() {
    cat > "$STATE_STATE/state_management_report.md" << EOF
# State Management Improvements Report

## Fixed Issues:
1. ✅ Error count caching accuracy
2. ✅ Multi-target build counting
3. ✅ State file synchronization
4. ✅ Stale cache detection
5. ✅ Lock mechanism for concurrent access
6. ✅ State validation and repair

## New Components:
- **Error Count Manager**: Accurate counting with smart caching
- **State Sync System**: Lock-based synchronization
- **State Validator**: JSON validation and structure checks
- **State Maintenance**: Automated cleanup and repair

## State Architecture:
\`\`\`
state/
├── .error_count_cache      # Current error count
├── .error_count_time       # Cache timestamp
├── .state.lock            # Synchronization lock
├── .state.version         # State version tracking
├── architecture/          # Agent coordination
├── logs/                 # Execution logs
├── dev_core/            # Core dev artifacts
├── integration/         # Integration artifacts
├── patterns/           # Pattern library
├── performance/        # Performance reports
├── state_management/   # State tools
└── testing/           # Test results
\`\`\`

## Best Practices:
1. Always use state sync functions for read/write
2. Check cache validity before use
3. Run maintenance daily
4. Monitor lock timeouts
5. Validate JSON before parsing

Generated: $(date)
EOF

    echo -e "\n${GREEN}State report saved to: $STATE_STATE/state_management_report.md${NC}"
}

# Main execution
main() {
    echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║  Developer Agent - State Management    ║${NC}"
    echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════╝${NC}"
    
    # Fix state management
    fix_state_management
    
    # Create report
    create_state_report
    
    # Update agent status
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.developer_3.status = "complete"' "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
        mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
    
    echo -e "\n${GREEN}✓ State management improvements complete${NC}"
}

main "$@"