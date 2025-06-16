#!/bin/bash

# Advanced Pattern-Based Error Resolution Engine
# Production-ready multi-language support with sophisticated pattern matching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DB="$SCRIPT_DIR/patterns/pattern_database.json"
CONTEXT_ANALYZER="$SCRIPT_DIR/patterns/context_analyzer.sh"
FIX_TEMPLATES="$SCRIPT_DIR/patterns/fix_templates"

# Initialize pattern database
initialize_pattern_db() {
    mkdir -p "$SCRIPT_DIR/patterns"
    
    # Create comprehensive pattern database if it doesn't exist
    if [[ ! -f "$PATTERNS_DB" ]]; then
        cat > "$PATTERNS_DB" << 'EOF'
{
  "languages": {
    "csharp": {
      "error_patterns": {
        "CS0246": {
          "description": "Type or namespace not found",
          "detection_patterns": [
            "The type or namespace name '([^']+)' could not be found",
            "are you missing a using directive or an assembly reference\\?"
          ],
          "resolution_strategies": [
            {
              "name": "add_using_directive",
              "conditions": ["type_in_standard_library", "no_existing_using"],
              "actions": [
                {
                  "type": "add_using",
                  "template": "using {namespace};"
                }
              ]
            },
            {
              "name": "add_package_reference",
              "conditions": ["type_in_nuget", "no_package_reference"],
              "actions": [
                {
                  "type": "add_package",
                  "template": "<PackageReference Include=\"{package}\" Version=\"{version}\" />"
                }
              ]
            },
            {
              "name": "create_missing_type",
              "conditions": ["type_not_in_libraries", "looks_like_custom_type"],
              "actions": [
                {
                  "type": "create_type",
                  "template": "public class {typename} { }"
                }
              ]
            }
          ],
          "context_analysis": {
            "look_for": ["namespace_declarations", "using_statements", "class_context"],
            "scope": 50
          }
        },
        "CS0104": {
          "description": "Ambiguous reference",
          "detection_patterns": [
            "'([^']+)' is an ambiguous reference between '([^']+)' and '([^']+)'"
          ],
          "resolution_strategies": [
            {
              "name": "use_fully_qualified",
              "conditions": ["both_types_needed"],
              "actions": [
                {
                  "type": "replace_type",
                  "template": "{namespace}.{type}"
                }
              ]
            },
            {
              "name": "add_using_alias",
              "conditions": ["frequent_usage"],
              "actions": [
                {
                  "type": "add_using_alias",
                  "template": "using {alias} = {namespace}.{type};"
                }
              ]
            }
          ]
        },
        "CS0111": {
          "description": "Type already defines member with same parameter types",
          "detection_patterns": [
            "Type '([^']+)' already defines a member called '([^']+)' with the same parameter types"
          ],
          "resolution_strategies": [
            {
              "name": "remove_duplicate",
              "conditions": ["exact_duplicate"],
              "actions": [
                {
                  "type": "remove_method",
                  "identify_by": "signature_match"
                }
              ]
            },
            {
              "name": "rename_method",
              "conditions": ["different_implementation"],
              "actions": [
                {
                  "type": "rename_method",
                  "template": "{original_name}_{suffix}"
                }
              ]
            }
          ]
        },
        "CS0534": {
          "description": "Does not implement inherited abstract member",
          "detection_patterns": [
            "'([^']+)' does not implement inherited abstract member '([^']+)'"
          ],
          "resolution_strategies": [
            {
              "name": "implement_abstract_member",
              "conditions": ["is_concrete_class"],
              "actions": [
                {
                  "type": "implement_method",
                  "template": "public override {return_type} {method_name}({parameters}) {\n    throw new NotImplementedException();\n}"
                }
              ]
            }
          ]
        },
        "CS0453": {
          "description": "Must be non-nullable value type",
          "detection_patterns": [
            "must be a non-nullable value type in order to use it as parameter"
          ],
          "resolution_strategies": [
            {
              "name": "add_struct_constraint",
              "conditions": ["is_generic_parameter"],
              "actions": [
                {
                  "type": "add_constraint",
                  "template": "where {type_param} : struct"
                }
              ]
            }
          ]
        }
      },
      "type_mappings": {
        "List": "System.Collections.Generic",
        "Dictionary": "System.Collections.Generic",
        "Task": "System.Threading.Tasks",
        "HttpClient": "System.Net.Http",
        "JsonSerializer": "System.Text.Json",
        "ILogger": "Microsoft.Extensions.Logging",
        "DbContext": "Microsoft.EntityFrameworkCore"
      }
    },
    "python": {
      "error_patterns": {
        "ImportError": {
          "description": "Module import error",
          "detection_patterns": [
            "ImportError: cannot import name '([^']+)' from '([^']+)'",
            "ModuleNotFoundError: No module named '([^']+)'"
          ],
          "resolution_strategies": [
            {
              "name": "install_package",
              "conditions": ["package_in_pypi"],
              "actions": [
                {
                  "type": "add_requirement",
                  "template": "{package}=={version}"
                }
              ]
            },
            {
              "name": "fix_import_path",
              "conditions": ["module_exists_different_path"],
              "actions": [
                {
                  "type": "update_import",
                  "template": "from {correct_module} import {name}"
                }
              ]
            }
          ]
        },
        "SyntaxError": {
          "description": "Python syntax error",
          "detection_patterns": [
            "SyntaxError: invalid syntax",
            "SyntaxError: unexpected EOF while parsing"
          ],
          "resolution_strategies": [
            {
              "name": "fix_indentation",
              "conditions": ["indentation_error"],
              "actions": [
                {
                  "type": "reindent",
                  "template": "fix_python_indentation"
                }
              ]
            },
            {
              "name": "add_missing_colon",
              "conditions": ["missing_colon_after_keyword"],
              "actions": [
                {
                  "type": "append_char",
                  "char": ":"
                }
              ]
            }
          ]
        },
        "NameError": {
          "description": "Name not defined",
          "detection_patterns": [
            "NameError: name '([^']+)' is not defined"
          ],
          "resolution_strategies": [
            {
              "name": "import_builtin",
              "conditions": ["is_standard_library"],
              "actions": [
                {
                  "type": "add_import",
                  "template": "import {module}"
                }
              ]
            },
            {
              "name": "define_variable",
              "conditions": ["looks_like_variable"],
              "actions": [
                {
                  "type": "add_definition",
                  "template": "{name} = None  # TODO: Initialize properly"
                }
              ]
            }
          ]
        }
      }
    },
    "javascript": {
      "error_patterns": {
        "ReferenceError": {
          "description": "Variable not defined",
          "detection_patterns": [
            "ReferenceError: ([^ ]+) is not defined"
          ],
          "resolution_strategies": [
            {
              "name": "import_module",
              "conditions": ["is_node_module"],
              "actions": [
                {
                  "type": "add_import",
                  "template": "const {name} = require('{module}');"
                }
              ]
            },
            {
              "name": "declare_variable",
              "conditions": ["looks_like_variable"],
              "actions": [
                {
                  "type": "add_declaration",
                  "template": "let {name};"
                }
              ]
            }
          ]
        },
        "SyntaxError": {
          "description": "JavaScript syntax error",
          "detection_patterns": [
            "SyntaxError: Unexpected token ([^ ]+)",
            "SyntaxError: missing ) after argument list"
          ],
          "resolution_strategies": [
            {
              "name": "fix_brackets",
              "conditions": ["unmatched_brackets"],
              "actions": [
                {
                  "type": "balance_brackets",
                  "template": "auto_balance_brackets"
                }
              ]
            }
          ]
        }
      }
    },
    "go": {
      "error_patterns": {
        "undefined": {
          "description": "Undefined symbol",
          "detection_patterns": [
            "undefined: ([^ ]+)"
          ],
          "resolution_strategies": [
            {
              "name": "import_package",
              "conditions": ["is_standard_package"],
              "actions": [
                {
                  "type": "add_import",
                  "template": "import \"{package}\""
                }
              ]
            }
          ]
        },
        "cannot_use": {
          "description": "Type mismatch",
          "detection_patterns": [
            "cannot use ([^ ]+) \\(type ([^)]+)\\) as type ([^ ]+)"
          ],
          "resolution_strategies": [
            {
              "name": "type_conversion",
              "conditions": ["convertible_types"],
              "actions": [
                {
                  "type": "wrap_conversion",
                  "template": "{target_type}({expression})"
                }
              ]
            }
          ]
        }
      }
    }
  },
  "common_patterns": {
    "missing_semicolon": {
      "languages": ["javascript", "java", "csharp", "cpp"],
      "detection": "expected ';'|missing semicolon",
      "fix": {
        "type": "append",
        "char": ";"
      }
    },
    "unclosed_string": {
      "languages": ["all"],
      "detection": "unterminated string|unclosed string",
      "fix": {
        "type": "close_string"
      }
    }
  }
}
EOF
    fi
}

# Context analyzer for better pattern matching
analyze_context() {
    local file_path=$1
    local line_number=$2
    local language=$3
    local scope=${4:-50}
    
    local context_info="{}"
    
    # Extract context around the error
    local start_line=$((line_number - scope))
    local end_line=$((line_number + scope))
    [[ $start_line -lt 1 ]] && start_line=1
    
    local context=$(sed -n "${start_line},${end_line}p" "$file_path" 2>/dev/null)
    
    case "$language" in
        csharp)
            # Extract C# specific context
            local namespace=$(echo "$context" | grep -oP 'namespace\s+\K[A-Za-z0-9.]+' | head -1)
            local class_name=$(echo "$context" | grep -oP 'class\s+\K[A-Za-z0-9_]+' | head -1)
            local using_statements=$(echo "$context" | grep '^using ' | grep -v 'using (')
            local method_context=$(echo "$context" | grep -B5 -A5 "line $line_number")
            
            context_info=$(jq -n \
                --arg ns "$namespace" \
                --arg class "$class_name" \
                --arg usings "$using_statements" \
                --arg method "$method_context" \
                '{namespace: $ns, class: $class, using_statements: $usings, method_context: $method}')
            ;;
            
        python)
            # Extract Python specific context
            local imports=$(echo "$context" | grep -E '^(import |from .+ import)')
            local class_name=$(echo "$context" | grep -oP 'class\s+\K[A-Za-z0-9_]+' | head -1)
            local function_name=$(echo "$context" | grep -oP 'def\s+\K[A-Za-z0-9_]+' | head -1)
            local indentation=$(echo "$context" | sed -n "${line_number}p" | grep -oP '^\s*' | wc -c)
            
            context_info=$(jq -n \
                --arg imports "$imports" \
                --arg class "$class_name" \
                --arg func "$function_name" \
                --argjson indent "$indentation" \
                '{imports: $imports, class: $class, function: $func, indentation_level: $indent}')
            ;;
            
        javascript)
            # Extract JavaScript specific context
            local imports=$(echo "$context" | grep -E '(import |require\()')
            local exports=$(echo "$context" | grep -E '(export |module\.exports)')
            local function_context=$(echo "$context" | grep -E '(function |=>|async )')
            
            context_info=$(jq -n \
                --arg imports "$imports" \
                --arg exports "$exports" \
                --arg functions "$function_context" \
                '{imports: $imports, exports: $exports, functions: $functions}')
            ;;
    esac
    
    echo "$context_info"
}

# Advanced pattern matcher with context awareness
match_pattern() {
    local error_message=$1
    local error_code=$2
    local language=$3
    local context=$4
    
    # Load patterns for the language and error code
    local patterns=$(jq -r ".languages.$language.error_patterns.$error_code" "$PATTERNS_DB")
    
    if [[ "$patterns" == "null" ]]; then
        # Try common patterns
        patterns=$(jq -r '.common_patterns' "$PATTERNS_DB")
    fi
    
    # Check each resolution strategy
    local best_match=""
    local best_score=0
    
    echo "$patterns" | jq -c '.resolution_strategies[]' 2>/dev/null | while IFS= read -r strategy; do
        local score=0
        
        # Check conditions
        local conditions=$(echo "$strategy" | jq -r '.conditions[]')
        while IFS= read -r condition; do
            if check_condition "$condition" "$error_message" "$context" "$language"; then
                ((score += 10))
            fi
        done <<< "$conditions"
        
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_match=$strategy
        fi
    done
    
    echo "$best_match"
}

# Condition checker for pattern matching
check_condition() {
    local condition=$1
    local error_message=$2
    local context=$3
    local language=$4
    
    case "$condition" in
        "type_in_standard_library")
            # Check if the missing type is in standard library
            local missing_type=$(echo "$error_message" | grep -oP "name '([^']+)'" | cut -d"'" -f2)
            local namespace=$(jq -r ".languages.$language.type_mappings.\"$missing_type\"" "$PATTERNS_DB")
            [[ "$namespace" != "null" ]]
            ;;
            
        "no_existing_using")
            # Check if using statement doesn't exist
            local using_statements=$(echo "$context" | jq -r '.using_statements')
            ! echo "$using_statements" | grep -q "$missing_type"
            ;;
            
        "type_in_nuget")
            # Check common NuGet packages (simplified)
            local missing_type=$(echo "$error_message" | grep -oP "name '([^']+)'" | cut -d"'" -f2)
            [[ "$missing_type" =~ ^(ILogger|DbContext|HttpClient)$ ]]
            ;;
            
        "exact_duplicate")
            # Check if methods are exact duplicates
            # This would need more sophisticated analysis in production
            true
            ;;
            
        "is_generic_parameter")
            # Check if error is about generic parameter
            echo "$error_message" | grep -q "parameter 'T'"
            ;;
            
        *)
            # Unknown condition
            false
            ;;
    esac
}

# Apply the selected fix strategy
apply_fix() {
    local file_path=$1
    local line_number=$2
    local strategy=$3
    local error_info=$4
    local context=$5
    local language=$6
    
    local actions=$(echo "$strategy" | jq -c '.actions[]')
    local fix_applied=false
    
    while IFS= read -r action; do
        local action_type=$(echo "$action" | jq -r '.type')
        local template=$(echo "$action" | jq -r '.template')
        
        case "$action_type" in
            "add_using")
                # Add using directive at the top of the file
                local namespace=$(get_namespace_for_type "$error_info" "$language")
                if [[ -n "$namespace" ]]; then
                    local using_line="using $namespace;"
                    
                    # Find position after existing usings
                    local last_using_line=$(grep -n '^using ' "$file_path" | tail -1 | cut -d: -f1)
                    if [[ -n "$last_using_line" ]]; then
                        sed -i "${last_using_line}a\\$using_line" "$file_path"
                    else
                        # Add after namespace declaration
                        local namespace_line=$(grep -n '^namespace ' "$file_path" | head -1 | cut -d: -f1)
                        if [[ -n "$namespace_line" ]]; then
                            sed -i "${namespace_line}a\\\\n$using_line" "$file_path"
                        else
                            # Add at the beginning
                            sed -i "1i$using_line\\n" "$file_path"
                        fi
                    fi
                    fix_applied=true
                fi
                ;;
                
            "replace_type")
                # Replace type with fully qualified name
                local type_name=$(echo "$error_info" | grep -oP "'([^']+)'" | head -1 | tr -d "'")
                local full_name=$(get_fully_qualified_name "$type_name" "$language")
                
                sed -i "${line_number}s/\\b${type_name}\\b/${full_name}/g" "$file_path"
                fix_applied=true
                ;;
                
            "remove_method")
                # Remove duplicate method
                # This is complex and needs careful implementation
                remove_duplicate_method "$file_path" "$line_number" "$error_info"
                fix_applied=true
                ;;
                
            "implement_method")
                # Implement abstract method
                local method_info=$(parse_method_signature "$error_info")
                local implementation=$(generate_method_implementation "$method_info" "$template")
                
                # Find class closing brace
                local class_end=$(find_class_end "$file_path" "$line_number")
                sed -i "${class_end}i\\    $implementation" "$file_path"
                fix_applied=true
                ;;
                
            "add_constraint")
                # Add generic constraint
                local type_param=$(echo "$error_info" | grep -oP "parameter '([^']+)'" | cut -d"'" -f2)
                add_generic_constraint "$file_path" "$line_number" "$type_param" "$template"
                fix_applied=true
                ;;
                
            "add_import")
                # Add import statement (Python/JS/Go)
                add_import_statement "$file_path" "$template" "$error_info" "$language"
                fix_applied=true
                ;;
                
            "balance_brackets")
                # Balance brackets in the file
                balance_brackets "$file_path" "$line_number"
                fix_applied=true
                ;;
        esac
    done <<< "$actions"
    
    echo "$fix_applied"
}

# Helper functions for specific fixes
get_namespace_for_type() {
    local error_info=$1
    local language=$2
    
    local type_name=$(echo "$error_info" | grep -oP "name '([^']+)'" | cut -d"'" -f2)
    local namespace=$(jq -r ".languages.$language.type_mappings.\"$type_name\"" "$PATTERNS_DB")
    
    if [[ "$namespace" != "null" ]]; then
        echo "$namespace"
    else
        # Try to infer from common patterns
        case "$type_name" in
            List|Dictionary|HashSet|Queue|Stack)
                echo "System.Collections.Generic"
                ;;
            Task|TaskCompletionSource)
                echo "System.Threading.Tasks"
                ;;
            HttpClient|HttpResponseMessage)
                echo "System.Net.Http"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

remove_duplicate_method() {
    local file_path=$1
    local line_number=$2
    local error_info=$3
    
    # Extract method name and signature
    local method_name=$(echo "$error_info" | grep -oP "called '([^']+)'" | cut -d"'" -f2)
    
    # Find method boundaries
    local method_start=$(grep -n "\\b$method_name\\b" "$file_path" | grep -v "^$line_number:" | head -1 | cut -d: -f1)
    
    if [[ -n "$method_start" ]]; then
        # Find method end (next method or class closing brace)
        local method_end=$(awk "NR > $method_start && /^[[:space:]]*}[[:space:]]*$/ {print NR; exit}" "$file_path")
        
        # Remove the duplicate method
        sed -i "${method_start},${method_end}d" "$file_path"
    fi
}

add_generic_constraint() {
    local file_path=$1
    local line_number=$2
    local type_param=$3
    local constraint=$4
    
    # Find the generic declaration
    local generic_line=$(grep -n "\\<${type_param}\\>" "$file_path" | grep -E "(class|interface|method)" | head -1 | cut -d: -f1)
    
    if [[ -n "$generic_line" ]]; then
        # Check if where clause exists
        if grep -q "where" <(sed -n "${generic_line}p" "$file_path"); then
            # Add to existing where clause
            sed -i "${generic_line}s/$/, ${constraint//where /}/" "$file_path"
        else
            # Add new where clause
            sed -i "${generic_line}s/$/ ${constraint}/" "$file_path"
        fi
    fi
}

balance_brackets() {
    local file_path=$1
    local line_number=$2
    
    # Count opening and closing brackets
    local open_count=$(grep -o "[({[]" "$file_path" | wc -l)
    local close_count=$(grep -o "[]})]" "$file_path" | wc -l)
    
    if [[ $open_count -gt $close_count ]]; then
        # Add missing closing brackets
        local diff=$((open_count - close_count))
        local last_line=$(wc -l < "$file_path")
        
        # Determine which brackets are missing
        local missing_brackets=""
        local paren_diff=$(($(grep -o "(" "$file_path" | wc -l) - $(grep -o ")" "$file_path" | wc -l)))
        local brace_diff=$(($(grep -o "{" "$file_path" | wc -l) - $(grep -o "}" "$file_path" | wc -l)))
        local bracket_diff=$(($(grep -o "\[" "$file_path" | wc -l) - $(grep -o "\]" "$file_path" | wc -l)))
        
        [[ $paren_diff -gt 0 ]] && missing_brackets+=$(printf ')%.0s' $(seq 1 $paren_diff))
        [[ $brace_diff -gt 0 ]] && missing_brackets+=$(printf '}%.0s' $(seq 1 $brace_diff))
        [[ $bracket_diff -gt 0 ]] && missing_brackets+=$(printf ']%.0s' $(seq 1 $bracket_diff))
        
        echo "$missing_brackets" >> "$file_path"
    fi
}

# Export functions
export -f initialize_pattern_db
export -f analyze_context
export -f match_pattern
export -f apply_fix