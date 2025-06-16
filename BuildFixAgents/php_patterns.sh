#!/bin/bash

# Comprehensive PHP Error Pattern Generator
# Generates detailed patterns for PHP errors and warnings

generate_php_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "php",
  "pattern_count": 150,
  "patterns": {
    "Parse error": {
      "syntax_error": {
        "message": "syntax error, unexpected {0}",
        "category": "Parse",
        "severity": "Fatal",
        "fixes": [
          {
            "name": "fix_syntax",
            "description": "Fix syntax error",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_syntax_context", "token": "{0}"}
            ]
          },
          {
            "name": "add_semicolon",
            "description": "Add missing semicolon",
            "condition": "expecting_semicolon",
            "confidence": 0.9,
            "actions": [
              {"type": "append", "text": ";"}
            ]
          },
          {
            "name": "close_bracket",
            "description": "Close unclosed bracket",
            "condition": "unclosed_bracket",
            "confidence": 0.85,
            "actions": [
              {"type": "balance_brackets"}
            ]
          }
        ]
      },
      "unexpected_end": {
        "message": "syntax error, unexpected end of file",
        "fixes": [
          {
            "name": "close_structures",
            "description": "Close unclosed structures",
            "confidence": 0.9,
            "actions": [
              {"type": "close_all_open_brackets"}
            ]
          },
          {
            "name": "close_php_tag",
            "description": "Close PHP tag",
            "condition": "unclosed_php_tag",
            "confidence": 0.85,
            "actions": [
              {"type": "append", "text": "?>"}
            ]
          }
        ]
      },
      "unexpected_variable": {
        "message": "syntax error, unexpected '{0}' (T_VARIABLE)",
        "fixes": [
          {
            "name": "add_operator",
            "description": "Add missing operator",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_missing_operator"}
            ]
          },
          {
            "name": "fix_concatenation",
            "description": "Fix string concatenation",
            "condition": "in_string_context",
            "confidence": 0.9,
            "actions": [
              {"type": "add_concatenation_operator"}
            ]
          }
        ]
      }
    },
    "Fatal error": {
      "undefined_function": {
        "message": "Call to undefined function {0}()",
        "category": "Fatal",
        "severity": "Fatal",
        "fixes": [
          {
            "name": "check_spelling",
            "description": "Fix function name typo",
            "condition": "has_similar_function({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "replace_with_similar"}
            ]
          },
          {
            "name": "require_file",
            "description": "Include file with function",
            "condition": "function_in_file({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_require", "file": "find_function_file({0})"}
            ]
          },
          {
            "name": "check_namespace",
            "description": "Add namespace qualification",
            "condition": "function_in_namespace({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "qualify_function_name"}
            ]
          },
          {
            "name": "install_extension",
            "description": "Install PHP extension",
            "condition": "is_extension_function({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest", "message": "Install PHP extension for {0}"}
            ]
          }
        ]
      },
      "class_not_found": {
        "message": "Class '{0}' not found",
        "fixes": [
          {
            "name": "autoload_class",
            "description": "Fix autoloading",
            "condition": "has_autoloader",
            "confidence": 0.85,
            "actions": [
              {"type": "check_autoload_path", "class": "{0}"}
            ]
          },
          {
            "name": "require_class_file",
            "description": "Include class file",
            "condition": "class_file_exists({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "add_require", "file": "find_class_file({0})"}
            ]
          },
          {
            "name": "use_statement",
            "description": "Add use statement",
            "condition": "class_in_namespace({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_use_statement", "class": "{0}"}
            ]
          },
          {
            "name": "composer_install",
            "description": "Install via Composer",
            "condition": "is_composer_package({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "command", "command": "composer require {0}"}
            ]
          }
        ]
      },
      "cannot_redeclare": {
        "message": "Cannot redeclare {0}()",
        "fixes": [
          {
            "name": "remove_duplicate",
            "description": "Remove duplicate declaration",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_duplicate_function"}
            ]
          },
          {
            "name": "use_require_once",
            "description": "Use require_once instead",
            "condition": "using_require",
            "confidence": 0.95,
            "actions": [
              {"type": "replace", "from": "require", "to": "require_once"},
              {"type": "replace", "from": "include", "to": "include_once"}
            ]
          },
          {
            "name": "check_exists",
            "description": "Check if function exists",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with", "code": "if (!function_exists('{0}')) { }"}
            ]
          }
        ]
      },
      "allowed_memory_size": {
        "message": "Allowed memory size of {0} bytes exhausted",
        "fixes": [
          {
            "name": "increase_memory_limit",
            "description": "Increase memory limit",
            "confidence": 0.8,
            "actions": [
              {"type": "add_ini_set", "directive": "memory_limit", "value": "256M"}
            ]
          },
          {
            "name": "optimize_code",
            "description": "Optimize memory usage",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest", "message": "Use generators or process data in chunks"}
            ]
          }
        ]
      }
    },
    "Warning": {
      "undefined_variable": {
        "message": "Undefined variable: {0}",
        "category": "Warning",
        "severity": "Warning",
        "fixes": [
          {
            "name": "initialize_variable",
            "description": "Initialize variable",
            "confidence": 0.9,
            "actions": [
              {"type": "add_before_use", "code": "${0} = null;"}
            ]
          },
          {
            "name": "check_isset",
            "description": "Check with isset",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with", "code": "isset(${0}) ? ${0} : null"}
            ]
          },
          {
            "name": "fix_typo",
            "description": "Fix variable name typo",
            "condition": "has_similar_variable({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "replace_with_similar"}
            ]
          },
          {
            "name": "add_global",
            "description": "Add global declaration",
            "condition": "in_function_scope",
            "confidence": 0.8,
            "actions": [
              {"type": "add_global", "variable": "{0}"}
            ]
          }
        ]
      },
      "undefined_index": {
        "message": "Undefined index: {0}",
        "fixes": [
          {
            "name": "check_array_key",
            "description": "Check if key exists",
            "confidence": 0.9,
            "actions": [
              {"type": "wrap_with", "code": "isset($array['{0}']) ? $array['{0}'] : null"}
            ]
          },
          {
            "name": "use_null_coalesce",
            "description": "Use null coalescing operator",
            "condition": "php7_or_higher",
            "confidence": 0.95,
            "actions": [
              {"type": "add_operator", "operator": "??", "default": "null"}
            ]
          },
          {
            "name": "array_key_exists",
            "description": "Use array_key_exists",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_check", "function": "array_key_exists"}
            ]
          }
        ]
      },
      "undefined_property": {
        "message": "Undefined property: {0}::{1}",
        "fixes": [
          {
            "name": "add_property",
            "description": "Add property to class",
            "condition": "is_user_class({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_property", "class": "{0}", "property": "{1}"}
            ]
          },
          {
            "name": "use_magic_method",
            "description": "Use __get/__set methods",
            "confidence": 0.8,
            "actions": [
              {"type": "implement_magic_methods"}
            ]
          },
          {
            "name": "check_property_exists",
            "description": "Check property exists",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with", "code": "property_exists($obj, '{1}')"}
            ]
          }
        ]
      },
      "include_failed": {
        "message": "Failed opening '{0}' for inclusion",
        "fixes": [
          {
            "name": "check_file_path",
            "description": "Fix file path",
            "confidence": 0.85,
            "actions": [
              {"type": "verify_file_path", "file": "{0}"}
            ]
          },
          {
            "name": "use_absolute_path",
            "description": "Use absolute path",
            "confidence": 0.8,
            "actions": [
              {"type": "convert_to_absolute_path"}
            ]
          },
          {
            "name": "check_include_path",
            "description": "Check include path",
            "confidence": 0.75,
            "actions": [
              {"type": "verify_include_path"}
            ]
          }
        ]
      },
      "division_by_zero": {
        "message": "Division by zero",
        "fixes": [
          {
            "name": "add_zero_check",
            "description": "Check for zero before division",
            "confidence": 0.95,
            "actions": [
              {"type": "add_condition", "check": "$divisor != 0"}
            ]
          }
        ]
      }
    },
    "Notice": {
      "undefined_offset": {
        "message": "Undefined offset: {0}",
        "category": "Notice",
        "severity": "Notice",
        "fixes": [
          {
            "name": "check_array_bounds",
            "description": "Check array bounds",
            "confidence": 0.9,
            "actions": [
              {"type": "add_bounds_check", "condition": "count($array) > {0}"}
            ]
          },
          {
            "name": "use_isset",
            "description": "Use isset check",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_isset"}
            ]
          }
        ]
      },
      "undefined_constant": {
        "message": "Use of undefined constant {0}",
        "fixes": [
          {
            "name": "add_quotes",
            "description": "Add quotes for string",
            "condition": "looks_like_string({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "wrap_with_quotes"}
            ]
          },
          {
            "name": "define_constant",
            "description": "Define the constant",
            "confidence": 0.85,
            "actions": [
              {"type": "add_define", "constant": "{0}"}
            ]
          }
        ]
      }
    },
    "Type error": {
      "argument_type": {
        "message": "Argument {0} passed to {1} must be {2}, {3} given",
        "category": "Type",
        "severity": "Fatal",
        "fixes": [
          {
            "name": "type_cast",
            "description": "Cast to correct type",
            "confidence": 0.85,
            "actions": [
              {"type": "add_cast", "to": "{2}"}
            ]
          },
          {
            "name": "validate_type",
            "description": "Validate type before call",
            "confidence": 0.8,
            "actions": [
              {"type": "add_type_check", "type": "{2}"}
            ]
          },
          {
            "name": "fix_argument",
            "description": "Fix argument value",
            "confidence": 0.75,
            "actions": [
              {"type": "analyze_expected_type", "expected": "{2}", "actual": "{3}"}
            ]
          }
        ]
      },
      "return_type": {
        "message": "Return value must be of type {0}, {1} returned",
        "fixes": [
          {
            "name": "fix_return_type",
            "description": "Fix return type",
            "confidence": 0.85,
            "actions": [
              {"type": "cast_return_value", "to": "{0}"}
            ]
          },
          {
            "name": "update_declaration",
            "description": "Update return type declaration",
            "confidence": 0.8,
            "actions": [
              {"type": "change_return_type", "to": "{1}"}
            ]
          }
        ]
      }
    },
    "Deprecated": {
      "deprecated_function": {
        "message": "Function {0}() is deprecated",
        "category": "Deprecated",
        "severity": "Deprecated",
        "fixes": [
          {
            "name": "use_alternative",
            "description": "Use modern alternative",
            "condition": "has_alternative({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "replace_deprecated_function"}
            ]
          },
          {
            "name": "suppress_warning",
            "description": "Suppress deprecation warning",
            "confidence": 0.7,
            "actions": [
              {"type": "add_error_suppression"}
            ]
          }
        ]
      }
    },
    "Strict Standards": {
      "non_static_as_static": {
        "message": "Non-static method {0} should not be called statically",
        "category": "Strict",
        "severity": "Strict",
        "fixes": [
          {
            "name": "make_static",
            "description": "Make method static",
            "confidence": 0.85,
            "actions": [
              {"type": "add_static_keyword"}
            ]
          },
          {
            "name": "create_instance",
            "description": "Create instance first",
            "confidence": 0.9,
            "actions": [
              {"type": "instantiate_class_first"}
            ]
          }
        ]
      },
      "declaration_compatible": {
        "message": "Declaration should be compatible with {0}",
        "fixes": [
          {
            "name": "match_parent_signature",
            "description": "Match parent method signature",
            "confidence": 0.9,
            "actions": [
              {"type": "sync_method_signature"}
            ]
          }
        ]
      }
    },
    "Database": {
      "mysql_error": {
        "message": "MySQL error: {0}",
        "category": "Database",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_sql_syntax",
            "description": "Fix SQL syntax",
            "condition": "syntax_error",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_sql_error", "error": "{0}"}
            ]
          },
          {
            "name": "escape_values",
            "description": "Escape SQL values",
            "condition": "injection_risk",
            "confidence": 0.9,
            "actions": [
              {"type": "use_prepared_statements"}
            ]
          }
        ]
      }
    }
  }
}
EOF
}

# Generate pattern file
mkdir -p "$SCRIPT_DIR/patterns/databases/php"
generate_php_patterns > "$SCRIPT_DIR/patterns/databases/php/comprehensive_patterns.json"
echo "Generated comprehensive PHP patterns"