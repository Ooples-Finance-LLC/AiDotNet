#!/bin/bash

# Fix Agent - Build Analyzer Error Parsing
# Fixes the generic_build_analyzer.sh to properly parse C# errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
BOLD='\033[1m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'

echo -e "${BOLD}${CYAN}=== Fix Agent: Build Analyzer Error Parsing ===${NC}"

# Backup original
cp "$SCRIPT_DIR/generic_build_analyzer.sh" "$SCRIPT_DIR/generic_build_analyzer.sh.backup.$(date +%s)"

# Fix 1: Update error extraction to properly parse C# errors
echo -e "\n${YELLOW}Fixing error extraction patterns...${NC}"

# Find the extract_error_details function
cat > /tmp/fix_extract_errors.patch << 'EOF'
# Extract detailed error information
extract_error_details() {
    local build_output="$1"
    local language="$2"
    
    case "$language" in
        "csharp")
            # Extract C# errors with proper parsing
            # Format: /path/to/file.cs(line,col): error CS0101: Description [target]
            echo "$build_output" | grep -E "error CS[0-9]{4}" | while IFS= read -r line; do
                # Extract components
                local file_path=$(echo "$line" | cut -d'(' -f1)
                local location=$(echo "$line" | cut -d'(' -f2 | cut -d')' -f1)
                local line_num=$(echo "$location" | cut -d',' -f1)
                local error_match=$(echo "$line" | grep -o "error CS[0-9]\{4\}")
                local error_code=$(echo "$error_match" | cut -d' ' -f2)
                local description=$(echo "$line" | sed 's/.*error CS[0-9]\{4\}: //' | cut -d'[' -f1 | sed 's/[[:space:]]*$//')
                
                # Only process if we have valid data
                if [[ -n "$file_path" ]] && [[ -n "$error_code" ]] && [[ -n "$line_num" ]]; then
                    echo "FILE:$file_path|LINE:$line_num|CODE:$error_code|DESC:$description"
                fi
            done | sort -u
            ;;
        "python")
            # Python error extraction (existing code)
            echo "$build_output" | grep -E "(SyntaxError|NameError|ImportError|TypeError|ValueError)" | while read -r line; do
                echo "FILE:unknown|LINE:0|CODE:PythonError|DESC:$line"
            done
            ;;
        *)
            # Generic error extraction
            echo "$build_output" | grep -iE "error|fail" | while read -r line; do
                echo "FILE:unknown|LINE:0|CODE:GenericError|DESC:$line"
            done
            ;;
    esac
}
EOF

# Apply the fix to generic_build_analyzer.sh
echo -e "${GREEN}Applying error extraction fix...${NC}"

# Find and replace the function
awk '
/^extract_error_details\(\)/ {
    print "# Backup of original function"
    print "# " $0
    while (getline && !/^}/) {
        print "# " $0
    }
    print "# " $0
    print ""
    # Insert new function
    system("cat /tmp/fix_extract_errors.patch")
    next
}
{print}
' "$SCRIPT_DIR/generic_build_analyzer.sh" > "$SCRIPT_DIR/generic_build_analyzer.sh.tmp"

mv "$SCRIPT_DIR/generic_build_analyzer.sh.tmp" "$SCRIPT_DIR/generic_build_analyzer.sh"
chmod +x "$SCRIPT_DIR/generic_build_analyzer.sh"

# Fix 2: Update the analyze_build_errors function to use the new format
echo -e "\n${YELLOW}Fixing build error analysis...${NC}"

cat > /tmp/fix_analyze_errors.patch << 'EOF'
# Analyze the build errors
analyze_build_errors() {
    log_message "Analyzing error patterns for $DETECTED_LANGUAGE..."
    
    # Extract detailed error information
    local error_details=$(extract_error_details "$BUILD_OUTPUT" "$DETECTED_LANGUAGE")
    
    # Count unique error types
    local unique_errors=$(echo "$error_details" | cut -d'|' -f3 | cut -d':' -f2 | sort -u)
    local error_count=$(echo "$unique_errors" | grep -v '^$' | wc -l)
    
    log_message "Error analysis complete - found $error_count unique error types"
    
    # Store error details for agent generation
    echo "$error_details" > "$STATE_DIR/error_details.txt"
    
    # Create error summary
    echo "$unique_errors" | while IFS= read -r error_code; do
        [[ -z "$error_code" ]] && continue
        local count=$(echo "$error_details" | grep -c "CODE:$error_code" || echo 0)
        echo "$error_code:$count"
    done > "$STATE_DIR/error_summary.txt"
}
EOF

# Apply analyze fix
sed -i '/^analyze_build_errors()/,/^}$/{
    /^analyze_build_errors()/r /tmp/fix_analyze_errors.patch
    d
}' "$SCRIPT_DIR/generic_build_analyzer.sh"

# Fix 3: Update generate_agent_specifications to create proper agents
echo -e "\n${YELLOW}Fixing agent specification generation...${NC}"

cat > /tmp/fix_agent_specs.patch << 'EOF'
# Generate agent specifications based on error analysis
generate_agent_specifications() {
    local language="$1"
    log_message "Generating agent specifications for $language..."
    
    local agents=()
    local agent_count=0
    
    # Read error summary and create agents
    if [[ -f "$STATE_DIR/error_summary.txt" ]]; then
        while IFS=: read -r error_code count; do
            [[ -z "$error_code" ]] && continue
            
            # Create agent for this error type
            local agent_name="agent_${error_code,,}_fixer"
            local priority_value
            if [[ "$count" -gt 10 ]]; then
                priority_value='"high"'
            else
                priority_value='"medium"'
            fi
            
            local agent_spec=$(cat <<EOF
    {
      "agent_id": "$agent_name",
      "name": "$error_code Error Fixer",
      "type": "error_fixer",
      "specialization": "$error_code",
      "target_errors": ["$error_code"],
      "priority": $priority_value,
      "max_iterations": 3,
      "strategies": ["pattern_matching", "file_modification"],
      "language": "$language",
      "error_count": $count
    }
EOF
)
            agents+=("$agent_spec")
            ((agent_count++))
            
            # Limit number of agents
            [[ $agent_count -ge 5 ]] && break
        done < "$STATE_DIR/error_summary.txt"
    fi
    
    # Always create at least one generic agent
    if [[ $agent_count -eq 0 ]]; then
        local generic_agent=$(cat <<EOF
    {
      "agent_id": "generic_error_fixer",
      "name": "Generic Error Fixer",
      "type": "error_fixer",
      "specialization": "general",
      "target_errors": ["*"],
      "priority": "high",
      "max_iterations": 3,
      "strategies": ["pattern_matching", "file_modification"],
      "language": "$language"
    }
EOF
)
        agents+=("$generic_agent")
        ((agent_count++))
    fi
    
    log_message "Generated specifications for $agent_count specialized agents"
    
    # Create the final specifications file
    cat > "$AGENT_SPEC_FILE" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "total_errors": $(cat "$STATE_DIR/error_details.txt" 2>/dev/null | wc -l || echo 0),
  "agent_specifications": [
$(printf '%s\n' "${agents[@]}" | paste -sd,)
  ],
  "coordination_strategy": "parallel_by_error_type",
  "max_concurrent_agents": 3
}
EOF
}
EOF

# Apply agent spec fix
sed -i '/^generate_agent_specifications()/,/^}$/{
    /^generate_agent_specifications()/r /tmp/fix_agent_specs.patch
    d
}' "$SCRIPT_DIR/generic_build_analyzer.sh"

# Test the fix
echo -e "\n${GREEN}Testing the fixed build analyzer...${NC}"

# Run a test
cd "$PROJECT_DIR"
if ./BuildFixAgents/generic_build_analyzer.sh "$PROJECT_DIR"; then
    echo -e "${GREEN}✓ Build analyzer fixed successfully!${NC}"
    
    # Check if agents were generated
    if [[ -f "$SCRIPT_DIR/state/agent_specifications.json" ]]; then
        agent_count=$(jq '.agent_specifications | length' "$SCRIPT_DIR/state/agent_specifications.json")
        echo -e "${GREEN}✓ Generated $agent_count agent specifications${NC}"
        
        # Show the agents
        echo -e "\n${CYAN}Generated Agents:${NC}"
        jq -r '.agent_specifications[] | "  - \(.name) [\(.specialization)]"' "$SCRIPT_DIR/state/agent_specifications.json"
    fi
else
    echo -e "${RED}✗ Build analyzer test failed${NC}"
fi

# Clean up
rm -f /tmp/fix_*.patch

echo -e "\n${BOLD}${GREEN}=== Build Analyzer Fix Complete ===${NC}"