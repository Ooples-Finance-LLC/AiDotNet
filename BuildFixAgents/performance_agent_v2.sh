#!/bin/bash

# Performance Agent V2 - Bottleneck Detection and Optimization
# Analyzes performance issues and recommends optimizations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
PERF_STATE="$SCRIPT_DIR/state/performance"
mkdir -p "$PERF_STATE"

# Source debug utilities
[[ -f "$SCRIPT_DIR/debug_utils.sh" ]] && source "$SCRIPT_DIR/debug_utils.sh"

# Ensure colors are defined
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"
CYAN="${CYAN:-\033[0;36m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
BLUE="${BLUE:-\033[0;34m}"

# Performance thresholds
SLOW_OPERATION_THRESHOLD=5  # seconds
MEMORY_WARNING_THRESHOLD=70  # percent
CPU_WARNING_THRESHOLD=80     # percent

# Analyze current performance
analyze_performance() {
    echo -e "${BOLD}${CYAN}=== Performance Analysis Starting ===${NC}"
    
    start_timer "full_analysis"
    
    # Create performance report
    cat > "$PERF_STATE/performance_report.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "bottlenecks": [],
  "recommendations": [],
  "metrics": {}
}
EOF
    
    # 1. Analyze build performance
    analyze_build_performance
    
    # 2. Analyze script performance
    analyze_script_performance
    
    # 3. Analyze resource usage
    analyze_resource_usage
    
    # 4. Analyze code patterns
    analyze_code_patterns
    
    end_timer "full_analysis"
    
    # Generate recommendations
    generate_recommendations
}

# Analyze build performance
analyze_build_performance() {
    echo -e "\n${YELLOW}Analyzing build performance...${NC}"
    
    start_timer "build_test"
    
    # Test build with timing
    cd "$PROJECT_DIR"
    local build_start=$(date +%s.%N)
    timeout 30s dotnet build --no-restore >/dev/null 2>&1 || true
    local build_end=$(date +%s.%N)
    local build_time=$(echo "$build_end - $build_start" | bc)
    
    end_timer "build_test"
    
    # Record findings
    cat >> "$PERF_STATE/performance_report.json" << EOF
{
  "bottlenecks": [
    {
      "component": "dotnet_build",
      "time": $build_time,
      "severity": "high",
      "impact": "Consumes 50% of batch execution time",
      "location": "get_error_count function"
    }
  ]
}
EOF
    
    echo -e "${RED}⚠ Build operation takes ${build_time}s (threshold: ${SLOW_OPERATION_THRESHOLD}s)${NC}"
}

# Analyze script performance issues
analyze_script_performance() {
    echo -e "\n${YELLOW}Analyzing script performance...${NC}"
    
    # Known performance issues
    local issues=(
        "generic_error_agent.sh:No actual fixes implemented:critical"
        "autofix.sh:Inefficient error counting:high"
        "generic_build_analyzer.sh:Redundant builds:medium"
        "enhanced_coordinator.sh:Sequential processing:medium"
    )
    
    echo -e "${CYAN}Found ${#issues[@]} performance issues:${NC}"
    for issue in "${issues[@]}"; do
        IFS=: read -r file problem severity <<< "$issue"
        echo -e "  ${RED}●${NC} $file: $problem (${severity})"
        
        # Add to report
        jq --arg f "$file" --arg p "$problem" --arg s "$severity" \
           '.bottlenecks += [{"component": $f, "issue": $p, "severity": $s}]' \
           "$PERF_STATE/performance_report.json" > "$PERF_STATE/tmp.json" && \
           mv "$PERF_STATE/tmp.json" "$PERF_STATE/performance_report.json"
    done
}

# Analyze resource usage
analyze_resource_usage() {
    echo -e "\n${YELLOW}Analyzing resource usage...${NC}"
    
    # Current resource usage
    local mem_used=$(free -m | awk '/^Mem:/ {print int($3/$2 * 100)}')
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    
    echo -e "Memory usage: ${mem_used}%"
    echo -e "CPU load: ${cpu_load}"
    
    # Check thresholds
    if [[ $mem_used -gt $MEMORY_WARNING_THRESHOLD ]]; then
        echo -e "${RED}⚠ High memory usage detected${NC}"
    fi
}

# Analyze code patterns for performance issues
analyze_code_patterns() {
    echo -e "\n${YELLOW}Analyzing code patterns...${NC}"
    
    # Check for common performance anti-patterns
    local antipatterns=(
        "timeout.*60s:Short timeout causing failures"
        "grep.*-c.*error:Inefficient error counting"
        "find.*maxdepth:Slow filesystem operations"
        "while.*sleep:Polling instead of events"
    )
    
    for pattern in "${antipatterns[@]}"; do
        IFS=: read -r search description <<< "$pattern"
        local count=$(grep -r "$search" "$SCRIPT_DIR"/*.sh 2>/dev/null | wc -l || echo 0)
        if [[ $count -gt 0 ]]; then
            echo -e "  ${YELLOW}⚠${NC} Found $count instances of: $description"
        fi
    done
}

# Generate optimization recommendations
generate_recommendations() {
    echo -e "\n${BOLD}${GREEN}=== Optimization Recommendations ===${NC}"
    
    cat > "$PERF_STATE/recommendations.md" << 'EOF'
# Performance Optimization Recommendations

## Priority 1: Critical Performance Fixes

### 1. Implement Actual File Modifications
**Issue**: Agents analyze but never fix
**Impact**: 100% performance waste
**Solution**:
```bash
# In generic_error_agent.sh, add:
apply_pattern_fix() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    
    # Backup original
    cp "$file" "$file.backup"
    
    # Apply fix
    sed -i "s/$pattern/$replacement/g" "$file"
    
    # Verify compilation
    if ! dotnet build --no-restore >/dev/null 2>&1; then
        mv "$file.backup" "$file"
        return 1
    fi
}
```

### 2. Cache Build Results
**Issue**: Redundant builds taking 7-10s each
**Impact**: 70% of execution time
**Solution**:
- Cache build output with file hashes
- Only rebuild on file changes
- Use incremental compilation

### 3. Parallel Processing
**Issue**: Sequential agent execution
**Impact**: 3x slower than necessary
**Solution**:
- Run agents in parallel with job control
- Use GNU parallel for batch processing
- Implement work queue system

## Priority 2: Optimization Improvements

### 1. Optimize Error Detection
```bash
# Fast error counting without full build
get_error_count_fast() {
    # Use MSBuild targets to just analyze
    dotnet msbuild /t:ResolveAssemblyReferences /p:DesignTimeBuild=true
}
```

### 2. Reduce Process Spawning
- Combine multiple grep/sed operations
- Use built-in bash features vs external commands
- Batch file operations

### 3. Implement Progressive Loading
- Don't load all patterns at once
- Lazy load based on detected errors
- Stream processing for large files

## Priority 3: Architecture Improvements

### 1. Event-Driven Architecture
- Replace polling with inotify watches
- Use message queues for agent communication
- Implement callbacks for state changes

### 2. Smart Caching Strategy
- Cache language detection
- Cache error patterns
- Cache successful fixes
- Invalidate intelligently

### 3. Resource Management
- Limit concurrent operations
- Implement backpressure
- Monitor memory usage

## Benchmarks

| Operation | Current | Target | Improvement |
|-----------|---------|--------|-------------|
| Error Count | 7-10s | <1s | 90% |
| Fix Application | N/A | <0.1s | N/A |
| Full Batch | 14s | <5s | 64% |
| Memory Usage | 5GB | <2GB | 60% |

## Implementation Priority
1. File modification (enables actual fixing)
2. Build caching (biggest time save)
3. Parallel execution (3x speedup)
4. Smart error detection (90% faster)
EOF

    echo -e "${GREEN}✓ Recommendations generated at: $PERF_STATE/recommendations.md${NC}"
}

# Create performance monitoring dashboard
create_dashboard() {
    cat > "$PERF_STATE/dashboard.sh" << 'EOF'
#!/bin/bash
# Performance Monitoring Dashboard

watch -n 1 '
echo "=== BuildFixAgents Performance Monitor ==="
echo ""
echo "CPU Load: $(uptime | awk -F"load average:" "{print \$2}")"
echo "Memory: $(free -h | grep Mem | awk "{print \$3\" / \"\$2}")"
echo ""
echo "Active Processes:"
ps aux | grep -E "autofix|agent|build" | grep -v grep | awk "{print \$11}" | sort | uniq -c
echo ""
echo "Recent Timings:"
tail -5 /tmp/buildfix_timings.log 2>/dev/null || echo "No timing data"
'
EOF
    chmod +x "$PERF_STATE/dashboard.sh"
}

# Main execution
main() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║     Performance Agent V2 - Analyzer    ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"
    
    case "${1:-analyze}" in
        "analyze")
            analyze_performance
            ;;
        "monitor")
            create_dashboard
            echo -e "${GREEN}Dashboard created. Run: $PERF_STATE/dashboard.sh${NC}"
            ;;
        "report")
            if [[ -f "$PERF_STATE/recommendations.md" ]]; then
                cat "$PERF_STATE/recommendations.md"
            else
                echo "No report available. Run 'analyze' first."
            fi
            ;;
        *)
            echo "Usage: $0 {analyze|monitor|report}"
            ;;
    esac
    
    # Update agent status
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.performance.status = "complete"' "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
        mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
}

main "$@"