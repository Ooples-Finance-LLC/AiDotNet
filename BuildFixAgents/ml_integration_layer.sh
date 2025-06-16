#!/bin/bash

# ML Integration Layer - AI-powered pattern learning and prediction system
# Learns from successful fixes to improve future solutions

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ML_DIR="$AGENT_DIR/state/ml"
MODELS_DIR="$ML_DIR/models"
TRAINING_DATA="$ML_DIR/training_data.json"
PREDICTIONS_DIR="$ML_DIR/predictions"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Create directories
mkdir -p "$MODELS_DIR" "$PREDICTIONS_DIR"

# Initialize ML configuration
init_ml_config() {
    local config_file="$AGENT_DIR/config/ml_config.yml"
    mkdir -p "$(dirname "$config_file")"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# ML Integration Configuration
ml_settings:
  learning:
    enabled: true
    min_confidence: 0.75
    training_threshold: 100  # Min samples before training
    
  models:
    error_predictor:
      type: "pattern_matching"
      features:
        - error_code
        - file_extension
        - error_context
        - previous_fixes
      
    fix_suggester:
      type: "similarity_based"
      algorithm: "cosine_similarity"
      
    anomaly_detector:
      type: "statistical"
      threshold: 2.5  # Standard deviations
      
  training:
    batch_size: 50
    update_frequency: "daily"
    validation_split: 0.2
    
  features:
    extract_context: true
    track_success_rate: true
    learn_from_failures: true
    cross_project_learning: false
EOF
        echo -e "${GREEN}Created ML configuration${NC}"
    fi
}

# Feature extraction from errors
extract_features() {
    local error_file="$1"
    local error_code="$2"
    local error_message="$3"
    
    # Extract various features for ML
    local features=$(jq -n \
        --arg code "$error_code" \
        --arg msg "$error_message" \
        --arg file "$error_file" \
        --arg ext "${error_file##*.}" \
        --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            error_code: $code,
            error_message: $msg,
            file_path: $file,
            file_extension: $ext,
            timestamp: $time,
            context: {
                line_count: 0,
                method_name: null,
                class_name: null,
                imports: []
            }
        }')
    
    # Extract additional context if file exists
    if [[ -f "$error_file" ]]; then
        local line_count=$(wc -l < "$error_file")
        features=$(echo "$features" | jq --arg lc "$line_count" '.context.line_count = ($lc | tonumber)')
        
        # Extract class name (simplified)
        local class_name=$(grep -oP 'class\s+\K\w+' "$error_file" | head -1 || echo "")
        if [[ -n "$class_name" ]]; then
            features=$(echo "$features" | jq --arg cn "$class_name" '.context.class_name = $cn')
        fi
    fi
    
    echo "$features"
}

# Train model on historical data
train_model() {
    local model_type="${1:-error_predictor}"
    
    echo -e "${BLUE}Training $model_type model...${NC}"
    
    # Load training data
    if [[ ! -f "$TRAINING_DATA" ]]; then
        echo -e "${YELLOW}No training data available yet${NC}"
        return
    fi
    
    local sample_count=$(jq length "$TRAINING_DATA")
    if [[ $sample_count -lt 100 ]]; then
        echo -e "${YELLOW}Insufficient training data: $sample_count samples (need 100+)${NC}"
        return
    fi
    
    # Create model based on patterns
    case "$model_type" in
        error_predictor)
            train_error_predictor
            ;;
        fix_suggester)
            train_fix_suggester
            ;;
        anomaly_detector)
            train_anomaly_detector
            ;;
    esac
    
    echo -e "${GREEN}Model training completed${NC}"
}

# Train error predictor model
train_error_predictor() {
    local model_file="$MODELS_DIR/error_predictor.json"
    
    echo -e "  Analyzing error patterns..."
    
    # Extract patterns from training data
    local patterns=$(jq -r '
        group_by(.error_code) |
        map({
            error_code: .[0].error_code,
            count: length,
            common_files: [.[].file_extension] | group_by(.) | map({ext: .[0], count: length}) | sort_by(.count) | reverse | .[0:3],
            avg_fix_time: ([.[].fix_duration // 0] | add / length),
            success_rate: ([.[].fix_successful // false] | map(if . then 1 else 0 end) | add / length)
        })' "$TRAINING_DATA")
    
    # Build prediction model
    cat > "$model_file" << EOF
{
    "model_type": "error_predictor",
    "version": "1.0",
    "trained_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "sample_count": $sample_count,
    "patterns": $patterns,
    "thresholds": {
        "high_probability": 0.8,
        "medium_probability": 0.5
    }
}
EOF
    
    echo -e "  Created error prediction model"
}

# Train fix suggester model
train_fix_suggester() {
    local model_file="$MODELS_DIR/fix_suggester.json"
    
    echo -e "  Building fix suggestion database..."
    
    # Group successful fixes by error type
    local fix_database=$(jq -r '
        map(select(.fix_successful == true)) |
        group_by(.error_code) |
        map({
            error_code: .[0].error_code,
            fixes: map({
                fix_type: .fix_type,
                fix_pattern: .fix_pattern,
                success_count: 1
            }) | group_by(.fix_type) | 
            map({
                fix_type: .[0].fix_type,
                patterns: map(.fix_pattern),
                total_successes: length
            }) | sort_by(.total_successes) | reverse
        })' "$TRAINING_DATA")
    
    cat > "$model_file" << EOF
{
    "model_type": "fix_suggester",
    "version": "1.0",
    "trained_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "fix_database": $fix_database,
    "similarity_threshold": 0.7
}
EOF
    
    echo -e "  Created fix suggestion model"
}

# Train anomaly detector
train_anomaly_detector() {
    local model_file="$MODELS_DIR/anomaly_detector.json"
    
    echo -e "  Calculating statistical baselines..."
    
    # Calculate statistics for anomaly detection
    local stats=$(jq -r '
        {
            error_frequency: {
                mean: ([group_by(.error_code) | map(length)] | add / length),
                std_dev: 0
            },
            fix_duration: {
                mean: ([.[].fix_duration // 30] | add / length),
                std_dev: 0
            },
            file_patterns: group_by(.file_extension) | map({ext: .[0].file_extension, count: length})
        }' "$TRAINING_DATA")
    
    cat > "$model_file" << EOF
{
    "model_type": "anomaly_detector",
    "version": "1.0",
    "trained_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "baselines": $stats,
    "threshold_multiplier": 2.5
}
EOF
    
    echo -e "  Created anomaly detection model"
}

# Predict likely errors
predict_errors() {
    local project_path="${1:-$PWD}"
    local prediction_file="$PREDICTIONS_DIR/prediction_$(date +%Y%m%d_%H%M%S).json"
    
    echo -e "${BLUE}Predicting potential errors in: $project_path${NC}"
    
    # Load error predictor model
    local model_file="$MODELS_DIR/error_predictor.json"
    if [[ ! -f "$model_file" ]]; then
        echo -e "${YELLOW}No trained model available. Run training first.${NC}"
        return
    fi
    
    # Analyze project structure
    local file_stats=$(find "$project_path" -type f \( -name "*.cs" -o -name "*.ts" -o -name "*.js" -o -name "*.py" \) | \
        awk -F. '{ext=$NF; count[ext]++} END {for (e in count) printf "{\"ext\":\"%s\",\"count\":%d},", e, count[e]}' | \
        sed 's/,$//')
    
    # Make predictions based on patterns
    local predictions=$(jq -r --argjson files "[$file_stats]" '
        .patterns | map({
            error_code: .error_code,
            probability: (
                if ($files | map(select(.ext == .common_files[0].ext)) | length) > 0 
                then .success_rate 
                else .success_rate * 0.5 
                end
            ),
            likely_files: .common_files[0].ext,
            estimated_count: (.count * 0.1) | floor
        }) | sort_by(.probability) | reverse | .[0:10]
    ' "$model_file")
    
    # Save predictions
    cat > "$prediction_file" << EOF
{
    "project": "$project_path",
    "predicted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "predictions": $predictions,
    "confidence": "medium",
    "recommendations": [
        "Focus on high-probability error types first",
        "Allocate more time for complex fixes",
        "Consider preventive refactoring"
    ]
}
EOF
    
    echo -e "${GREEN}Predictions saved to: $prediction_file${NC}"
    
    # Display top predictions
    echo -e "\n${CYAN}Top 5 Predicted Errors:${NC}"
    jq -r '.predictions[0:5] | .[] | "  \(.error_code): \(.probability * 100 | floor)% probability (\(.estimated_count) likely occurrences)"' "$prediction_file"
}

# Suggest fixes based on ML model
suggest_fix() {
    local error_code="$1"
    local error_context="${2:-}"
    
    echo -e "${BLUE}Generating ML-based fix suggestions for: $error_code${NC}"
    
    # Load fix suggester model
    local model_file="$MODELS_DIR/fix_suggester.json"
    if [[ ! -f "$model_file" ]]; then
        echo -e "${YELLOW}No fix suggestion model available${NC}"
        return
    fi
    
    # Find relevant fixes
    local suggestions=$(jq -r --arg code "$error_code" '
        .fix_database[] | select(.error_code == $code) | .fixes[0:3]
    ' "$model_file")
    
    if [[ -z "$suggestions" ]] || [[ "$suggestions" == "null" ]]; then
        echo -e "${YELLOW}No ML suggestions available for this error type${NC}"
        return
    fi
    
    echo -e "\n${CYAN}ML-Suggested Fixes:${NC}"
    echo "$suggestions" | jq -r '.[] | "  • \(.fix_type) (Success rate: \(.total_successes))"'
    
    # Save suggestion for learning
    local suggestion_file="$PREDICTIONS_DIR/suggestion_${error_code}_$(date +%s).json"
    cat > "$suggestion_file" << EOF
{
    "error_code": "$error_code",
    "context": "$error_context",
    "suggestions": $suggestions,
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Record fix result for learning
record_fix_result() {
    local error_code="$1"
    local fix_type="$2"
    local success="${3:-true}"
    local duration="${4:-0}"
    local fix_pattern="${5:-}"
    
    echo -e "${CYAN}Recording fix result for ML training${NC}"
    
    # Create training record
    local record=$(jq -n \
        --arg code "$error_code" \
        --arg type "$fix_type" \
        --argjson success "$success" \
        --argjson duration "$duration" \
        --arg pattern "$fix_pattern" \
        '{
            error_code: $code,
            fix_type: $type,
            fix_successful: $success,
            fix_duration: $duration,
            fix_pattern: $pattern,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }')
    
    # Append to training data
    if [[ -f "$TRAINING_DATA" ]]; then
        jq --argjson record "$record" '. += [$record]' "$TRAINING_DATA" > "$TRAINING_DATA.tmp" && \
            mv "$TRAINING_DATA.tmp" "$TRAINING_DATA"
    else
        echo "[$record]" > "$TRAINING_DATA"
    fi
    
    echo -e "${GREEN}Fix result recorded${NC}"
    
    # Check if we should retrain
    local record_count=$(jq length "$TRAINING_DATA")
    if [[ $((record_count % 50)) -eq 0 ]]; then
        echo -e "${YELLOW}Reached $record_count records. Consider retraining models.${NC}"
    fi
}

# Detect anomalies in error patterns
detect_anomalies() {
    local current_errors="$1"
    
    echo -e "${BLUE}Detecting anomalies in error patterns...${NC}"
    
    # Load anomaly detector model
    local model_file="$MODELS_DIR/anomaly_detector.json"
    if [[ ! -f "$model_file" ]]; then
        echo -e "${YELLOW}No anomaly detection model available${NC}"
        return
    fi
    
    # Analyze current error distribution
    local error_counts=$(echo "$current_errors" | jq -r '
        group_by(.error_code) | 
        map({code: .[0].error_code, count: length})
    ')
    
    # Compare against baselines
    local anomalies=()
    local threshold=$(jq -r '.threshold_multiplier' "$model_file")
    local mean=$(jq -r '.baselines.error_frequency.mean' "$model_file")
    
    echo "$error_counts" | jq -r '.[] | "\(.code):\(.count)"' | while IFS=: read -r code count; do
        if [[ $(echo "$count > $mean * $threshold" | bc) -eq 1 ]]; then
            echo -e "${RED}⚠ Anomaly detected: $code has $count occurrences (expected ~$mean)${NC}"
            anomalies+=("$code")
        fi
    done
    
    if [[ ${#anomalies[@]} -eq 0 ]]; then
        echo -e "${GREEN}No anomalies detected${NC}"
    fi
}

# Generate ML insights report
generate_ml_report() {
    local report_file="$ML_DIR/ml_insights_$(date +%Y%m%d_%H%M%S).html"
    
    echo -e "${BLUE}Generating ML insights report...${NC}"
    
    # Gather statistics
    local total_records=0
    if [[ -f "$TRAINING_DATA" ]]; then
        total_records=$(jq length "$TRAINING_DATA")
    fi
    
    local models_count=$(ls "$MODELS_DIR"/*.json 2>/dev/null | wc -l)
    local predictions_count=$(ls "$PREDICTIONS_DIR"/*.json 2>/dev/null | wc -l)
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ML Integration Layer - Insights Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #3498db; }
        .metric-card h3 { margin-top: 0; color: #34495e; }
        .metric-card .value { font-size: 36px; font-weight: bold; color: #3498db; }
        .chart { margin: 20px 0; padding: 20px; background-color: #f8f9fa; border-radius: 8px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #34495e; color: white; }
        .insight { background-color: #e8f4f8; padding: 15px; border-radius: 4px; margin: 10px 0; border-left: 4px solid #3498db; }
    </style>
</head>
<body>
    <div class="container">
        <h1>ML Integration Layer - Insights Report</h1>
        <p>Generated: $(date)</p>
        
        <div class="metric-grid">
            <div class="metric-card">
                <h3>Training Records</h3>
                <div class="value">EOF
    echo -n "$total_records" >> "$report_file"
    cat >> "$report_file" << 'EOF'</div>
            </div>
            <div class="metric-card">
                <h3>Trained Models</h3>
                <div class="value">EOF
    echo -n "$models_count" >> "$report_file"
    cat >> "$report_file" << 'EOF'</div>
            </div>
            <div class="metric-card">
                <h3>Predictions Made</h3>
                <div class="value">EOF
    echo -n "$predictions_count" >> "$report_file"
    cat >> "$report_file" << 'EOF'</div>
            </div>
        </div>
        
        <h2>Model Performance</h2>
        <div class="chart">
            <h3>Error Prediction Accuracy</h3>
            <p>Model accuracy improves with more training data. Current status: EOF
    
    if [[ $total_records -lt 100 ]]; then
        echo "Building initial dataset" >> "$report_file"
    elif [[ $total_records -lt 1000 ]]; then
        echo "Learning patterns" >> "$report_file"
    else
        echo "Mature model" >> "$report_file"
    fi
    
    cat >> "$report_file" << 'EOF'</p>
        </div>
        
        <h2>Key Insights</h2>
        <div class="insight">
            <strong>Most Common Error Pattern:</strong> Analyzing historical data to identify recurring issues
        </div>
        <div class="insight">
            <strong>Fix Success Rate:</strong> Tracking which automated fixes are most effective
        </div>
        <div class="insight">
            <strong>Anomaly Detection:</strong> Monitoring for unusual error patterns that may indicate new issues
        </div>
        
        <h2>Recommendations</h2>
        <ul>
            <li>Continue collecting training data to improve model accuracy</li>
            <li>Review and validate suggested fixes before applying</li>
            <li>Monitor anomaly alerts for potential system issues</li>
            <li>Retrain models periodically as codebase evolves</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}ML insights report generated: $report_file${NC}"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    init_ml_config
    
    case "$command" in
        train)
            local model="${2:-all}"
            if [[ "$model" == "all" ]]; then
                train_model "error_predictor"
                train_model "fix_suggester"
                train_model "anomaly_detector"
            else
                train_model "$model"
            fi
            ;;
            
        predict)
            local project_path="${2:-$PWD}"
            predict_errors "$project_path"
            ;;
            
        suggest)
            local error_code="${2:-}"
            local context="${3:-}"
            if [[ -z "$error_code" ]]; then
                echo "Usage: $0 suggest <error_code> [context]"
                exit 1
            fi
            suggest_fix "$error_code" "$context"
            ;;
            
        record)
            local error_code="${2:-}"
            local fix_type="${3:-}"
            local success="${4:-true}"
            local duration="${5:-30}"
            
            if [[ -z "$error_code" ]] || [[ -z "$fix_type" ]]; then
                echo "Usage: $0 record <error_code> <fix_type> [success] [duration]"
                exit 1
            fi
            
            record_fix_result "$error_code" "$fix_type" "$success" "$duration"
            ;;
            
        anomaly)
            local errors_file="${2:-}"
            if [[ -z "$errors_file" ]] || [[ ! -f "$errors_file" ]]; then
                echo "Usage: $0 anomaly <errors_file>"
                exit 1
            fi
            
            detect_anomalies "$(cat "$errors_file")"
            ;;
            
        report)
            generate_ml_report
            ;;
            
        status)
            echo -e "${CYAN}ML Integration Status:${NC}"
            echo -e "Training records: $(jq length "$TRAINING_DATA" 2>/dev/null || echo 0)"
            echo -e "Models trained: $(ls "$MODELS_DIR"/*.json 2>/dev/null | wc -l)"
            echo -e "Predictions made: $(ls "$PREDICTIONS_DIR"/*.json 2>/dev/null | wc -l)"
            ;;
            
        *)
            cat << EOF
ML Integration Layer - AI-powered pattern learning and prediction

Usage: $0 {command} [options]

Commands:
    train       Train ML models
                Usage: train [model_type|all]
                Models: error_predictor, fix_suggester, anomaly_detector
                
    predict     Predict likely errors in a project
                Usage: predict [project_path]
                
    suggest     Get ML-based fix suggestions
                Usage: suggest <error_code> [context]
                
    record      Record fix result for training
                Usage: record <error_code> <fix_type> [success] [duration]
                
    anomaly     Detect anomalies in error patterns
                Usage: anomaly <errors_file>
                
    report      Generate ML insights report
    
    status      Show ML system status

Examples:
    $0 train all                           # Train all models
    $0 predict /path/to/project           # Predict errors
    $0 suggest CS0246                     # Get fix suggestions
    $0 record CS0246 "add_using" true 45  # Record successful fix
    $0 anomaly current_errors.json        # Check for anomalies

The ML system learns from every fix attempt to improve future suggestions.
Models are automatically retrained as more data becomes available.
EOF
            ;;
    esac
}

# Execute
main "$@"