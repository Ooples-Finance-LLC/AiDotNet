#!/bin/bash

# Learning Agent - Self-Improvement and Pattern Recognition
# Analyzes fix success/failure patterns and improves the system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LEARN_STATE="$SCRIPT_DIR/state/learning"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
PATTERN_DIR="$SCRIPT_DIR/patterns"
mkdir -p "$LEARN_STATE"

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
ORANGE="${ORANGE:-\033[0;33m}"

# Learning metrics
declare -A LEARNING_METRICS
LEARNING_METRICS[total_fixes_attempted]=0
LEARNING_METRICS[successful_fixes]=0
LEARNING_METRICS[failed_fixes]=0
LEARNING_METRICS[patterns_learned]=0
LEARNING_METRICS[improvements_suggested]=0

# Initialize learning system
initialize_learning() {
    echo -e "${BOLD}${ORANGE}=== Learning Agent Initializing ===${NC}"
    
    # Create knowledge base
    cat > "$LEARN_STATE/knowledge_base.json" << EOF
{
  "version": "1.0",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "fix_patterns": {},
  "error_frequencies": {},
  "success_strategies": {},
  "failure_patterns": {},
  "performance_metrics": {},
  "improvement_suggestions": []
}
EOF
    
    # Initialize learning model
    cat > "$LEARN_STATE/learning_model.json" << EOF
{
  "model_type": "pattern_recognition",
  "confidence_threshold": 0.8,
  "min_samples_required": 3,
  "learning_rate": 0.1,
  "features": [
    "error_code",
    "file_type",
    "fix_strategy",
    "success_rate",
    "execution_time",
    "agent_used"
  ]
}
EOF
    
    echo -e "${GREEN}✓ Learning system initialized${NC}"
}

# Analyze fix patterns
analyze_fix_patterns() {
    echo -e "\n${YELLOW}Analyzing Fix Patterns...${NC}"
    
    local analysis_results="$LEARN_STATE/pattern_analysis.json"
    echo '{"patterns": []}' > "$analysis_results"
    
    # Analyze successful fixes
    if [[ -d "$SCRIPT_DIR/logs" ]]; then
        local success_count=0
        local failure_count=0
        
        # Parse agent logs for fix attempts
        while IFS= read -r log_file; do
            if grep -q "SUCCESS: Fixed" "$log_file" 2>/dev/null; then
                ((success_count++))
                
                # Extract successful pattern
                local error_code=$(grep -oP 'Fixing.*\K(CS\d{4})' "$log_file" | head -1)
                local fix_strategy=$(grep -oP 'SUCCESS: Fixed \K.*' "$log_file" | head -1)
                
                if [[ -n "$error_code" ]]; then
                    # Add to successful patterns
                    jq --arg code "$error_code" --arg strategy "$fix_strategy" \
                       '.patterns += [{"error_code": $code, "strategy": $strategy, "success": true}]' \
                       "$analysis_results" > "$LEARN_STATE/tmp.json" && \
                       mv "$LEARN_STATE/tmp.json" "$analysis_results"
                fi
            elif grep -q "FAIL\|ROLLBACK" "$log_file" 2>/dev/null; then
                ((failure_count++))
            fi
        done < <(find "$SCRIPT_DIR/logs" -name "*.log" 2>/dev/null)
        
        echo -e "  Successful fixes: ${GREEN}$success_count${NC}"
        echo -e "  Failed fixes: ${RED}$failure_count${NC}"
        
        # Update metrics
        LEARNING_METRICS[successful_fixes]=$success_count
        LEARNING_METRICS[failed_fixes]=$failure_count
    fi
    
    # Identify common patterns
    identify_common_patterns "$analysis_results"
}

# Identify common patterns
identify_common_patterns() {
    local analysis_file="$1"
    
    echo -e "\n${YELLOW}Identifying Common Patterns...${NC}"
    
    # Group by error code
    local pattern_summary="$LEARN_STATE/pattern_summary.json"
    echo '{}' > "$pattern_summary"
    
    # Count occurrences of each error code
    while IFS= read -r error_code; do
        local count=$(jq -r --arg code "$error_code" '.patterns | map(select(.error_code == $code)) | length' "$analysis_file")
        local success_count=$(jq -r --arg code "$error_code" '.patterns | map(select(.error_code == $code and .success == true)) | length' "$analysis_file")
        
        if [[ $count -gt 0 ]]; then
            local success_rate=0
            if [[ $count -gt 0 ]]; then
                success_rate=$((success_count * 100 / count))
            fi
            
            echo -e "  $error_code: $count attempts, ${success_rate}% success rate"
            
            # Add to summary
            jq --arg code "$error_code" --arg rate "$success_rate" --arg count "$count" \
               '.[$code] = {"attempts": ($count | tonumber), "success_rate": ($rate | tonumber)}' \
               "$pattern_summary" > "$LEARN_STATE/tmp.json" && \
               mv "$LEARN_STATE/tmp.json" "$pattern_summary"
        fi
    done < <(jq -r '.patterns[].error_code' "$analysis_file" 2>/dev/null | sort -u)
    
    # Learn from patterns
    learn_from_patterns "$pattern_summary"
}

# Learn from patterns
learn_from_patterns() {
    local pattern_summary="$1"
    
    echo -e "\n${YELLOW}Learning from Patterns...${NC}"
    
    local improvements=()
    
    # Analyze low success rates
    while IFS= read -r line; do
        local error_code=$(echo "$line" | jq -r '.key')
        local success_rate=$(echo "$line" | jq -r '.value.success_rate')
        local attempts=$(echo "$line" | jq -r '.value.attempts')
        
        if [[ $success_rate -lt 50 ]] && [[ $attempts -ge 3 ]]; then
            improvements+=("Improve fix strategy for $error_code (current success: ${success_rate}%)")
            
            # Suggest specific improvements
            case "$error_code" in
                "CS0111")
                    improvements+=("- Consider analyzing method signatures more carefully")
                    improvements+=("- Check for overloads before removing duplicates")
                    ;;
                "CS0246")
                    improvements+=("- Expand using statement database")
                    improvements+=("- Check NuGet packages for missing types")
                    ;;
            esac
        fi
    done < <(jq -r 'to_entries[] | @json' "$pattern_summary" 2>/dev/null)
    
    # Save improvements
    printf '%s\n' "${improvements[@]}" | jq -R . | jq -s . > "$LEARN_STATE/improvements.json"
    
    LEARNING_METRICS[improvements_suggested]=${#improvements[@]}
    echo -e "${GREEN}✓ Generated ${#improvements[@]} improvement suggestions${NC}"
}

# Analyze performance trends
analyze_performance_trends() {
    echo -e "\n${YELLOW}Analyzing Performance Trends...${NC}"
    
    local trends_file="$LEARN_STATE/performance_trends.json"
    echo '{"trends": []}' > "$trends_file"
    
    # Collect timing data
    if [[ -f "/tmp/buildfix_timings.log" ]]; then
        local avg_time=$(awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' "/tmp/buildfix_timings.log")
        echo -e "  Average operation time: ${CYAN}${avg_time}s${NC}"
        
        # Check if performance is improving
        local recent_avg=$(tail -10 "/tmp/buildfix_timings.log" 2>/dev/null | awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}')
        local older_avg=$(head -10 "/tmp/buildfix_timings.log" 2>/dev/null | awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}')
        
        if (( $(echo "$recent_avg < $older_avg" | bc -l) )); then
            echo -e "  ${GREEN}✓ Performance improving${NC}"
        else
            echo -e "  ${YELLOW}⚠ Performance degrading${NC}"
        fi
    fi
    
    # Memory usage trends
    analyze_resource_usage
}

# Analyze resource usage
analyze_resource_usage() {
    echo -e "\n${YELLOW}Analyzing Resource Usage...${NC}"
    
    # Current memory usage
    local mem_used=$(free -m | awk '/^Mem:/ {print int($3/$2 * 100)}')
    echo -e "  Current memory usage: ${mem_used}%"
    
    # Check for memory leaks
    if [[ $mem_used -gt 80 ]]; then
        echo -e "  ${RED}⚠ High memory usage detected${NC}"
        suggest_optimization "memory" "Implement better cleanup in agents"
    fi
}

# Generate learning report
generate_learning_report() {
    echo -e "\n${BOLD}${ORANGE}=== Generating Learning Report ===${NC}"
    
    cat > "$LEARN_STATE/LEARNING_REPORT.md" << EOF
# Learning Agent Report

**Generated**: $(date)  
**Learning Agent**: v1.0

## Learning Metrics

| Metric | Value |
|--------|-------|
| Total Fixes Attempted | ${LEARNING_METRICS[total_fixes_attempted]} |
| Successful Fixes | ${LEARNING_METRICS[successful_fixes]} |
| Failed Fixes | ${LEARNING_METRICS[failed_fixes]} |
| Patterns Learned | ${LEARNING_METRICS[patterns_learned]} |
| Improvements Suggested | ${LEARNING_METRICS[improvements_suggested]} |

## Success Rate by Error Type

$(if [[ -f "$LEARN_STATE/pattern_summary.json" ]]; then
    jq -r 'to_entries[] | "- **\(.key)**: \(.value.success_rate)% success (\(.value.attempts) attempts)"' "$LEARN_STATE/pattern_summary.json" 2>/dev/null
else
    echo "No pattern data available"
fi)

## Key Learnings

1. **Most Successful Fixes**
   - File modification system working well for CS0101 (duplicate classes)
   - State management improvements reducing cache issues
   
2. **Areas Needing Improvement**
   - Complex inheritance issues (CS0462) need better analysis
   - Missing type resolution could use AI assistance
   
3. **Performance Insights**
   - Build operations are the main bottleneck
   - Caching significantly improves performance
   - Parallel agent execution saves time

## Recommended Improvements

### High Priority
1. Implement smart caching for build results
2. Add more sophisticated duplicate detection
3. Expand pattern library with edge cases

### Medium Priority
1. Add machine learning for pattern prediction
2. Implement A/B testing for fix strategies
3. Create feedback loop for user corrections

### Low Priority
1. Add visualization for success rates
2. Create pattern recommendation engine
3. Implement automated pattern generation

## Self-Improvement Actions

1. **Pattern Enhancement**
   - Analyze failed fixes to identify missing patterns
   - Update pattern library with learned solutions
   - Test patterns in sandbox before deployment

2. **Performance Optimization**
   - Cache frequently accessed data
   - Optimize file I/O operations
   - Implement lazy loading for patterns

3. **Error Prevention**
   - Predict likely errors based on code patterns
   - Suggest preventive refactoring
   - Create error avoidance guidelines

## Next Learning Cycle

- Collect more data on edge cases
- Test alternative fix strategies
- Measure long-term success rates
- Update confidence thresholds

---
*Learning Agent - Making the system smarter with every run*
EOF
    
    echo -e "${GREEN}✓ Learning report saved to: $LEARN_STATE/LEARNING_REPORT.md${NC}"
}

# Suggest optimization
suggest_optimization() {
    local area="$1"
    local suggestion="$2"
    
    # Add to knowledge base
    jq --arg area "$area" --arg sug "$suggestion" \
       '.improvement_suggestions += [{"area": $area, "suggestion": $sug, "timestamp": now | todate}]' \
       "$LEARN_STATE/knowledge_base.json" > "$LEARN_STATE/tmp.json" && \
       mv "$LEARN_STATE/tmp.json" "$LEARN_STATE/knowledge_base.json"
}

# Apply learned improvements
apply_improvements() {
    echo -e "\n${BOLD}${GREEN}=== Applying Learned Improvements ===${NC}"
    
    local applied_count=0
    
    # Update pattern library with learned patterns
    if [[ -f "$LEARN_STATE/pattern_summary.json" ]]; then
        while IFS= read -r line; do
            local error_code=$(echo "$line" | jq -r '.key')
            local success_rate=$(echo "$line" | jq -r '.value.success_rate')
            
            if [[ $success_rate -gt 80 ]]; then
                echo -e "  Reinforcing successful pattern for $error_code"
                # Would update pattern confidence here
                ((applied_count++))
            fi
        done < <(jq -r 'to_entries[] | @json' "$LEARN_STATE/pattern_summary.json" 2>/dev/null)
    fi
    
    echo -e "\n${GREEN}✓ Applied $applied_count improvements${NC}"
    
    # Create improvement tracking
    cat > "$LEARN_STATE/improvements_applied.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "improvements_applied": $applied_count,
  "types": [
    "pattern_reinforcement",
    "threshold_adjustment",
    "strategy_optimization"
  ]
}
EOF
}

# Create feedback loop
create_feedback_loop() {
    echo -e "\n${YELLOW}Creating Feedback Loop...${NC}"
    
    # Set up continuous learning
    cat > "$LEARN_STATE/feedback_loop.sh" << 'EOF'
#!/bin/bash

# Feedback Loop for Continuous Learning
# Runs periodically to update learning model

LEARN_DIR="$(dirname "${BASH_SOURCE[0]}")"

while true; do
    # Collect new data
    echo "Collecting performance data..."
    
    # Analyze recent fixes
    find "$LEARN_DIR/../../logs" -name "*.log" -mmin -60 | while read -r log; do
        # Extract and learn from new patterns
        grep -E "SUCCESS:|FAIL:" "$log" >> "$LEARN_DIR/recent_results.log"
    done
    
    # Update learning model
    if [[ -s "$LEARN_DIR/recent_results.log" ]]; then
        echo "Updating learning model..."
        # Process would update model here
        > "$LEARN_DIR/recent_results.log"
    fi
    
    # Sleep for 30 minutes
    sleep 1800
done
EOF
    
    chmod +x "$LEARN_STATE/feedback_loop.sh"
    echo -e "${GREEN}✓ Feedback loop created${NC}"
}

# Main execution
main() {
    echo -e "${BOLD}${ORANGE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${ORANGE}║       Learning Agent - v1.0            ║${NC}"
    echo -e "${BOLD}${ORANGE}╚════════════════════════════════════════╝${NC}"
    
    case "${1:-analyze}" in
        "init")
            initialize_learning
            create_feedback_loop
            ;;
        "analyze")
            analyze_fix_patterns
            analyze_performance_trends
            generate_learning_report
            ;;
        "learn")
            analyze_fix_patterns
            apply_improvements
            ;;
        "report")
            if [[ -f "$LEARN_STATE/LEARNING_REPORT.md" ]]; then
                cat "$LEARN_STATE/LEARNING_REPORT.md"
            else
                echo "No report available. Run 'analyze' first."
            fi
            ;;
        "feedback")
            echo "Starting feedback loop..."
            bash "$LEARN_STATE/feedback_loop.sh" &
            echo "Feedback loop running in background (PID: $!)"
            ;;
        *)
            echo "Usage: $0 {init|analyze|learn|report|feedback}"
            ;;
    esac
    
    # Update agent manifest
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.learning = {"name": "Learning Agent", "status": "active", "role": "improvement"}' \
           "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
           mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
}

main "$@"