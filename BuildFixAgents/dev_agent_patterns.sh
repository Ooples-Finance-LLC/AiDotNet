#!/bin/bash

# Developer Agent - Pattern Library Specialist
# Completes and enhances the pattern library for all supported error codes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARCH_STATE="$SCRIPT_DIR/state/architecture"
PATTERN_STATE="$SCRIPT_DIR/state/patterns"
PATTERN_DIR="$SCRIPT_DIR/patterns"
mkdir -p "$PATTERN_STATE" "$PATTERN_DIR"

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

# Build comprehensive pattern library
build_pattern_library() {
    echo -e "${BOLD}${MAGENTA}=== Building Comprehensive Pattern Library ===${NC}"
    
    # Create C# patterns
    create_csharp_patterns
    
    # Create patterns for other languages
    create_python_patterns
    create_javascript_patterns
    create_java_patterns
    
    # Validate patterns
    validate_pattern_library
    
    echo -e "${GREEN}✓ Pattern library built${NC}"
}

# Create comprehensive C# error patterns
create_csharp_patterns() {
    echo -e "\n${YELLOW}Creating C# pattern library...${NC}"
    
    cat > "$PATTERN_DIR/csharp_patterns.json" << 'EOF'
{
  "language": "csharp",
  "version": "2.0",
  "errors": [
    {
      "code": "CS0101",
      "description": "Duplicate class/type definition",
      "pattern": "(class|struct|interface|enum)\\s+(\\w+)",
      "detection": "multiple_occurrences",
      "fix_strategy": "remove_duplicate",
      "example": "public class MyClass { } public class MyClass { }",
      "replacement": null
    },
    {
      "code": "CS0111",
      "description": "Duplicate method definition",
      "pattern": "(public|private|protected|internal)\\s+.*\\s+(\\w+)\\s*\\([^)]*\\)",
      "detection": "signature_match",
      "fix_strategy": "remove_duplicate_method",
      "example": "public void Method() { } public void Method() { }",
      "replacement": null
    },
    {
      "code": "CS0246",
      "description": "Type or namespace not found",
      "pattern": "\\b(\\w+)\\b",
      "detection": "missing_type",
      "fix_strategy": "add_using_or_reference",
      "common_fixes": {
        "List": "using System.Collections.Generic;",
        "Task": "using System.Threading.Tasks;",
        "HttpClient": "using System.Net.Http;",
        "File": "using System.IO;",
        "Regex": "using System.Text.RegularExpressions;"
      }
    },
    {
      "code": "CS0462",
      "description": "Inheritance member conflict",
      "pattern": "override.*\\s+(\\w+)\\s*\\(",
      "detection": "override_conflict",
      "fix_strategy": "fix_override_signature",
      "replacement": "public override ${return_type} ${method_name}(${parameters})"
    },
    {
      "code": "CS1061",
      "description": "Type does not contain definition",
      "pattern": "\\.([a-zA-Z_]\\w*)\\s*[\\(\\[]?",
      "detection": "missing_member",
      "fix_strategy": "add_member_or_extension"
    },
    {
      "code": "CS0103",
      "description": "Name does not exist in context",
      "pattern": "\\b(\\w+)\\b",
      "detection": "undefined_variable",
      "fix_strategy": "declare_variable_or_import"
    },
    {
      "code": "CS0535",
      "description": "Does not implement interface member",
      "pattern": "interface\\s+(\\w+)",
      "detection": "missing_implementation",
      "fix_strategy": "implement_interface_member"
    },
    {
      "code": "CS0161",
      "description": "Not all code paths return value",
      "pattern": "(public|private|protected|internal)\\s+(?!void)\\w+\\s+(\\w+)\\s*\\(",
      "detection": "missing_return",
      "fix_strategy": "add_return_statement",
      "replacement": "throw new NotImplementedException();"
    },
    {
      "code": "CS0029",
      "description": "Cannot implicitly convert type",
      "pattern": "=\\s*([^;]+);",
      "detection": "type_mismatch",
      "fix_strategy": "add_cast_or_conversion"
    },
    {
      "code": "CS0117",
      "description": "Type does not contain definition for member",
      "pattern": "(\\w+)\\.(\\w+)",
      "detection": "static_member_missing",
      "fix_strategy": "check_static_vs_instance"
    }
  ],
  "fix_templates": {
    "add_method": "public ${return_type} ${method_name}(${parameters})\n{\n    ${body}\n}",
    "add_property": "public ${type} ${name} { get; set; }",
    "add_using": "using ${namespace};",
    "implement_interface": "public ${return_type} ${method_name}(${parameters})\n{\n    throw new NotImplementedException();\n}"
  },
  "common_namespaces": [
    "System",
    "System.Collections.Generic",
    "System.Linq",
    "System.Text",
    "System.Threading.Tasks",
    "System.IO",
    "System.Net.Http"
  ]
}
EOF
    
    echo -e "${GREEN}✓ C# patterns created${NC}"
}

# Create Python error patterns
create_python_patterns() {
    echo -e "\n${YELLOW}Creating Python pattern library...${NC}"
    
    cat > "$PATTERN_DIR/python_patterns.json" << 'EOF'
{
  "language": "python",
  "version": "1.0",
  "errors": [
    {
      "code": "NameError",
      "description": "Name not defined",
      "pattern": "name '(\\w+)' is not defined",
      "fix_strategy": "import_or_define"
    },
    {
      "code": "ImportError",
      "description": "Module not found",
      "pattern": "No module named '(\\w+)'",
      "fix_strategy": "install_or_fix_import"
    },
    {
      "code": "SyntaxError",
      "description": "Invalid syntax",
      "pattern": "invalid syntax",
      "fix_strategy": "fix_syntax"
    },
    {
      "code": "IndentationError",
      "description": "Incorrect indentation",
      "pattern": "unexpected indent|expected an indented block",
      "fix_strategy": "fix_indentation"
    }
  ]
}
EOF
}

# Create JavaScript error patterns
create_javascript_patterns() {
    echo -e "\n${YELLOW}Creating JavaScript pattern library...${NC}"
    
    cat > "$PATTERN_DIR/javascript_patterns.json" << 'EOF'
{
  "language": "javascript",
  "version": "1.0",
  "errors": [
    {
      "code": "ReferenceError",
      "description": "Variable not defined",
      "pattern": "(\\w+) is not defined",
      "fix_strategy": "declare_or_import"
    },
    {
      "code": "SyntaxError",
      "description": "Unexpected token",
      "pattern": "Unexpected token (\\w+)",
      "fix_strategy": "fix_syntax"
    },
    {
      "code": "TypeError",
      "description": "Type error",
      "pattern": "Cannot read property '(\\w+)' of undefined",
      "fix_strategy": "add_null_check"
    }
  ]
}
EOF
}

# Create Java error patterns
create_java_patterns() {
    echo -e "\n${YELLOW}Creating Java pattern library...${NC}"
    
    cat > "$PATTERN_DIR/java_patterns.json" << 'EOF'
{
  "language": "java",
  "version": "1.0",
  "errors": [
    {
      "code": "cannot find symbol",
      "description": "Symbol not found",
      "pattern": "cannot find symbol.*symbol:\\s+(\\w+)\\s+(\\w+)",
      "fix_strategy": "import_or_declare"
    },
    {
      "code": "incompatible types",
      "description": "Type mismatch",
      "pattern": "incompatible types: (\\w+) cannot be converted to (\\w+)",
      "fix_strategy": "add_cast_or_change_type"
    }
  ]
}
EOF
}

# Validate pattern library
validate_pattern_library() {
    echo -e "\n${YELLOW}Validating pattern library...${NC}"
    
    local validation_report="$PATTERN_STATE/validation_report.md"
    
    cat > "$validation_report" << EOF
# Pattern Library Validation Report

## Pattern Files Created:
EOF
    
    # Check each pattern file
    for pattern_file in "$PATTERN_DIR"/*.json; do
        if [[ -f "$pattern_file" ]]; then
            local filename=$(basename "$pattern_file")
            local is_valid="❌"
            
            # Validate JSON
            if jq . "$pattern_file" >/dev/null 2>&1; then
                is_valid="✅"
                local error_count=$(jq '.errors | length' "$pattern_file")
                echo "- $is_valid $filename (${error_count} patterns)" >> "$validation_report"
            else
                echo "- $is_valid $filename (INVALID JSON)" >> "$validation_report"
            fi
        fi
    done
    
    # Summary statistics
    cat >> "$validation_report" << EOF

## Statistics:
- Total pattern files: $(ls "$PATTERN_DIR"/*.json 2>/dev/null | wc -l)
- C# patterns: $(jq '.errors | length' "$PATTERN_DIR/csharp_patterns.json" 2>/dev/null || echo 0)
- Python patterns: $(jq '.errors | length' "$PATTERN_DIR/python_patterns.json" 2>/dev/null || echo 0)
- JavaScript patterns: $(jq '.errors | length' "$PATTERN_DIR/javascript_patterns.json" 2>/dev/null || echo 0)
- Java patterns: $(jq '.errors | length' "$PATTERN_DIR/java_patterns.json" 2>/dev/null || echo 0)

## Pattern Coverage:
### C# Error Codes Covered:
$(jq -r '.errors[].code' "$PATTERN_DIR/csharp_patterns.json" 2>/dev/null | sort | sed 's/^/- /')

Generated: $(date)
EOF
    
    echo -e "${GREEN}✓ Validation complete${NC}"
    echo -e "Report saved to: $validation_report"
}

# Create pattern matching engine
create_pattern_engine() {
    echo -e "\n${YELLOW}Creating pattern matching engine...${NC}"
    
    cat > "$PATTERN_STATE/pattern_engine.sh" << 'EOF'
#!/bin/bash

# Pattern Matching Engine for BuildFixAgents
# Provides advanced pattern matching and fix application

# Match error against pattern database
match_error_pattern() {
    local error_code="$1"
    local error_msg="$2"
    local language="$3"
    local pattern_file="$SCRIPT_DIR/patterns/${language}_patterns.json"
    
    if [[ ! -f "$pattern_file" ]]; then
        return 1
    fi
    
    # Find matching pattern
    local pattern_data=$(jq -r ".errors[] | select(.code == \"$error_code\")" "$pattern_file")
    if [[ -n "$pattern_data" ]]; then
        echo "$pattern_data"
        return 0
    fi
    
    return 1
}

# Apply pattern-based fix
apply_pattern_based_fix() {
    local file="$1"
    local line="$2"
    local pattern_data="$3"
    
    local fix_strategy=$(echo "$pattern_data" | jq -r '.fix_strategy')
    
    case "$fix_strategy" in
        "remove_duplicate")
            remove_duplicate_definition "$file" "$line"
            ;;
        "add_using_or_reference")
            add_missing_reference "$file" "$pattern_data"
            ;;
        "fix_override_signature")
            fix_method_override "$file" "$line"
            ;;
        "implement_interface_member")
            implement_missing_member "$file" "$pattern_data"
            ;;
        *)
            return 1
            ;;
    esac
}

# Export functions
export -f match_error_pattern apply_pattern_based_fix
EOF
    
    chmod +x "$PATTERN_STATE/pattern_engine.sh"
    echo -e "${GREEN}✓ Pattern engine created${NC}"
}

# Create pattern documentation
create_pattern_documentation() {
    cat > "$PATTERN_DIR/PATTERN_GUIDE.md" << 'EOF'
# BuildFixAgents Pattern Library Guide

## Overview
The pattern library provides automated fix strategies for common compilation errors across multiple languages.

## Pattern Structure

Each pattern contains:
- `code`: The error code (e.g., CS0101)
- `description`: Human-readable description
- `pattern`: Regex pattern for matching
- `detection`: How to detect the error
- `fix_strategy`: The approach to fix
- `replacement`: Optional replacement template

## Supported Languages

### C# (.NET)
- 10 common error patterns
- Automatic using statement addition
- Duplicate definition removal
- Interface implementation

### Python
- 4 common error patterns
- Import fixes
- Indentation corrections

### JavaScript
- 3 common error patterns  
- Variable declarations
- Null checks

### Java
- 2 common error patterns
- Import management
- Type conversions

## Adding New Patterns

To add a new pattern:
1. Edit the appropriate language JSON file
2. Add pattern object with all required fields
3. Test with sample code
4. Document the fix strategy

## Pattern Matching Process

1. Error code extracted from build output
2. Pattern matched against database
3. Fix strategy determined
4. Fix applied with backup
5. Build verification
6. Rollback if needed

## Best Practices

- Keep patterns specific but flexible
- Always create backups
- Verify fixes compile
- Document edge cases
- Test thoroughly
EOF
}

# Main execution
main() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║  Developer Agent - Pattern Specialist  ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"
    
    # Build pattern library
    build_pattern_library
    
    # Create pattern engine
    create_pattern_engine
    
    # Create documentation
    create_pattern_documentation
    
    # Update agent status
    if [[ -f "$ARCH_STATE/agent_manifest.json" ]]; then
        jq '.agents.developer_2.status = "complete"' "$ARCH_STATE/agent_manifest.json" > "$ARCH_STATE/tmp.json" && \
        mv "$ARCH_STATE/tmp.json" "$ARCH_STATE/agent_manifest.json"
    fi
    
    echo -e "\n${GREEN}✓ Pattern library complete${NC}"
}

main "$@"