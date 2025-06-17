#!/bin/bash

# Batch File Operations Library
# Optimized functions for processing multiple files efficiently

set -euo pipefail

# Configuration
MAX_PARALLEL_OPERATIONS=${MAX_PARALLEL_OPERATIONS:-8}
BATCH_SIZE=${BATCH_SIZE:-100}
USE_GNU_PARALLEL=${USE_GNU_PARALLEL:-true}

# Check for GNU parallel
HAS_PARALLEL=false
if command -v parallel >/dev/null 2>&1 && [[ "$USE_GNU_PARALLEL" == "true" ]]; then
    HAS_PARALLEL=true
fi

# Batch sed operations on multiple files
batch_sed() {
    local pattern="$1"
    shift
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    
    if [[ "$HAS_PARALLEL" == "true" ]]; then
        # Use GNU parallel for maximum performance
        printf '%s\n' "${files[@]}" | \
            parallel -j "$MAX_PARALLEL_OPERATIONS" --bar \
            "sed -i '$pattern' {}"
    else
        # Use xargs with parallel processing
        printf '%s\0' "${files[@]}" | \
            xargs -0 -P "$MAX_PARALLEL_OPERATIONS" -I {} \
            sed -i "$pattern" {}
    fi
}

# Batch sed with multiple patterns
batch_sed_multi() {
    local patterns_file="$1"
    shift
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]] || [[ ! -f "$patterns_file" ]]; then
        return 0
    fi
    
    if [[ "$HAS_PARALLEL" == "true" ]]; then
        # Apply all patterns to each file in parallel
        printf '%s\n' "${files[@]}" | \
            parallel -j "$MAX_PARALLEL_OPERATIONS" --bar \
            "sed -i -f '$patterns_file' {}"
    else
        # Process in batches
        local i
        for ((i=0; i<${#files[@]}; i+=BATCH_SIZE)); do
            local batch=("${files[@]:i:BATCH_SIZE}")
            printf '%s\0' "${batch[@]}" | \
                xargs -0 -P "$MAX_PARALLEL_OPERATIONS" -I {} \
                sed -i -f "$patterns_file" {}
        done
    fi
}

# Batch grep operations
batch_grep() {
    local pattern="$1"
    local output_file="$2"
    shift 2
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    
    > "$output_file"  # Clear output file
    
    if [[ "$HAS_PARALLEL" == "true" ]]; then
        printf '%s\n' "${files[@]}" | \
            parallel -j "$MAX_PARALLEL_OPERATIONS" --keep-order \
            "grep -H '$pattern' {} 2>/dev/null || true" >> "$output_file"
    else
        # Use xargs with parallel grep
        printf '%s\0' "${files[@]}" | \
            xargs -0 -P "$MAX_PARALLEL_OPERATIONS" \
            grep -H "$pattern" 2>/dev/null >> "$output_file" || true
    fi
}

# Batch file content replacement
batch_replace_content() {
    local old_content_file="$1"
    local new_content_file="$2"
    shift 2
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    
    # Create awk script for complex replacement
    local awk_script=$(mktemp)
    cat > "$awk_script" << 'EOF'
BEGIN {
    # Read old content
    while ((getline line < old_file) > 0) {
        old_content = old_content (old_content ? "\n" : "") line
    }
    close(old_file)
    
    # Read new content
    while ((getline line < new_file) > 0) {
        new_content = new_content (new_content ? "\n" : "") line
    }
    close(new_file)
}
{
    # Store entire file
    content = content (content ? "\n" : "") $0
}
END {
    # Replace old with new
    gsub(old_content, new_content, content)
    print content
}
EOF
    
    # Process files in parallel
    for file in "${files[@]}"; do
        (
            awk -v old_file="$old_content_file" -v new_file="$new_content_file" \
                -f "$awk_script" "$file" > "$file.tmp" && \
            mv "$file.tmp" "$file"
        ) &
        
        # Limit parallel jobs
        while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL_OPERATIONS ]]; do
            sleep 0.1
        done
    done
    
    wait
    rm -f "$awk_script"
}

# Batch file backup before operations
batch_backup() {
    local backup_suffix="${1:-.backup}"
    shift
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    
    if [[ "$HAS_PARALLEL" == "true" ]]; then
        printf '%s\n' "${files[@]}" | \
            parallel -j "$MAX_PARALLEL_OPERATIONS" \
            "cp {} {}{}"  ::: "$backup_suffix"
    else
        for file in "${files[@]}"; do
            cp "$file" "${file}${backup_suffix}" &
            
            while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL_OPERATIONS ]]; do
                sleep 0.1
            done
        done
        wait
    fi
}

# Batch apply fix patterns
batch_apply_fixes() {
    local fix_type="$1"
    shift
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    
    case "$fix_type" in
        "CS0101_duplicate")
            # Fix duplicate class definitions
            batch_sed 's/\(public\|private\|internal\) class \([A-Za-z0-9_]*\)\(.*\)\n\s*\(public\|private\|internal\) class \2/\1 class \2\3\n\4 class \2_2/g' "${files[@]}"
            ;;
            
        "CS8618_nullable")
            # Fix nullable reference types
            local patterns_file=$(mktemp)
            cat > "$patterns_file" << 'EOF'
s/\(public\|private\|protected\) \([A-Za-z0-9_<>]*\) \([A-Za-z0-9_]*\) { get; set; }/\1 \2? \3 { get; set; } = default!/g
s/\(public\|private\|protected\) string \([A-Za-z0-9_]*\) { get; set; }/\1 string \2 { get; set; } = string.Empty;/g
s/\(public\|private\|protected\) List<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 List<\2> \3 { get; set; } = new();/g
EOF
            batch_sed_multi "$patterns_file" "${files[@]}"
            rm -f "$patterns_file"
            ;;
            
        "CS0234_namespace")
            # Add common using statements
            local temp_file=$(mktemp)
            for file in "${files[@]}"; do
                # Check if using statements are missing
                if ! grep -q "using System.Linq;" "$file"; then
                    echo "using System.Linq;" > "$temp_file"
                    cat "$file" >> "$temp_file"
                    mv "$temp_file" "$file"
                fi &
                
                while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL_OPERATIONS ]]; do
                    sleep 0.1
                done
            done
            wait
            ;;
            
        "indent_fix")
            # Fix indentation in parallel
            if command -v clang-format >/dev/null 2>&1; then
                printf '%s\0' "${files[@]}" | \
                    xargs -0 -P "$MAX_PARALLEL_OPERATIONS" -I {} \
                    clang-format -i {}
            fi
            ;;
    esac
}

# Batch file analysis
batch_analyze_files() {
    local analysis_type="$1"
    local output_dir="$2"
    shift 2
    local files=("$@")
    
    mkdir -p "$output_dir"
    
    case "$analysis_type" in
        "complexity")
            # Analyze code complexity
            for file in "${files[@]}"; do
                (
                    local base_name=$(basename "$file")
                    local output_file="$output_dir/${base_name}.complexity"
                    
                    # Simple complexity analysis
                    {
                        echo "File: $file"
                        echo "Lines: $(wc -l < "$file")"
                        echo "Functions: $(grep -c "^\s*\(public\|private\|protected\|internal\).*(" "$file" || echo 0)"
                        echo "Classes: $(grep -c "^\s*\(public\|private\|protected\|internal\) class" "$file" || echo 0)"
                        echo "Interfaces: $(grep -c "^\s*\(public\|private\|protected\|internal\) interface" "$file" || echo 0)"
                    } > "$output_file"
                ) &
                
                while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL_OPERATIONS ]]; do
                    sleep 0.1
                done
            done
            wait
            ;;
            
        "errors")
            # Extract errors related to each file
            batch_grep "error CS[0-9]" "$output_dir/errors.txt" "${files[@]}"
            ;;
    esac
}

# Optimized file finding
find_files_parallel() {
    local pattern="$1"
    local directory="${2:-.}"
    local output_file="${3:-/dev/stdout}"
    
    if [[ "$HAS_PARALLEL" == "true" ]]; then
        # Use parallel find for large directories
        find "$directory" -type d -print0 2>/dev/null | \
            parallel -0 -j "$MAX_PARALLEL_OPERATIONS" \
            "find {} -maxdepth 1 -name '$pattern' -type f 2>/dev/null" > "$output_file"
    else
        # Standard find
        find "$directory" -name "$pattern" -type f 2>/dev/null > "$output_file"
    fi
}

# Export functions for use in other scripts
export -f batch_sed
export -f batch_sed_multi
export -f batch_grep
export -f batch_replace_content
export -f batch_backup
export -f batch_apply_fixes
export -f batch_analyze_files
export -f find_files_parallel

# Test if GNU parallel is available
if [[ "$HAS_PARALLEL" == "true" ]]; then
    echo "Batch operations library loaded with GNU Parallel support"
else
    echo "Batch operations library loaded (using xargs for parallel processing)"
fi