#!/bin/bash

# Incremental Processing System - Only process changes since last run
# Dramatically reduces processing time by focusing on what's new

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/incremental"
TIMESTAMP_FILE="$STATE_DIR/.last_run_timestamp"
CHANGE_LOG="$STATE_DIR/change_log.json"
INCREMENTAL_STATE="$STATE_DIR/incremental_state.json"
CHECKSUM_DB="$STATE_DIR/file_checksums.db"

# Configuration
ENABLE_INCREMENTAL=${ENABLE_INCREMENTAL:-true}
TRACK_DEPENDENCIES=${TRACK_DEPENDENCIES:-true}
FORCE_FULL_SCAN=${FORCE_FULL_SCAN:-false}

# Create directories
mkdir -p "$STATE_DIR"

# Initialize state files
init_incremental_state() {
    if [[ ! -f "$INCREMENTAL_STATE" ]]; then
        cat > "$INCREMENTAL_STATE" << EOF
{
    "version": "1.0",
    "last_full_scan": null,
    "incremental_runs": 0,
    "total_time_saved": 0,
    "files_tracked": 0,
    "dependencies": {}
}
EOF
    fi
    
    if [[ ! -f "$CHECKSUM_DB" ]]; then
        echo "# File Checksum Database" > "$CHECKSUM_DB"
        echo "# Format: filepath|checksum|last_modified|last_errors" >> "$CHECKSUM_DB"
    fi
}

# Check if incremental processing is applicable
can_use_incremental() {
    # Force full scan if requested
    if [[ "$FORCE_FULL_SCAN" == "true" ]]; then
        echo "[INCREMENTAL] Force full scan requested"
        return 1
    fi
    
    # Check if we have a previous run
    if [[ ! -f "$TIMESTAMP_FILE" ]]; then
        echo "[INCREMENTAL] No previous run found, need full scan"
        return 1
    fi
    
    # Check if build output changed significantly
    if [[ -f "build_output.txt" ]]; then
        local current_hash=$(md5sum build_output.txt | cut -d' ' -f1)
        local last_hash=$(jq -r '.last_build_hash // ""' "$INCREMENTAL_STATE" 2>/dev/null)
        
        if [[ "$current_hash" != "$last_hash" ]]; then
            echo "[INCREMENTAL] Build output changed, checking scope..."
            
            # Quick check if it's a minor change
            local error_diff=$(diff <(grep "error" build_output.txt 2>/dev/null | sort) \
                                   <(grep "error" "$STATE_DIR/last_build_errors.txt" 2>/dev/null | sort) \
                                   2>/dev/null | wc -l || echo "999")
            
            if [[ $error_diff -lt 50 ]]; then
                echo "[INCREMENTAL] Minor build changes detected, using incremental"
                return 0
            else
                echo "[INCREMENTAL] Major build changes detected, need full scan"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Find changed files since last run
find_changed_files() {
    local last_run_time=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    
    echo "[INCREMENTAL] Finding files changed since $(date -d @$last_run_time 2>/dev/null || echo 'never')"
    
    # Initialize change log
    cat > "$CHANGE_LOG" << EOF
{
    "scan_time": "$(date -Iseconds)",
    "last_run": "$last_run_time",
    "changed_files": [],
    "new_files": [],
    "deleted_files": [],
    "dependency_changes": []
}
EOF
    
    # Find modified and new files
    local changed_count=0
    local new_count=0
    
    # Use find with -newer for efficiency
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                local file_hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "")
                local old_hash=$(grep "^$file|" "$CHECKSUM_DB" 2>/dev/null | cut -d'|' -f2 || echo "")
                
                if [[ -z "$old_hash" ]]; then
                    # New file
                    jq --arg file "$file" '.new_files += [$file]' "$CHANGE_LOG" > "$CHANGE_LOG.tmp" && \
                        mv "$CHANGE_LOG.tmp" "$CHANGE_LOG"
                    ((new_count++))
                elif [[ "$file_hash" != "$old_hash" ]]; then
                    # Modified file
                    jq --arg file "$file" '.changed_files += [$file]' "$CHANGE_LOG" > "$CHANGE_LOG.tmp" && \
                        mv "$CHANGE_LOG.tmp" "$CHANGE_LOG"
                    ((changed_count++))
                fi
                
                # Update checksum database
                update_file_checksum "$file" "$file_hash"
            fi
        done < <(find . -name "*.cs" -newer "$TIMESTAMP_FILE" -type f 2>/dev/null)
    else
        # First run - all files are new
        find . -name "*.cs" -type f | while read -r file; do
            local file_hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "")
            jq --arg file "$file" '.new_files += [$file]' "$CHANGE_LOG" > "$CHANGE_LOG.tmp" && \
                mv "$CHANGE_LOG.tmp" "$CHANGE_LOG"
            update_file_checksum "$file" "$file_hash"
            ((new_count++))
        done
    fi
    
    # Find deleted files
    local deleted_count=0
    while IFS='|' read -r file rest; do
        if [[ ! -f "$file" ]]; then
            jq --arg file "$file" '.deleted_files += [$file]' "$CHANGE_LOG" > "$CHANGE_LOG.tmp" && \
                mv "$CHANGE_LOG.tmp" "$CHANGE_LOG"
            ((deleted_count++))
        fi
    done < <(grep -v "^#" "$CHECKSUM_DB" 2>/dev/null || true)
    
    echo "[INCREMENTAL] Found: $changed_count modified, $new_count new, $deleted_count deleted files"
    
    # Update state
    jq --argjson changed "$changed_count" \
       --argjson new "$new_count" \
       --argjson deleted "$deleted_count" \
       '.last_change_summary = {
           "modified": $changed,
           "new": $new,
           "deleted": $deleted
       }' "$INCREMENTAL_STATE" > "$INCREMENTAL_STATE.tmp" && \
        mv "$INCREMENTAL_STATE.tmp" "$INCREMENTAL_STATE"
    
    return 0
}

# Update file checksum in database
update_file_checksum() {
    local file="$1"
    local checksum="$2"
    local timestamp=$(date +%s)
    
    # Remove old entry
    grep -v "^$file|" "$CHECKSUM_DB" > "$CHECKSUM_DB.tmp" 2>/dev/null || true
    
    # Add new entry
    echo "${file}|${checksum}|${timestamp}|" >> "$CHECKSUM_DB.tmp"
    
    mv "$CHECKSUM_DB.tmp" "$CHECKSUM_DB"
}

# Track file dependencies
track_dependencies() {
    local file="$1"
    
    if [[ "$TRACK_DEPENDENCIES" != "true" ]]; then
        return
    fi
    
    # Extract dependencies (using statements, includes, etc.)
    local deps=()
    
    # For C# files, track using statements and project references
    if [[ "$file" =~ \.cs$ ]]; then
        # Extract namespaces
        while IFS= read -r using; do
            deps+=("$using")
        done < <(grep "^using " "$file" 2>/dev/null | sed 's/using \(.*\);/\1/' | sort -u)
        
        # Extract project references from nearby csproj
        local proj_file=$(find "$(dirname "$file")" -name "*.csproj" -maxdepth 3 | head -1)
        if [[ -f "$proj_file" ]]; then
            while IFS= read -r ref; do
                deps+=("project:$ref")
            done < <(grep -o 'Include="[^"]*"' "$proj_file" | cut -d'"' -f2)
        fi
    fi
    
    # Update dependency tracking
    if [[ ${#deps[@]} -gt 0 ]]; then
        local deps_json=$(printf '%s\n' "${deps[@]}" | jq -R . | jq -s .)
        jq --arg file "$file" --argjson deps "$deps_json" \
           '.dependencies[$file] = $deps' \
           "$INCREMENTAL_STATE" > "$INCREMENTAL_STATE.tmp" && \
            mv "$INCREMENTAL_STATE.tmp" "$INCREMENTAL_STATE"
    fi
}

# Get files affected by changes (including dependencies)
get_affected_files() {
    local changed_files=($(jq -r '.changed_files[]' "$CHANGE_LOG" 2>/dev/null))
    local new_files=($(jq -r '.new_files[]' "$CHANGE_LOG" 2>/dev/null))
    
    # Start with directly changed files
    local affected_files=()
    affected_files+=("${changed_files[@]}")
    affected_files+=("${new_files[@]}")
    
    if [[ "$TRACK_DEPENDENCIES" == "true" ]]; then
        # Find files that depend on changed files
        for changed_file in "${changed_files[@]}"; do
            # Get namespace from changed file
            local namespace=$(grep "^namespace " "$changed_file" 2>/dev/null | \
                             sed 's/namespace \([^ ]*\).*/\1/' | head -1)
            
            if [[ -n "$namespace" ]]; then
                # Find files using this namespace
                local dependent_files=$(grep -l "using $namespace;" **/*.cs 2>/dev/null || true)
                for dep_file in $dependent_files; do
                    affected_files+=("$dep_file")
                done
            fi
        done
    fi
    
    # Remove duplicates
    printf '%s\n' "${affected_files[@]}" | sort -u
}

# Generate incremental error analysis
generate_incremental_analysis() {
    local affected_files=("$@")
    
    echo "[INCREMENTAL] Analyzing errors in ${#affected_files[@]} affected files"
    
    # Create focused error analysis
    local analysis_file="$STATE_DIR/incremental_error_analysis.json"
    
    cat > "$analysis_file" << EOF
{
    "type": "incremental",
    "timestamp": "$(date -Iseconds)",
    "scope": {
        "total_files": ${#affected_files[@]},
        "files": $(printf '%s\n' "${affected_files[@]}" | jq -R . | jq -s .)
    },
    "errors": []
}
EOF
    
    # Extract errors only from affected files
    if [[ -f "build_output.txt" ]]; then
        for file in "${affected_files[@]}"; do
            # Extract errors for this file
            grep "$file" build_output.txt 2>/dev/null | grep "error" | while read -r error_line; do
                # Parse error
                if [[ "$error_line" =~ ([^:]+):([0-9]+),([0-9]+):[[:space:]]*error[[:space:]]+([A-Z]+[0-9]+):[[:space:]]*(.*) ]]; then
                    local error_file="${BASH_REMATCH[1]}"
                    local line="${BASH_REMATCH[2]}"
                    local col="${BASH_REMATCH[3]}"
                    local code="${BASH_REMATCH[4]}"
                    local message="${BASH_REMATCH[5]}"
                    
                    # Add to analysis
                    jq --arg file "$error_file" \
                       --arg line "$line" \
                       --arg col "$col" \
                       --arg code "$code" \
                       --arg msg "$message" \
                       '.errors += [{
                           "file": $file,
                           "line": ($line | tonumber),
                           "column": ($col | tonumber),
                           "code": $code,
                           "message": $msg
                       }]' "$analysis_file" > "$analysis_file.tmp" && \
                        mv "$analysis_file.tmp" "$analysis_file"
                fi
            done
        done
    fi
    
    # Add summary
    local error_count=$(jq '.errors | length' "$analysis_file")
    jq --argjson count "$error_count" '.total_errors = $count' "$analysis_file" > "$analysis_file.tmp" && \
        mv "$analysis_file.tmp" "$analysis_file"
    
    echo "[INCREMENTAL] Found $error_count errors in affected files"
    echo "$analysis_file"
}

# Save incremental state
save_incremental_state() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update timestamp
    echo "$end_time" > "$TIMESTAMP_FILE"
    
    # Save current build errors for next comparison
    grep "error" build_output.txt 2>/dev/null > "$STATE_DIR/last_build_errors.txt" || true
    
    # Update state
    jq --argjson duration "$duration" \
       --arg build_hash "$(md5sum build_output.txt 2>/dev/null | cut -d' ' -f1 || echo "")" \
       --argjson runs "$(jq -r '.incremental_runs' "$INCREMENTAL_STATE")" \
       '.incremental_runs = ($runs + 1) |
        .total_time_saved += $duration |
        .last_incremental_run = "'"$(date -Iseconds)"'" |
        .last_build_hash = $build_hash' \
       "$INCREMENTAL_STATE" > "$INCREMENTAL_STATE.tmp" && \
        mv "$INCREMENTAL_STATE.tmp" "$INCREMENTAL_STATE"
    
    echo "[INCREMENTAL] State saved. Time saved: ${duration}s"
}

# Main incremental processing function
process_incremental() {
    local start_time=$(date +%s)
    
    init_incremental_state
    
    # Check if we can use incremental
    if ! can_use_incremental; then
        echo "[INCREMENTAL] Full scan required"
        # Mark for full scan
        rm -f "$TIMESTAMP_FILE"
        return 1
    fi
    
    # Find changed files
    find_changed_files
    
    # Get all affected files (including dependencies)
    local affected_files=($(get_affected_files))
    
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[INCREMENTAL] No changes detected since last run"
        save_incremental_state "$start_time"
        
        # Return empty analysis
        cat > "$STATE_DIR/incremental_error_analysis.json" << EOF
{
    "type": "incremental",
    "timestamp": "$(date -Iseconds)",
    "scope": {"total_files": 0, "files": []},
    "errors": [],
    "total_errors": 0,
    "message": "No changes detected"
}
EOF
        return 0
    fi
    
    # Generate incremental analysis
    local analysis_file=$(generate_incremental_analysis "${affected_files[@]}")
    
    # Track dependencies for changed files
    for file in "${affected_files[@]}"; do
        track_dependencies "$file"
    done
    
    # Save state
    save_incremental_state "$start_time"
    
    # Output results
    cat "$analysis_file"
    return 0
}

# Reset incremental state (for testing or forced full scan)
reset_incremental_state() {
    echo "[INCREMENTAL] Resetting incremental state..."
    rm -f "$TIMESTAMP_FILE"
    rm -f "$CHECKSUM_DB"
    rm -f "$INCREMENTAL_STATE"
    rm -f "$STATE_DIR/last_build_errors.txt"
    echo "[INCREMENTAL] State reset complete"
}

# Show incremental statistics
show_incremental_stats() {
    if [[ ! -f "$INCREMENTAL_STATE" ]]; then
        echo "No incremental state found"
        return
    fi
    
    echo "=== Incremental Processing Statistics ==="
    jq -r '
        "Total Runs: \(.incremental_runs // 0)",
        "Time Saved: \(.total_time_saved // 0) seconds",
        "Files Tracked: \(.files_tracked // 0)",
        "Last Run: \(.last_incremental_run // "never")",
        "",
        "Last Change Summary:",
        if .last_change_summary then
            "  Modified: \(.last_change_summary.modified)",
            "  New: \(.last_change_summary.new)",
            "  Deleted: \(.last_change_summary.deleted)"
        else
            "  No change data available"
        end
    ' "$INCREMENTAL_STATE"
}

# Main function
main() {
    case "${1:-process}" in
        process)
            process_incremental
            ;;
        reset)
            reset_incremental_state
            ;;
        stats)
            show_incremental_stats
            ;;
        check)
            if can_use_incremental; then
                echo "Incremental processing available"
                exit 0
            else
                echo "Full scan required"
                exit 1
            fi
            ;;
        *)
            cat << EOF
Incremental Processing System

Usage: $0 <command>

Commands:
  process - Run incremental processing (default)
  reset   - Reset incremental state
  stats   - Show incremental statistics
  check   - Check if incremental is available

Environment Variables:
  ENABLE_INCREMENTAL=true    - Enable incremental processing
  TRACK_DEPENDENCIES=true    - Track file dependencies
  FORCE_FULL_SCAN=false     - Force full scan

Examples:
  # Normal incremental run
  $0
  
  # Force full scan once
  FORCE_FULL_SCAN=true $0
  
  # Check statistics
  $0 stats
EOF
            ;;
    esac
}

# Export functions for use by other scripts
export -f can_use_incremental
export -f find_changed_files
export -f get_affected_files
export -f process_incremental

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi