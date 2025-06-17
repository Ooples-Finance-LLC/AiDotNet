#!/bin/bash

# Enhanced Generic Build Error Analyzer with Sampling Support
# Optimized for large codebases with intelligent error sampling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SAMPLING_THRESHOLD=${SAMPLING_THRESHOLD:-1000}  # Enable sampling above this error count
SAMPLE_SIZE=${SAMPLE_SIZE:-100}  # Number of unique error types to sample
PATTERN_CACHE_DIR="$SCRIPT_DIR/state/pattern_cache"
ENABLE_SAMPLING=${ENABLE_SAMPLING:-true}

# Source original analyzer for base functionality
source "$SCRIPT_DIR/generic_build_analyzer.sh"

# Create cache directory
mkdir -p "$PATTERN_CACHE_DIR"

# Enhanced logging
log_sampling() {
    log_message "[SAMPLING] $1"
}

# Count total errors efficiently
count_total_errors() {
    local count=0
    if [[ -f "$BUILD_OUTPUT_FILE" ]]; then
        # Use multiple patterns for different languages
        count=$(grep -cE "(error|Error|ERROR|failed|Failed|FAILED)" "$BUILD_OUTPUT_FILE" || echo 0)
    fi
    echo "$count"
}

# Extract error patterns with frequency
extract_error_patterns() {
    local output_file="$1"
    log_sampling "Extracting error patterns with frequency..."
    
    # Extract different error patterns based on language
    {
        # C# errors (CS####)
        grep -oE 'error CS[0-9]{4}' "$BUILD_OUTPUT_FILE" 2>/dev/null | sort | uniq -c | sort -nr || true
        
        # Generic compilation errors
        grep -oE '(error|Error):[[:space:]]*[A-Z][A-Za-z0-9_]*' "$BUILD_OUTPUT_FILE" 2>/dev/null | \
            sed 's/.*:[[:space:]]*//' | sort | uniq -c | sort -nr || true
        
        # Python errors
        grep -oE '[A-Za-z]*Error:' "$BUILD_OUTPUT_FILE" 2>/dev/null | sort | uniq -c | sort -nr || true
        
        # TypeScript/JavaScript errors
        grep -oE 'TS[0-9]{4}:' "$BUILD_OUTPUT_FILE" 2>/dev/null | sort | uniq -c | sort -nr || true
        
        # Go errors
        grep -oE 'undefined:|cannot use|missing return|declared but not used' "$BUILD_OUTPUT_FILE" 2>/dev/null | \
            sort | uniq -c | sort -nr || true
    } > "$output_file"
}

# Sample representative errors
sample_errors() {
    local pattern_file="$1"
    local sampled_file="$2"
    
    log_sampling "Sampling top $SAMPLE_SIZE error patterns..."
    
    # Get top error patterns
    head -n "$SAMPLE_SIZE" "$pattern_file" > "$sampled_file"
    
    # For each pattern, extract a few example instances
    local examples_file="${sampled_file}.examples"
    > "$examples_file"
    
    while read -r count pattern; do
        echo "=== Pattern: $pattern (Count: $count) ===" >> "$examples_file"
        # Extract up to 3 examples of this error pattern
        grep -m 3 "$pattern" "$BUILD_OUTPUT_FILE" >> "$examples_file" 2>/dev/null || true
        echo "" >> "$examples_file"
    done < "$sampled_file"
    
    log_sampling "Sampled $(wc -l < "$sampled_file") unique error patterns"
}

# Generate fix patterns from sampled errors
generate_fix_patterns() {
    local sampled_file="$1"
    local patterns_file="$2"
    
    log_sampling "Generating fix patterns from samples..."
    
    cat > "$patterns_file" << 'EOF'
{
  "fix_patterns": {
EOF
    
    local first=true
    while read -r count pattern; do
        [[ "$first" == "false" ]] && echo "," >> "$patterns_file"
        first=false
        
        # Generate fix pattern based on error type
        case "$pattern" in
            *CS0101*)
                cat >> "$patterns_file" << EOF
    "CS0101_duplicate": {
      "pattern": "CS0101",
      "frequency": $count,
      "fix_strategy": "rename_duplicates",
      "confidence": 0.95,
      "bulk_fix": true,
      "command": "sed -i 's/class \\([A-Za-z0-9_]*\\)\\(.*\\)class \\1/class \\1\\2class \\1_2/g'"
    }
EOF
                ;;
            *CS8618*)
                cat >> "$patterns_file" << EOF
    "CS8618_nullable": {
      "pattern": "CS8618",
      "frequency": $count,
      "fix_strategy": "add_nullable_annotation",
      "confidence": 0.90,
      "bulk_fix": true,
      "command": "sed -i 's/{ get; set; }/{ get; set; } = default!/g'"
    }
EOF
                ;;
            *CS0234*)
                cat >> "$patterns_file" << EOF
    "CS0234_namespace": {
      "pattern": "CS0234",
      "frequency": $count,
      "fix_strategy": "add_using_statement",
      "confidence": 0.85,
      "bulk_fix": false,
      "requires_analysis": true
    }
EOF
                ;;
            *undefined*)
                cat >> "$patterns_file" << EOF
    "undefined_reference": {
      "pattern": "undefined",
      "frequency": $count,
      "fix_strategy": "resolve_references",
      "confidence": 0.80,
      "bulk_fix": false,
      "requires_analysis": true
    }
EOF
                ;;
        esac
    done < <(head -20 "$sampled_file")  # Process top 20 patterns
    
    echo -e "\n  }\n}" >> "$patterns_file"
}

# Apply bulk fixes based on patterns
apply_bulk_fixes() {
    local patterns_file="$1"
    local fixed_count=0
    
    log_sampling "Applying bulk fixes based on patterns..."
    
    # Extract bulk-fixable patterns
    local bulk_patterns=$(jq -r '.fix_patterns | to_entries[] | select(.value.bulk_fix == true) | .key' "$patterns_file" 2>/dev/null)
    
    for pattern_key in $bulk_patterns; do
        local command=$(jq -r ".fix_patterns.$pattern_key.command" "$patterns_file" 2>/dev/null)
        local confidence=$(jq -r ".fix_patterns.$pattern_key.confidence" "$patterns_file" 2>/dev/null)
        
        if [[ -n "$command" ]] && [[ $(echo "$confidence > 0.85" | bc -l) -eq 1 ]]; then
            log_sampling "Applying bulk fix for $pattern_key (confidence: $confidence)"
            # Note: In production, you'd apply this to actual source files
            # For now, we're just counting potential fixes
            local potential_fixes=$(jq -r ".fix_patterns.$pattern_key.frequency" "$patterns_file")
            fixed_count=$((fixed_count + potential_fixes))
        fi
    done
    
    log_sampling "Bulk fixes could resolve approximately $fixed_count errors"
    echo "$fixed_count"
}

# Enhanced analyze function with sampling
analyze_error_patterns_with_sampling() {
    local language="${1:-$(detect_language)}"
    local total_errors=$(count_total_errors)
    
    log_message "Total errors found: $total_errors"
    
    # Check if sampling should be used
    if [[ "$ENABLE_SAMPLING" == "true" ]] && [[ $total_errors -gt $SAMPLING_THRESHOLD ]]; then
        log_sampling "Large error count detected. Enabling intelligent sampling..."
        
        # Create temporary files for sampling
        local pattern_file="$PATTERN_CACHE_DIR/error_patterns_$(date +%s).txt"
        local sampled_file="$PATTERN_CACHE_DIR/sampled_errors_$(date +%s).txt"
        local fix_patterns_file="$PATTERN_CACHE_DIR/fix_patterns_$(date +%s).json"
        
        # Extract and sample error patterns
        extract_error_patterns "$pattern_file"
        sample_errors "$pattern_file" "$sampled_file"
        generate_fix_patterns "$sampled_file" "$fix_patterns_file"
        
        # Apply bulk fixes (simulation)
        local fixes_applied=$(apply_bulk_fixes "$fix_patterns_file")
        
        # Generate enhanced analysis with sampling results
        generate_sampled_analysis "$language" "$total_errors" "$sampled_file" "$fix_patterns_file"
        
        # Clean up old pattern files (keep last 10)
        ls -t "$PATTERN_CACHE_DIR"/error_patterns_*.txt 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    else
        # Use original analysis for smaller error counts
        analyze_error_patterns "$language"
    fi
}

# Generate analysis report with sampling results
generate_sampled_analysis() {
    local language="$1"
    local total_errors="$2"
    local sampled_file="$3"
    local fix_patterns_file="$4"
    
    # Start JSON structure
    cat > "$ERROR_ANALYSIS_FILE" << EOF
{
  "analysis_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "total_errors": $total_errors,
  "sampling_enabled": true,
  "sample_size": $SAMPLE_SIZE,
  "error_patterns": {
EOF
    
    # Add top error patterns
    local first=true
    while read -r count pattern; do
        [[ "$first" == "false" ]] && echo "," >> "$ERROR_ANALYSIS_FILE"
        first=false
        
        cat >> "$ERROR_ANALYSIS_FILE" << EOF
    "$pattern": {
      "count": $count,
      "percentage": $(echo "scale=2; $count * 100 / $total_errors" | bc -l),
      "fixable": $(jq -r ".fix_patterns | to_entries[] | select(.value.pattern == \"$pattern\") | .value.bulk_fix" "$fix_patterns_file" 2>/dev/null || echo "false")
    }
EOF
    done < <(head -10 "$sampled_file")
    
    # Add fix recommendations
    cat >> "$ERROR_ANALYSIS_FILE" << EOF
  },
  "fix_recommendations": $(jq '.fix_patterns' "$fix_patterns_file"),
  "estimated_auto_fixable": $(jq '[.fix_patterns[] | select(.bulk_fix == true) | .frequency] | add' "$fix_patterns_file"),
  "optimization_notes": {
    "sampling_used": true,
    "reason": "Error count exceeded threshold ($SAMPLING_THRESHOLD)",
    "confidence": "High - based on top $SAMPLE_SIZE error patterns",
    "recommended_action": "Apply bulk fixes first, then re-analyze"
  }
}
EOF
}

# Override main function to use enhanced analysis
main() {
    cd "$PROJECT_DIR"
    
    log_message "Starting enhanced build analysis with sampling support..."
    log_message "Project directory: $PROJECT_DIR"
    
    # Run build and capture output
    if ! run_build; then
        log_message "Build failed. Analyzing errors..."
    fi
    
    # Use enhanced analysis with sampling
    analyze_error_patterns_with_sampling
    
    # Generate agent specifications
    generate_agent_specifications
    
    log_message "Enhanced analysis complete. Results saved to $ERROR_ANALYSIS_FILE"
}

# Export enhanced functions
export -f analyze_error_patterns_with_sampling
export -f count_total_errors
export -f sample_errors

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi