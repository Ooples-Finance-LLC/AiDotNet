#!/bin/bash

# Parallel Error Processor - Splits and processes errors in parallel
# Maximizes CPU utilization for faster error analysis and fixing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/parallel"
CHUNKS_DIR="$STATE_DIR/chunks"
RESULTS_DIR="$STATE_DIR/results"
METRICS_FILE="$STATE_DIR/parallel_metrics.json"

# Configuration
MAX_PARALLEL=${MAX_PARALLEL:-$(nproc)}
CHUNK_SIZE=${CHUNK_SIZE:-100}
USE_GNU_PARALLEL=${USE_GNU_PARALLEL:-true}
MERGE_RESULTS=${MERGE_RESULTS:-true}
ADAPTIVE_CHUNKING=${ADAPTIVE_CHUNKING:-true}

# Create directories
mkdir -p "$CHUNKS_DIR" "$RESULTS_DIR"

# Initialize metrics
init_metrics() {
    if [[ ! -f "$METRICS_FILE" ]]; then
        cat > "$METRICS_FILE" << EOF
{
    "total_chunks": 0,
    "processed_chunks": 0,
    "failed_chunks": 0,
    "total_time": 0,
    "average_chunk_time": 0,
    "parallelism_efficiency": 0
}
EOF
    fi
}

# Split errors into optimal chunks
split_errors_smart() {
    local error_file="${1:-$STATE_DIR/../error_analysis.json}"
    local target_chunks="${2:-$MAX_PARALLEL}"
    
    if [[ ! -f "$error_file" ]]; then
        echo "[PARALLEL] No error file found: $error_file"
        return 1
    fi
    
    # Clear previous chunks
    rm -f "$CHUNKS_DIR"/chunk_*.json
    
    local total_errors=$(jq '.total_errors // 0' "$error_file")
    
    if [[ $total_errors -eq 0 ]]; then
        echo "[PARALLEL] No errors to process"
        return 0
    fi
    
    echo "[PARALLEL] Splitting $total_errors errors into chunks..."
    
    # Adaptive chunking based on error count and CPU cores
    if [[ "$ADAPTIVE_CHUNKING" == "true" ]]; then
        # Calculate optimal chunk size
        local optimal_chunk_size=$((total_errors / (target_chunks * 2) + 1))
        
        # Enforce min/max bounds
        if [[ $optimal_chunk_size -lt 10 ]]; then
            optimal_chunk_size=10
        elif [[ $optimal_chunk_size -gt 500 ]]; then
            optimal_chunk_size=500
        fi
        
        CHUNK_SIZE=$optimal_chunk_size
        echo "[PARALLEL] Using adaptive chunk size: $CHUNK_SIZE"
    fi
    
    # Group by error type for better cache locality
    local chunk_id=0
    
    # First, split by error code for better pattern matching
    jq -r '.errors | group_by(.code) | .[]' "$error_file" 2>/dev/null | while IFS= read -r error_group; do
        local group_size=$(echo "$error_group" | jq 'length')
        
        if [[ $group_size -le $CHUNK_SIZE ]]; then
            # Small group, save as single chunk
            cat > "$CHUNKS_DIR/chunk_${chunk_id}.json" << EOF
{
    "chunk_id": $chunk_id,
    "type": "homogeneous",
    "error_code": $(echo "$error_group" | jq -r '.[0].code'),
    "errors": $error_group
}
EOF
            ((chunk_id++))
        else
            # Large group, split into multiple chunks
            for ((i=0; i<group_size; i+=CHUNK_SIZE)); do
                local end=$((i + CHUNK_SIZE))
                cat > "$CHUNKS_DIR/chunk_${chunk_id}.json" << EOF
{
    "chunk_id": $chunk_id,
    "type": "homogeneous",
    "error_code": $(echo "$error_group" | jq -r '.[0].code'),
    "errors": $(echo "$error_group" | jq ".[$i:$end]")
}
EOF
                ((chunk_id++))
            done
        fi
    done
    
    # Update metrics
    jq --argjson chunks "$chunk_id" '.total_chunks = $chunks' "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
        mv "$METRICS_FILE.tmp" "$METRICS_FILE"
    
    echo "[PARALLEL] Created $chunk_id chunks"
    return 0
}

# Process single chunk
process_chunk() {
    local chunk_file="$1"
    local chunk_id=$(basename "$chunk_file" .json | sed 's/chunk_//')
    
    echo "[PARALLEL] Processing chunk $chunk_id..."
    
    local start_time=$(date +%s.%N)
    local result_file="$RESULTS_DIR/result_${chunk_id}.json"
    
    # Extract chunk metadata
    local error_code=$(jq -r '.error_code // "mixed"' "$chunk_file")
    local chunk_type=$(jq -r '.type // "mixed"' "$chunk_file")
    local error_count=$(jq '.errors | length' "$chunk_file")
    
    # Initialize result
    cat > "$result_file" << EOF
{
    "chunk_id": $chunk_id,
    "status": "processing",
    "error_code": "$error_code",
    "error_count": $error_count,
    "fixes_applied": 0,
    "start_time": "$(date -Iseconds)"
}
EOF
    
    # Try pre-compiled patterns first
    if [[ -f "$SCRIPT_DIR/precompiled_patterns.sh" ]] && [[ "$chunk_type" == "homogeneous" ]]; then
        source "$SCRIPT_DIR/precompiled_patterns.sh"
        
        if get_precompiled_pattern "$error_code" >/dev/null 2>&1; then
            echo "[PARALLEL] Using pre-compiled pattern for $error_code"
            
            # Extract affected files
            local files=($(jq -r '.errors[].file' "$chunk_file" | sort -u))
            
            if apply_precompiled "$error_code" "${files[@]}"; then
                jq --argjson fixed "${#files[@]}" '.fixes_applied = $fixed | .status = "completed"' \
                    "$result_file" > "$result_file.tmp" && mv "$result_file.tmp" "$result_file"
            fi
        fi
    fi
    
    # Try pattern learning
    if [[ -f "$SCRIPT_DIR/pattern_learning_integration.sh" ]]; then
        source "$SCRIPT_DIR/pattern_learning_integration.sh"
        
        if [[ "$error_code" != "mixed" ]] && has_patterns "$error_code"; then
            echo "[PARALLEL] Using learned patterns for $error_code"
            
            local fixed=0
            jq -r '.errors[] | @base64' "$chunk_file" | while read -r error_data; do
                local error=$(echo "$error_data" | base64 -d)
                local file=$(echo "$error" | jq -r '.file')
                
                if try_learned_patterns "$error_code" "$file"; then
                    ((fixed++))
                fi
            done
            
            jq --argjson fixed "$fixed" '.fixes_applied += $fixed' \
                "$result_file" > "$result_file.tmp" && mv "$result_file.tmp" "$result_file"
        fi
    fi
    
    # Fallback to dynamic agent
    if [[ -f "$SCRIPT_DIR/dynamic_fix_agent.sh" ]] && [[ "$error_code" != "mixed" ]]; then
        echo "[PARALLEL] Using dynamic agent for $error_code"
        
        # Create temporary error file for agent
        local temp_errors="$STATE_DIR/temp_errors_${chunk_id}.json"
        jq --argjson errors "$(jq '.errors' "$chunk_file")" \
           '{errors: $errors, total_errors: ($errors | length)}' > "$temp_errors"
        
        ERROR_ANALYSIS_FILE="$temp_errors" \
        CHUNK_MODE=true \
        CHUNK_ID="$chunk_id" \
            "$SCRIPT_DIR/dynamic_fix_agent.sh" "$error_code" "$chunk_id" "auto" >/dev/null 2>&1
        
        rm -f "$temp_errors"
    fi
    
    # Finalize result
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    jq --arg end "$(date -Iseconds)" \
       --argjson duration "$duration" \
       '.end_time = $end | .duration = $duration | .status = "completed"' \
       "$result_file" > "$result_file.tmp" && mv "$result_file.tmp" "$result_file"
    
    # Update metrics
    update_chunk_metrics "$duration"
    
    echo "[PARALLEL] Chunk $chunk_id completed in ${duration}s"
}

# Update metrics after chunk processing
update_chunk_metrics() {
    local duration="$1"
    
    local processed=$(jq -r '.processed_chunks' "$METRICS_FILE")
    local total_time=$(jq -r '.total_time' "$METRICS_FILE")
    
    processed=$((processed + 1))
    total_time=$(echo "$total_time + $duration" | bc)
    average_time=$(echo "scale=2; $total_time / $processed" | bc)
    
    jq --argjson processed "$processed" \
       --argjson total_time "$total_time" \
       --argjson avg_time "$average_time" \
       '.processed_chunks = $processed |
        .total_time = $total_time |
        .average_chunk_time = $avg_time' \
       "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Process chunks in parallel using GNU Parallel
process_with_gnu_parallel() {
    local chunk_files=("$CHUNKS_DIR"/chunk_*.json)
    
    if [[ ${#chunk_files[@]} -eq 0 ]]; then
        echo "[PARALLEL] No chunks to process"
        return 0
    fi
    
    echo "[PARALLEL] Processing ${#chunk_files[@]} chunks with GNU Parallel (max: $MAX_PARALLEL)"
    
    # Export function for parallel
    export -f process_chunk
    export -f update_chunk_metrics
    export SCRIPT_DIR STATE_DIR RESULTS_DIR METRICS_FILE
    
    # Process with progress bar
    printf '%s\n' "${chunk_files[@]}" | \
        parallel -j "$MAX_PARALLEL" --bar --joblog "$STATE_DIR/parallel.log" \
        process_chunk {}
}

# Process chunks using background jobs
process_with_jobs() {
    local chunk_files=("$CHUNKS_DIR"/chunk_*.json)
    
    if [[ ${#chunk_files[@]} -eq 0 ]]; then
        echo "[PARALLEL] No chunks to process"
        return 0
    fi
    
    echo "[PARALLEL] Processing ${#chunk_files[@]} chunks with background jobs (max: $MAX_PARALLEL)"
    
    local active_jobs=0
    
    for chunk_file in "${chunk_files[@]}"; do
        # Wait if we've reached max parallel jobs
        while [[ $active_jobs -ge $MAX_PARALLEL ]]; do
            wait -n  # Wait for any job to complete
            active_jobs=$((active_jobs - 1))
        done
        
        # Start new job
        process_chunk "$chunk_file" &
        active_jobs=$((active_jobs + 1))
    done
    
    # Wait for all remaining jobs
    wait
}

# Merge chunk results
merge_results() {
    echo "[PARALLEL] Merging results..."
    
    local merged_file="$STATE_DIR/merged_results.json"
    
    # Initialize merged results
    cat > "$merged_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_chunks": $(jq -r '.total_chunks' "$METRICS_FILE"),
    "processed_chunks": $(jq -r '.processed_chunks' "$METRICS_FILE"),
    "total_fixes": 0,
    "chunk_results": []
}
EOF
    
    # Merge all result files
    local total_fixes=0
    for result_file in "$RESULTS_DIR"/result_*.json; do
        if [[ -f "$result_file" ]]; then
            local fixes=$(jq -r '.fixes_applied // 0' "$result_file")
            total_fixes=$((total_fixes + fixes))
            
            # Add to merged results
            jq --argjson result "$(cat "$result_file")" \
               '.chunk_results += [$result]' \
               "$merged_file" > "$merged_file.tmp" && mv "$merged_file.tmp" "$merged_file"
        fi
    done
    
    # Update totals
    jq --argjson fixes "$total_fixes" '.total_fixes = $fixes' \
       "$merged_file" > "$merged_file.tmp" && mv "$merged_file.tmp" "$merged_file"
    
    echo "[PARALLEL] Merged results: $total_fixes total fixes applied"
    
    # Copy to standard location
    cp "$merged_file" "$STATE_DIR/../parallel_processing_results.json"
}

# Calculate parallelism efficiency
calculate_efficiency() {
    local total_time=$(jq -r '.total_time' "$METRICS_FILE")
    local avg_time=$(jq -r '.average_chunk_time' "$METRICS_FILE")
    local total_chunks=$(jq -r '.total_chunks' "$METRICS_FILE")
    
    if [[ $total_chunks -gt 0 ]] && [[ $(echo "$total_time > 0" | bc) -eq 1 ]]; then
        # Theoretical sequential time
        local sequential_time=$(echo "$avg_time * $total_chunks" | bc)
        
        # Efficiency = sequential_time / (parallel_time * cores)
        local efficiency=$(echo "scale=2; $sequential_time / ($total_time * $MAX_PARALLEL) * 100" | bc)
        
        jq --argjson eff "$efficiency" '.parallelism_efficiency = $eff' \
           "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        
        echo "[PARALLEL] Parallelism efficiency: ${efficiency}%"
    fi
}

# Main parallel processing function
process_errors_parallel() {
    local error_file="${1:-}"
    local chunk_method="${2:-smart}"
    
    init_metrics
    
    local start_time=$(date +%s)
    
    # Split errors into chunks
    case "$chunk_method" in
        "smart")
            split_errors_smart "$error_file"
            ;;
        "simple")
            # Simple equal-size chunks
            split_errors_simple "$error_file" "$CHUNK_SIZE"
            ;;
        *)
            echo "[PARALLEL] Unknown chunk method: $chunk_method"
            return 1
            ;;
    esac
    
    # Process chunks in parallel
    if [[ "$USE_GNU_PARALLEL" == "true" ]] && command -v parallel >/dev/null 2>&1; then
        process_with_gnu_parallel
    else
        process_with_jobs
    fi
    
    # Merge results if requested
    if [[ "$MERGE_RESULTS" == "true" ]]; then
        merge_results
    fi
    
    # Calculate efficiency
    calculate_efficiency
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo "[PARALLEL] Total processing time: ${total_duration}s"
    
    # Show summary
    show_parallel_summary
}

# Show processing summary
show_parallel_summary() {
    echo ""
    echo "=== Parallel Processing Summary ==="
    
    # Ensure metrics file exists
    if [[ ! -f "$METRICS_FILE" ]]; then
        mkdir -p "$STATE_DIR"
        echo '{
            "total_chunks": 0,
            "processed_chunks": 0,
            "failed_chunks": 0,
            "total_time": 0,
            "average_chunk_time": 0,
            "parallelism_efficiency": 0
        }' > "$METRICS_FILE"
    fi
    
    jq -r '
        "Total Chunks: \(.total_chunks)",
        "Processed: \(.processed_chunks)",
        "Failed: \(.failed_chunks)",
        "Total Time: \(.total_time | tonumber | floor)s",
        "Average Chunk Time: \(.average_chunk_time)s",
        "Parallelism Efficiency: \(.parallelism_efficiency)%"
    ' "$METRICS_FILE"
    
    if [[ -f "$STATE_DIR/../parallel_processing_results.json" ]]; then
        echo ""
        jq -r '"Total Fixes Applied: \(.total_fixes)"' "$STATE_DIR/../parallel_processing_results.json"
    fi
}

# Cleanup old chunks and results
cleanup_parallel_state() {
    echo "[PARALLEL] Cleaning up old state..."
    
    # Remove chunks older than 1 day
    find "$CHUNKS_DIR" -name "chunk_*.json" -mtime +1 -delete 2>/dev/null || true
    find "$RESULTS_DIR" -name "result_*.json" -mtime +1 -delete 2>/dev/null || true
    
    # Archive old metrics
    if [[ -f "$METRICS_FILE" ]]; then
        mv "$METRICS_FILE" "$STATE_DIR/metrics_$(date +%Y%m%d_%H%M%S).json"
        init_metrics
    fi
    
    echo "[PARALLEL] Cleanup complete"
}

# Main function
main() {
    case "${1:-process}" in
        process)
            process_errors_parallel "${2:-}" "${3:-smart}"
            ;;
        split)
            split_errors_smart "${2:-}"
            ;;
        summary)
            show_parallel_summary
            ;;
        cleanup)
            cleanup_parallel_state
            ;;
        test)
            # Test parallel processing
            echo "[PARALLEL] Running test..."
            MAX_PARALLEL=2 CHUNK_SIZE=5 process_errors_parallel
            ;;
        *)
            cat << EOF
Parallel Error Processor

Usage: $0 <command> [options]

Commands:
  process [error_file] [method]  - Process errors in parallel
  split [error_file]            - Split errors into chunks only
  summary                       - Show processing summary
  cleanup                       - Clean up old state
  test                         - Run test with small parameters

Methods:
  smart   - Smart chunking by error type (default)
  simple  - Simple equal-size chunks

Environment Variables:
  MAX_PARALLEL=$MAX_PARALLEL         - Max parallel processes
  CHUNK_SIZE=$CHUNK_SIZE            - Target chunk size
  USE_GNU_PARALLEL=$USE_GNU_PARALLEL     - Use GNU Parallel if available
  MERGE_RESULTS=$MERGE_RESULTS         - Merge chunk results
  ADAPTIVE_CHUNKING=$ADAPTIVE_CHUNKING    - Use adaptive chunk sizing

Examples:
  # Process with defaults
  $0
  
  # Process specific file with 8 cores
  MAX_PARALLEL=8 $0 process error_analysis.json
  
  # Show summary
  $0 summary
EOF
            ;;
    esac
}

# Export functions
export -f process_chunk
export -f split_errors_smart
export -f process_errors_parallel

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi