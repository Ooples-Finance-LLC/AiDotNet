#!/bin/bash

# Stream Processor - Handles large files through streaming to prevent memory issues
# Processes build output and errors in real-time without loading entire files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/streaming"
PIPES_DIR="$STATE_DIR/pipes"
BUFFERS_DIR="$STATE_DIR/buffers"

# Configuration
BUFFER_SIZE=${BUFFER_SIZE:-1000}  # Lines per buffer
STREAM_TIMEOUT=${STREAM_TIMEOUT:-300}  # 5 minutes default
MAX_MEMORY_MB=${MAX_MEMORY_MB:-512}  # Max memory usage
ENABLE_COMPRESSION=${ENABLE_COMPRESSION:-true}
PARALLEL_STREAMS=${PARALLEL_STREAMS:-4}

# Create directories
mkdir -p "$PIPES_DIR" "$BUFFERS_DIR"

# Stream statistics
STREAM_STATS="$STATE_DIR/stream_stats.json"

# Initialize statistics
init_stream_stats() {
    if [[ ! -f "$STREAM_STATS" ]]; then
        cat > "$STREAM_STATS" << EOF
{
    "lines_processed": 0,
    "errors_found": 0,
    "buffers_created": 0,
    "memory_saved_mb": 0,
    "processing_time": 0
}
EOF
    fi
}

# Create named pipes for streaming
setup_pipes() {
    # Error stream pipe
    local error_pipe="$PIPES_DIR/error_stream"
    local fix_pipe="$PIPES_DIR/fix_stream"
    local result_pipe="$PIPES_DIR/result_stream"
    
    # Remove old pipes
    rm -f "$error_pipe" "$fix_pipe" "$result_pipe"
    
    # Create new pipes
    mkfifo "$error_pipe" "$fix_pipe" "$result_pipe"
    
    echo "[STREAM] Created named pipes for streaming"
    
    # Return pipe paths
    echo "$error_pipe|$fix_pipe|$result_pipe"
}

# Stream processor for build output
stream_build_output() {
    local build_file="${1:-build_output.txt}"
    local output_pipe="${2:-$PIPES_DIR/error_stream}"
    
    if [[ ! -f "$build_file" ]]; then
        echo "[STREAM] Build file not found: $build_file"
        return 1
    fi
    
    local file_size=$(stat -c %s "$build_file" 2>/dev/null || stat -f %z "$build_file" 2>/dev/null || echo 0)
    local file_size_mb=$((file_size / 1048576))
    
    echo "[STREAM] Streaming build output (${file_size_mb}MB)..."
    
    local start_time=$(date +%s)
    local line_count=0
    local error_count=0
    local buffer=""
    local buffer_count=0
    
    # Process file line by line
    while IFS= read -r line; do
        ((line_count++))
        
        # Check for errors
        if [[ "$line" =~ error[[:space:]]+(CS[0-9]+|TS[0-9]+): ]]; then
            ((error_count++))
            
            # Extract error details
            if [[ "$line" =~ ([^:]+):([0-9]+),([0-9]+):[[:space:]]*error[[:space:]]+([A-Z]+[0-9]+):[[:space:]]*(.*) ]]; then
                local file="${BASH_REMATCH[1]}"
                local line_num="${BASH_REMATCH[2]}"
                local col="${BASH_REMATCH[3]}"
                local code="${BASH_REMATCH[4]}"
                local message="${BASH_REMATCH[5]}"
                
                # Create JSON error object
                local error_json=$(jq -nc \
                    --arg file "$file" \
                    --arg line "$line_num" \
                    --arg col "$col" \
                    --arg code "$code" \
                    --arg msg "$message" \
                    '{file: $file, line: ($line | tonumber), column: ($col | tonumber), code: $code, message: $msg}')
                
                # Send to pipe
                echo "$error_json" > "$output_pipe" &
                
                # Add to buffer
                buffer="${buffer}${error_json}\n"
                
                # Flush buffer if full
                if [[ $((error_count % BUFFER_SIZE)) -eq 0 ]]; then
                    flush_buffer "$buffer" "$buffer_count"
                    buffer=""
                    ((buffer_count++))
                fi
            fi
        fi
        
        # Memory check every 10000 lines
        if [[ $((line_count % 10000)) -eq 0 ]]; then
            check_memory_usage
            echo "[STREAM] Processed $line_count lines, found $error_count errors"
        fi
        
    done < "$build_file"
    
    # Flush remaining buffer
    if [[ -n "$buffer" ]]; then
        flush_buffer "$buffer" "$buffer_count"
    fi
    
    # Close pipe
    echo "EOF" > "$output_pipe"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update statistics
    update_stream_stats "$line_count" "$error_count" "$buffer_count" "$duration"
    
    echo "[STREAM] Completed: $line_count lines, $error_count errors in ${duration}s"
}

# Flush buffer to disk
flush_buffer() {
    local buffer_content="$1"
    local buffer_id="$2"
    local buffer_file="$BUFFERS_DIR/buffer_${buffer_id}.jsonl"
    
    if [[ "$ENABLE_COMPRESSION" == "true" ]]; then
        echo -e "$buffer_content" | gzip > "${buffer_file}.gz"
    else
        echo -e "$buffer_content" > "$buffer_file"
    fi
    
    echo "[STREAM] Flushed buffer $buffer_id"
}

# Check memory usage
check_memory_usage() {
    local current_mem=$(ps -o rss= -p $$ | awk '{print int($1/1024)}')
    
    if [[ $current_mem -gt $MAX_MEMORY_MB ]]; then
        echo "[STREAM] WARNING: Memory usage ${current_mem}MB exceeds limit ${MAX_MEMORY_MB}MB"
        
        # Force garbage collection (bash doesn't have GC, but we can unset vars)
        unset buffer
        
        # Sleep briefly to allow system to reclaim memory
        sleep 0.1
    fi
}

# Stream error processor (consumer)
stream_error_processor() {
    local input_pipe="${1:-$PIPES_DIR/error_stream}"
    local processor_id="${2:-1}"
    
    echo "[STREAM] Error processor $processor_id started"
    
    local processed=0
    local fixes_applied=0
    
    # Load fix patterns if available
    if [[ -f "$SCRIPT_DIR/precompiled_patterns.sh" ]]; then
        source "$SCRIPT_DIR/precompiled_patterns.sh"
    fi
    
    while true; do
        # Read from pipe with timeout
        if read -t "$STREAM_TIMEOUT" error_json < "$input_pipe"; then
            if [[ "$error_json" == "EOF" ]]; then
                echo "[STREAM] Processor $processor_id received EOF"
                break
            fi
            
            # Process error
            local error_code=$(echo "$error_json" | jq -r '.code')
            local file=$(echo "$error_json" | jq -r '.file')
            
            # Try to apply fix immediately
            if command -v apply_precompiled >/dev/null 2>&1; then
                if apply_precompiled "$error_code" "$file" >/dev/null 2>&1; then
                    ((fixes_applied++))
                    echo "[STREAM] Applied fix for $error_code in $file"
                fi
            fi
            
            ((processed++))
            
            # Report progress
            if [[ $((processed % 100)) -eq 0 ]]; then
                echo "[STREAM] Processor $processor_id: $processed errors, $fixes_applied fixes"
            fi
        else
            echo "[STREAM] Processor $processor_id timeout"
            break
        fi
    done
    
    echo "[STREAM] Processor $processor_id completed: $processed errors, $fixes_applied fixes"
}

# Parallel stream processing
parallel_stream_processing() {
    local build_file="${1:-build_output.txt}"
    
    echo "[STREAM] Starting parallel stream processing..."
    
    # Setup pipes
    local pipes=$(setup_pipes)
    local error_pipe=$(echo "$pipes" | cut -d'|' -f1)
    
    # Start stream producer
    stream_build_output "$build_file" "$error_pipe" &
    local producer_pid=$!
    
    # Start multiple consumers
    local consumer_pids=()
    for ((i=1; i<=PARALLEL_STREAMS; i++)); do
        stream_error_processor "$error_pipe" "$i" &
        consumer_pids+=($!)
    done
    
    # Wait for producer
    wait $producer_pid
    
    # Wait for all consumers
    for pid in "${consumer_pids[@]}"; do
        wait $pid
    done
    
    echo "[STREAM] Parallel processing complete"
}

# Stream-based error analysis
analyze_errors_streaming() {
    local build_file="${1:-build_output.txt}"
    local output_file="${2:-$STATE_DIR/stream_analysis.json}"
    
    echo "[STREAM] Analyzing errors using streaming..."
    
    # Initialize analysis
    cat > "$output_file" << EOF
{
    "type": "streaming",
    "timestamp": "$(date -Iseconds)",
    "errors_by_code": {},
    "errors_by_file": {},
    "total_errors": 0
}
EOF
    
    local temp_file=$(mktemp)
    local error_count=0
    
    # Stream and aggregate
    while IFS= read -r line; do
        if [[ "$line" =~ error[[:space:]]+(CS[0-9]+|TS[0-9]+): ]]; then
            # Extract error code
            local error_code=$(echo "$line" | grep -oE 'error [A-Z]+[0-9]+:' | awk '{print $2}' | tr -d ':')
            
            # Extract file
            local file=$(echo "$line" | cut -d':' -f1)
            
            if [[ -n "$error_code" ]]; then
                ((error_count++))
                
                # Update aggregates in temp file
                echo "${error_code}|${file}" >> "$temp_file"
                
                # Periodic update of analysis file
                if [[ $((error_count % 1000)) -eq 0 ]]; then
                    update_analysis_file "$output_file" "$temp_file"
                fi
            fi
        fi
    done < "$build_file"
    
    # Final update
    update_analysis_file "$output_file" "$temp_file"
    
    # Update total
    jq --argjson total "$error_count" '.total_errors = $total' "$output_file" > "$output_file.tmp" && \
        mv "$output_file.tmp" "$output_file"
    
    rm -f "$temp_file"
    
    echo "[STREAM] Analysis complete: $error_count errors found"
}

# Update analysis file with aggregated data
update_analysis_file() {
    local analysis_file="$1"
    local temp_file="$2"
    
    # Aggregate by error code
    local by_code=$(cut -d'|' -f1 "$temp_file" | sort | uniq -c | \
        awk '{print "{\"" $2 "\": " $1 "}"}' | jq -s 'add // {}')
    
    # Aggregate by file
    local by_file=$(cut -d'|' -f2 "$temp_file" | sort | uniq -c | \
        awk '{print "{\"" $2 "\": " $1 "}"}' | jq -s 'add // {}')
    
    # Update analysis
    jq --argjson by_code "$by_code" \
       --argjson by_file "$by_file" \
       '.errors_by_code = $by_code |
        .errors_by_file = $by_file' \
       "$analysis_file" > "$analysis_file.tmp" && \
        mv "$analysis_file.tmp" "$analysis_file"
}

# Update streaming statistics
update_stream_stats() {
    local lines="$1"
    local errors="$2"
    local buffers="$3"
    local duration="$4"
    
    # Calculate memory saved (approximate)
    local file_size=$(stat -c %s "build_output.txt" 2>/dev/null || echo 0)
    local memory_saved=$((file_size / 1048576))  # Convert to MB
    
    jq --argjson lines "$lines" \
       --argjson errors "$errors" \
       --argjson buffers "$buffers" \
       --argjson duration "$duration" \
       --argjson saved "$memory_saved" \
       '.lines_processed += $lines |
        .errors_found += $errors |
        .buffers_created += $buffers |
        .processing_time += $duration |
        .memory_saved_mb += $saved' \
       "$STREAM_STATS" > "$STREAM_STATS.tmp" && \
        mv "$STREAM_STATS.tmp" "$STREAM_STATS"
}

# Clean up streaming artifacts
cleanup_streaming() {
    echo "[STREAM] Cleaning up..."
    
    # Remove pipes
    rm -f "$PIPES_DIR"/*
    
    # Archive old buffers
    if [[ -d "$BUFFERS_DIR" ]]; then
        local archive="$STATE_DIR/buffers_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$archive" -C "$BUFFERS_DIR" . 2>/dev/null || true
        rm -f "$BUFFERS_DIR"/*
    fi
    
    echo "[STREAM] Cleanup complete"
}

# Show streaming statistics
show_stream_stats() {
    if [[ ! -f "$STREAM_STATS" ]]; then
        echo "No streaming statistics available"
        return
    fi
    
    echo "=== Streaming Statistics ==="
    jq -r '
        "Lines Processed: \(.lines_processed | tostring | gsub("(?<a>[0-9])(?=([0-9]{3})+$)"; "\(.a),"))",
        "Errors Found: \(.errors_found)",
        "Buffers Created: \(.buffers_created)",
        "Memory Saved: \(.memory_saved_mb) MB",
        "Total Processing Time: \(.processing_time) seconds",
        "Processing Rate: \(if .processing_time > 0 then (.lines_processed / .processing_time | floor) else 0 end) lines/sec"
    ' "$STREAM_STATS"
}

# Main function
main() {
    init_stream_stats
    
    case "${1:-stream}" in
        stream)
            stream_build_output "${2:-build_output.txt}"
            ;;
        parallel)
            parallel_stream_processing "${2:-build_output.txt}"
            ;;
        analyze)
            analyze_errors_streaming "${2:-build_output.txt}"
            ;;
        processor)
            stream_error_processor "${2:-}" "${3:-1}"
            ;;
        stats)
            show_stream_stats
            ;;
        cleanup)
            cleanup_streaming
            ;;
        test)
            # Test streaming with small buffer
            BUFFER_SIZE=10 stream_build_output "${2:-build_output.txt}"
            ;;
        *)
            cat << EOF
Stream Processor - Memory-efficient large file processing

Usage: $0 <command> [options]

Commands:
  stream [file]     - Stream process build output (default)
  parallel [file]   - Parallel stream processing
  analyze [file]    - Stream-based error analysis
  processor [pipe]  - Run error processor (internal)
  stats            - Show streaming statistics
  cleanup          - Clean up streaming artifacts
  test [file]      - Test with small buffer

Environment Variables:
  BUFFER_SIZE=$BUFFER_SIZE        - Lines per buffer
  STREAM_TIMEOUT=$STREAM_TIMEOUT     - Stream timeout (seconds)
  MAX_MEMORY_MB=$MAX_MEMORY_MB      - Max memory usage (MB)
  PARALLEL_STREAMS=$PARALLEL_STREAMS   - Number of parallel processors

Examples:
  # Stream process large build output
  $0 stream large_build.txt
  
  # Parallel processing with 8 streams
  PARALLEL_STREAMS=8 $0 parallel
  
  # Analyze with streaming
  $0 analyze build_output.txt
EOF
            ;;
    esac
}

# Export functions
export -f stream_build_output
export -f stream_error_processor
export -f analyze_errors_streaming

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi