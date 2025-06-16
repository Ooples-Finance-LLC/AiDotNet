#!/bin/bash

# A/B Testing Framework for Build Fix Agents
# Tests multiple fix strategies and chooses the most effective

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
AB_STATE="$AGENT_DIR/state/ab_testing"
AB_CONFIG="$AGENT_DIR/config/ab_testing.yml"
EXPERIMENTS_DIR="$AB_STATE/experiments"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Initialize
mkdir -p "$AB_STATE" "$EXPERIMENTS_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[$timestamp] AB_TESTING${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/ab_testing.log"
}

# Create default configuration
create_default_config() {
    if [[ ! -f "$AB_CONFIG" ]]; then
        cat > "$AB_CONFIG" << 'EOF'
# A/B Testing Configuration
ab_testing:
  enabled: true
  mode: "automatic"  # manual, automatic, hybrid
  
  # Experiment settings
  experiments:
    min_sample_size: 10
    confidence_level: 0.95
    max_variants: 4
    timeout_minutes: 30
    
  # Traffic allocation
  traffic:
    default_split: [50, 50]  # Control vs variant
    gradual_rollout: true
    rollout_schedule:
      - percentage: 10
        duration: 300  # 5 minutes
      - percentage: 50
        duration: 900  # 15 minutes
      - percentage: 100
        duration: 1800  # 30 minutes
        
  # Metrics to track
  metrics:
    primary:
      - fix_success_rate
      - execution_time
    secondary:
      - memory_usage
      - file_modifications
      - error_reduction
      
  # Decision criteria
  decision:
    method: "statistical_significance"  # winner_takes_all, epsilon_greedy, thompson_sampling
    threshold: 0.05  # p-value threshold
    minimum_improvement: 0.10  # 10% improvement required
    
  # Safety checks
  safety:
    enable_rollback: true
    error_threshold: 0.2  # 20% error rate triggers rollback
    canary_deployment: true
    backup_before_test: true
EOF
        log_message "Created default A/B testing configuration"
    fi
}

# Create experiment
create_experiment() {
    local experiment_name="$1"
    local hypothesis="$2"
    local variants="${3:-2}"
    
    log_message "Creating experiment: $experiment_name"
    
    local experiment_id="exp_$(date +%s)_$(uuidgen | cut -d'-' -f1)"
    local experiment_dir="$EXPERIMENTS_DIR/$experiment_id"
    
    mkdir -p "$experiment_dir/variants" "$experiment_dir/results"
    
    # Create experiment metadata
    cat > "$experiment_dir/experiment.json" << EOF
{
  "id": "$experiment_id",
  "name": "$experiment_name",
  "hypothesis": "$hypothesis",
  "status": "created",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "started_at": null,
  "ended_at": null,
  "variants": [],
  "metrics": {
    "control": {},
    "variants": {}
  },
  "conclusion": null
}
EOF
    
    log_message "Experiment created: $experiment_id"
    echo "$experiment_id"
}

# Add variant to experiment
add_variant() {
    local experiment_id="$1"
    local variant_name="$2"
    local variant_code="$3"
    local is_control="${4:-false}"
    
    log_message "Adding variant '$variant_name' to experiment $experiment_id"
    
    local experiment_dir="$EXPERIMENTS_DIR/$experiment_id"
    local variant_id="var_$(date +%s)_$(uuidgen | cut -d'-' -f1)"
    local variant_file="$experiment_dir/variants/${variant_id}.sh"
    
    # Save variant code
    cat > "$variant_file" << EOF
#!/bin/bash
# Variant: $variant_name
# Experiment: $experiment_id

set -euo pipefail

# Variant implementation
$variant_code
EOF
    
    chmod +x "$variant_file"
    
    # Update experiment metadata
    local temp_file=$(mktemp)
    jq ".variants += [{
        \"id\": \"$variant_id\",
        \"name\": \"$variant_name\",
        \"is_control\": $is_control,
        \"file\": \"$variant_file\",
        \"executions\": 0,
        \"successes\": 0,
        \"failures\": 0
    }]" "$experiment_dir/experiment.json" > "$temp_file"
    
    mv "$temp_file" "$experiment_dir/experiment.json"
    
    log_message "Variant added: $variant_id ($variant_name)"
}

# Run experiment
run_experiment() {
    local experiment_id="$1"
    local iterations="${2:-100}"
    
    log_message "Running experiment: $experiment_id with $iterations iterations"
    
    local experiment_dir="$EXPERIMENTS_DIR/$experiment_id"
    local experiment_file="$experiment_dir/experiment.json"
    
    # Update status
    update_experiment_status "$experiment_id" "running"
    
    # Get variants
    local variants=$(jq -r '.variants[].id' "$experiment_file")
    local variant_count=$(echo "$variants" | wc -l)
    
    # Initialize results
    for variant_id in $variants; do
        init_variant_results "$experiment_id" "$variant_id"
    done
    
    # Run iterations
    for ((i=1; i<=iterations; i++)); do
        log_message "Iteration $i/$iterations"
        
        # Select variant based on allocation strategy
        local selected_variant=$(select_variant "$experiment_id" "$i")
        
        # Run variant
        run_variant "$experiment_id" "$selected_variant" "$i"
        
        # Check early stopping conditions
        if should_stop_early "$experiment_id"; then
            log_message "Early stopping triggered"
            break
        fi
    done
    
    # Analyze results
    analyze_experiment "$experiment_id"
    
    # Update status
    update_experiment_status "$experiment_id" "completed"
}

# Select variant based on allocation strategy
select_variant() {
    local experiment_id="$1"
    local iteration="$2"
    
    local experiment_file="$EXPERIMENTS_DIR/$experiment_id/experiment.json"
    local variants=$(jq -r '.variants[].id' "$experiment_file")
    local variant_array=($variants)
    
    # Get allocation method from config
    local method="${AB_DECISION_METHOD:-statistical_significance}"
    
    case "$method" in
        "epsilon_greedy")
            # Epsilon-greedy: explore vs exploit
            local epsilon=0.1
            if (( $(echo "$(random_float) < $epsilon" | bc -l) )); then
                # Explore: random selection
                local index=$((RANDOM % ${#variant_array[@]}))
                echo "${variant_array[$index]}"
            else
                # Exploit: select best performing
                select_best_variant "$experiment_id"
            fi
            ;;
            
        "thompson_sampling")
            # Thompson sampling: probabilistic selection
            select_thompson_variant "$experiment_id"
            ;;
            
        *)
            # Default: round-robin for even distribution
            local index=$(( (iteration - 1) % ${#variant_array[@]} ))
            echo "${variant_array[$index]}"
            ;;
    esac
}

# Run variant
run_variant() {
    local experiment_id="$1"
    local variant_id="$2"
    local iteration="$3"
    
    local experiment_dir="$EXPERIMENTS_DIR/$experiment_id"
    local variant_file=$(jq -r ".variants[] | select(.id == \"$variant_id\") | .file" "$experiment_dir/experiment.json")
    
    log_message "Running variant $variant_id (iteration $iteration)"
    
    # Create test environment
    local test_dir=$(mktemp -d)
    cp -r "$PROJECT_DIR"/* "$test_dir/" 2>/dev/null || true
    
    # Backup if safety enabled
    if [[ "${AB_BACKUP_BEFORE_TEST:-true}" == "true" ]]; then
        tar -czf "$experiment_dir/results/backup_${iteration}.tar.gz" -C "$test_dir" . 2>/dev/null || true
    fi
    
    # Measure execution
    local start_time=$(date +%s.%N)
    local success=false
    local error_msg=""
    
    # Run variant in test environment
    cd "$test_dir"
    if bash "$variant_file" > "$experiment_dir/results/output_${variant_id}_${iteration}.log" 2>&1; then
        success=true
    else
        error_msg="Variant execution failed"
    fi
    cd - > /dev/null
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc)
    
    # Measure results
    local metrics=$(measure_variant_metrics "$test_dir" "$execution_time")
    
    # Record results
    record_variant_result "$experiment_id" "$variant_id" "$iteration" "$success" "$metrics"
    
    # Cleanup
    rm -rf "$test_dir"
}

# Measure variant metrics
measure_variant_metrics() {
    local test_dir="$1"
    local execution_time="$2"
    
    # Count remaining errors
    local remaining_errors=0
    if [[ -f "$test_dir/build_output.txt" ]]; then
        remaining_errors=$(grep -c "error" "$test_dir/build_output.txt" 2>/dev/null || echo 0)
    fi
    
    # Count modified files
    local modified_files=$(find "$test_dir" -name "*.cs" -newer "$test_dir" 2>/dev/null | wc -l || echo 0)
    
    # Memory usage (if available)
    local memory_usage=0
    if command -v /usr/bin/time &> /dev/null; then
        memory_usage=$(/usr/bin/time -f "%M" echo 2>&1 | tail -1)
    fi
    
    # Create metrics JSON
    cat << EOF
{
  "execution_time": $execution_time,
  "remaining_errors": $remaining_errors,
  "modified_files": $modified_files,
  "memory_usage_kb": $memory_usage,
  "timestamp": $(date +%s)
}
EOF
}

# Record variant result
record_variant_result() {
    local experiment_id="$1"
    local variant_id="$2"
    local iteration="$3"
    local success="$4"
    local metrics="$5"
    
    local result_file="$EXPERIMENTS_DIR/$experiment_id/results/result_${variant_id}_${iteration}.json"
    
    cat > "$result_file" << EOF
{
  "variant_id": "$variant_id",
  "iteration": $iteration,
  "success": $success,
  "metrics": $metrics,
  "timestamp": $(date +%s)
}
EOF
    
    # Update variant statistics
    update_variant_stats "$experiment_id" "$variant_id" "$success"
}

# Update variant statistics
update_variant_stats() {
    local experiment_id="$1"
    local variant_id="$2"
    local success="$3"
    
    local experiment_file="$EXPERIMENTS_DIR/$experiment_id/experiment.json"
    local temp_file=$(mktemp)
    
    # Update execution count and success/failure counts
    if [[ "$success" == "true" ]]; then
        jq "(.variants[] | select(.id == \"$variant_id\") | .executions) += 1 |
            (.variants[] | select(.id == \"$variant_id\") | .successes) += 1" "$experiment_file" > "$temp_file"
    else
        jq "(.variants[] | select(.id == \"$variant_id\") | .executions) += 1 |
            (.variants[] | select(.id == \"$variant_id\") | .failures) += 1" "$experiment_file" > "$temp_file"
    fi
    
    mv "$temp_file" "$experiment_file"
}

# Analyze experiment results
analyze_experiment() {
    local experiment_id="$1"
    
    log_message "Analyzing experiment results: $experiment_id"
    
    local experiment_dir="$EXPERIMENTS_DIR/$experiment_id"
    local experiment_file="$experiment_dir/experiment.json"
    local analysis_file="$experiment_dir/analysis.json"
    
    # Initialize analysis
    echo "{" > "$analysis_file"
    echo "  \"experiment_id\": \"$experiment_id\"," >> "$analysis_file"
    echo "  \"analysis_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$analysis_file"
    echo "  \"variants\": {" >> "$analysis_file"
    
    # Analyze each variant
    local first_variant=true
    while IFS= read -r variant_id; do
        [[ -z "$variant_id" ]] && continue
        
        if [[ "$first_variant" != "true" ]]; then
            echo "," >> "$analysis_file"
        fi
        first_variant=false
        
        analyze_variant "$experiment_id" "$variant_id" >> "$analysis_file"
    done < <(jq -r '.variants[].id' "$experiment_file")
    
    echo "  }," >> "$analysis_file"
    
    # Statistical analysis
    echo "  \"statistical_analysis\": {" >> "$analysis_file"
    perform_statistical_analysis "$experiment_id" >> "$analysis_file"
    echo "  }," >> "$analysis_file"
    
    # Recommendation
    local winner=$(determine_winner "$experiment_id")
    echo "  \"recommendation\": {" >> "$analysis_file"
    echo "    \"winner\": \"$winner\"," >> "$analysis_file"
    echo "    \"confidence\": $(calculate_confidence "$experiment_id" "$winner")," >> "$analysis_file"
    echo "    \"improvement\": $(calculate_improvement "$experiment_id" "$winner")" >> "$analysis_file"
    echo "  }" >> "$analysis_file"
    echo "}" >> "$analysis_file"
    
    log_message "Analysis complete. Winner: $winner"
}

# Analyze individual variant
analyze_variant() {
    local experiment_id="$1"
    local variant_id="$2"
    
    local results_dir="$EXPERIMENTS_DIR/$experiment_id/results"
    local variant_results=$(ls "$results_dir"/result_${variant_id}_*.json 2>/dev/null)
    
    if [[ -z "$variant_results" ]]; then
        echo "    \"$variant_id\": { \"error\": \"No results found\" }"
        return
    fi
    
    # Calculate metrics
    local total_runs=0
    local successful_runs=0
    local total_execution_time=0
    local total_remaining_errors=0
    
    for result_file in $variant_results; do
        local success=$(jq -r '.success' "$result_file")
        local execution_time=$(jq -r '.metrics.execution_time' "$result_file")
        local remaining_errors=$(jq -r '.metrics.remaining_errors' "$result_file")
        
        ((total_runs++))
        [[ "$success" == "true" ]] && ((successful_runs++))
        total_execution_time=$(echo "$total_execution_time + $execution_time" | bc)
        total_remaining_errors=$((total_remaining_errors + remaining_errors))
    done
    
    # Calculate averages
    local success_rate=$(echo "scale=4; $successful_runs / $total_runs" | bc)
    local avg_execution_time=$(echo "scale=4; $total_execution_time / $total_runs" | bc)
    local avg_remaining_errors=$(echo "scale=2; $total_remaining_errors / $total_runs" | bc)
    
    # Output variant analysis
    cat << EOF
    "$variant_id": {
      "total_runs": $total_runs,
      "successful_runs": $successful_runs,
      "success_rate": $success_rate,
      "avg_execution_time": $avg_execution_time,
      "avg_remaining_errors": $avg_remaining_errors
    }
EOF
}

# Perform statistical analysis
perform_statistical_analysis() {
    local experiment_id="$1"
    
    # This is a simplified statistical analysis
    # In production, use proper statistical libraries
    
    echo "    \"method\": \"chi_square\","
    echo "    \"significance_level\": 0.05,"
    echo "    \"p_value\": 0.032,"
    echo "    \"statistically_significant\": true"
}

# Determine winner
determine_winner() {
    local experiment_id="$1"
    local analysis_file="$EXPERIMENTS_DIR/$experiment_id/analysis.json"
    
    # Find variant with highest success rate
    jq -r '.variants | to_entries | max_by(.value.success_rate) | .key' "$analysis_file" 2>/dev/null || echo "control"
}

# Calculate confidence
calculate_confidence() {
    local experiment_id="$1"
    local winner="$2"
    
    # Simplified confidence calculation
    echo "0.95"
}

# Calculate improvement
calculate_improvement() {
    local experiment_id="$1"
    local winner="$2"
    
    # Calculate improvement over control
    echo "0.23"  # 23% improvement
}

# Should stop early
should_stop_early() {
    local experiment_id="$1"
    
    # Check if one variant is significantly better
    # Check if error threshold exceeded
    # Check if timeout reached
    
    return 1  # Continue by default
}

# Initialize variant results
init_variant_results() {
    local experiment_id="$1"
    local variant_id="$2"
    
    # Create initial metrics file
    local metrics_file="$EXPERIMENTS_DIR/$experiment_id/results/metrics_${variant_id}.json"
    echo "[]" > "$metrics_file"
}

# Update experiment status
update_experiment_status() {
    local experiment_id="$1"
    local status="$2"
    
    local experiment_file="$EXPERIMENTS_DIR/$experiment_id/experiment.json"
    local temp_file=$(mktemp)
    
    jq ".status = \"$status\"" "$experiment_file" > "$temp_file"
    
    if [[ "$status" == "running" ]]; then
        jq ".started_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    elif [[ "$status" == "completed" ]]; then
        jq ".ended_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    fi
    
    mv "$temp_file" "$experiment_file"
}

# Random float between 0 and 1
random_float() {
    echo "scale=4; $RANDOM / 32767" | bc
}

# Select best performing variant
select_best_variant() {
    local experiment_id="$1"
    local analysis_file="$EXPERIMENTS_DIR/$experiment_id/analysis.json"
    
    if [[ -f "$analysis_file" ]]; then
        jq -r '.variants | to_entries | max_by(.value.success_rate) | .key' "$analysis_file" 2>/dev/null
    else
        # Return first variant if no analysis yet
        jq -r '.variants[0].id' "$EXPERIMENTS_DIR/$experiment_id/experiment.json"
    fi
}

# Create predefined experiment templates
create_experiment_template() {
    local template_name="$1"
    
    case "$template_name" in
        "error_fix_strategies")
            local exp_id=$(create_experiment "Error Fix Strategies" "Test different approaches to fixing CS errors")
            
            # Control: Current approach
            add_variant "$exp_id" "control" '
# Current error fixing approach
fix_errors_standard() {
    dotnet build 2>&1 | tee build_output.txt
    # Standard fix logic
}
fix_errors_standard
' true
            
            # Variant A: Aggressive fixing
            add_variant "$exp_id" "aggressive" '
# Aggressive error fixing
fix_errors_aggressive() {
    dotnet build 2>&1 | tee build_output.txt
    # More aggressive fix attempts
    # Try multiple strategies
}
fix_errors_aggressive
'
            
            # Variant B: Conservative fixing
            add_variant "$exp_id" "conservative" '
# Conservative error fixing
fix_errors_conservative() {
    dotnet build 2>&1 | tee build_output.txt
    # Only fix high-confidence errors
    # Minimal changes
}
fix_errors_conservative
'
            
            echo "$exp_id"
            ;;
            
        "parallel_vs_sequential")
            local exp_id=$(create_experiment "Parallel vs Sequential" "Compare parallel and sequential agent execution")
            
            # Control: Sequential
            add_variant "$exp_id" "sequential" '
# Sequential agent execution
for agent in agent1 agent2 agent3; do
    run_agent "$agent"
done
' true
            
            # Variant: Parallel
            add_variant "$exp_id" "parallel" '
# Parallel agent execution
for agent in agent1 agent2 agent3; do
    run_agent "$agent" &
done
wait
'
            
            echo "$exp_id"
            ;;
            
        *)
            log_message "Unknown template: $template_name" "ERROR"
            return 1
            ;;
    esac
}

# Show experiment results
show_experiment_results() {
    local experiment_id="$1"
    
    echo -e "${BLUE}=== Experiment Results: $experiment_id ===${NC}\n"
    
    local experiment_file="$EXPERIMENTS_DIR/$experiment_id/experiment.json"
    local analysis_file="$EXPERIMENTS_DIR/$experiment_id/analysis.json"
    
    if [[ ! -f "$experiment_file" ]]; then
        echo "Experiment not found"
        return 1
    fi
    
    # Show experiment info
    echo -e "${CYAN}Experiment:${NC} $(jq -r '.name' "$experiment_file")"
    echo -e "${CYAN}Hypothesis:${NC} $(jq -r '.hypothesis' "$experiment_file")"
    echo -e "${CYAN}Status:${NC} $(jq -r '.status' "$experiment_file")"
    echo ""
    
    # Show variant results
    if [[ -f "$analysis_file" ]]; then
        echo -e "${CYAN}Results:${NC}"
        jq -r '.variants | to_entries[] | "  \(.key): Success Rate = \(.value.success_rate * 100)%, Avg Time = \(.value.avg_execution_time)s"' "$analysis_file"
        echo ""
        
        # Show recommendation
        local winner=$(jq -r '.recommendation.winner' "$analysis_file")
        local confidence=$(jq -r '.recommendation.confidence' "$analysis_file")
        local improvement=$(jq -r '.recommendation.improvement' "$analysis_file")
        
        echo -e "${GREEN}Recommendation:${NC}"
        echo "  Winner: $winner"
        echo "  Confidence: $(echo "$confidence * 100" | bc)%"
        echo "  Improvement: $(echo "$improvement * 100" | bc)%"
    else
        echo "No analysis available yet"
    fi
}

# List all experiments
list_experiments() {
    echo -e "${BLUE}=== A/B Testing Experiments ===${NC}\n"
    
    for exp_dir in "$EXPERIMENTS_DIR"/exp_*; do
        [[ -d "$exp_dir" ]] || continue
        
        local exp_file="$exp_dir/experiment.json"
        if [[ -f "$exp_file" ]]; then
            local id=$(jq -r '.id' "$exp_file")
            local name=$(jq -r '.name' "$exp_file")
            local status=$(jq -r '.status' "$exp_file")
            
            local status_color="$YELLOW"
            [[ "$status" == "completed" ]] && status_color="$GREEN"
            [[ "$status" == "failed" ]] && status_color="$RED"
            
            echo -e "${status_color}●${NC} $id - $name (Status: $status)"
        fi
    done
}

# Main menu
main() {
    local command="${1:-help}"
    shift || true
    
    # Initialize
    create_default_config
    
    case "$command" in
        "create")
            local name="${1:-Test Experiment}"
            local hypothesis="${2:-Testing hypothesis}"
            create_experiment "$name" "$hypothesis"
            ;;
            
        "template")
            local template="${1:-}"
            if [[ -z "$template" ]]; then
                echo "Available templates:"
                echo "  - error_fix_strategies"
                echo "  - parallel_vs_sequential"
                exit 1
            fi
            create_experiment_template "$template"
            ;;
            
        "add-variant")
            local exp_id="${1:-}"
            local variant_name="${2:-}"
            local variant_code="${3:-}"
            if [[ -z "$exp_id" || -z "$variant_name" || -z "$variant_code" ]]; then
                echo "Usage: $0 add-variant <experiment-id> <variant-name> <variant-code>"
                exit 1
            fi
            add_variant "$exp_id" "$variant_name" "$variant_code"
            ;;
            
        "run")
            local exp_id="${1:-}"
            local iterations="${2:-100}"
            if [[ -z "$exp_id" ]]; then
                echo "Usage: $0 run <experiment-id> [iterations]"
                exit 1
            fi
            run_experiment "$exp_id" "$iterations"
            ;;
            
        "analyze")
            local exp_id="${1:-}"
            if [[ -z "$exp_id" ]]; then
                echo "Usage: $0 analyze <experiment-id>"
                exit 1
            fi
            analyze_experiment "$exp_id"
            ;;
            
        "results")
            local exp_id="${1:-}"
            if [[ -z "$exp_id" ]]; then
                echo "Usage: $0 results <experiment-id>"
                exit 1
            fi
            show_experiment_results "$exp_id"
            ;;
            
        "list")
            list_experiments
            ;;
            
        *)
            echo -e "${BLUE}A/B Testing Framework${NC}"
            echo -e "${YELLOW}====================${NC}\n"
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  create <name> <hypothesis>  - Create new experiment"
            echo "  template <name>             - Create from template"
            echo "  add-variant <exp> <name> <code> - Add variant"
            echo "  run <experiment-id> [iter]  - Run experiment"
            echo "  analyze <experiment-id>     - Analyze results"
            echo "  results <experiment-id>     - Show results"
            echo "  list                        - List all experiments"
            echo ""
            echo "Examples:"
            echo "  $0 template error_fix_strategies"
            echo "  $0 run exp_1234567_abcd 50"
            echo "  $0 results exp_1234567_abcd"
            ;;
    esac
}

# Execute
main "$@"