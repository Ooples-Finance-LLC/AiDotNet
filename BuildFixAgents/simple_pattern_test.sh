#!/bin/bash

# Simple Pattern System Test
echo "Testing Pattern System Components..."
echo ""

# Test 1: Check pattern files exist
echo "1. Checking pattern generator files..."
pattern_files=(
    "python_patterns.sh"
    "javascript_patterns.sh" 
    "go_patterns.sh"
    "rust_patterns.sh"
    "java_patterns.sh"
    "cpp_patterns.sh"
    "php_patterns.sh"
    "ruby_patterns.sh"
    "html_css_patterns.sh"
    "sql_patterns.sh"
)

found=0
for file in "${pattern_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✓ Found $file"
        ((found++))
    else
        echo "✗ Missing $file"
    fi
done

echo "Found $found/${#pattern_files[@]} pattern files"
echo ""

# Test 2: Verify JSON output
echo "2. Testing pattern generation..."
for lang in python javascript go; do
    echo -n "Testing $lang patterns... "
    if bash "${lang}_patterns.sh" 2>/dev/null | python3 -m json.tool > /dev/null 2>&1; then
        echo "✓ Valid JSON"
    else
        echo "✗ Invalid JSON"
    fi
done
echo ""

# Test 3: Count patterns
echo "3. Pattern counts:"
for file in *_patterns.sh; do
    if [[ -f "$file" ]]; then
        lang=$(basename "$file" _patterns.sh)
        count=$(grep -o '"pattern_count": [0-9]*' "$file" 2>/dev/null | grep -o '[0-9]*' || echo "0")
        printf "%-12s: %s patterns\n" "$lang" "$count"
    fi
done
echo ""

# Test 4: Total patterns
total=$(grep -h '"pattern_count": [0-9]*' *_patterns.sh 2>/dev/null | grep -o '[0-9]*' | awk '{sum+=$1} END {print sum}')
echo "Total patterns across all languages: $total"
echo ""

echo "✅ Pattern system test complete!"