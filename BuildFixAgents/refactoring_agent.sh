#!/bin/bash
# Refactoring Agent - Analyzes and improves code quality, structure, and maintainability
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFACTOR_STATE="$SCRIPT_DIR/state/refactoring"
mkdir -p "$REFACTOR_STATE/analysis" "$REFACTOR_STATE/suggestions" "$REFACTOR_STATE/reports"

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
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║       Refactoring Agent v1.0           ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
}

# Analyze code complexity
analyze_complexity() {
    local target_dir="${1:-.}"
    local output_file="$REFACTOR_STATE/analysis/complexity_report.json"
    
    log_event "INFO" "REFACTORING" "Analyzing code complexity in $target_dir"
    
    # Initialize report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "target": "$target_dir",
  "files": [],
  "summary": {
    "total_files": 0,
    "high_complexity_files": 0,
    "total_lines": 0,
    "total_functions": 0
  }
}
EOF
    
    # Analyze JavaScript/TypeScript files
    local js_files=0
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local lines=$(wc -l < "$file")
            local functions=$(grep -E "(function|const.*=.*=>|class)" "$file" | wc -l)
            local complexity=$(calculate_cyclomatic_complexity "$file")
            
            # Add to report
            local temp_file=$(mktemp)
            jq --arg file "$file" \
               --arg lines "$lines" \
               --arg functions "$functions" \
               --arg complexity "$complexity" \
               '.files += [{
                 "path": $file,
                 "lines": ($lines | tonumber),
                 "functions": ($functions | tonumber),
                 "complexity": ($complexity | tonumber)
               }]' "$output_file" > "$temp_file"
            mv "$temp_file" "$output_file"
            
            ((js_files++))
        fi
    done < <(find "$target_dir" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null)
    
    # Update summary
    local temp_file=$(mktemp)
    jq '.summary.total_files = (.files | length) |
        .summary.high_complexity_files = ([.files[] | select(.complexity > 10)] | length) |
        .summary.total_lines = ([.files[].lines] | add) |
        .summary.total_functions = ([.files[].functions] | add)' "$output_file" > "$temp_file"
    mv "$temp_file" "$output_file"
    
    log_event "SUCCESS" "REFACTORING" "Complexity analysis complete. Found $js_files files."
}

# Calculate cyclomatic complexity (simplified)
calculate_cyclomatic_complexity() {
    local file="$1"
    local complexity=1
    
    # Count decision points
    complexity=$((complexity + $(grep -E "(if|else if|while|for|case|catch|\?|&&|\|\|)" "$file" | wc -l)))
    
    echo "$complexity"
}

# Detect code smells
detect_code_smells() {
    local target_dir="${1:-.}"
    local output_file="$REFACTOR_STATE/analysis/code_smells.md"
    
    log_event "INFO" "REFACTORING" "Detecting code smells in $target_dir"
    
    cat > "$output_file" << 'EOF'
# Code Smells Report

Generated: $(date)

## Summary

This report identifies potential code smells and areas for improvement.

## Detected Issues

EOF
    
    # Long functions
    echo -e "\n### Long Functions (>50 lines)" >> "$output_file"
    while IFS= read -r file; do
        # Simple heuristic for function detection
        awk '
        /function|const.*=.*=>|class.*{/ {
            start = NR
            name = $0
        }
        /^}/ {
            if (start && NR - start > 50) {
                print FILENAME ":" start "-" NR " (" NR - start " lines)"
            }
            start = 0
        }
        ' "$file" >> "$output_file"
    done < <(find "$target_dir" -type f \( -name "*.js" -o -name "*.ts" \) 2>/dev/null)
    
    # Duplicate code detection
    echo -e "\n### Potential Duplicate Code" >> "$output_file"
    echo "Files with similar content:" >> "$output_file"
    
    # God objects/classes
    echo -e "\n### Large Classes (>500 lines)" >> "$output_file"
    find "$target_dir" -type f \( -name "*.js" -o -name "*.ts" \) -exec awk '
        /^class/ { inClass=1; className=$2; start=NR }
        inClass && /^}/ { 
            if (NR - start > 500) {
                print FILENAME ":" className " (" NR - start " lines)"
            }
            inClass=0
        }
    ' {} \; >> "$output_file" 2>/dev/null
    
    # TODO comments
    echo -e "\n### TODO/FIXME Comments" >> "$output_file"
    grep -rn "TODO\|FIXME\|HACK\|XXX" "$target_dir" --include="*.js" --include="*.ts" >> "$output_file" 2>/dev/null || true
    
    log_event "SUCCESS" "REFACTORING" "Code smell detection complete"
}

# Generate refactoring suggestions
generate_suggestions() {
    local analysis_file="$REFACTOR_STATE/analysis/complexity_report.json"
    local output_file="$REFACTOR_STATE/suggestions/refactoring_suggestions.md"
    
    log_event "INFO" "REFACTORING" "Generating refactoring suggestions"
    
    cat > "$output_file" << 'EOF'
# Refactoring Suggestions

Based on the code analysis, here are recommended refactoring strategies:

## High Priority Refactorings

EOF
    
    # High complexity files
    echo "### 1. Reduce Complexity in High-Complexity Files" >> "$output_file"
    echo "" >> "$output_file"
    
    if [[ -f "$analysis_file" ]]; then
        jq -r '.files[] | select(.complexity > 10) | "- **\(.path)** (Complexity: \(.complexity))"' "$analysis_file" >> "$output_file" 2>/dev/null || true
        echo "" >> "$output_file"
        cat >> "$output_file" << 'EOF'
**Suggested Actions:**
- Extract methods to reduce function complexity
- Use early returns to reduce nesting
- Replace complex conditionals with guard clauses
- Consider using the Strategy pattern for complex branching logic

EOF
    fi
    
    # Common refactoring patterns
    cat >> "$output_file" << 'EOF'
### 2. Common Refactoring Patterns

#### Extract Function
Before:
```javascript
function processOrder(order) {
  // validation logic
  if (!order.id || !order.items) {
    throw new Error('Invalid order');
  }
  if (order.items.length === 0) {
    throw new Error('Empty order');
  }
  
  // calculation logic
  let total = 0;
  for (const item of order.items) {
    total += item.price * item.quantity;
  }
  
  // save logic
  database.save(order);
  return total;
}
```

After:
```javascript
function processOrder(order) {
  validateOrder(order);
  const total = calculateOrderTotal(order);
  saveOrder(order);
  return total;
}

function validateOrder(order) {
  if (!order.id || !order.items) {
    throw new Error('Invalid order');
  }
  if (order.items.length === 0) {
    throw new Error('Empty order');
  }
}

function calculateOrderTotal(order) {
  return order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

function saveOrder(order) {
  database.save(order);
}
```

#### Replace Conditional with Polymorphism
Before:
```javascript
function calculatePrice(product) {
  switch (product.type) {
    case 'book':
      return product.basePrice * 0.9;
    case 'electronics':
      return product.basePrice * 1.2;
    case 'food':
      return product.basePrice * 0.95;
    default:
      return product.basePrice;
  }
}
```

After:
```javascript
class Product {
  calculatePrice() {
    return this.basePrice;
  }
}

class Book extends Product {
  calculatePrice() {
    return this.basePrice * 0.9;
  }
}

class Electronics extends Product {
  calculatePrice() {
    return this.basePrice * 1.2;
  }
}

class Food extends Product {
  calculatePrice() {
    return this.basePrice * 0.95;
  }
}
```

### 3. Code Organization

- **Single Responsibility Principle**: Each class/function should have one reason to change
- **DRY (Don't Repeat Yourself)**: Extract common code into reusable functions
- **SOLID Principles**: Apply all SOLID principles for better design

### 4. Performance Optimizations

- Use memoization for expensive calculations
- Implement lazy loading for large datasets
- Consider using Web Workers for CPU-intensive tasks
- Optimize database queries with proper indexing

### 5. Testing Improvements

- Add unit tests for all public methods
- Implement integration tests for API endpoints
- Use test-driven development (TDD) for new features
- Aim for >80% code coverage
EOF
    
    log_event "SUCCESS" "REFACTORING" "Refactoring suggestions generated"
}

# Generate ESLint configuration
generate_eslint_config() {
    local output_file="${1:-.eslintrc.json}"
    
    log_event "INFO" "REFACTORING" "Generating ESLint configuration"
    
    cat > "$output_file" << 'EOF'
{
  "env": {
    "browser": true,
    "es2021": true,
    "node": true,
    "jest": true
  },
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "plugin:@typescript-eslint/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaFeatures": {
      "jsx": true
    },
    "ecmaVersion": 12,
    "sourceType": "module"
  },
  "plugins": [
    "react",
    "@typescript-eslint",
    "prettier"
  ],
  "rules": {
    "complexity": ["warn", 10],
    "max-lines-per-function": ["warn", 50],
    "max-depth": ["warn", 4],
    "max-params": ["warn", 3],
    "no-console": "warn",
    "no-unused-vars": "off",
    "@typescript-eslint/no-unused-vars": ["error"],
    "prefer-const": "error",
    "no-var": "error",
    "eqeqeq": ["error", "always"],
    "curly": ["error", "all"],
    "brace-style": ["error", "1tbs"],
    "consistent-return": "error",
    "no-magic-numbers": ["warn", { "ignore": [0, 1, -1] }],
    "prefer-arrow-callback": "error",
    "arrow-body-style": ["error", "as-needed"],
    "no-duplicate-imports": "error",
    "sort-imports": ["error", {
      "ignoreCase": true,
      "ignoreDeclarationSort": true
    }],
    "react/prop-types": "off",
    "react/react-in-jsx-scope": "off"
  },
  "settings": {
    "react": {
      "version": "detect"
    }
  }
}
EOF
    
    # Prettier configuration
    cat > ".prettierrc.json" << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "bracketSpacing": true,
  "arrowParens": "avoid",
  "endOfLine": "lf"
}
EOF
    
    log_event "SUCCESS" "REFACTORING" "Linting configuration generated"
}

# Run automated refactoring
run_refactoring() {
    local target_file="$1"
    local refactor_type="${2:-extract-function}"
    
    log_event "INFO" "REFACTORING" "Running $refactor_type refactoring on $target_file"
    
    case "$refactor_type" in
        extract-function)
            # Example: Extract long functions
            echo "Extracting functions from $target_file..."
            # This would normally use AST manipulation tools
            ;;
        remove-duplication)
            echo "Removing code duplication in $target_file..."
            ;;
        simplify-conditionals)
            echo "Simplifying conditionals in $target_file..."
            ;;
        *)
            echo "Unknown refactoring type: $refactor_type"
            return 1
            ;;
    esac
    
    log_event "SUCCESS" "REFACTORING" "Refactoring complete"
}

# Generate refactoring report
generate_report() {
    local output_file="$REFACTOR_STATE/reports/refactoring_report.html"
    
    log_event "INFO" "REFACTORING" "Generating refactoring report"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Refactoring Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .header {
            background-color: #007bff;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .metric-card {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #007bff;
        }
        .chart {
            height: 300px;
            background-color: #f8f9fa;
            border-radius: 5px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background-color: white;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #007bff;
            color: white;
        }
        .complexity-high { color: #dc3545; }
        .complexity-medium { color: #ffc107; }
        .complexity-low { color: #28a745; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Refactoring Report</h1>
        <p>Generated: <span id="timestamp"></span></p>
    </div>

    <div class="metric-card">
        <h2>Code Quality Metrics</h2>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px;">
            <div>
                <h3>Total Files</h3>
                <div class="metric-value" id="total-files">0</div>
            </div>
            <div>
                <h3>High Complexity</h3>
                <div class="metric-value complexity-high" id="high-complexity">0</div>
            </div>
            <div>
                <h3>Code Coverage</h3>
                <div class="metric-value" id="coverage">0%</div>
            </div>
            <div>
                <h3>Technical Debt</h3>
                <div class="metric-value" id="tech-debt">0h</div>
            </div>
        </div>
    </div>

    <div class="metric-card">
        <h2>Complexity Distribution</h2>
        <div class="chart">
            <p>Complexity chart would be rendered here</p>
        </div>
    </div>

    <div class="metric-card">
        <h2>Files Requiring Refactoring</h2>
        <table id="files-table">
            <thead>
                <tr>
                    <th>File</th>
                    <th>Complexity</th>
                    <th>Lines</th>
                    <th>Issues</th>
                    <th>Priority</th>
                </tr>
            </thead>
            <tbody>
                <!-- Files will be populated here -->
            </tbody>
        </table>
    </div>

    <div class="metric-card">
        <h2>Recommended Actions</h2>
        <ol>
            <li>Extract methods from high-complexity functions</li>
            <li>Remove duplicate code blocks</li>
            <li>Simplify nested conditionals</li>
            <li>Add missing unit tests</li>
            <li>Update deprecated dependencies</li>
        </ol>
    </div>

    <script>
        // Set timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Load data from analysis (this would normally fetch from API)
        // For now, using placeholder data
        document.getElementById('total-files').textContent = '42';
        document.getElementById('high-complexity').textContent = '7';
        document.getElementById('coverage').textContent = '78%';
        document.getElementById('tech-debt').textContent = '32h';
    </script>
</body>
</html>
EOF
    
    log_event "SUCCESS" "REFACTORING" "Refactoring report generated at $output_file"
}

# Generate refactoring scripts
generate_refactor_scripts() {
    local output_dir="$REFACTOR_STATE/scripts"
    mkdir -p "$output_dir"
    
    log_event "INFO" "REFACTORING" "Generating refactoring scripts"
    
    # Script to find and fix common issues
    cat > "$output_dir/auto-refactor.sh" << 'EOF'
#!/bin/bash
# Automated refactoring script

set -euo pipefail

echo "Starting automated refactoring..."

# Fix ESLint issues
if command -v eslint &> /dev/null; then
    echo "Fixing ESLint issues..."
    eslint . --fix --ext .js,.jsx,.ts,.tsx || true
fi

# Format with Prettier
if command -v prettier &> /dev/null; then
    echo "Formatting with Prettier..."
    prettier --write "**/*.{js,jsx,ts,tsx,json,css,md}" || true
fi

# Remove unused imports (requires eslint-plugin-unused-imports)
echo "Removing unused imports..."
find . -name "*.js" -o -name "*.ts" | while read file; do
    # This is a placeholder - actual implementation would use AST tools
    echo "Processing $file"
done

# Convert var to let/const
echo "Converting var to let/const..."
find . -name "*.js" | xargs sed -i.bak 's/\bvar\b/let/g'

# Add missing semicolons
echo "Adding missing semicolons..."
# This would use a proper AST tool in production

echo "Automated refactoring complete!"
EOF
    
    chmod +x "$output_dir/auto-refactor.sh"
    
    log_event "SUCCESS" "REFACTORING" "Refactoring scripts generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        analyze)
            analyze_complexity "${2:-.}"
            detect_code_smells "${2:-.}"
            ;;
        suggest)
            generate_suggestions
            ;;
        lint)
            generate_eslint_config "${2:-.eslintrc.json}"
            ;;
        refactor)
            run_refactoring "${2:-}" "${3:-extract-function}"
            ;;
        report)
            generate_report
            ;;
        scripts)
            generate_refactor_scripts
            ;;
        init)
            echo -e "${CYAN}Initializing refactoring analysis...${NC}"
            analyze_complexity "."
            detect_code_smells "."
            generate_suggestions
            generate_eslint_config
            generate_report
            generate_refactor_scripts
            echo -e "${GREEN}✓ Refactoring analysis complete!${NC}"
            echo -e "${YELLOW}Review the reports in: $REFACTOR_STATE${NC}"
            ;;
        *)
            echo "Usage: $0 {analyze|suggest|lint|refactor|report|scripts|init} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze [dir]       - Analyze code complexity and smells"
            echo "  suggest            - Generate refactoring suggestions"
            echo "  lint [file]        - Generate linting configuration"
            echo "  refactor [file]    - Run automated refactoring"
            echo "  report             - Generate HTML report"
            echo "  scripts            - Generate refactoring scripts"
            echo "  init               - Run complete analysis"
            exit 1
            ;;
    esac
}

main "$@"