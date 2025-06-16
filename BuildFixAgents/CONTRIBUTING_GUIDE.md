# Contributing to BuildFixAgents

Welcome! We're excited that you're interested in contributing to BuildFixAgents. This guide will help you get started quickly and effectively.

## 🎯 Contribution Opportunities

### For Beginners
- **Documentation**: Improve guides, fix typos, add examples
- **Bug Reports**: Report issues with detailed reproduction steps
- **Simple Patterns**: Add basic error patterns for common issues
- **Tests**: Write unit tests for existing functionality

### For Intermediate Contributors
- **New Language Support**: Add patterns for additional languages
- **Feature Enhancement**: Improve existing agents or features
- **Performance**: Optimize slow operations
- **Integration**: Add CI/CD or IDE integrations

### For Advanced Contributors
- **Core Architecture**: Enhance the agent system
- **Machine Learning**: Implement ML-based pattern generation
- **Distributed Systems**: Add distributed execution support
- **Security**: Improve security and sandboxing

## 🚀 Getting Started

### 1. Fork and Clone
```bash
# Fork on GitHub, then:
git clone https://github.com/YOUR_USERNAME/BuildFixAgents.git
cd BuildFixAgents
git remote add upstream https://github.com/ORIGINAL/BuildFixAgents.git
```

### 2. Set Up Development Environment
```bash
# Make scripts executable
chmod +x *.sh

# Install dependencies
./setup.sh

# Set development environment
export BUILDFIX_DEV=true
export DEBUG=true
```

### 3. Create Feature Branch
```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create your feature branch
git checkout -b feature/your-feature-name
```

## 📝 Contribution Examples

### Example 1: Adding a New Error Pattern

Let's add support for Python's `IndentationError`:

```bash
# 1. Open the Python patterns file
vim patterns/python_patterns.json
```

```json
# 2. Add the pattern
{
  "IndentationError": {
    "description": "Fix Python indentation errors",
    "detection": "IndentationError: (unexpected indent|expected an indented block)",
    "patterns": [
      {
        "name": "unexpected_indent",
        "regex": "File \"([^\"]+)\", line (\\d+).*IndentationError: unexpected indent",
        "fix_strategy": "align_with_previous_line"
      },
      {
        "name": "expected_indent",
        "regex": "File \"([^\"]+)\", line (\\d+).*IndentationError: expected an indented block",
        "fix_strategy": "add_standard_indent"
      }
    ],
    "confidence": 0.95
  }
}
```

```bash
# 3. Implement the fix logic
vim python_patterns.sh
```

```bash
# 4. Add fix function
fix_indentation_error() {
    local file=$1
    local line=$2
    local error_type=$3
    
    case "$error_type" in
        "unexpected_indent")
            # Get indentation of previous line
            local prev_line=$((line - 1))
            local prev_indent=$(sed -n "${prev_line}p" "$file" | sed 's/[^ ].*//' | wc -c)
            
            # Fix current line indentation
            sed -i "${line}s/^[[:space:]]*/$(printf ' %.0s' $(seq 1 $prev_indent))/" "$file"
            ;;
        "expected_indent")
            # Add 4 spaces indentation
            sed -i "${line}s/^/    /" "$file"
            ;;
    esac
}
```

```bash
# 5. Test your pattern
./test_single_fix.sh IndentationError

# 6. Add unit test
vim tests/unit/test_python_indentation.sh
```

### Example 2: Creating a New Agent

Let's create a "Documentation Agent" that updates docs when fixes are made:

```bash
# 1. Create the agent script
cat > documentation_agent.sh << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_STATE="$SCRIPT_DIR/state/documentation"
mkdir -p "$DOC_STATE"

# Agent banner
show_banner() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║     Documentation Agent - v1.0         ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
}

# Update documentation based on fixes
update_docs() {
    echo -e "${YELLOW}Analyzing recent fixes...${NC}"
    
    # Check for recent fixes
    local fix_log="$SCRIPT_DIR/state/fixes/recent_fixes.json"
    if [[ ! -f "$fix_log" ]]; then
        echo "No recent fixes to document"
        return
    fi
    
    # Generate documentation updates
    local doc_updates="$DOC_STATE/updates.md"
    {
        echo "# Recent Fix Documentation"
        echo "Generated: $(date)"
        echo
        echo "## Fixed Issues"
        
        jq -r '.fixes[] | "- **\(.error_type)**: \(.description) in `\(.file)`"' "$fix_log"
        
        echo
        echo "## Patterns Updated"
        jq -r '.patterns_learned[] | "- \(.pattern_name): \(.description)"' "$fix_log"
        
    } > "$doc_updates"
    
    echo -e "${GREEN}✓ Documentation updated${NC}"
}

# Main function
main() {
    show_banner
    
    case "${1:-update}" in
        update)
            update_docs
            ;;
        report)
            cat "$DOC_STATE/updates.md" 2>/dev/null || echo "No updates available"
            ;;
        *)
            echo "Usage: $0 {update|report}"
            ;;
    esac
}

main "$@"
EOF

chmod +x documentation_agent.sh
```

```bash
# 2. Register the agent
vim state/agent_specifications.json
# Add:
{
  "documentation_agent": {
    "name": "Documentation Agent",
    "role": "documentation",
    "script": "documentation_agent.sh",
    "level": 2,
    "dependencies": ["learning_agent"],
    "enabled": true
  }
}
```

```bash
# 3. Integrate with coordinator
vim enhanced_coordinator_v2.sh
# Add to AGENT_HIERARCHY:
AGENT_HIERARCHY[level2]+=" documentation_agent"
```

```bash
# 4. Test the agent
./documentation_agent.sh update
./test_agent.sh documentation_agent
```

### Example 3: Adding a Performance Optimization

Let's optimize the error counting process:

```bash
# 1. Create optimized error counter
cat > optimized_error_counter.sh << 'EOF'
#!/bin/bash

# Use ripgrep for faster searching
count_errors_fast() {
    local build_output=$1
    
    # Use parallel processing with ripgrep
    local error_patterns=(
        "error CS[0-9]+"
        "Error:"
        "ERROR:"
        "SyntaxError"
        "TypeError"
    )
    
    # Count in parallel
    local total=0
    for pattern in "${error_patterns[@]}"; do
        count=$(rg -c "$pattern" "$build_output" 2>/dev/null || echo 0)
        total=$((total + count))
    done
    
    echo "$total"
}

# Benchmark the improvement
benchmark() {
    echo "Benchmarking error counting..."
    
    # Old method
    time_old=$(time (grep -E "(error|Error|ERROR)" build_output.txt | wc -l) 2>&1)
    
    # New method
    time_new=$(time (count_errors_fast build_output.txt) 2>&1)
    
    echo "Old method: $time_old"
    echo "New method: $time_new"
}
EOF

chmod +x optimized_error_counter.sh
```

## 🧪 Testing Your Changes

### Running Tests
```bash
# Run all tests
./run_all_tests.sh

# Run specific test suite
./tests/unit/run_unit_tests.sh
./tests/integration/run_integration_tests.sh

# Test your specific feature
./test_feature.sh your-feature-name
```

### Writing Tests
```bash
# Create test file
cat > tests/unit/test_my_feature.sh << 'EOF'
#!/bin/bash
source "$(dirname "$0")/../test_framework.sh"

test_my_feature() {
    # Arrange
    local input="test input"
    local expected="expected output"
    
    # Act
    local result=$(my_feature_function "$input")
    
    # Assert
    assert_equals "$expected" "$result" "Feature should produce expected output"
}

# Run tests
run_test_suite "My Feature Tests" \
    test_my_feature \
    test_another_aspect
EOF
```

## 📋 Pull Request Process

### 1. Before Submitting
- [ ] Run all tests: `./run_all_tests.sh`
- [ ] Update documentation if needed
- [ ] Add tests for new features
- [ ] Follow code style guidelines
- [ ] Update CHANGELOG.md

### 2. PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the project style
- [ ] I've added tests for my changes
- [ ] Documentation is updated
- [ ] All tests pass locally

## Screenshots (if applicable)
Add any relevant screenshots

## Additional Notes
Any additional information
```

### 3. Review Process
1. Automated CI checks must pass
2. At least one maintainer review required
3. Address review feedback
4. Squash commits if requested
5. Maintainer merges when approved

## 🎨 Code Style Guidelines

### Bash Scripts
```bash
# Good: Clear variable names, proper quoting
fix_error() {
    local error_type="$1"
    local file_path="$2"
    
    if [[ -z "$error_type" || -z "$file_path" ]]; then
        echo "Error: Missing required parameters" >&2
        return 1
    fi
    
    # Process error...
}

# Bad: Poor naming, missing quotes
fix() {
    e=$1
    f=$2
    if [ -z $e ]; then echo error; fi
}
```

### JSON Files
```json
{
  "patterns": {
    "error_code": {
      "description": "Human-readable description",
      "pattern": "regex_pattern",
      "confidence": 0.95,
      "test_cases": ["example1", "example2"]
    }
  }
}
```

### Comments
```bash
# Function: Processes build output to extract errors
# Parameters:
#   $1 - Path to build output file
#   $2 - Error type filter (optional)
# Returns:
#   0 on success, 1 on failure
# Example:
#   process_build_output "build.log" "CS0101"
process_build_output() {
    # Implementation...
}
```

## 🐛 Debugging Tips

### Enable Maximum Debugging
```bash
export DEBUG=true
export VERBOSE=true
export TRACE=true
export PS4='+ ${BASH_SOURCE}:${LINENO}: '
set -x
```

### Useful Debug Commands
```bash
# Trace function calls
bash -x ./your_script.sh 2>&1 | grep "^+"

# Monitor state changes
watch -n 1 'find state/ -name "*.json" -exec stat -c "%y %n" {} \; | sort -r | head -20'

# Check agent communication
tail -f state/scrum_master/communications/message_board.json | jq .
```

## 🤝 Community Guidelines

### Be Respectful
- Welcome newcomers
- Provide constructive feedback
- Respect different perspectives
- Follow the Code of Conduct

### Be Helpful
- Answer questions in discussions
- Share your knowledge
- Help review PRs
- Improve documentation

### Be Patient
- Complex features take time
- Reviews ensure quality
- Discussion improves outcomes
- Learning is part of the process

## 📞 Getting Help

- **Discord**: [Join our Discord](https://discord.gg/buildfix)
- **Discussions**: GitHub Discussions
- **Issues**: GitHub Issues (for bugs)
- **Email**: buildfix@example.com

## 🏆 Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project website
- Annual contributor awards

Thank you for contributing to BuildFixAgents! 🎉

---

*Your contributions make BuildFixAgents better for everyone!*