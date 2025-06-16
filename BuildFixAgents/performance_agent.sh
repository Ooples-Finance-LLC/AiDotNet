#!/bin/bash

# Performance Agent - Runs benchmarks and detects performance bottlenecks
# Reports performance issues to developer agents for optimization

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
PERF_RESULTS_DIR="$AGENT_DIR/state/performance_results"
BOTTLENECKS_LOG="$AGENT_DIR/state/performance_bottlenecks.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Agent ID
AGENT_ID="performance_agent_$$"

# Performance thresholds
MEMORY_THRESHOLD_MB=500
CPU_THRESHOLD_PERCENT=80
RESPONSE_TIME_THRESHOLD_MS=1000
GC_PRESSURE_THRESHOLD=10

# Initialize
mkdir -p "$PERF_RESULTS_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] PERFORMANCE_AGENT [$level]: $message" | tee -a "$AGENT_DIR/logs/performance_agent.log"
}

# Create simple benchmark
create_benchmark() {
    local project_file="$1"
    local benchmark_file="${project_file%.csproj}.Benchmark.cs"
    
    if [[ -f "$benchmark_file" ]]; then
        return 0
    fi
    
    # Create a basic benchmark file
    cat > "$benchmark_file" << 'EOF'
using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

public static class PerformanceBenchmark
{
    public static void RunBenchmarks()
    {
        Console.WriteLine("=== Performance Benchmarks ===");
        
        // Memory allocation test
        var memoryTest = MeasureMemoryAllocation();
        Console.WriteLine($"Memory Test: {memoryTest.TotalMilliseconds:F2}ms, {GC.GetTotalMemory(false) / 1024 / 1024}MB used");
        
        // CPU intensive test
        var cpuTest = MeasureCPUIntensive();
        Console.WriteLine($"CPU Test: {cpuTest.TotalMilliseconds:F2}ms");
        
        // Collection performance
        var collectionTest = MeasureCollections();
        Console.WriteLine($"Collection Test: {collectionTest.TotalMilliseconds:F2}ms");
        
        // GC pressure
        Console.WriteLine($"GC Collections - Gen0: {GC.CollectionCount(0)}, Gen1: {GC.CollectionCount(1)}, Gen2: {GC.CollectionCount(2)}");
    }
    
    static TimeSpan MeasureMemoryAllocation()
    {
        var sw = Stopwatch.StartNew();
        var list = new List<byte[]>();
        for (int i = 0; i < 1000; i++)
        {
            list.Add(new byte[1024 * 10]); // 10KB allocations
        }
        sw.Stop();
        return sw.Elapsed;
    }
    
    static TimeSpan MeasureCPUIntensive()
    {
        var sw = Stopwatch.StartNew();
        double result = 0;
        for (int i = 0; i < 1000000; i++)
        {
            result += Math.Sqrt(i) * Math.Sin(i);
        }
        sw.Stop();
        return sw.Elapsed;
    }
    
    static TimeSpan MeasureCollections()
    {
        var sw = Stopwatch.StartNew();
        var dict = new Dictionary<int, string>();
        for (int i = 0; i < 10000; i++)
        {
            dict[i] = i.ToString();
        }
        var sum = dict.Values.Where(v => v.Length > 2).Count();
        sw.Stop();
        return sw.Elapsed;
    }
}
EOF
}

# Profile application performance
profile_application() {
    local project_file="$1"
    local project_name=$(basename "$project_file" .csproj)
    local output_file="$PERF_RESULTS_DIR/${project_name}_perf_$(date +%Y%m%d_%H%M%S).log"
    
    log_message "Profiling performance: $project_name"
    
    # Build with Release configuration
    if ! dotnet build "$project_file" -c Release -nologo > "$output_file.build" 2>&1; then
        log_message "Build failed for $project_name" "ERROR"
        return 1
    fi
    
    # Run with performance monitoring
    local start_time=$(date +%s%N)
    local start_memory=$(ps aux | grep -E "dotnet|${project_name}" | awk '{sum+=$6} END {print sum/1024}' || echo "0")
    
    # Execute with performance tracking
    (
        export DOTNET_EnableEventLog=1
        export COMPlus_EnableEventLog=1
        timeout 60 dotnet run --project "$project_file" --configuration Release --no-build
    ) > "$output_file" 2>&1 &
    
    local pid=$!
    
    # Monitor performance metrics
    monitor_process_performance "$pid" "$output_file.metrics" &
    local monitor_pid=$!
    
    # Wait for completion
    local exit_code=0
    if wait $pid; then
        exit_code=$?
    else
        exit_code=$?
    fi
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    # Analyze performance results
    analyze_performance "$project_name" "$output_file" "$output_file.metrics" "$duration"
}

# Monitor process performance metrics
monitor_process_performance() {
    local pid="$1"
    local metrics_file="$2"
    
    echo "timestamp,cpu,memory,threads" > "$metrics_file"
    
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -f "/proc/$pid/stat" ]]; then
            local cpu=$(ps -p "$pid" -o %cpu= || echo "0")
            local memory=$(ps -p "$pid" -o %mem= || echo "0")
            local threads=$(ps -p "$pid" -o nlwp= || echo "1")
            
            echo "$(date +%s),$cpu,$memory,$threads" >> "$metrics_file"
        fi
        sleep 0.5
    done
}

# Analyze performance results
analyze_performance() {
    local project_name="$1"
    local output_file="$2"
    local metrics_file="$3"
    local duration="$4"
    
    local bottlenecks=()
    
    # Check execution time
    if [[ $duration -gt $RESPONSE_TIME_THRESHOLD_MS ]]; then
        bottlenecks+=("SLOW: Execution time ${duration}ms exceeds threshold")
        record_bottleneck "$project_name" "slow_execution" "$duration" "Execution took ${duration}ms"
    fi
    
    # Check CPU usage
    if [[ -f "$metrics_file" ]]; then
        local avg_cpu=$(tail -n +2 "$metrics_file" | awk -F, '{sum+=$2; count++} END {print sum/count}' || echo "0")
        if (( $(echo "$avg_cpu > $CPU_THRESHOLD_PERCENT" | bc -l) )); then
            bottlenecks+=("CPU: High CPU usage ${avg_cpu}%")
            record_bottleneck "$project_name" "high_cpu" "$avg_cpu" "Average CPU usage ${avg_cpu}%"
        fi
    fi
    
    # Check memory usage
    local memory_usage=$(grep -E "MB used|Memory:" "$output_file" | grep -oE '[0-9]+' | head -1 || echo "0")
    if [[ $memory_usage -gt $MEMORY_THRESHOLD_MB ]]; then
        bottlenecks+=("MEMORY: High memory usage ${memory_usage}MB")
        record_bottleneck "$project_name" "high_memory" "$memory_usage" "Memory usage ${memory_usage}MB"
    fi
    
    # Check GC pressure
    local gc_count=$(grep -oE "Gen[0-2]: [0-9]+" "$output_file" | awk '{sum+=$2} END {print sum}' || echo "0")
    if [[ $gc_count -gt $GC_PRESSURE_THRESHOLD ]]; then
        bottlenecks+=("GC: High garbage collection pressure")
        record_bottleneck "$project_name" "gc_pressure" "$gc_count" "GC collections: $gc_count"
    fi
    
    # Check for specific performance anti-patterns
    check_antipatterns "$project_name" "$output_file"
    
    # Report results
    if [[ ${#bottlenecks[@]} -eq 0 ]]; then
        log_message "✓ $project_name performance acceptable (${duration}ms)" "SUCCESS"
    else
        log_message "✗ $project_name has ${#bottlenecks[@]} performance issues:" "WARNING"
        for bottleneck in "${bottlenecks[@]}"; do
            log_message "  - $bottleneck" "WARNING"
        done
    fi
}

# Check for performance anti-patterns
check_antipatterns() {
    local project_name="$1"
    local output_file="$2"
    
    # Check for common issues
    if grep -q "StackOverflowException" "$output_file"; then
        record_bottleneck "$project_name" "stack_overflow" "infinite_recursion" "Possible infinite recursion detected"
    fi
    
    if grep -q "OutOfMemoryException" "$output_file"; then
        record_bottleneck "$project_name" "out_of_memory" "memory_leak" "Possible memory leak detected"
    fi
    
    # Scan source for anti-patterns
    local source_files=$(find "$(dirname "$project_name")" -name "*.cs" -type f 2>/dev/null || true)
    
    while IFS= read -r source; do
        [[ -z "$source" ]] && continue
        
        # Check for nested loops
        if grep -E "for.*for|while.*while" "$source" > /dev/null; then
            record_bottleneck "$project_name" "nested_loops" "$(basename "$source")" "Nested loops detected - potential O(n²) complexity"
        fi
        
        # Check for large collections in memory
        if grep -E "new.*\[[0-9]{6,}\]|List.*\([0-9]{6,}\)" "$source" > /dev/null; then
            record_bottleneck "$project_name" "large_allocation" "$(basename "$source")" "Large memory allocation detected"
        fi
        
        # Check for synchronous I/O in async context
        if grep -E "async.*\.Result|async.*\.Wait\(\)" "$source" > /dev/null; then
            record_bottleneck "$project_name" "sync_over_async" "$(basename "$source")" "Synchronous wait in async method"
        fi
    done <<< "$source_files"
}

# Record performance bottleneck
record_bottleneck() {
    local project="$1"
    local bottleneck_type="$2"
    local metric="$3"
    local context="$4"
    
    # Create bottleneck record
    local bottleneck_record=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "$AGENT_ID",
  "project": "$project",
  "bottleneck_type": "$bottleneck_type",
  "metric": "$metric",
  "context": "$context",
  "severity": "$(get_severity "$bottleneck_type")",
  "suggested_optimization": "$(suggest_optimization "$bottleneck_type")"
}
EOF
)
    
    # Append to bottlenecks log
    echo "$bottleneck_record," >> "$BOTTLENECKS_LOG"
    
    # Create optimization task for developer agents
    create_optimization_task "$project" "$bottleneck_type" "$metric" "$context"
}

# Get severity of bottleneck
get_severity() {
    local bottleneck_type="$1"
    
    case "$bottleneck_type" in
        "out_of_memory"|"stack_overflow")
            echo "critical"
            ;;
        "high_cpu"|"high_memory"|"gc_pressure")
            echo "high"
            ;;
        "slow_execution"|"nested_loops")
            echo "medium"
            ;;
        *)
            echo "low"
            ;;
    esac
}

# Suggest optimization
suggest_optimization() {
    local bottleneck_type="$1"
    
    case "$bottleneck_type" in
        "slow_execution")
            echo "Profile and optimize hot paths, consider async operations"
            ;;
        "high_cpu")
            echo "Optimize algorithms, use parallel processing where appropriate"
            ;;
        "high_memory")
            echo "Reduce memory allocations, use object pooling"
            ;;
        "gc_pressure")
            echo "Reduce allocations, use value types, implement IDisposable"
            ;;
        "nested_loops")
            echo "Optimize algorithm complexity, use hash tables or better data structures"
            ;;
        "large_allocation")
            echo "Use streaming or pagination instead of loading everything in memory"
            ;;
        "sync_over_async")
            echo "Use await instead of .Result or .Wait()"
            ;;
        *)
            echo "Analyze and optimize performance bottleneck"
            ;;
    esac
}

# Create optimization task
create_optimization_task() {
    local project="$1"
    local bottleneck_type="$2"
    local metric="$3"
    local context="$4"
    
    # Add to coordination file
    cat >> "$AGENT_DIR/state/AGENT_COORDINATION.md" << EOF

## Performance Bottleneck Detected - $(date '+%Y-%m-%d %H:%M:%S')
- **Project**: $project
- **Bottleneck Type**: $bottleneck_type
- **Metric**: $metric
- **Severity**: $(get_severity "$bottleneck_type")
- **Optimization**: $(suggest_optimization "$bottleneck_type")
- **Context**: $context
- **Status**: PENDING_OPTIMIZATION
EOF
    
    log_message "Created optimization task for $bottleneck_type in $project"
}

# Run benchmarks
run_benchmarks() {
    log_message "Running performance benchmarks..."
    
    # Find all executable projects
    local projects=$(find "$PROJECT_DIR" -name "*.csproj" -type f | \
        xargs grep -l "<OutputType>Exe</OutputType>" || true)
    
    if [[ -z "$projects" ]]; then
        log_message "No executable projects found for benchmarking"
        return
    fi
    
    while IFS= read -r proj; do
        [[ -z "$proj" ]] && continue
        
        # Create benchmark if needed
        create_benchmark "$proj"
        
        # Profile the application
        profile_application "$proj"
    done <<< "$projects"
}

# Generate performance report
generate_report() {
    local report_file="$AGENT_DIR/state/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Performance Analysis Report
Generated: $(date)

## Summary
- Projects Analyzed: $(find "$PERF_RESULTS_DIR" -name "*.log" | wc -l)
- Bottlenecks Found: $(grep -c "bottleneck_type" "$BOTTLENECKS_LOG" 2>/dev/null || echo "0")

## Bottlenecks by Type
EOF
    
    if [[ -f "$BOTTLENECKS_LOG" ]]; then
        echo "| Bottleneck Type | Count | Severity |" >> "$report_file"
        echo "|-----------------|-------|----------|" >> "$report_file"
        
        grep "bottleneck_type" "$BOTTLENECKS_LOG" | cut -d'"' -f6 | sort | uniq -c | \
            while read -r count type; do
                local severity=$(grep -A2 "\"$type\"" "$BOTTLENECKS_LOG" | grep severity | head -1 | cut -d'"' -f4)
                echo "| $type | $count | $severity |" >> "$report_file"
            done
    fi
    
    echo -e "\n## Recommendations" >> "$report_file"
    echo "1. Address critical bottlenecks first" >> "$report_file"
    echo "2. Profile before and after optimization" >> "$report_file"
    echo "3. Consider architectural changes for systemic issues" >> "$report_file"
    
    echo -e "\nReport saved to: $report_file"
}

# Main execution
main() {
    log_message "=== PERFORMANCE AGENT STARTING ==="
    
    case "${1:-analyze}" in
        "analyze")
            run_benchmarks
            generate_report
            ;;
            
        "monitor")
            # Continuous monitoring mode
            while true; do
                run_benchmarks
                sleep 300  # Run every 5 minutes
            done
            ;;
            
        "report")
            generate_report
            ;;
            
        *)
            echo "Usage: $0 {analyze|monitor|report}"
            exit 1
            ;;
    esac
    
    log_message "=== PERFORMANCE AGENT COMPLETE ==="
}

# Execute
main "$@"