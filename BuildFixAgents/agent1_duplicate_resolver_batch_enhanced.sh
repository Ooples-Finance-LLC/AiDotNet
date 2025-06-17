#!/bin/bash

# Agent 1 - Duplicate Resolution Specialist (Batch Enhanced)
# Handles CS0101 (duplicate classes) and CS0111 (duplicate members)
# Enhanced with batch operations for better performance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ID="AGENT1_BATCH"
LOG_FILE="$SCRIPT_DIR/agent_coordination.log"
BUILD_CHECKER="$SCRIPT_DIR/build_checker_agent.sh"

# Source batch operations library
source "$SCRIPT_DIR/fix_agent_batch_lib.sh"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $AGENT_ID: $message" | tee -a "$LOG_FILE"
}

# Main agent execution
main() {
    log_message "=== AGENT 1 - DUPLICATE RESOLUTION SPECIALIST (BATCH) STARTING ==="
    log_message "Target: CS0101 (duplicate classes) and CS0111 (duplicate members)"
    
    local start_time=$(date +%s)
    local errors_before=0
    
    # Get baseline error count
    if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
        errors_before=$(cat "$SCRIPT_DIR/build_error_count.txt")
        log_message "Starting with $errors_before total error types"
    fi
    
    # Phase 1: Batch fix CS0101 errors
    log_message "Phase 1: Batch fixing CS0101 (duplicate definitions)..."
    batch_fix_cs0101
    
    # Phase 2: Batch fix CS0111 errors
    log_message "Phase 2: Batch fixing CS0111 (duplicate members)..."
    batch_fix_cs0111
    
    # Phase 3: Additional duplicate pattern detection and removal
    log_message "Phase 3: Scanning for additional duplicate patterns..."
    
    # Get list of files with duplicate errors
    local cs0101_files=($(get_affected_files "CS0101"))
    local cs0111_files=($(get_affected_files "CS0111"))
    
    # Combine and deduplicate file lists
    local all_files=($(printf '%s\n' "${cs0101_files[@]}" "${cs0111_files[@]}" | sort -u))
    
    if [[ ${#all_files[@]} -gt 0 ]]; then
        log_message "Found ${#all_files[@]} files with duplicate issues"
        
        # Create custom patterns for known duplicate issues
        local custom_patterns="$BATCH_PATTERNS_DIR/agent1_custom_patterns.sed"
        cat > "$custom_patterns" << 'EOF'
# Remove duplicate CachedModel class from CloudOptimizer.cs
/CloudOptimizer\.cs/ {
    /internal class CachedModel/,/^[[:space:]]*}[[:space:]]*$/ {
        /internal class CachedModel/ {
            i\// Duplicate CachedModel class removed - using separate file
        }
        d
    }
}

# Remove duplicate quantization strategy classes from ModelQuantizer.cs
/ModelQuantizer\.cs/ {
    /class \(Int8\|Int16\|Dynamic\|QAT\|MixedPrecision\|Binary\|Ternary\)QuantizationStrategy/,/^[[:space:]]*}[[:space:]]*$/ {
        /class.*QuantizationStrategy/ {
            i\// Duplicate strategy class removed - using separate file
        }
        d
    }
}

# Remove duplicate config classes from FoundationModelConfig.cs
/FoundationModelConfig\.cs/ {
    /class \(Cache\|Memory\|Generation\)Config/,/^[[:space:]]*}[[:space:]]*$/ {
        /class.*Config/ {
            i\// Duplicate config class removed - using separate file
        }
        d
    }
}
EOF
        
        # Apply custom patterns
        batch_sed_multi "$custom_patterns" "${all_files[@]}"
        log_message "Applied custom duplicate removal patterns"
    fi
    
    # Phase 4: Clean up known duplicate files
    log_message "Phase 4: Removing known duplicate files..."
    
    local duplicate_files=(
        "src/Compression/Quantization/WeightDistributionStatistics.cs"
        "src/Compression/Quantization/QuantizedModelFactoryRegistry.cs"
        "src/Compression/Quantization/QuantizationMethod.cs"
        "src/Compression/Pruning/PrunedModelFactoryRegistry.cs"
        "src/Compression/Pruning/PrunedParameter.cs"
        "src/Enums/PruningMethod.cs"
        "src/Enums/PruningSchedule.cs"
        "src/Deployment/CachedModel.cs"
        "src/Models/Options/BERTConfig.cs"
        "src/Models/Options/CacheConfig.cs"
        "src/Models/Options/GenerationConfig.cs"
        "src/Models/Options/MemoryConfig.cs"
        "src/Models/Options/ModelQuantizationConfig.cs"
        "src/Interfaces/IQuantizationStrategy.cs"
        "src/FederatedLearning/Aggregation/AggregationMetrics.cs"
        "src/Helpers/ArrayHelper.cs"
    )
    
    local removed_count=0
    for file in "${duplicate_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/../$file" ]]; then
            rm -f "$SCRIPT_DIR/../$file"
            log_message "Removed duplicate file: $file"
            ((removed_count++))
        fi
    done
    
    log_message "Removed $removed_count duplicate files"
    
    # Report completion
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_message "=== AGENT 1 BATCH PROCESSING COMPLETE ==="
    log_message "Total processing time: ${duration} seconds"
    log_message "Files processed: ${#all_files[@]}"
    log_message "Duplicate files removed: $removed_count"
    
    # Get final error count
    if command -v "$SCRIPT_DIR/unified_error_counter.sh" &>/dev/null; then
        "$SCRIPT_DIR/unified_error_counter.sh" > /dev/null 2>&1
        if [[ -f "$SCRIPT_DIR/build_error_count.txt" ]]; then
            local errors_after=$(cat "$SCRIPT_DIR/build_error_count.txt")
            log_message "Error count: $errors_before -> $errors_after"
        fi
    fi
    
    log_message "Agent 1 batch duplicate resolution work complete"
    return 0
}

# Handle command line arguments
case "${1:-main}" in
    "main")
        main
        ;;
    "batch-cs0101")
        batch_fix_cs0101
        ;;
    "batch-cs0111")
        batch_fix_cs0111
        ;;
    "clean-duplicates")
        log_message "Cleaning duplicate files..."
        main
        ;;
    *)
        echo "Usage: $0 {main|batch-cs0101|batch-cs0111|clean-duplicates}"
        exit 1
        ;;
esac