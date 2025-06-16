#!/bin/bash

# Comprehensive JavaScript/TypeScript Error Pattern Generator
# Generates detailed patterns for JS/TS errors

generate_javascript_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "javascript",
  "pattern_count": 250,
  "patterns": {
    "ReferenceError": {
      "not_defined": {
        "message": "{0} is not defined",
        "category": "Reference",
        "severity": "Error",
        "fixes": [
          {
            "name": "declare_variable",
            "description": "Declare the variable",
            "confidence": 0.9,
            "actions": [
              {"type": "add_declaration", "code": "let {0};", "position": "before_first_use"}
            ]
          },
          {
            "name": "import_module",
            "description": "Import from module",
            "condition": "is_module_export({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_import", "search": "{0}"}
            ]
          },
          {
            "name": "add_to_window",
            "description": "Check window object",
            "condition": "is_browser_global({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "prefix_with", "text": "window."}
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
            "name": "require_module",
            "description": "Require CommonJS module",
            "condition": "is_node_env",
            "confidence": 0.8,
            "actions": [
              {"type": "add_require", "module": "{0}"}
            ]
          }
        ]
      },
      "cannot_access_before_init": {
        "message": "Cannot access '{0}' before initialization",
        "fixes": [
          {
            "name": "move_declaration_up",
            "description": "Move declaration before use",
            "confidence": 0.95,
            "actions": [
              {"type": "reorder_declarations"}
            ]
          },
          {
            "name": "use_var_instead",
            "description": "Change const/let to var",
            "condition": "hoisting_needed",
            "confidence": 0.7,
            "actions": [
              {"type": "change_declaration", "to": "var"}
            ]
          }
        ]
      }
    },
    "TypeError": {
      "not_a_function": {
        "message": "{0} is not a function",
        "category": "Type",
        "severity": "Error",
        "fixes": [
          {
            "name": "remove_call",
            "description": "Remove function call",
            "confidence": 0.85,
            "actions": [
              {"type": "remove_parentheses"}
            ]
          },
          {
            "name": "check_method_name",
            "description": "Fix method name",
            "condition": "has_similar_method({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "fix_method_name"}
            ]
          },
          {
            "name": "add_optional_chaining",
            "description": "Add optional chaining",
            "condition": "might_be_undefined",
            "confidence": 0.8,
            "actions": [
              {"type": "add_optional_chain", "before": "("}
            ]
          },
          {
            "name": "check_import",
            "description": "Fix import statement",
            "condition": "is_imported({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_import", "for": "{0}"}
            ]
          }
        ]
      },
      "cannot_read_property": {
        "message": "Cannot read property '{0}' of undefined",
        "fixes": [
          {
            "name": "add_null_check",
            "description": "Add null/undefined check",
            "confidence": 0.95,
            "actions": [
              {"type": "wrap_with_check", "template": "if (obj) { }"}
            ]
          },
          {
            "name": "use_optional_chaining",
            "description": "Use optional chaining operator",
            "confidence": 0.9,
            "actions": [
              {"type": "replace_dot", "with": "?."}
            ]
          },
          {
            "name": "initialize_object",
            "description": "Initialize object",
            "confidence": 0.85,
            "actions": [
              {"type": "add_initialization", "code": "obj = obj || {};"}
            ]
          },
          {
            "name": "use_default_value",
            "description": "Use default value",
            "confidence": 0.8,
            "actions": [
              {"type": "add_default", "code": "|| defaultValue"}
            ]
          }
        ]
      },
      "cannot_read_properties_null": {
        "message": "Cannot read properties of null (reading '{0}')",
        "fixes": [
          {
            "name": "add_null_check",
            "description": "Add explicit null check",
            "confidence": 0.95,
            "actions": [
              {"type": "add_condition", "check": "!== null"}
            ]
          },
          {
            "name": "use_nullish_coalescing",
            "description": "Use nullish coalescing",
            "confidence": 0.9,
            "actions": [
              {"type": "add_operator", "op": "??", "default": "{}"}
            ]
          }
        ]
      },
      "not_iterable": {
        "message": "{0} is not iterable",
        "fixes": [
          {
            "name": "check_array",
            "description": "Ensure value is array",
            "confidence": 0.9,
            "actions": [
              {"type": "add_check", "code": "Array.isArray({0})"}
            ]
          },
          {
            "name": "convert_to_array",
            "description": "Convert to array",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with", "code": "Array.from({0})"}
            ]
          },
          {
            "name": "use_object_entries",
            "description": "Use Object.entries for objects",
            "condition": "is_object",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_with", "code": "Object.entries({0})"}
            ]
          }
        ]
      },
      "constructor_not_new": {
        "message": "Class constructor {0} cannot be invoked without 'new'",
        "fixes": [
          {
            "name": "add_new_keyword",
            "description": "Add 'new' keyword",
            "confidence": 0.95,
            "actions": [
              {"type": "prefix_with", "text": "new "}
            ]
          }
        ]
      }
    },
    "SyntaxError": {
      "unexpected_token": {
        "message": "Unexpected token {0}",
        "category": "Syntax",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_json_trailing_comma",
            "description": "Remove trailing comma",
            "condition": "is_json_context",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_trailing_comma"}
            ]
          },
          {
            "name": "add_missing_semicolon",
            "description": "Add missing semicolon",
            "condition": "missing_semicolon",
            "confidence": 0.85,
            "actions": [
              {"type": "add_semicolon"}
            ]
          },
          {
            "name": "fix_arrow_function",
            "description": "Fix arrow function syntax",
            "condition": "is_arrow_function",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_arrow_syntax"}
            ]
          },
          {
            "name": "balance_brackets",
            "description": "Balance brackets",
            "condition": "unbalanced_brackets",
            "confidence": 0.9,
            "actions": [
              {"type": "balance_brackets"}
            ]
          }
        ]
      },
      "missing_initializer": {
        "message": "Missing initializer in const declaration",
        "fixes": [
          {
            "name": "add_initializer",
            "description": "Add initial value",
            "confidence": 0.95,
            "actions": [
              {"type": "add_assignment", "value": "undefined"}
            ]
          },
          {
            "name": "change_to_let",
            "description": "Change const to let",
            "confidence": 0.9,
            "actions": [
              {"type": "replace", "from": "const", "to": "let"}
            ]
          }
        ]
      },
      "unexpected_end_of_input": {
        "message": "Unexpected end of input",
        "fixes": [
          {
            "name": "close_brackets",
            "description": "Close unclosed brackets",
            "confidence": 0.9,
            "actions": [
              {"type": "auto_close_brackets"}
            ]
          },
          {
            "name": "complete_statement",
            "description": "Complete incomplete statement",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_incomplete_statement"}
            ]
          }
        ]
      },
      "unexpected_reserved_word": {
        "message": "Unexpected reserved word",
        "fixes": [
          {
            "name": "rename_variable",
            "description": "Rename reserved word",
            "confidence": 0.95,
            "actions": [
              {"type": "rename_identifier", "suffix": "_var"}
            ]
          }
        ]
      },
      "unterminated_string": {
        "message": "Unterminated string literal",
        "fixes": [
          {
            "name": "close_string",
            "description": "Add closing quote",
            "confidence": 0.95,
            "actions": [
              {"type": "close_string_literal"}
            ]
          },
          {
            "name": "escape_quotes",
            "description": "Escape internal quotes",
            "condition": "has_unescaped_quotes",
            "confidence": 0.9,
            "actions": [
              {"type": "escape_quotes"}
            ]
          }
        ]
      }
    },
    "RangeError": {
      "invalid_array_length": {
        "message": "Invalid array length",
        "category": "Range",
        "severity": "Error",
        "fixes": [
          {
            "name": "validate_length",
            "description": "Validate array length",
            "confidence": 0.9,
            "actions": [
              {"type": "add_validation", "check": "length >= 0 && length <= Number.MAX_SAFE_INTEGER"}
            ]
          }
        ]
      },
      "maximum_call_stack": {
        "message": "Maximum call stack size exceeded",
        "fixes": [
          {
            "name": "check_recursion",
            "description": "Add recursion base case",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_recursion"},
              {"type": "add_base_case"}
            ]
          },
          {
            "name": "use_iteration",
            "description": "Convert to iterative",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest_iterative_approach"}
            ]
          },
          {
            "name": "use_settimeout",
            "description": "Break call stack with setTimeout",
            "condition": "async_safe",
            "confidence": 0.7,
            "actions": [
              {"type": "wrap_with_settimeout", "delay": 0}
            ]
          }
        ]
      }
    },
    "EvalError": {
      "eval_error": {
        "message": "EvalError",
        "category": "Eval",
        "severity": "Error",
        "fixes": [
          {
            "name": "avoid_eval",
            "description": "Replace eval with safer alternative",
            "confidence": 0.95,
            "actions": [
              {"type": "suggest_eval_alternative"}
            ]
          },
          {
            "name": "use_function_constructor",
            "description": "Use Function constructor",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_eval_with_function"}
            ]
          }
        ]
      }
    },
    "URIError": {
      "uri_malformed": {
        "message": "URI malformed",
        "category": "URI",
        "severity": "Error",
        "fixes": [
          {
            "name": "encode_uri_component",
            "description": "Properly encode URI component",
            "confidence": 0.9,
            "actions": [
              {"type": "wrap_with", "function": "encodeURIComponent"}
            ]
          },
          {
            "name": "validate_uri",
            "description": "Validate URI before use",
            "confidence": 0.85,
            "actions": [
              {"type": "add_uri_validation"}
            ]
          }
        ]
      }
    },
    "AggregateError": {
      "aggregate_error": {
        "message": "AggregateError",
        "category": "Aggregate",
        "severity": "Error",
        "fixes": [
          {
            "name": "handle_multiple_errors",
            "description": "Handle each error individually",
            "confidence": 0.85,
            "actions": [
              {"type": "iterate_errors"}
            ]
          }
        ]
      }
    },
    "InternalError": {
      "too_much_recursion": {
        "message": "too much recursion",
        "category": "Internal",
        "severity": "Error",
        "fixes": [
          {
            "name": "limit_recursion",
            "description": "Add recursion depth limit",
            "confidence": 0.85,
            "actions": [
              {"type": "add_depth_counter"},
              {"type": "add_depth_check"}
            ]
          }
        ]
      }
    },
    "Error": {
      "module_not_found": {
        "message": "Cannot find module '{0}'",
        "category": "Module",
        "severity": "Error",
        "fixes": [
          {
            "name": "npm_install",
            "description": "Install npm package",
            "condition": "is_npm_package({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "command", "command": "npm install {0}"}
            ]
          },
          {
            "name": "fix_import_path",
            "description": "Fix relative import path",
            "condition": "is_relative_path({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_relative_path", "module": "{0}"}
            ]
          },
          {
            "name": "add_file_extension",
            "description": "Add .js extension",
            "condition": "missing_extension",
            "confidence": 0.8,
            "actions": [
              {"type": "append", "text": ".js"}
            ]
          },
          {
            "name": "check_case_sensitivity",
            "description": "Fix module name case",
            "condition": "has_case_mismatch({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_module_case"}
            ]
          }
        ]
      },
      "exports_not_defined": {
        "message": "exports is not defined",
        "fixes": [
          {
            "name": "use_es_modules",
            "description": "Convert to ES modules",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_es_modules"}
            ]
          },
          {
            "name": "add_module_check",
            "description": "Add module environment check",
            "confidence": 0.8,
            "actions": [
              {"type": "add_check", "code": "typeof exports !== 'undefined'"}
            ]
          }
        ]
      },
      "require_not_defined": {
        "message": "require is not defined",
        "fixes": [
          {
            "name": "use_import",
            "description": "Convert require to import",
            "confidence": 0.9,
            "actions": [
              {"type": "convert_require_to_import"}
            ]
          },
          {
            "name": "add_script_type",
            "description": "Add type='module' to script",
            "condition": "is_browser_script",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest", "message": "Add type='module' to script tag"}
            ]
          }
        ]
      }
    },
    "Promise": {
      "unhandled_promise_rejection": {
        "message": "Unhandled promise rejection",
        "category": "Promise",
        "severity": "Warning",
        "fixes": [
          {
            "name": "add_catch",
            "description": "Add .catch() handler",
            "confidence": 0.95,
            "actions": [
              {"type": "append", "code": ".catch(err => console.error(err))"}
            ]
          },
          {
            "name": "use_try_catch",
            "description": "Wrap in try-catch with async/await",
            "condition": "in_async_function",
            "confidence": 0.9,
            "actions": [
              {"type": "wrap_with_try_catch"}
            ]
          }
        ]
      }
    },
    "ESLint": {
      "no_undef": {
        "message": "'{0}' is not defined",
        "category": "Linter",
        "severity": "Warning",
        "fixes": [
          {
            "name": "add_eslint_global",
            "description": "Add ESLint global comment",
            "confidence": 0.85,
            "actions": [
              {"type": "add_comment", "text": "/* global {0} */", "position": "file_top"}
            ]
          },
          {
            "name": "declare_variable",
            "description": "Declare the variable",
            "confidence": 0.9,
            "actions": [
              {"type": "add_declaration", "code": "const {0} = undefined;"}
            ]
          }
        ]
      },
      "no_unused_vars": {
        "message": "'{0}' is defined but never used",
        "fixes": [
          {
            "name": "remove_unused",
            "description": "Remove unused variable",
            "confidence": 0.8,
            "actions": [
              {"type": "remove_declaration", "var": "{0}"}
            ]
          },
          {
            "name": "add_underscore",
            "description": "Prefix with underscore",
            "confidence": 0.85,
            "actions": [
              {"type": "rename", "from": "{0}", "to": "_{0}"}
            ]
          }
        ]
      },
      "semi": {
        "message": "Missing semicolon",
        "fixes": [
          {
            "name": "add_semicolon",
            "description": "Add semicolon",
            "confidence": 0.95,
            "actions": [
              {"type": "append", "text": ";"}
            ]
          }
        ]
      },
      "quotes": {
        "message": "Strings must use {0}",
        "fixes": [
          {
            "name": "fix_quotes",
            "description": "Change quote style",
            "confidence": 0.95,
            "actions": [
              {"type": "change_quotes", "to": "{0}"}
            ]
          }
        ]
      }
    }
  },
  "typescript_patterns": {
    "TS2307": {
      "message": "Cannot find module '{0}' or its corresponding type declarations",
      "category": "Module",
      "severity": "Error",
      "fixes": [
        {
          "name": "install_types",
          "description": "Install @types package",
          "condition": "is_npm_package({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "command", "command": "npm install --save-dev @types/{0}"}
          ]
        },
        {
          "name": "declare_module",
          "description": "Declare module",
          "confidence": 0.8,
          "actions": [
            {"type": "create_declaration", "module": "{0}"}
          ]
        },
        {
          "name": "fix_tsconfig_paths",
          "description": "Update tsconfig paths",
          "condition": "has_path_mapping",
          "confidence": 0.85,
          "actions": [
            {"type": "update_tsconfig_paths"}
          ]
        }
      ]
    },
    "TS2322": {
      "message": "Type '{0}' is not assignable to type '{1}'",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_type_assertion",
          "description": "Add type assertion",
          "confidence": 0.8,
          "actions": [
            {"type": "add_assertion", "as": "{1}"}
          ]
        },
        {
          "name": "fix_type_annotation",
          "description": "Update type annotation",
          "confidence": 0.85,
          "actions": [
            {"type": "update_type", "to": "{0}"}
          ]
        },
        {
          "name": "add_type_guard",
          "description": "Add type guard",
          "condition": "union_type",
          "confidence": 0.8,
          "actions": [
            {"type": "add_type_guard"}
          ]
        }
      ]
    },
    "TS2339": {
      "message": "Property '{0}' does not exist on type '{1}'",
      "category": "Property",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_property",
          "description": "Add property to interface",
          "condition": "is_interface({1})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_interface_property", "name": "{0}", "type": "any"}
          ]
        },
        {
          "name": "use_bracket_notation",
          "description": "Use bracket notation",
          "confidence": 0.75,
          "actions": [
            {"type": "convert_to_bracket", "property": "{0}"}
          ]
        },
        {
          "name": "add_index_signature",
          "description": "Add index signature",
          "confidence": 0.8,
          "actions": [
            {"type": "add_index_signature", "to": "{1}"}
          ]
        },
        {
          "name": "fix_typo",
          "description": "Fix property name typo",
          "condition": "has_similar_property({1}, {0})",
          "confidence": 0.9,
          "actions": [
            {"type": "fix_property_name"}
          ]
        }
      ]
    },
    "TS2345": {
      "message": "Argument of type '{0}' is not assignable to parameter of type '{1}'",
      "category": "Argument",
      "severity": "Error",
      "fixes": [
        {
          "name": "cast_argument",
          "description": "Cast argument type",
          "confidence": 0.8,
          "actions": [
            {"type": "cast_as", "type": "{1}"}
          ]
        },
        {
          "name": "convert_type",
          "description": "Convert to expected type",
          "condition": "has_converter({0}, {1})",
          "confidence": 0.85,
          "actions": [
            {"type": "apply_converter"}
          ]
        }
      ]
    },
    "TS2304": {
      "message": "Cannot find name '{0}'",
      "category": "Name",
      "severity": "Error",
      "fixes": [
        {
          "name": "import_type",
          "description": "Import missing type",
          "condition": "is_known_type({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "add_import", "name": "{0}"}
          ]
        },
        {
          "name": "declare_type",
          "description": "Declare type",
          "confidence": 0.8,
          "actions": [
            {"type": "add_type_declaration", "name": "{0}"}
          ]
        }
      ]
    },
    "TS2532": {
      "message": "Object is possibly 'undefined'",
      "category": "Null",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_null_check",
          "description": "Add null check",
          "confidence": 0.95,
          "actions": [
            {"type": "add_guard", "check": "!== undefined"}
          ]
        },
        {
          "name": "use_optional_chaining",
          "description": "Use optional chaining",
          "confidence": 0.9,
          "actions": [
            {"type": "add_optional_chain"}
          ]
        },
        {
          "name": "use_non_null_assertion",
          "description": "Add non-null assertion",
          "condition": "definitely_defined",
          "confidence": 0.85,
          "actions": [
            {"type": "add_non_null_assertion"}
          ]
        }
      ]
    },
    "TS1005": {
      "message": "';' expected",
      "category": "Syntax",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_semicolon",
          "description": "Add missing semicolon",
          "confidence": 0.95,
          "actions": [
            {"type": "append", "text": ";"}
          ]
        }
      ]
    },
    "TS2588": {
      "message": "Cannot assign to '{0}' because it is a constant",
      "category": "Assignment",
      "severity": "Error",
      "fixes": [
        {
          "name": "change_to_let",
          "description": "Change const to let",
          "confidence": 0.9,
          "actions": [
            {"type": "change_declaration", "from": "const", "to": "let"}
          ]
        },
        {
          "name": "use_mutable_pattern",
          "description": "Use mutable data structure",
          "condition": "is_object_mutation",
          "confidence": 0.85,
          "actions": [
            {"type": "suggest_mutable_alternative"}
          ]
        }
      ]
    }
  }
}
EOF
}

# Generate pattern file
mkdir -p "$SCRIPT_DIR/patterns/databases/javascript"
generate_javascript_patterns > "$SCRIPT_DIR/patterns/databases/javascript/comprehensive_patterns.json"
echo "Generated comprehensive JavaScript/TypeScript patterns"