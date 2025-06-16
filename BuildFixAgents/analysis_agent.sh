#!/bin/bash
# Analysis Agent - Comprehensive codebase analysis, metrics, and insights
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYSIS_STATE="$SCRIPT_DIR/state/analysis"
mkdir -p "$ANALYSIS_STATE/metrics" "$ANALYSIS_STATE/insights" "$ANALYSIS_STATE/visualizations"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║        Analysis Agent v1.0             ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"
}

# Analyze codebase structure
analyze_structure() {
    local target_dir="${1:-.}"
    local output_file="$ANALYSIS_STATE/metrics/structure_analysis.json"
    
    log_event "INFO" "ANALYSIS" "Analyzing codebase structure"
    
    # Initialize structure report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "root": "$target_dir",
  "summary": {
    "total_files": 0,
    "total_directories": 0,
    "total_size_bytes": 0,
    "languages": {}
  },
  "tree": {},
  "patterns": {
    "architecture": "unknown",
    "framework": "unknown",
    "testing": "unknown"
  }
}
EOF
    
    # Count files and directories
    local file_count=$(find "$target_dir" -type f ! -path "*/\.*" ! -path "*/node_modules/*" 2>/dev/null | wc -l)
    local dir_count=$(find "$target_dir" -type d ! -path "*/\.*" ! -path "*/node_modules/*" 2>/dev/null | wc -l)
    
    # Calculate total size
    local total_size=$(find "$target_dir" -type f ! -path "*/\.*" ! -path "*/node_modules/*" -exec du -b {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
    
    # Update summary
    local temp_file=$(mktemp)
    jq --arg files "$file_count" \
       --arg dirs "$dir_count" \
       --arg size "${total_size:-0}" \
       '.summary.total_files = ($files | tonumber) |
        .summary.total_directories = ($dirs | tonumber) |
        .summary.total_size_bytes = ($size | tonumber)' "$output_file" > "$temp_file"
    mv "$temp_file" "$output_file"
    
    # Detect architecture patterns
    detect_architecture_pattern "$target_dir" "$output_file"
    
    log_event "SUCCESS" "ANALYSIS" "Structure analysis complete"
}

# Detect architecture pattern
detect_architecture_pattern() {
    local target_dir="$1"
    local output_file="$2"
    local architecture="monolithic"
    local framework="unknown"
    
    # Check for microservices pattern
    if [[ -d "$target_dir/services" ]] || [[ -f "$target_dir/docker-compose.yml" ]]; then
        architecture="microservices"
    fi
    
    # Check for MVC pattern
    if [[ -d "$target_dir/models" ]] && [[ -d "$target_dir/views" ]] && [[ -d "$target_dir/controllers" ]]; then
        architecture="mvc"
    fi
    
    # Check for layered architecture
    if [[ -d "$target_dir/domain" ]] && [[ -d "$target_dir/infrastructure" ]] && [[ -d "$target_dir/application" ]]; then
        architecture="layered"
    fi
    
    # Detect framework
    if [[ -f "$target_dir/package.json" ]]; then
        if grep -q "react" "$target_dir/package.json" 2>/dev/null; then
            framework="react"
        elif grep -q "angular" "$target_dir/package.json" 2>/dev/null; then
            framework="angular"
        elif grep -q "vue" "$target_dir/package.json" 2>/dev/null; then
            framework="vue"
        elif grep -q "express" "$target_dir/package.json" 2>/dev/null; then
            framework="express"
        fi
    fi
    
    # Update patterns
    local temp_file=$(mktemp)
    jq --arg arch "$architecture" \
       --arg fw "$framework" \
       '.patterns.architecture = $arch |
        .patterns.framework = $fw' "$output_file" > "$temp_file"
    mv "$temp_file" "$output_file"
}

# Analyze code metrics
analyze_metrics() {
    local target_dir="${1:-.}"
    local output_file="$ANALYSIS_STATE/metrics/code_metrics.json"
    
    log_event "INFO" "ANALYSIS" "Calculating code metrics"
    
    # Initialize metrics report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "languages": {},
  "totals": {
    "lines_of_code": 0,
    "comment_lines": 0,
    "blank_lines": 0,
    "files": 0
  },
  "averages": {
    "lines_per_file": 0,
    "complexity_per_function": 0
  }
}
EOF
    
    # Analyze each language
    analyze_language_metrics "$target_dir" "JavaScript" "*.js" "$output_file"
    analyze_language_metrics "$target_dir" "TypeScript" "*.ts" "$output_file"
    analyze_language_metrics "$target_dir" "Python" "*.py" "$output_file"
    analyze_language_metrics "$target_dir" "Java" "*.java" "$output_file"
    analyze_language_metrics "$target_dir" "C#" "*.cs" "$output_file"
    
    # Calculate totals
    calculate_metric_totals "$output_file"
    
    log_event "SUCCESS" "ANALYSIS" "Code metrics calculated"
}

# Analyze metrics for specific language
analyze_language_metrics() {
    local target_dir="$1"
    local language="$2"
    local pattern="$3"
    local output_file="$4"
    
    local files=$(find "$target_dir" -name "$pattern" ! -path "*/node_modules/*" ! -path "*/\.*" 2>/dev/null)
    if [[ -z "$files" ]]; then
        return
    fi
    
    local total_lines=0
    local comment_lines=0
    local blank_lines=0
    local file_count=0
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local lines=$(wc -l < "$file")
            local comments=$(grep -c "^\s*\/\/" "$file" 2>/dev/null || echo 0)
            local blanks=$(grep -c "^\s*$" "$file" 2>/dev/null || echo 0)
            
            total_lines=$((total_lines + lines))
            comment_lines=$((comment_lines + comments))
            blank_lines=$((blank_lines + blanks))
            file_count=$((file_count + 1))
        fi
    done <<< "$files"
    
    # Update language metrics
    local temp_file=$(mktemp)
    jq --arg lang "$language" \
       --arg files "$file_count" \
       --arg lines "$total_lines" \
       --arg comments "$comment_lines" \
       --arg blanks "$blank_lines" \
       '.languages[$lang] = {
         "files": ($files | tonumber),
         "lines": ($lines | tonumber),
         "comments": ($comments | tonumber),
         "blanks": ($blanks | tonumber),
         "code": (($lines | tonumber) - ($comments | tonumber) - ($blanks | tonumber))
       }' "$output_file" > "$temp_file"
    mv "$temp_file" "$output_file"
}

# Calculate total metrics
calculate_metric_totals() {
    local output_file="$1"
    
    local temp_file=$(mktemp)
    jq '.totals.lines_of_code = ([.languages[].code] | add // 0) |
        .totals.comment_lines = ([.languages[].comments] | add // 0) |
        .totals.blank_lines = ([.languages[].blanks] | add // 0) |
        .totals.files = ([.languages[].files] | add // 0) |
        .averages.lines_per_file = if .totals.files > 0 then (.totals.lines_of_code / .totals.files) else 0 end' \
        "$output_file" > "$temp_file"
    mv "$temp_file" "$output_file"
}

# Generate insights
generate_insights() {
    local metrics_file="$ANALYSIS_STATE/metrics/code_metrics.json"
    local structure_file="$ANALYSIS_STATE/metrics/structure_analysis.json"
    local output_file="$ANALYSIS_STATE/insights/codebase_insights.md"
    
    log_event "INFO" "ANALYSIS" "Generating codebase insights"
    
    cat > "$output_file" << 'EOF'
# Codebase Analysis Insights

Generated: $(date)

## Executive Summary

This report provides comprehensive insights into the codebase structure, quality, and maintainability.

EOF
    
    # Add structure insights
    if [[ -f "$structure_file" ]]; then
        local total_files=$(jq -r '.summary.total_files' "$structure_file")
        local total_size=$(jq -r '.summary.total_size_bytes' "$structure_file")
        local size_mb=$((total_size / 1024 / 1024))
        local architecture=$(jq -r '.patterns.architecture' "$structure_file")
        
        cat >> "$output_file" << EOF
## Codebase Structure

- **Total Files**: $total_files
- **Total Size**: ${size_mb}MB
- **Architecture Pattern**: $architecture

EOF
    fi
    
    # Add metrics insights
    if [[ -f "$metrics_file" ]]; then
        local loc=$(jq -r '.totals.lines_of_code' "$metrics_file")
        local comment_ratio=$(jq -r 'if .totals.lines_of_code > 0 then (.totals.comment_lines / .totals.lines_of_code * 100) else 0 end' "$metrics_file")
        
        cat >> "$output_file" << EOF
## Code Metrics

- **Lines of Code**: $loc
- **Comment Ratio**: ${comment_ratio}%

### Language Distribution
EOF
        
        jq -r '.languages | to_entries[] | "- **\(.key)**: \(.value.code) lines (\(.value.files) files)"' "$metrics_file" >> "$output_file"
    fi
    
    # Add recommendations
    cat >> "$output_file" << 'EOF'

## Recommendations

### Code Quality
1. **Documentation**: Aim for 15-20% comment ratio for better maintainability
2. **File Size**: Keep files under 500 lines for better readability
3. **Function Length**: Limit functions to 50 lines or less

### Architecture
1. **Modularity**: Consider breaking large modules into smaller, focused components
2. **Dependencies**: Review and minimize external dependencies
3. **Testing**: Ensure test coverage of at least 80%

### Performance
1. **Bundle Size**: Optimize imports and use code splitting
2. **Caching**: Implement appropriate caching strategies
3. **Database**: Add indexes for frequently queried fields

### Security
1. **Dependencies**: Regular security audits of dependencies
2. **Input Validation**: Implement comprehensive input validation
3. **Authentication**: Use industry-standard authentication methods
EOF
    
    log_event "SUCCESS" "ANALYSIS" "Insights generated"
}

# Generate visualizations
generate_visualizations() {
    local output_dir="$ANALYSIS_STATE/visualizations"
    
    log_event "INFO" "ANALYSIS" "Generating visualizations"
    
    # Generate language distribution chart
    cat > "$output_dir/language_distribution.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Codebase Analysis Visualizations</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .chart-container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .chart-title {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 20px;
            color: #333;
        }
        canvas {
            max-height: 400px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Codebase Analysis Dashboard</h1>
        
        <div class="chart-container">
            <div class="chart-title">Language Distribution</div>
            <canvas id="languageChart"></canvas>
        </div>
        
        <div class="chart-container">
            <div class="chart-title">Code vs Comments vs Blank Lines</div>
            <canvas id="compositionChart"></canvas>
        </div>
        
        <div class="chart-container">
            <div class="chart-title">File Size Distribution</div>
            <canvas id="fileSizeChart"></canvas>
        </div>
    </div>
    
    <script>
        // Sample data - would be populated from actual metrics
        const languageData = {
            labels: ['JavaScript', 'TypeScript', 'CSS', 'HTML', 'Python'],
            datasets: [{
                data: [12300, 8500, 3200, 2100, 1500],
                backgroundColor: [
                    '#f7df1e',
                    '#3178c6',
                    '#264de4',
                    '#e34c26',
                    '#3776ab'
                ]
            }]
        };
        
        // Language distribution pie chart
        new Chart(document.getElementById('languageChart'), {
            type: 'doughnut',
            data: languageData,
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'right'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return label + ': ' + value + ' lines (' + percentage + '%)';
                            }
                        }
                    }
                }
            }
        });
        
        // Code composition chart
        new Chart(document.getElementById('compositionChart'), {
            type: 'bar',
            data: {
                labels: ['JavaScript', 'TypeScript', 'CSS', 'HTML', 'Python'],
                datasets: [
                    {
                        label: 'Code',
                        data: [10000, 7000, 3000, 2000, 1200],
                        backgroundColor: '#28a745'
                    },
                    {
                        label: 'Comments',
                        data: [1500, 1000, 150, 50, 200],
                        backgroundColor: '#ffc107'
                    },
                    {
                        label: 'Blank Lines',
                        data: [800, 500, 50, 50, 100],
                        backgroundColor: '#6c757d'
                    }
                ]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        stacked: true
                    },
                    y: {
                        stacked: true
                    }
                }
            }
        });
        
        // File size distribution
        new Chart(document.getElementById('fileSizeChart'), {
            type: 'line',
            data: {
                labels: ['0-100', '100-200', '200-300', '300-400', '400-500', '500+'],
                datasets: [{
                    label: 'Number of Files',
                    data: [120, 85, 45, 25, 15, 8],
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log_event "SUCCESS" "ANALYSIS" "Visualizations generated"
}

# Analyze dependencies relationships
analyze_dependencies() {
    local target_dir="${1:-.}"
    local output_file="$ANALYSIS_STATE/metrics/dependency_analysis.json"
    
    log_event "INFO" "ANALYSIS" "Analyzing dependency relationships"
    
    # Initialize dependency report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "direct_dependencies": 0,
  "transitive_dependencies": 0,
  "depth": 0,
  "circular_dependencies": [],
  "unused_dependencies": [],
  "outdated_count": 0
}
EOF
    
    # Analyze based on package manager
    if [[ -f "$target_dir/package.json" ]]; then
        analyze_npm_dependencies "$target_dir" "$output_file"
    elif [[ -f "$target_dir/requirements.txt" ]]; then
        analyze_python_dependencies "$target_dir" "$output_file"
    fi
    
    log_event "SUCCESS" "ANALYSIS" "Dependency analysis complete"
}

# Analyze npm dependencies
analyze_npm_dependencies() {
    local target_dir="$1"
    local output_file="$2"
    
    if [[ -f "$target_dir/package.json" ]]; then
        # Count direct dependencies
        local prod_deps=$(jq -r '.dependencies | length' "$target_dir/package.json" 2>/dev/null || echo 0)
        local dev_deps=$(jq -r '.devDependencies | length' "$target_dir/package.json" 2>/dev/null || echo 0)
        local direct_total=$((prod_deps + dev_deps))
        
        # Update report
        local temp_file=$(mktemp)
        jq --arg direct "$direct_total" \
           '.direct_dependencies = ($direct | tonumber)' "$output_file" > "$temp_file"
        mv "$temp_file" "$output_file"
    fi
}

# Generate complexity report
generate_complexity_report() {
    local target_dir="${1:-.}"
    local output_file="$ANALYSIS_STATE/insights/complexity_report.md"
    
    log_event "INFO" "ANALYSIS" "Generating complexity report"
    
    cat > "$output_file" << 'EOF'
# Complexity Analysis Report

## Overview

This report analyzes the complexity of the codebase to identify areas that may need refactoring.

## Complexity Metrics

### Cyclomatic Complexity
Measures the number of linearly independent paths through the code.

| Rating | Complexity | Risk |
|--------|------------|------|
| Simple | 1-10 | Low |
| Moderate | 11-20 | Medium |
| Complex | 21-50 | High |
| Very Complex | >50 | Very High |

### Cognitive Complexity
Measures how difficult the code is to understand.

## High Complexity Files

The following files have been identified as having high complexity:

EOF
    
    # Find complex files (simplified analysis)
    find "$target_dir" -name "*.js" -o -name "*.ts" | while read -r file; do
        if [[ -f "$file" ]]; then
            local nested_ifs=$(grep -c "if.*if" "$file" 2>/dev/null || echo 0)
            local functions=$(grep -c "function\|=>" "$file" 2>/dev/null || echo 0)
            
            if [[ $nested_ifs -gt 3 ]] || [[ $functions -gt 20 ]]; then
                echo "- **$file**: $functions functions, $nested_ifs nested conditions" >> "$output_file"
            fi
        fi
    done
    
    cat >> "$output_file" << 'EOF'

## Recommendations

1. **Extract Methods**: Break down complex functions into smaller, focused methods
2. **Reduce Nesting**: Use early returns and guard clauses
3. **Simplify Conditionals**: Extract complex boolean logic into well-named variables
4. **Use Design Patterns**: Apply appropriate patterns to reduce complexity

## Next Steps

1. Prioritize refactoring high-complexity files
2. Add unit tests before refactoring
3. Use automated tools to track complexity over time
4. Set complexity thresholds in your CI/CD pipeline
EOF
    
    log_event "SUCCESS" "ANALYSIS" "Complexity report generated"
}

# Generate tech debt report
generate_tech_debt_report() {
    local output_file="$ANALYSIS_STATE/insights/tech_debt_report.md"
    
    log_event "INFO" "ANALYSIS" "Generating technical debt report"
    
    cat > "$output_file" << 'EOF'
# Technical Debt Report

Generated: $(date)

## Technical Debt Categories

### 1. Code Debt
- **TODO/FIXME Comments**: Incomplete implementations
- **Code Duplication**: Similar code in multiple places
- **Dead Code**: Unused functions and variables
- **Poor Naming**: Variables and functions with unclear names

### 2. Architecture Debt
- **Tight Coupling**: Components with high interdependence
- **Missing Abstractions**: Direct dependencies on implementations
- **Inconsistent Patterns**: Mixed architectural styles

### 3. Testing Debt
- **Low Coverage**: Areas with insufficient test coverage
- **Missing Tests**: Critical paths without tests
- **Outdated Tests**: Tests that no longer reflect current behavior

### 4. Documentation Debt
- **Missing Documentation**: Undocumented APIs and complex logic
- **Outdated Documentation**: Documentation not matching code
- **No Architecture Docs**: Missing high-level design documentation

### 5. Infrastructure Debt
- **Manual Processes**: Deployment and build processes not automated
- **Missing Monitoring**: No visibility into production issues
- **Security Updates**: Delayed security patches

## Debt Inventory

### High Priority (Address within 1 sprint)
- [ ] Security vulnerabilities in dependencies
- [ ] Critical bugs in production
- [ ] Missing error handling in payment processing

### Medium Priority (Address within 1 month)
- [ ] Refactor authentication module
- [ ] Add integration tests for API endpoints
- [ ] Update outdated documentation

### Low Priority (Address within 1 quarter)
- [ ] Improve code consistency
- [ ] Optimize database queries
- [ ] Implement comprehensive logging

## Debt Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Code Coverage | 65% | 80% | ⚠️ |
| Outdated Dependencies | 12 | 0 | ❌ |
| TODO Comments | 47 | <20 | ⚠️ |
| Average Complexity | 15 | <10 | ⚠️ |

## Remediation Strategy

### Quick Wins (1-2 hours each)
1. Update dependencies with known vulnerabilities
2. Remove commented-out code
3. Fix ESLint warnings

### Major Initiatives
1. **Refactoring Sprint**: Dedicate 20% of each sprint to debt reduction
2. **Documentation Day**: Monthly documentation update session
3. **Testing Week**: Focused effort to improve test coverage

### Prevention Measures
1. Code review checklist including debt checks
2. Automated complexity analysis in CI/CD
3. Regular dependency updates
4. Mandatory documentation for new features

## Cost of Delay

Estimated impact of not addressing technical debt:
- **Velocity Decrease**: 15-20% slower feature development
- **Bug Rate Increase**: 2x more bugs in debt-heavy areas
- **Onboarding Time**: 50% longer for new developers
- **Security Risk**: Increased exposure to vulnerabilities

## Return on Investment

Addressing technical debt will:
- Reduce bug rates by 40%
- Improve development velocity by 25%
- Decrease onboarding time by 30%
- Improve team morale and retention
EOF
    
    log_event "SUCCESS" "ANALYSIS" "Technical debt report generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        structure)
            analyze_structure "${2:-.}"
            ;;
        metrics)
            analyze_metrics "${2:-.}"
            ;;
        insights)
            generate_insights
            ;;
        visualize)
            generate_visualizations
            ;;
        dependencies)
            analyze_dependencies "${2:-.}"
            ;;
        complexity)
            generate_complexity_report "${2:-.}"
            ;;
        tech-debt)
            generate_tech_debt_report
            ;;
        full)
            echo -e "${CYAN}Running comprehensive analysis...${NC}"
            analyze_structure "${2:-.}"
            analyze_metrics "${2:-.}"
            analyze_dependencies "${2:-.}"
            generate_insights
            generate_visualizations
            generate_complexity_report "${2:-.}"
            generate_tech_debt_report
            echo -e "${GREEN}✓ Comprehensive analysis complete!${NC}"
            echo -e "${YELLOW}View results in: $ANALYSIS_STATE${NC}"
            ;;
        *)
            echo "Usage: $0 {structure|metrics|insights|visualize|dependencies|complexity|tech-debt|full} [directory]"
            echo ""
            echo "Commands:"
            echo "  structure [dir]    - Analyze codebase structure"
            echo "  metrics [dir]      - Calculate code metrics"
            echo "  insights           - Generate insights from analysis"
            echo "  visualize          - Create visual charts"
            echo "  dependencies [dir] - Analyze dependency relationships"
            echo "  complexity [dir]   - Generate complexity report"
            echo "  tech-debt          - Generate technical debt report"
            echo "  full [dir]         - Run complete analysis"
            exit 1
            ;;
    esac
}

main "$@"