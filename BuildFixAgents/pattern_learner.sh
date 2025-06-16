#!/bin/bash

# Pattern Learning System
# Learns new patterns from successful fixes and improves existing ones

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DIR="$SCRIPT_DIR/patterns"
LEARNING_DIR="$PATTERNS_DIR/learning"
HISTORY_DIR="$LEARNING_DIR/history"
MODELS_DIR="$LEARNING_DIR/models"

# Create directory structure
mkdir -p "$HISTORY_DIR" "$MODELS_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LEARNING_THRESHOLD=3  # Minimum successful fixes before pattern is learned
CONFIDENCE_INCREMENT=0.05  # How much to increase confidence per success
MAX_CONFIDENCE=0.95  # Maximum confidence level

# Log functions
log() {
    echo -e "${BLUE}[LEARNER]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Initialize learning database
init_learning_db() {
    local db_file="$LEARNING_DIR/learning_database.json"
    
    if [[ ! -f "$db_file" ]]; then
        cat > "$db_file" << EOF
{
  "version": "1.0.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "statistics": {
    "total_fixes_tracked": 0,
    "patterns_learned": 0,
    "patterns_improved": 0,
    "languages": {}
  },
  "learned_patterns": {},
  "fix_history": []
}
EOF
        log "Initialized learning database"
    fi
}

# Record a successful fix
record_successful_fix() {
    local language=$1
    local error_code=$2
    local fix_type=$3
    local file_path=$4
    local context=${5:-""}
    
    log "Recording successful fix: $language/$error_code using $fix_type"
    
    # Create fix record
    local fix_id="fix_$(date +%s)_$$"
    local fix_record="$HISTORY_DIR/${fix_id}.json"
    
    cat > "$fix_record" << EOF
{
  "fix_id": "$fix_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "error_code": "$error_code",
  "fix_type": "$fix_type",
  "file_path": "$file_path",
  "context": {
    "before": "$(capture_context_before "$file_path")",
    "after": "$(capture_context_after "$file_path")",
    "error_message": "$context"
  },
  "environment": {
    "os": "$(uname -s)",
    "compiler_version": "$(get_compiler_version "$language")",
    "project_type": "$(detect_project_type "$file_path")"
  }
}
EOF
    
    # Update learning database
    update_learning_database "$fix_id" "$language" "$error_code" "$fix_type"
    
    # Check if pattern should be learned
    check_pattern_learning "$language" "$error_code" "$fix_type"
    
    success "Fix recorded: $fix_id"
}

# Capture code context before fix
capture_context_before() {
    local file=$1
    # In real implementation, this would capture relevant code snippet
    echo "Code before fix"
}

# Capture code context after fix
capture_context_after() {
    local file=$1
    echo "Code after fix"
}

# Get compiler version
get_compiler_version() {
    local language=$1
    
    case "$language" in
        csharp) dotnet --version 2>/dev/null || echo "unknown" ;;
        python) python3 --version 2>/dev/null | cut -d' ' -f2 || echo "unknown" ;;
        javascript|typescript) node --version 2>/dev/null || echo "unknown" ;;
        go) go version 2>/dev/null | cut -d' ' -f3 || echo "unknown" ;;
        rust) rustc --version 2>/dev/null | cut -d' ' -f2 || echo "unknown" ;;
        java) javac -version 2>&1 | cut -d' ' -f2 || echo "unknown" ;;
        cpp) g++ --version 2>/dev/null | head -1 || echo "unknown" ;;
        *) echo "unknown" ;;
    esac
}

# Detect project type
detect_project_type() {
    local file_path=$1
    local dir=$(dirname "$file_path")
    
    # Check for project files
    if [[ -f "$dir/package.json" ]]; then
        echo "node"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        echo "cargo"
    elif [[ -f "$dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$dir/pom.xml" ]]; then
        echo "maven"
    elif [[ -f "$dir/build.gradle" ]]; then
        echo "gradle"
    elif find "$dir" -name "*.csproj" -o -name "*.sln" | head -1 > /dev/null; then
        echo "dotnet"
    elif [[ -f "$dir/setup.py" ]] || [[ -f "$dir/requirements.txt" ]]; then
        echo "python"
    else
        echo "generic"
    fi
}

# Update learning database with new fix
update_learning_database() {
    local fix_id=$1
    local language=$2
    local error_code=$3
    local fix_type=$4
    
    local db_file="$LEARNING_DIR/learning_database.json"
    local temp_file="$db_file.tmp"
    
    # Create pattern key
    local pattern_key="${language}_${error_code}_${fix_type}"
    
    # Update database (simplified - in production use jq)
    # This is a placeholder for actual JSON manipulation
    log "Updating learning database for pattern: $pattern_key"
    
    # Increment fix count
    echo "$fix_id" >> "$LEARNING_DIR/fix_counts/${pattern_key}.log"
}

# Check if pattern should be learned
check_pattern_learning() {
    local language=$1
    local error_code=$2
    local fix_type=$3
    
    local pattern_key="${language}_${error_code}_${fix_type}"
    local fix_count_file="$LEARNING_DIR/fix_counts/${pattern_key}.log"
    
    mkdir -p "$LEARNING_DIR/fix_counts"
    
    if [[ -f "$fix_count_file" ]]; then
        local fix_count=$(wc -l < "$fix_count_file")
        
        if [[ $fix_count -ge $LEARNING_THRESHOLD ]]; then
            log "Pattern $pattern_key has $fix_count successful fixes - learning pattern"
            learn_new_pattern "$language" "$error_code" "$fix_type"
        else
            log "Pattern $pattern_key has $fix_count fixes (threshold: $LEARNING_THRESHOLD)"
        fi
    fi
}

# Learn a new pattern from successful fixes
learn_new_pattern() {
    local language=$1
    local error_code=$2
    local fix_type=$3
    
    log "Learning new pattern for $language/$error_code"
    
    # Analyze fix history
    local pattern_key="${language}_${error_code}_${fix_type}"
    local learned_pattern_file="$PATTERNS_DIR/learned/${language}_${error_code}.json"
    
    mkdir -p "$PATTERNS_DIR/learned"
    
    # Generate learned pattern
    cat > "$learned_pattern_file" << EOF
{
  "pattern_id": "${pattern_key}_learned",
  "learned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "error_code": "$error_code",
  "fix_statistics": {
    "total_applications": $(wc -l < "$LEARNING_DIR/fix_counts/${pattern_key}.log"),
    "success_rate": 1.0,
    "average_time_ms": 0
  },
  "pattern": {
    "name": "${fix_type}_learned",
    "description": "Automatically learned fix for $error_code",
    "confidence": 0.7,
    "source": "machine_learned",
    "conditions": [],
    "actions": [
      {
        "type": "$fix_type",
        "learned": true,
        "parameters": {}
      }
    ]
  },
  "validation": {
    "tested": false,
    "test_cases": 0,
    "last_validated": null
  }
}
EOF
    
    success "Learned new pattern: $pattern_key"
    
    # Optionally merge with main pattern database
    merge_learned_pattern "$language" "$error_code" "$learned_pattern_file"
}

# Merge learned pattern into main database
merge_learned_pattern() {
    local language=$1
    local error_code=$2
    local learned_file=$3
    
    local main_db="$PATTERNS_DIR/databases/$language/patterns.json"
    
    if [[ -f "$main_db" ]]; then
        log "Merging learned pattern into main database"
        # In production, use proper JSON merging
        # This is a placeholder
        cp "$learned_file" "$PATTERNS_DIR/databases/$language/learned_${error_code}.json"
        success "Pattern merged and ready for validation"
    fi
}

# Analyze pattern effectiveness
analyze_pattern_effectiveness() {
    local language=$1
    local time_window=${2:-"7d"}  # Default to last 7 days
    
    log "Analyzing pattern effectiveness for $language (last $time_window)"
    
    local report_file="$LEARNING_DIR/effectiveness_report_$(date +%s).json"
    
    cat > "$report_file" << EOF
{
  "analysis_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "time_window": "$time_window",
  "patterns": [
EOF
    
    # Analyze each pattern's performance
    local first=true
    for pattern_file in "$LEARNING_DIR/fix_counts"/*${language}*.log; do
        if [[ -f "$pattern_file" ]]; then
            local pattern_name=$(basename "$pattern_file" .log)
            local fix_count=$(wc -l < "$pattern_file")
            
            [[ "$first" == "false" ]] && echo "," >> "$report_file"
            first=false
            
            cat >> "$report_file" << EOF
    {
      "pattern": "$pattern_name",
      "applications": $fix_count,
      "success_rate": 1.0,
      "confidence_score": $(calculate_confidence "$fix_count"),
      "recommendation": "$(get_recommendation "$fix_count")"
    }
EOF
        fi
    done
    
    echo '
  ]
}' >> "$report_file"
    
    success "Effectiveness report saved to: $report_file"
}

# Calculate confidence score based on usage
calculate_confidence() {
    local usage_count=$1
    local base_confidence=0.5
    
    # Increase confidence with usage
    local confidence=$(awk "BEGIN {
        c = $base_confidence + ($usage_count * $CONFIDENCE_INCREMENT);
        if (c > $MAX_CONFIDENCE) c = $MAX_CONFIDENCE;
        printf \"%.2f\", c
    }")
    
    echo "$confidence"
}

# Get recommendation based on usage
get_recommendation() {
    local usage_count=$1
    
    if [[ $usage_count -gt 50 ]]; then
        echo "promote_to_primary"
    elif [[ $usage_count -gt 20 ]]; then
        echo "increase_confidence"
    elif [[ $usage_count -gt 10 ]]; then
        echo "keep_monitoring"
    else
        echo "needs_more_data"
    fi
}

# Export learned patterns for sharing
export_learned_patterns() {
    local export_file="$PATTERNS_DIR/learned_patterns_export_$(date +%Y%m%d).tar.gz"
    
    log "Exporting learned patterns..."
    
    # Create export package
    tar -czf "$export_file" \
        -C "$PATTERNS_DIR" \
        learned/ \
        -C "$LEARNING_DIR" \
        learning_database.json \
        effectiveness_report_*.json 2>/dev/null || true
    
    success "Patterns exported to: $export_file"
    echo "Share this file to contribute patterns to the community!"
}

# Import patterns from community
import_community_patterns() {
    local import_file=$1
    
    if [[ ! -f "$import_file" ]]; then
        error "Import file not found: $import_file"
        return 1
    fi
    
    log "Importing community patterns from: $import_file"
    
    local temp_dir="$LEARNING_DIR/import_$(date +%s)"
    mkdir -p "$temp_dir"
    
    # Extract patterns
    tar -xzf "$import_file" -C "$temp_dir"
    
    # Validate and merge patterns
    local imported_count=0
    for pattern in "$temp_dir/learned"/*.json; do
        if [[ -f "$pattern" ]]; then
            # Validate pattern structure
            if validate_pattern_structure "$pattern"; then
                cp "$pattern" "$PATTERNS_DIR/community/"
                ((imported_count++))
            fi
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    success "Imported $imported_count patterns from community"
}

# Validate pattern structure
validate_pattern_structure() {
    local pattern_file=$1
    
    # Basic validation - check for required fields
    if grep -q '"pattern_id"' "$pattern_file" && \
       grep -q '"language"' "$pattern_file" && \
       grep -q '"error_code"' "$pattern_file"; then
        return 0
    else
        return 1
    fi
}

# Generate learning report
generate_learning_report() {
    log "Generating learning report..."
    
    local report_file="$LEARNING_DIR/learning_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Pattern Learning Report

Generated: $(date)

## Overview

The pattern learning system tracks successful fixes and automatically learns new patterns when fixes are consistently successful.

## Statistics

### Total Fixes Tracked
$(find "$HISTORY_DIR" -name "*.json" 2>/dev/null | wc -l)

### Patterns Learned
$(find "$PATTERNS_DIR/learned" -name "*.json" 2>/dev/null | wc -l)

### Languages Covered
EOF
    
    # Add language statistics
    for lang in csharp python javascript typescript go rust java cpp; do
        local pattern_count=$(find "$PATTERNS_DIR/learned" -name "${lang}_*.json" 2>/dev/null | wc -l)
        if [[ $pattern_count -gt 0 ]]; then
            echo "- **$lang**: $pattern_count patterns" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << 'EOF'

## Top Learned Patterns

| Pattern | Applications | Confidence | Status |
|---------|--------------|------------|--------|
EOF
    
    # Add top patterns (simplified)
    for log_file in $(ls -S "$LEARNING_DIR/fix_counts"/*.log 2>/dev/null | head -10); do
        if [[ -f "$log_file" ]]; then
            local pattern=$(basename "$log_file" .log)
            local count=$(wc -l < "$log_file")
            local confidence=$(calculate_confidence "$count")
            local status=$(get_recommendation "$count")
            
            echo "| $pattern | $count | $confidence | $status |" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << 'EOF'

## Recommendations

1. **Validation**: Test learned patterns with high usage counts
2. **Promotion**: Move high-confidence patterns to main database
3. **Sharing**: Export successful patterns for community benefit
4. **Monitoring**: Continue tracking pattern effectiveness

## Next Steps

- Review patterns with "promote_to_primary" status
- Run validation tests on new learned patterns
- Update pattern confidence scores based on usage
- Share successful patterns with the community
EOF
    
    success "Learning report saved to: $report_file"
}

# Main command processing
main() {
    local command=${1:-help}
    
    # Initialize database
    init_learning_db
    
    case "$command" in
        record)
            # Record a successful fix
            local language=${2:-csharp}
            local error_code=${3:-CS0001}
            local fix_type=${4:-generic}
            local file_path=${5:-"unknown"}
            local context=${6:-""}
            
            record_successful_fix "$language" "$error_code" "$fix_type" "$file_path" "$context"
            ;;
            
        analyze)
            # Analyze pattern effectiveness
            local language=${2:-all}
            local time_window=${3:-"7d"}
            
            if [[ "$language" == "all" ]]; then
                for lang in csharp python javascript typescript go rust java cpp; do
                    analyze_pattern_effectiveness "$lang" "$time_window"
                done
            else
                analyze_pattern_effectiveness "$language" "$time_window"
            fi
            ;;
            
        export)
            # Export learned patterns
            export_learned_patterns
            ;;
            
        import)
            # Import community patterns
            local import_file=${2:-}
            if [[ -n "$import_file" ]]; then
                import_community_patterns "$import_file"
            else
                error "Please specify import file"
            fi
            ;;
            
        report)
            # Generate learning report
            generate_learning_report
            ;;
            
        learn)
            # Force learn a pattern
            local language=${2:-csharp}
            local error_code=${3:-CS0001}
            local fix_type=${4:-generic}
            
            learn_new_pattern "$language" "$error_code" "$fix_type"
            ;;
            
        help|*)
            cat << EOF
Pattern Learning System

Usage: $0 <command> [options]

Commands:
  record <lang> <code> <fix> <file> [context]
    Record a successful fix for learning
    
  analyze [language] [time_window]
    Analyze pattern effectiveness
    
  export
    Export learned patterns for sharing
    
  import <file>
    Import patterns from community
    
  report
    Generate comprehensive learning report
    
  learn <lang> <code> <fix>
    Force learn a pattern (testing)

Examples:
  $0 record csharp CS0246 add_using Program.cs
  $0 analyze python 30d
  $0 export
  $0 import community_patterns.tar.gz
  $0 report

Learning Configuration:
  Threshold: $LEARNING_THRESHOLD successful fixes
  Confidence increment: $CONFIDENCE_INCREMENT per fix
  Max confidence: $MAX_CONFIDENCE

EOF
            ;;
    esac
}

# Run main
main "$@"