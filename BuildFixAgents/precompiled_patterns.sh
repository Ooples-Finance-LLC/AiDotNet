#!/bin/bash

# Pre-compiled Fix Patterns - Fast pattern application for common errors
# Stores optimized, ready-to-apply fixes for instant execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DIR="$SCRIPT_DIR/state/precompiled_patterns"
COMPILED_DIR="$PATTERNS_DIR/compiled"
CACHE_DIR="$PATTERNS_DIR/cache"
METRICS_FILE="$PATTERNS_DIR/metrics.json"

# Create directories
mkdir -p "$COMPILED_DIR" "$CACHE_DIR"

# Initialize metrics
[[ ! -f "$METRICS_FILE" ]] && echo '{"cache_hits": 0, "cache_misses": 0, "compile_time_saved": 0}' > "$METRICS_FILE"

# Pre-compiled pattern structure
create_pattern_template() {
    local error_code="$1"
    local pattern_name="$2"
    local pattern_file="$COMPILED_DIR/${error_code}_${pattern_name}.pattern"
    
    cat > "$pattern_file" << EOF
#!/bin/bash
# Pre-compiled pattern for $error_code - $pattern_name
# Generated: $(date -Iseconds)

ERROR_CODE="$error_code"
PATTERN_NAME="$pattern_name"
PATTERN_VERSION="1.0"

# Pattern metadata
PATTERN_META='{
    "error_code": "'$error_code'",
    "name": "'$pattern_name'",
    "type": "precompiled",
    "performance": "optimized",
    "batch_capable": true
}'

# Pre-validated file selector
get_target_files() {
    # Optimized file selection for $error_code
    find . -name "*.cs" -type f | xargs grep -l "error $ERROR_CODE:" 2>/dev/null || true
}

# Apply pattern with minimal overhead
apply_pattern() {
    local files=(\$@)
    # Pattern-specific implementation goes here
}

# Export for use
export -f get_target_files
export -f apply_pattern
EOF
    
    chmod +x "$pattern_file"
    echo "$pattern_file"
}

# Compile common C# error patterns
compile_csharp_patterns() {
    echo "Compiling C# error patterns..."
    
    # CS8618 - Nullable reference types
    cat > "$COMPILED_DIR/CS8618_nullable_fix.pattern" << 'EOF'
#!/bin/bash
ERROR_CODE="CS8618"
PATTERN_NAME="nullable_fix"

# Pre-compiled sed expressions
declare -A NULLABLE_PATTERNS=(
    ["string_property"]='s/\(public\|private\|protected\|internal\) string \([A-Za-z0-9_]*\) { get; set; }/\1 string \2 { get; set; } = string.Empty;/g'
    ["list_property"]='s/\(public\|private\|protected\|internal\) List<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 List<\2> \3 { get; set; } = new();/g'
    ["array_property"]='s/\(public\|private\|protected\|internal\) \([A-Za-z0-9_]*\)\[\] \([A-Za-z0-9_]*\) { get; set; }/\1 \2[] \3 { get; set; } = Array.Empty<\2>();/g'
    ["reference_nullable"]='s/\(public\|private\|protected\|internal\) \([A-Z][A-Za-z0-9_]*\) \([A-Za-z0-9_]*\) { get; set; }/\1 \2? \3 { get; set; }/g'
)

apply_pattern() {
    local files=("$@")
    
    # Create combined sed script for efficiency
    local sed_script=$(mktemp)
    for pattern in "${NULLABLE_PATTERNS[@]}"; do
        echo "$pattern" >> "$sed_script"
    done
    
    # Apply in parallel
    printf '%s\0' "${files[@]}" | xargs -0 -P 8 -I {} sed -i -f "$sed_script" {}
    
    rm -f "$sed_script"
}

# Batch mode
apply_pattern_batch() {
    local error_file="$1"
    
    # Extract unique files with CS8618 errors
    local files=($(grep "error CS8618:" "$error_file" | cut -d: -f1 | sort -u))
    
    if [[ ${#files[@]} -gt 0 ]]; then
        apply_pattern "${files[@]}"
    fi
}

export -f apply_pattern
export -f apply_pattern_batch
EOF
    
    # CS0101 - Duplicate definitions
    cat > "$COMPILED_DIR/CS0101_duplicate_fix.pattern" << 'EOF'
#!/bin/bash
ERROR_CODE="CS0101"
PATTERN_NAME="duplicate_fix"

# Pre-analyzed duplicate patterns
apply_pattern() {
    local files=("$@")
    
    for file in "${files[@]}"; do
        # Fast duplicate detection using awk
        awk '
        /^[[:space:]]*(public|private|protected|internal)[[:space:]]+(class|interface|enum)[[:space:]]+[A-Za-z0-9_]+/ {
            match($0, /(class|interface|enum)[[:space:]]+([A-Za-z0-9_]+)/, arr)
            if (arr[2] in seen) {
                # Comment out duplicate
                print "// Duplicate removed: " $0
                in_duplicate = 1
                brace_count = 0
            } else {
                seen[arr[2]] = 1
                print $0
                in_duplicate = 0
            }
            next
        }
        in_duplicate && /{/ { brace_count++ }
        in_duplicate && /}/ { 
            brace_count--
            if (brace_count == 0) {
                in_duplicate = 0
                next
            }
        }
        !in_duplicate { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    done
}

export -f apply_pattern
EOF
    
    # CS0234 - Missing namespace
    cat > "$COMPILED_DIR/CS0234_namespace_fix.pattern" << 'EOF'
#!/bin/bash
ERROR_CODE="CS0234"
PATTERN_NAME="namespace_fix"

# Pre-mapped common namespaces
declare -A NAMESPACE_MAP=(
    ["List"]="System.Collections.Generic"
    ["Dictionary"]="System.Collections.Generic"
    ["Task"]="System.Threading.Tasks"
    ["CancellationToken"]="System.Threading"
    ["Linq"]="System.Linq"
    ["HttpClient"]="System.Net.Http"
    ["JsonSerializer"]="System.Text.Json"
    ["ILogger"]="Microsoft.Extensions.Logging"
    ["DbContext"]="Microsoft.EntityFrameworkCore"
)

apply_pattern() {
    local files=("$@")
    
    for file in "${files[@]}"; do
        # Extract missing types
        local missing_types=$(grep -h "error CS0234:" build_output.txt | \
            grep "$file" | \
            grep -oE "type or namespace name '[^']+'" | \
            sed "s/type or namespace name '\\([^']*\\)'/\\1/" | sort -u)
        
        # Add using statements
        for type in $missing_types; do
            if [[ -n "${NAMESPACE_MAP[$type]}" ]]; then
                local namespace="${NAMESPACE_MAP[$type]}"
                if ! grep -q "using $namespace;" "$file"; then
                    sed -i "1i\\using $namespace;" "$file"
                fi
            fi
        done
    done
}

export -f apply_pattern
EOF
    
    # Make all patterns executable
    chmod +x "$COMPILED_DIR"/*.pattern
    
    echo "Compiled $(ls -1 "$COMPILED_DIR"/*.pattern 2>/dev/null | wc -l) patterns"
}

# Quick pattern lookup
get_precompiled_pattern() {
    local error_code="$1"
    local strategy="${2:-default}"
    
    # Check cache first
    local cache_key="${error_code}_${strategy}"
    local cache_file="$CACHE_DIR/${cache_key}.cache"
    
    if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -60 -type f 2>/dev/null) ]]; then
        # Cache hit
        jq '.cache_hits += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        cat "$cache_file"
        return 0
    fi
    
    # Cache miss
    jq '.cache_misses += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
    
    # Find best matching pattern
    local pattern_file=""
    
    case "$strategy" in
        "fast")
            # Prefer optimized patterns
            pattern_file=$(ls -1 "$COMPILED_DIR/${error_code}_"*_fast.pattern 2>/dev/null | head -1)
            ;;
        "safe")
            # Prefer conservative patterns
            pattern_file=$(ls -1 "$COMPILED_DIR/${error_code}_"*_safe.pattern 2>/dev/null | head -1)
            ;;
        *)
            # Default pattern
            pattern_file=$(ls -1 "$COMPILED_DIR/${error_code}_"*.pattern 2>/dev/null | head -1)
            ;;
    esac
    
    if [[ -f "$pattern_file" ]]; then
        # Cache for next time
        echo "$pattern_file" > "$cache_file"
        echo "$pattern_file"
        return 0
    fi
    
    return 1
}

# Apply pre-compiled pattern
apply_precompiled() {
    local error_code="$1"
    local files=("${@:2}")
    
    local start_time=$(date +%s.%N)
    
    # Get pattern
    local pattern_file=$(get_precompiled_pattern "$error_code")
    
    if [[ -z "$pattern_file" ]] || [[ ! -f "$pattern_file" ]]; then
        echo "[PRECOMPILED] No pre-compiled pattern for $error_code"
        return 1
    fi
    
    echo "[PRECOMPILED] Using pattern: $(basename "$pattern_file")"
    
    # Source and apply pattern
    source "$pattern_file"
    
    if [[ ${#files[@]} -eq 0 ]]; then
        # Auto-detect files
        files=($(get_target_files 2>/dev/null))
    fi
    
    if [[ ${#files[@]} -gt 0 ]]; then
        apply_pattern "${files[@]}"
        local exit_code=$?
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        # Update metrics
        jq --arg duration "$duration" '.compile_time_saved += ($duration | tonumber)' "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        
        echo "[PRECOMPILED] Applied to ${#files[@]} files in ${duration}s"
        return $exit_code
    else
        echo "[PRECOMPILED] No files to process"
        return 0
    fi
}

# Benchmark pattern performance
benchmark_pattern() {
    local error_code="$1"
    local test_files=("${@:2}")
    
    echo "Benchmarking patterns for $error_code..."
    
    # Test pre-compiled version
    local pc_start=$(date +%s.%N)
    apply_precompiled "$error_code" "${test_files[@]}"
    local pc_end=$(date +%s.%N)
    local pc_duration=$(echo "$pc_end - $pc_start" | bc)
    
    # Test dynamic version (if available)
    local dyn_duration="N/A"
    if command -v "$SCRIPT_DIR/dynamic_fix_agent.sh" >/dev/null 2>&1; then
        local dyn_start=$(date +%s.%N)
        "$SCRIPT_DIR/dynamic_fix_agent.sh" "$error_code" 1 "auto" >/dev/null 2>&1
        local dyn_end=$(date +%s.%N)
        dyn_duration=$(echo "$dyn_end - $dyn_start" | bc)
    fi
    
    echo "Results:"
    echo "  Pre-compiled: ${pc_duration}s"
    echo "  Dynamic: ${dyn_duration}s"
    
    if [[ "$dyn_duration" != "N/A" ]]; then
        local speedup=$(echo "scale=2; $dyn_duration / $pc_duration" | bc)
        echo "  Speedup: ${speedup}x"
    fi
}

# Generate pattern from learning database
generate_from_learning() {
    if [[ ! -f "$SCRIPT_DIR/pattern_learning_db.sh" ]]; then
        echo "Pattern learning database not available"
        return 1
    fi
    
    source "$SCRIPT_DIR/pattern_learning_db.sh"
    
    # Get top patterns
    local error_codes=$(jq -r '.error_map | keys[]' "$INDEX_FILE" 2>/dev/null | head -20)
    
    for error_code in $error_codes; do
        local best_pattern=$(get_best_pattern "$error_code")
        if [[ "$best_pattern" != "{}" ]]; then
            local pattern_content=$(echo "$best_pattern" | jq -r '.content')
            local success_rate=$(echo "$best_pattern" | jq -r '.success_rate')
            
            if (( $(echo "$success_rate > 0.8" | bc -l) )); then
                echo "Generating pre-compiled pattern for $error_code (${success_rate} success rate)"
                
                # Create optimized pattern
                local pattern_file="$COMPILED_DIR/${error_code}_learned.pattern"
                cat > "$pattern_file" << EOF
#!/bin/bash
# Auto-generated from learning database
ERROR_CODE="$error_code"
PATTERN_NAME="learned"
SUCCESS_RATE="$success_rate"

apply_pattern() {
    local files=("\$@")
    # Learned pattern
    $pattern_content
}

export -f apply_pattern
EOF
                chmod +x "$pattern_file"
            fi
        fi
    done
}

# Show statistics
show_stats() {
    echo "=== Pre-compiled Patterns Statistics ==="
    echo "Patterns Directory: $PATTERNS_DIR"
    echo ""
    
    # Pattern count
    local pattern_count=$(ls -1 "$COMPILED_DIR"/*.pattern 2>/dev/null | wc -l)
    echo "Total Patterns: $pattern_count"
    
    # Pattern breakdown
    echo ""
    echo "Patterns by Error Code:"
    for pattern in "$COMPILED_DIR"/*.pattern; do
        if [[ -f "$pattern" ]]; then
            local error_code=$(basename "$pattern" | cut -d_ -f1)
            echo "  $error_code: $(ls -1 "$COMPILED_DIR/${error_code}_"*.pattern 2>/dev/null | wc -l)"
        fi
    done | sort -u
    
    # Performance metrics
    echo ""
    echo "Performance Metrics:"
    jq -r 'to_entries[] | "  \(.key): \(.value)"' "$METRICS_FILE"
    
    # Cache status
    echo ""
    echo "Cache Status:"
    local cache_files=$(ls -1 "$CACHE_DIR"/*.cache 2>/dev/null | wc -l)
    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "  Cached Lookups: $cache_files"
    echo "  Cache Size: $cache_size"
}

# Main function
main() {
    case "${1:-help}" in
        compile)
            compile_csharp_patterns
            ;;
        apply)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 apply <error_code> [files...]"
                exit 1
            fi
            apply_precompiled "$2" "${@:3}"
            ;;
        get)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 get <error_code> [strategy]"
                exit 1
            fi
            get_precompiled_pattern "$2" "${3:-default}"
            ;;
        benchmark)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 benchmark <error_code> [test_files...]"
                exit 1
            fi
            benchmark_pattern "$2" "${@:3}"
            ;;
        generate)
            generate_from_learning
            ;;
        stats)
            show_stats
            ;;
        clean)
            rm -f "$CACHE_DIR"/*.cache
            echo "Cache cleaned"
            ;;
        *)
            cat << EOF
Pre-compiled Fix Patterns - Fast pattern application

Usage: $0 <command> [options]

Commands:
  compile              - Compile standard patterns
  apply <code> [files] - Apply pre-compiled pattern
  get <code> [strategy] - Get pattern file path
  benchmark <code>     - Benchmark pattern performance
  generate             - Generate from learning database
  stats                - Show statistics
  clean                - Clear cache

Examples:
  # Compile all patterns
  $0 compile
  
  # Apply pattern to specific files
  $0 apply CS8618 src/Model.cs src/Entity.cs
  
  # Benchmark performance
  $0 benchmark CS8618
  
  # Show statistics
  $0 stats
EOF
            ;;
    esac
}

# Export functions
export -f get_precompiled_pattern
export -f apply_precompiled

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi