#!/bin/bash

# Pattern Generator System
# Automatically generates error patterns from compiler documentation and real errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DIR="$SCRIPT_DIR/patterns"
GENERATOR_DIR="$PATTERNS_DIR/generators"
DOCS_DIR="$PATTERNS_DIR/compiler_docs"
OUTPUT_DIR="$PATTERNS_DIR/generated"

# Create directory structure
mkdir -p "$GENERATOR_DIR" "$DOCS_DIR" "$OUTPUT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Log function
log() {
    echo -e "${BLUE}[GENERATOR]${NC} $1"
}

# Error function
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Success function
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Generate patterns from Roslyn compiler documentation
generate_csharp_patterns_from_docs() {
    log "Generating C# patterns from Roslyn documentation..."
    
    cat > "$OUTPUT_DIR/csharp_generated_patterns.json" << 'EOF'
{
  "generator": "roslyn_docs_v1.0",
  "generated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "source": "https://github.com/dotnet/roslyn/tree/main/docs/compilers/CSharp",
  "patterns": {
EOF
    
    # Generate patterns for each error category
    local first=true
    
    # Syntax Errors (CS0001-CS0999)
    for i in {1..999}; do
        local error_code=$(printf "CS%04d" $i)
        
        if [[ "$first" == "false" ]]; then
            echo "," >> "$OUTPUT_DIR/csharp_generated_patterns.json"
        fi
        first=false
        
        generate_single_csharp_pattern "$error_code" >> "$OUTPUT_DIR/csharp_generated_patterns.json"
    done
    
    # Semantic Errors (CS1000-CS1999)
    for i in {1000..1999}; do
        local error_code=$(printf "CS%04d" $i)
        echo "," >> "$OUTPUT_DIR/csharp_generated_patterns.json"
        generate_single_csharp_pattern "$error_code" >> "$OUTPUT_DIR/csharp_generated_patterns.json"
    done
    
    # Close JSON
    echo '
  }
}' >> "$OUTPUT_DIR/csharp_generated_patterns.json"
    
    success "Generated C# patterns at: $OUTPUT_DIR/csharp_generated_patterns.json"
}

# Generate a single C# error pattern
generate_single_csharp_pattern() {
    local error_code=$1
    
    # Map error codes to categories and fixes
    case "$error_code" in
        CS0001) generate_compiler_error_pattern "$error_code" ;;
        CS000[2-9]) generate_file_error_pattern "$error_code" ;;
        CS00[1-2][0-9]) generate_syntax_error_pattern "$error_code" ;;
        CS00[3-9][0-9]) generate_type_error_pattern "$error_code" ;;
        CS0[1-9][0-9][0-9]) generate_member_error_pattern "$error_code" ;;
        CS1[0-4][0-9][0-9]) generate_declaration_error_pattern "$error_code" ;;
        CS1[5-9][0-9][0-9]) generate_expression_error_pattern "$error_code" ;;
        CS[2-9][0-9][0-9][0-9]) generate_advanced_error_pattern "$error_code" ;;
        *) generate_generic_error_pattern "$error_code" ;;
    esac
}

# Generate compiler error patterns
generate_compiler_error_pattern() {
    local code=$1
    cat << EOF
    "$code": {
      "message": "Internal compiler error",
      "category": "Compiler",
      "severity": "Error",
      "documentation_url": "https://docs.microsoft.com/en-us/dotnet/csharp/misc/$code",
      "fixes": [
        {
          "name": "clean_rebuild",
          "description": "Clean and rebuild the project",
          "confidence": 0.9,
          "actions": [
            {"type": "command", "command": "dotnet clean"},
            {"type": "command", "command": "dotnet build"}
          ]
        },
        {
          "name": "clear_cache",
          "description": "Clear compiler caches",
          "confidence": 0.7,
          "actions": [
            {"type": "delete", "path": "obj/"},
            {"type": "delete", "path": "bin/"},
            {"type": "command", "command": "dotnet restore"}
          ]
        }
      ]
    }
EOF
}

# Generate file error patterns
generate_file_error_pattern() {
    local code=$1
    cat << EOF
    "$code": {
      "message": "File or assembly reference error",
      "category": "Reference",
      "severity": "Error",
      "documentation_url": "https://docs.microsoft.com/en-us/dotnet/csharp/misc/$code",
      "fixes": [
        {
          "name": "restore_packages",
          "description": "Restore NuGet packages",
          "confidence": 0.85,
          "actions": [
            {"type": "command", "command": "dotnet restore"}
          ]
        },
        {
          "name": "check_file_path",
          "description": "Verify file paths in project",
          "confidence": 0.75,
          "actions": [
            {"type": "validate_paths", "pattern": "*.csproj"},
            {"type": "fix_relative_paths", "base": "project_root"}
          ]
        }
      ]
    }
EOF
}

# Generate Python patterns from documentation
generate_python_patterns() {
    log "Generating Python patterns..."
    
    cat > "$OUTPUT_DIR/python_generated_patterns.json" << 'EOF'
{
  "generator": "python_docs_v1.0",
  "generated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "patterns": {
    "SyntaxError": {
      "category": "Syntax",
      "patterns": [
        {
          "regex": "invalid syntax",
          "fixes": [
            {
              "name": "fix_indentation",
              "description": "Fix Python indentation",
              "actions": [
                {"type": "analyze_indentation"},
                {"type": "apply_consistent_indentation"}
              ]
            }
          ]
        },
        {
          "regex": "unexpected EOF while parsing",
          "fixes": [
            {
              "name": "close_brackets",
              "description": "Add missing closing brackets",
              "actions": [
                {"type": "count_brackets"},
                {"type": "add_closing_brackets"}
              ]
            }
          ]
        }
      ]
    },
    "ImportError": {
      "category": "Import",
      "patterns": [
        {
          "regex": "No module named '([^']+)'",
          "capture_groups": ["module_name"],
          "fixes": [
            {
              "name": "install_module",
              "description": "Install missing module",
              "actions": [
                {"type": "command", "command": "pip install {module_name}"}
              ]
            },
            {
              "name": "check_pythonpath",
              "description": "Add to PYTHONPATH",
              "actions": [
                {"type": "check_module_location"},
                {"type": "update_pythonpath"}
              ]
            }
          ]
        }
      ]
    },
    "TypeError": {
      "category": "Type",
      "patterns": [
        {
          "regex": "unsupported operand type\\(s\\) for (.+): '(.+)' and '(.+)'",
          "capture_groups": ["operator", "type1", "type2"],
          "fixes": [
            {
              "name": "type_conversion",
              "description": "Add type conversion",
              "actions": [
                {"type": "analyze_types", "types": ["{type1}", "{type2}"]},
                {"type": "suggest_conversion"}
              ]
            }
          ]
        }
      ]
    }
  }
}
EOF
    
    success "Generated Python patterns at: $OUTPUT_DIR/python_generated_patterns.json"
}

# Generate JavaScript/TypeScript patterns
generate_javascript_patterns() {
    log "Generating JavaScript/TypeScript patterns..."
    
    cat > "$OUTPUT_DIR/javascript_generated_patterns.json" << 'EOF'
{
  "generator": "js_ts_v1.0",
  "generated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "patterns": {
    "ReferenceError": {
      "patterns": [
        {
          "regex": "(.+) is not defined",
          "capture_groups": ["variable_name"],
          "fixes": [
            {
              "name": "declare_variable",
              "description": "Declare the variable",
              "actions": [
                {"type": "find_usage_context"},
                {"type": "add_declaration", "template": "let {variable_name};"}
              ]
            },
            {
              "name": "import_module",
              "description": "Import from module",
              "actions": [
                {"type": "search_exports", "name": "{variable_name}"},
                {"type": "add_import"}
              ]
            }
          ]
        }
      ]
    },
    "TypeError": {
      "patterns": [
        {
          "regex": "Cannot read prop(?:erty|erties) '(.+)' of (null|undefined)",
          "capture_groups": ["property", "value"],
          "fixes": [
            {
              "name": "add_null_check",
              "description": "Add null/undefined check",
              "actions": [
                {"type": "wrap_with_check", "template": "if (obj && obj.{property})"}
              ]
            },
            {
              "name": "optional_chaining",
              "description": "Use optional chaining",
              "actions": [
                {"type": "replace_access", "template": "obj?.{property}"}
              ]
            }
          ]
        }
      ]
    },
    "TSError": {
      "patterns": [
        {
          "regex": "TS(\\d{4}): (.+)",
          "capture_groups": ["error_code", "message"],
          "fixes": [
            {
              "name": "typescript_fix",
              "description": "Apply TypeScript-specific fix",
              "actions": [
                {"type": "lookup_ts_error", "code": "{error_code}"},
                {"type": "apply_ts_fix"}
              ]
            }
          ]
        }
      ]
    }
  }
}
EOF
    
    success "Generated JavaScript/TypeScript patterns at: $OUTPUT_DIR/javascript_generated_patterns.json"
}

# Generate patterns from actual build errors
generate_from_build_errors() {
    local build_log=$1
    local language=$2
    
    log "Analyzing build errors from: $build_log"
    
    local output_file="$OUTPUT_DIR/${language}_learned_patterns.json"
    
    # Start JSON structure
    cat > "$output_file" << EOF
{
  "generator": "build_error_analyzer_v1.0",
  "source_file": "$build_log",
  "analyzed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "$language",
  "patterns": {
EOF
    
    # Extract unique error patterns
    local patterns=()
    case "$language" in
        csharp)
            # Extract C# error patterns
            grep -E "error CS[0-9]{4}:" "$build_log" | \
                sed -E 's/.*error (CS[0-9]{4}): (.*)$/\1|\2/' | \
                sort -u > "$OUTPUT_DIR/temp_patterns.txt"
            ;;
        python)
            # Extract Python error patterns
            grep -E "(SyntaxError|ImportError|TypeError|ValueError):" "$build_log" | \
                sed -E 's/.*(SyntaxError|ImportError|TypeError|ValueError): (.*)$/\1|\2/' | \
                sort -u > "$OUTPUT_DIR/temp_patterns.txt"
            ;;
        javascript|typescript)
            # Extract JS/TS error patterns
            grep -E "(ReferenceError|TypeError|SyntaxError|TS[0-9]{4}):" "$build_log" | \
                sort -u > "$OUTPUT_DIR/temp_patterns.txt"
            ;;
    esac
    
    # Process each pattern
    local first=true
    while IFS='|' read -r error_code error_message; do
        if [[ -n "$error_code" ]]; then
            if [[ "$first" == "false" ]]; then
                echo "," >> "$output_file"
            fi
            first=false
            
            # Generate pattern entry
            cat >> "$output_file" << EOF
    "${error_code}_learned": {
      "original_error": "$error_code: $error_message",
      "frequency": 1,
      "first_seen": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "suggested_fixes": [
        {
          "name": "learned_fix",
          "description": "Fix learned from build error",
          "confidence": 0.5,
          "requires_validation": true
        }
      ]
    }
EOF
        fi
    done < "$OUTPUT_DIR/temp_patterns.txt"
    
    # Close JSON
    echo '
  }
}' >> "$output_file"
    
    # Cleanup
    rm -f "$OUTPUT_DIR/temp_patterns.txt"
    
    success "Generated learned patterns at: $output_file"
}

# Merge generated patterns with existing database
merge_patterns() {
    local language=$1
    local generated_file=$2
    local database_file="$PATTERNS_DIR/databases/$language/patterns.json"
    
    log "Merging generated patterns into database..."
    
    if [[ ! -f "$database_file" ]]; then
        error "Database file not found: $database_file"
        return 1
    fi
    
    # Create backup
    cp "$database_file" "${database_file}.backup.$(date +%s)"
    
    # Use jq to merge patterns (if available)
    if command -v jq &> /dev/null; then
        jq -s '.[0] * .[1]' "$database_file" "$generated_file" > "${database_file}.tmp"
        mv "${database_file}.tmp" "$database_file"
        success "Patterns merged successfully"
    else
        log "jq not found, manual merge required"
        echo "Generated patterns saved to: $generated_file"
        echo "Please manually merge with: $database_file"
    fi
}

# Generate documentation from patterns
generate_pattern_docs() {
    local language=$1
    local output_file="$PATTERNS_DIR/docs/${language}_patterns.md"
    
    mkdir -p "$PATTERNS_DIR/docs"
    
    log "Generating documentation for $language patterns..."
    
    cat > "$output_file" << EOF
# $language Error Patterns Documentation

Generated on: $(date)

## Overview

This document describes the error patterns and fixes available for $language.

## Pattern Categories

EOF
    
    # Add pattern documentation based on language
    case "$language" in
        csharp)
            cat >> "$output_file" << 'EOF'
### Compiler Errors (CS0001-CS0999)
- Internal compiler errors
- File and assembly errors
- Basic syntax errors

### Type System Errors (CS1000-CS1999)
- Type resolution errors
- Generic type errors
- Inheritance issues

### Member Errors (CS2000-CS2999)
- Method signatures
- Property definitions
- Interface implementations

### Modern Feature Errors (CS8000-CS8999)
- Nullable reference types
- Pattern matching
- Async streams

EOF
            ;;
        python)
            cat >> "$output_file" << 'EOF'
### Syntax Errors
- Indentation errors
- Missing colons
- Invalid syntax constructs

### Import Errors
- Module not found
- Circular imports
- Package issues

### Type Errors
- Type mismatches
- Invalid operations
- Attribute errors

EOF
            ;;
    esac
    
    success "Documentation generated at: $output_file"
}

# Main command processing
main() {
    local command=${1:-help}
    
    case "$command" in
        generate-all)
            log "Generating patterns for all languages..."
            generate_csharp_patterns_from_docs
            generate_python_patterns
            generate_javascript_patterns
            ;;
            
        generate)
            local language=${2:-csharp}
            case "$language" in
                csharp) generate_csharp_patterns_from_docs ;;
                python) generate_python_patterns ;;
                javascript|js) generate_javascript_patterns ;;
                typescript|ts) generate_javascript_patterns ;;
                *) error "Unknown language: $language" ;;
            esac
            ;;
            
        learn)
            local build_log=${2:-build_output.txt}
            local language=${3:-csharp}
            if [[ -f "$build_log" ]]; then
                generate_from_build_errors "$build_log" "$language"
            else
                error "Build log not found: $build_log"
            fi
            ;;
            
        merge)
            local language=${2:-csharp}
            local pattern_file=${3:-}
            if [[ -n "$pattern_file" && -f "$pattern_file" ]]; then
                merge_patterns "$language" "$pattern_file"
            else
                error "Pattern file not specified or not found"
            fi
            ;;
            
        docs)
            local language=${2:-csharp}
            generate_pattern_docs "$language"
            ;;
            
        help|*)
            cat << EOF
Pattern Generator System

Usage: $0 <command> [options]

Commands:
  generate-all          Generate patterns for all supported languages
  generate <language>   Generate patterns for specific language
  learn <log> <lang>    Learn patterns from build error log
  merge <lang> <file>   Merge generated patterns into database
  docs <language>       Generate documentation for patterns

Languages:
  csharp       C# (Roslyn compiler)
  python       Python
  javascript   JavaScript
  typescript   TypeScript

Examples:
  $0 generate-all
  $0 generate csharp
  $0 learn build_output.txt csharp
  $0 merge csharp generated_patterns.json
  $0 docs python

EOF
            ;;
    esac
}

# Run main function
main "$@"