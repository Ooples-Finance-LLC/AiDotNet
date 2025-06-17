#!/bin/bash

# Fix Agent Batch Operations Library
# Common batch functions for all fix agents to maximize performance

set -euo pipefail

# Source base batch operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/batch_file_operations.sh"

# Configuration
BATCH_FIX_CACHE="$SCRIPT_DIR/state/batch_fix_cache"
BATCH_PATTERNS_DIR="$SCRIPT_DIR/state/batch_patterns"
mkdir -p "$BATCH_FIX_CACHE" "$BATCH_PATTERNS_DIR"

# Extract all errors of a specific type from build output
extract_errors_batch() {
    local error_codes=("$@")
    local output_file="$BATCH_FIX_CACHE/extracted_errors_$(date +%s).txt"
    
    # Build grep pattern
    local pattern=$(printf '%s|' "${error_codes[@]}")
    pattern="${pattern%|}"  # Remove trailing |
    
    # Extract all matching errors with file information
    grep -E "error ($pattern):" build_output.txt > "$output_file" 2>/dev/null || {
        > "$output_file"  # Create empty file if no matches
    }
    
    echo "$output_file"
}

# Group errors by file for batch processing
group_errors_by_file() {
    local error_file="$1"
    local grouped_file="$BATCH_FIX_CACHE/grouped_$(basename "$error_file")"
    
    # Parse and group errors by file
    awk -F: '
    {
        # Extract filename from error line
        if (match($0, /^([^:]+\.cs)/, arr)) {
            file = arr[1]
            errors[file] = errors[file] $0 "\n"
            file_list[file] = 1
        }
    }
    END {
        for (file in file_list) {
            print "FILE:" file
            print errors[file]
        }
    }
    ' "$error_file" > "$grouped_file"
    
    echo "$grouped_file"
}

# Get list of affected files from error output
get_affected_files() {
    local error_codes=("$@")
    local pattern=$(printf '%s|' "${error_codes[@]}")
    pattern="${pattern%|}"
    
    # Extract unique file paths
    grep -E "error ($pattern):" build_output.txt 2>/dev/null | \
        grep -oE '^[^:]+\.cs' | \
        sort -u
}

# Batch fix for CS0101 (Duplicate definitions)
batch_fix_cs0101() {
    echo "[CS0101] Starting batch fix for duplicate definitions..."
    
    local affected_files=($(get_affected_files "CS0101"))
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[CS0101] No duplicate definition errors found"
        return 0
    fi
    
    echo "[CS0101] Found ${#affected_files[@]} files with duplicate definitions"
    
    # Create patterns file
    local patterns_file="$BATCH_PATTERNS_DIR/cs0101_patterns.sed"
    cat > "$patterns_file" << 'EOF'
# Fix duplicate class definitions by adding suffix to second occurrence
s/\(class \)\([A-Za-z0-9_]*\)\(.*\n.*\)\(class \)\2\([^_]\)/\1\2\3\4\2_Duplicate\5/g

# Fix duplicate interface definitions
s/\(interface \)\([A-Za-z0-9_]*\)\(.*\n.*\)\(interface \)\2\([^_]\)/\1\2\3\4\2_Duplicate\5/g

# Fix duplicate enum definitions
s/\(enum \)\([A-Za-z0-9_]*\)\(.*\n.*\)\(enum \)\2\([^_]\)/\1\2\3\4\2_Duplicate\5/g
EOF
    
    # Backup and apply fixes
    batch_backup ".cs0101_backup" "${affected_files[@]}"
    batch_sed_multi "$patterns_file" "${affected_files[@]}"
    
    echo "[CS0101] Batch fix complete for ${#affected_files[@]} files"
}

# Batch fix for CS8618 (Nullable reference types)
batch_fix_cs8618() {
    echo "[CS8618] Starting batch fix for nullable reference types..."
    
    local affected_files=($(get_affected_files "CS8618"))
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[CS8618] No nullable reference errors found"
        return 0
    fi
    
    echo "[CS8618] Found ${#affected_files[@]} files with nullable reference issues"
    
    # Create comprehensive patterns file
    local patterns_file="$BATCH_PATTERNS_DIR/cs8618_patterns.sed"
    cat > "$patterns_file" << 'EOF'
# Fix non-nullable string properties
s/\(public\|private\|protected\|internal\) string \([A-Za-z0-9_]*\) { get; set; }/\1 string \2 { get; set; } = string.Empty;/g

# Fix non-nullable reference type properties - make nullable
s/\(public\|private\|protected\|internal\) \([A-Z][A-Za-z0-9_]*\) \([A-Za-z0-9_]*\) { get; set; }/\1 \2? \3 { get; set; }/g

# Fix non-nullable List/Collection properties
s/\(public\|private\|protected\|internal\) List<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 List<\2> \3 { get; set; } = new();/g
s/\(public\|private\|protected\|internal\) IList<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 IList<\2> \3 { get; set; } = new List<\2>();/g
s/\(public\|private\|protected\|internal\) IEnumerable<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 IEnumerable<\2> \3 { get; set; } = Enumerable.Empty<\2>();/g

# Fix non-nullable array properties
s/\(public\|private\|protected\|internal\) \([A-Za-z0-9_]*\)\[\] \([A-Za-z0-9_]*\) { get; set; }/\1 \2[] \3 { get; set; } = Array.Empty<\2>();/g

# Fix non-nullable Dictionary properties
s/\(public\|private\|protected\|internal\) Dictionary<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 Dictionary<\2> \3 { get; set; } = new();/g
EOF
    
    # Apply fixes in parallel
    batch_sed_multi "$patterns_file" "${affected_files[@]}"
    
    echo "[CS8618] Batch fix complete for ${#affected_files[@]} files"
}

# Batch fix for CS0234 (Missing namespace)
batch_fix_cs0234() {
    echo "[CS0234] Starting batch fix for missing namespaces..."
    
    local error_file=$(extract_errors_batch "CS0234")
    local namespace_map="$BATCH_FIX_CACHE/namespace_map.txt"
    
    # Extract missing types and their likely namespaces
    grep -oE "type or namespace name '([^']+)'" "$error_file" | \
        sed "s/type or namespace name '\\([^']*\\)'/\\1/" | \
        sort -u > "$BATCH_FIX_CACHE/missing_types.txt"
    
    # Map common types to namespaces
    cat > "$namespace_map" << 'EOF'
Linq:System.Linq
Task:System.Threading.Tasks
CancellationToken:System.Threading
IEnumerable:System.Collections.Generic
List:System.Collections.Generic
Dictionary:System.Collections.Generic
HttpClient:System.Net.Http
JsonSerializer:System.Text.Json
ILogger:Microsoft.Extensions.Logging
IConfiguration:Microsoft.Extensions.Configuration
DbContext:Microsoft.EntityFrameworkCore
EOF
    
    # Process each file
    local affected_files=($(get_affected_files "CS0234"))
    
    for file in "${affected_files[@]}"; do
        # Get missing types for this file
        local missing_types=$(grep "$file" "$error_file" | \
            grep -oE "type or namespace name '([^']+)'" | \
            sed "s/type or namespace name '\\([^']*\\)'/\\1/" | sort -u)
        
        # Add using statements
        local temp_file=$(mktemp)
        cp "$file" "$temp_file"
        
        # Find insertion point (after existing using statements or at beginning)
        local last_using_line=$(grep -n "^using " "$file" | tail -1 | cut -d: -f1 || echo 0)
        
        for type in $missing_types; do
            local namespace=$(grep "^$type:" "$namespace_map" | cut -d: -f2)
            if [[ -n "$namespace" ]]; then
                # Check if using already exists
                if ! grep -q "using $namespace;" "$file"; then
                    sed -i "$((last_using_line + 1))i\\using $namespace;" "$temp_file"
                    ((last_using_line++))
                fi
            fi
        done
        
        mv "$temp_file" "$file"
    done
    
    echo "[CS0234] Batch fix complete for ${#affected_files[@]} files"
}

# Batch fix for CS0103 (Name does not exist)
batch_fix_cs0103() {
    echo "[CS0103] Starting batch fix for undefined names..."
    
    local affected_files=($(get_affected_files "CS0103"))
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[CS0103] No undefined name errors found"
        return 0
    fi
    
    # Common variable name fixes
    local patterns_file="$BATCH_PATTERNS_DIR/cs0103_patterns.sed"
    cat > "$patterns_file" << 'EOF'
# Fix common typos
s/\blenght\b/length/g
s/\bLenght\b/Length/g
s\bstring\.\bempty\b/string.Empty/g
s/\bnull\.\b/null!/g
s/\bCancellationtoken\b/CancellationToken/g
s/\bcancellationtoken\b/cancellationToken/g
EOF
    
    batch_sed_multi "$patterns_file" "${affected_files[@]}"
    
    echo "[CS0103] Batch fix complete for ${#affected_files[@]} files"
}

# Batch fix for CS0111 (Duplicate member)
batch_fix_cs0111() {
    echo "[CS0111] Starting batch fix for duplicate members..."
    
    local affected_files=($(get_affected_files "CS0111"))
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[CS0111] No duplicate member errors found"
        return 0
    fi
    
    # Patterns to fix duplicate members
    local patterns_file="$BATCH_PATTERNS_DIR/cs0111_patterns.sed"
    cat > "$patterns_file" << 'EOF'
# Comment out duplicate method definitions (second occurrence)
/^[[:space:]]*\(public\|private\|protected\|internal\)[[:space:]]\+.*([^)]*)[[:space:]]*$/ {
    h
    n
    /^[[:space:]]*{/ {
        :loop
        N
        /^[[:space:]]*}[[:space:]]*$/!b loop
        # Check if this is a duplicate by looking for same signature
        g
        s/^/\/\/ Duplicate method removed: /
        p
        s/.*//
        :skip
        n
        b skip
    }
}
EOF
    
    batch_sed_multi "$patterns_file" "${affected_files[@]}"
    
    echo "[CS0111] Batch fix complete for ${#affected_files[@]} files"
}

# Batch fix for CS1061 (Missing member)
batch_fix_cs1061() {
    echo "[CS1061] Starting batch fix for missing members..."
    
    local affected_files=($(get_affected_files "CS1061"))
    if [[ ${#affected_files[@]} -eq 0 ]]; then
        echo "[CS1061] No missing member errors found"
        return 0
    fi
    
    # Extract error details for pattern generation
    local error_details="$BATCH_FIX_CACHE/cs1061_details.txt"
    grep "error CS1061:" build_output.txt > "$error_details"
    
    # Common extension method namespaces
    local extension_namespaces=(
        "System.Linq"
        "System.Threading.Tasks"
        "Microsoft.EntityFrameworkCore"
    )
    
    # Add common using statements for extension methods
    for file in "${affected_files[@]}"; do
        for ns in "${extension_namespaces[@]}"; do
            if ! grep -q "using $ns;" "$file"; then
                sed -i "1i\\using $ns;" "$file"
            fi
        done
    done
    
    echo "[CS1061] Batch fix complete for ${#affected_files[@]} files"
}

# Master batch fix function
batch_fix_all_errors() {
    echo "Starting comprehensive batch error fixing..."
    
    local start_time=$(date +%s)
    
    # Run all batch fixes in order of priority
    batch_fix_cs0234  # Fix missing namespaces first
    batch_fix_cs8618  # Fix nullable references
    batch_fix_cs0101  # Fix duplicate definitions
    batch_fix_cs0111  # Fix duplicate members
    batch_fix_cs0103  # Fix undefined names
    batch_fix_cs1061  # Fix missing members
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Batch fixing complete in ${duration} seconds"
    
    # Clean up old cache files
    find "$BATCH_FIX_CACHE" -type f -mtime +1 -delete 2>/dev/null || true
    find "$BATCH_PATTERNS_DIR" -type f -mtime +7 -delete 2>/dev/null || true
}

# Utility to update all fix agents to use batch operations
update_fix_agents_for_batch() {
    local agents=(
        "agent1_duplicate_resolver.sh"
        "agent2_constraints_specialist.sh"
        "agent3_inheritance_specialist.sh"
        "generic_error_agent.sh"
    )
    
    for agent in "${agents[@]}"; do
        if [[ -f "$SCRIPT_DIR/$agent" ]]; then
            # Check if already sources batch lib
            if ! grep -q "fix_agent_batch_lib.sh" "$agent"; then
                # Add source line after shebang
                sed -i '2i\source "$(dirname "${BASH_SOURCE[0]}")/fix_agent_batch_lib.sh"' "$agent"
                echo "Updated $agent to use batch operations"
            fi
        fi
    done
}

# Export all batch fix functions
export -f extract_errors_batch
export -f group_errors_by_file
export -f get_affected_files
export -f batch_fix_cs0101
export -f batch_fix_cs8618
export -f batch_fix_cs0234
export -f batch_fix_cs0103
export -f batch_fix_cs0111
export -f batch_fix_cs1061
export -f batch_fix_all_errors

echo "Fix agent batch operations library loaded"