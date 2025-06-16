#!/bin/bash

# Comprehensive Python Error Pattern Generator
# Generates detailed patterns for Python errors

generate_python_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "python",
  "pattern_count": 200,
  "patterns": {
    "SyntaxError": {
      "invalid_syntax": {
        "message": "invalid syntax",
        "category": "Syntax",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_missing_colon",
            "description": "Add missing colon after if/for/while/def/class",
            "condition": "line_ends_with_control_statement",
            "confidence": 0.95,
            "actions": [
              {"type": "append", "text": ":"}
            ]
          },
          {
            "name": "fix_parentheses_mismatch",
            "description": "Balance parentheses",
            "condition": "unbalanced_parentheses",
            "confidence": 0.9,
            "actions": [
              {"type": "balance_parentheses"}
            ]
          },
          {
            "name": "fix_indentation",
            "description": "Fix inconsistent indentation",
            "condition": "mixed_tabs_spaces",
            "confidence": 0.95,
            "actions": [
              {"type": "normalize_indentation", "style": "spaces", "size": 4}
            ]
          }
        ]
      },
      "unexpected_eof": {
        "message": "unexpected EOF while parsing",
        "fixes": [
          {
            "name": "close_open_structures",
            "description": "Close unclosed brackets/parentheses",
            "confidence": 0.9,
            "actions": [
              {"type": "count_brackets"},
              {"type": "add_closing_brackets"}
            ]
          },
          {
            "name": "complete_block",
            "description": "Add pass to empty block",
            "condition": "empty_code_block",
            "confidence": 0.85,
            "actions": [
              {"type": "add_line", "text": "    pass"}
            ]
          }
        ]
      },
      "invalid_character": {
        "message": "invalid character in identifier",
        "fixes": [
          {
            "name": "remove_invalid_chars",
            "description": "Remove non-ASCII characters",
            "confidence": 0.9,
            "actions": [
              {"type": "sanitize_identifiers"}
            ]
          }
        ]
      }
    },
    "IndentationError": {
      "unexpected_indent": {
        "message": "unexpected indent",
        "category": "Syntax",
        "severity": "Error",
        "fixes": [
          {
            "name": "align_with_previous",
            "description": "Align with previous line indentation",
            "confidence": 0.9,
            "actions": [
              {"type": "match_previous_indent"}
            ]
          }
        ]
      },
      "expected_indented_block": {
        "message": "expected an indented block",
        "fixes": [
          {
            "name": "add_indented_pass",
            "description": "Add indented pass statement",
            "confidence": 0.95,
            "actions": [
              {"type": "add_line", "text": "    pass", "indent": true}
            ]
          },
          {
            "name": "indent_next_line",
            "description": "Indent the following line",
            "condition": "next_line_exists",
            "confidence": 0.85,
            "actions": [
              {"type": "indent_next_line", "size": 4}
            ]
          }
        ]
      },
      "unindent_mismatch": {
        "message": "unindent does not match any outer indentation level",
        "fixes": [
          {
            "name": "fix_indentation_level",
            "description": "Match outer indentation level",
            "confidence": 0.9,
            "actions": [
              {"type": "analyze_indentation_levels"},
              {"type": "fix_to_valid_level"}
            ]
          }
        ]
      }
    },
    "NameError": {
      "name_not_defined": {
        "message": "name '{0}' is not defined",
        "category": "Name",
        "severity": "Error",
        "fixes": [
          {
            "name": "import_builtin",
            "description": "Import from builtins",
            "condition": "is_builtin({0})",
            "confidence": 0.95,
            "actions": [
              {"type": "add_import", "module": "builtins", "name": "{0}"}
            ]
          },
          {
            "name": "import_common_module",
            "description": "Import from common modules",
            "condition": "is_common_name({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest_import", "name": "{0}"}
            ]
          },
          {
            "name": "define_variable",
            "description": "Define the variable",
            "condition": "looks_like_variable({0})",
            "confidence": 0.7,
            "actions": [
              {"type": "add_before_first_use", "code": "{0} = None  # TODO: Initialize"}
            ]
          },
          {
            "name": "fix_typo",
            "description": "Fix typo in variable name",
            "condition": "has_similar_name({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_with_similar", "threshold": 0.8}
            ]
          },
          {
            "name": "add_self",
            "description": "Add self prefix in class",
            "condition": "in_class_method",
            "confidence": 0.9,
            "actions": [
              {"type": "prefix_with", "text": "self."}
            ]
          }
        ]
      }
    },
    "ImportError": {
      "no_module_named": {
        "message": "No module named '{0}'",
        "category": "Import",
        "severity": "Error",
        "fixes": [
          {
            "name": "pip_install",
            "description": "Install package with pip",
            "condition": "is_pip_package({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "command", "command": "pip install {0}"}
            ]
          },
          {
            "name": "fix_module_path",
            "description": "Fix import path",
            "condition": "is_local_module({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_relative_import", "module": "{0}"}
            ]
          },
          {
            "name": "add_init_file",
            "description": "Add __init__.py file",
            "condition": "is_directory({0})",
            "confidence": 0.95,
            "actions": [
              {"type": "create_file", "path": "{0}/__init__.py", "content": ""}
            ]
          },
          {
            "name": "fix_case_sensitivity",
            "description": "Fix module name case",
            "condition": "has_case_variant({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "fix_import_case", "module": "{0}"}
            ]
          }
        ]
      },
      "cannot_import_name": {
        "message": "cannot import name '{0}' from '{1}'",
        "fixes": [
          {
            "name": "check_export",
            "description": "Verify name is exported",
            "confidence": 0.8,
            "actions": [
              {"type": "verify_module_export", "module": "{1}", "name": "{0}"}
            ]
          },
          {
            "name": "import_module_instead",
            "description": "Import entire module",
            "confidence": 0.7,
            "actions": [
              {"type": "change_import", "to": "import {1}"},
              {"type": "update_usage", "to": "{1}.{0}"}
            ]
          }
        ]
      },
      "circular_import": {
        "message": "cannot import name '{0}' from partially initialized module",
        "fixes": [
          {
            "name": "move_import_inside_function",
            "description": "Move import inside function",
            "confidence": 0.85,
            "actions": [
              {"type": "move_import_to_function"}
            ]
          },
          {
            "name": "restructure_imports",
            "description": "Restructure module imports",
            "confidence": 0.7,
            "actions": [
              {"type": "analyze_circular_dependency"},
              {"type": "suggest_refactoring"}
            ]
          }
        ]
      }
    },
    "TypeError": {
      "missing_required_positional": {
        "message": "{0}() missing {1} required positional argument",
        "category": "Type",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_missing_arguments",
            "description": "Add missing arguments",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_function_signature", "function": "{0}"},
              {"type": "add_required_args"}
            ]
          },
          {
            "name": "use_default_values",
            "description": "Use default values",
            "condition": "has_defaults({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_defaults"}
            ]
          }
        ]
      },
      "unexpected_keyword_argument": {
        "message": "{0}() got an unexpected keyword argument '{1}'",
        "fixes": [
          {
            "name": "remove_keyword_arg",
            "description": "Remove unexpected argument",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_kwarg", "name": "{1}"}
            ]
          },
          {
            "name": "fix_argument_name",
            "description": "Fix typo in argument name",
            "condition": "has_similar_param({0}, {1})",
            "confidence": 0.85,
            "actions": [
              {"type": "rename_kwarg", "from": "{1}", "to": "similar_param"}
            ]
          }
        ]
      },
      "unsupported_operand_type": {
        "message": "unsupported operand type(s) for {0}: '{1}' and '{2}'",
        "fixes": [
          {
            "name": "type_conversion",
            "description": "Convert types to compatible",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_operation", "op": "{0}"},
              {"type": "suggest_conversion", "type1": "{1}", "type2": "{2}"}
            ]
          },
          {
            "name": "use_appropriate_method",
            "description": "Use type-appropriate method",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest_method", "for_types": ["{1}", "{2}"]}
            ]
          }
        ]
      },
      "not_callable": {
        "message": "'{0}' object is not callable",
        "fixes": [
          {
            "name": "remove_parentheses",
            "description": "Remove function call parentheses",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_call_syntax"}
            ]
          },
          {
            "name": "use_correct_method",
            "description": "Call appropriate method",
            "condition": "has_callable_method({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_callable_attribute", "object": "{0}"}
            ]
          }
        ]
      },
      "must_be_str_not": {
        "message": "must be str, not {0}",
        "fixes": [
          {
            "name": "convert_to_string",
            "description": "Convert to string",
            "confidence": 0.95,
            "actions": [
              {"type": "wrap_with", "function": "str"}
            ]
          },
          {
            "name": "use_format_string",
            "description": "Use f-string or format",
            "confidence": 0.9,
            "actions": [
              {"type": "convert_to_fstring"}
            ]
          }
        ]
      }
    },
    "AttributeError": {
      "no_attribute": {
        "message": "'{0}' object has no attribute '{1}'",
        "category": "Attribute",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_attribute_typo",
            "description": "Fix typo in attribute name",
            "condition": "has_similar_attribute({0}, {1})",
            "confidence": 0.85,
            "actions": [
              {"type": "replace_attribute", "with": "similar_attribute"}
            ]
          },
          {
            "name": "use_correct_api",
            "description": "Use correct API method",
            "condition": "is_common_mistake({0}, {1})",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_correct_api", "for": "{0}.{1}"}
            ]
          },
          {
            "name": "add_attribute",
            "description": "Add attribute to class",
            "condition": "is_user_class({0})",
            "confidence": 0.7,
            "actions": [
              {"type": "add_to_class", "attribute": "{1}", "value": "None"}
            ]
          },
          {
            "name": "check_initialization",
            "description": "Check object initialization",
            "condition": "might_be_none({0})",
            "confidence": 0.75,
            "actions": [
              {"type": "add_none_check", "object": "{0}"}
            ]
          }
        ]
      },
      "module_no_attribute": {
        "message": "module '{0}' has no attribute '{1}'",
        "fixes": [
          {
            "name": "check_import",
            "description": "Verify import statement",
            "confidence": 0.85,
            "actions": [
              {"type": "verify_module_attribute", "module": "{0}", "attr": "{1}"}
            ]
          },
          {
            "name": "update_import",
            "description": "Import from submodule",
            "condition": "exists_in_submodule({0}, {1})",
            "confidence": 0.8,
            "actions": [
              {"type": "update_import_path", "to_submodule": true}
            ]
          }
        ]
      }
    },
    "ValueError": {
      "invalid_literal": {
        "message": "invalid literal for {0}() with base {1}: '{2}'",
        "category": "Value",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_error_handling",
            "description": "Add try-except block",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_try_except", "exception": "ValueError"}
            ]
          },
          {
            "name": "validate_before_convert",
            "description": "Validate input before conversion",
            "confidence": 0.8,
            "actions": [
              {"type": "add_validation", "for_type": "{0}"}
            ]
          }
        ]
      },
      "too_many_values_to_unpack": {
        "message": "too many values to unpack (expected {0})",
        "fixes": [
          {
            "name": "match_unpacking_count",
            "description": "Adjust unpacking variables",
            "confidence": 0.9,
            "actions": [
              {"type": "count_values"},
              {"type": "adjust_variables", "to": "{0}"}
            ]
          },
          {
            "name": "use_underscore",
            "description": "Use _ for unused values",
            "confidence": 0.85,
            "actions": [
              {"type": "add_underscore_variables"}
            ]
          }
        ]
      },
      "not_enough_values_to_unpack": {
        "message": "not enough values to unpack (expected {0}, got {1})",
        "fixes": [
          {
            "name": "reduce_variables",
            "description": "Reduce unpacking variables",
            "confidence": 0.9,
            "actions": [
              {"type": "match_available_values", "count": "{1}"}
            ]
          },
          {
            "name": "check_iterable",
            "description": "Verify iterable content",
            "confidence": 0.8,
            "actions": [
              {"type": "debug_iterable_content"}
            ]
          }
        ]
      }
    },
    "KeyError": {
      "key_error": {
        "message": "'{0}'",
        "category": "Key",
        "severity": "Error",
        "fixes": [
          {
            "name": "use_get_method",
            "description": "Use dict.get() with default",
            "confidence": 0.95,
            "actions": [
              {"type": "replace_access", "with": ".get('{0}', None)"}
            ]
          },
          {
            "name": "check_key_exists",
            "description": "Add key existence check",
            "confidence": 0.9,
            "actions": [
              {"type": "add_condition", "check": "'{0}' in dict"}
            ]
          },
          {
            "name": "use_defaultdict",
            "description": "Use collections.defaultdict",
            "condition": "multiple_key_errors",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest_defaultdict"}
            ]
          },
          {
            "name": "fix_key_typo",
            "description": "Fix typo in key name",
            "condition": "has_similar_key({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_key", "with": "similar_key"}
            ]
          }
        ]
      }
    },
    "IndexError": {
      "list_index_out_of_range": {
        "message": "list index out of range",
        "category": "Index",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_bounds_check",
            "description": "Add index bounds check",
            "confidence": 0.9,
            "actions": [
              {"type": "add_condition", "check": "index < len(list)"}
            ]
          },
          {
            "name": "use_try_except",
            "description": "Handle with try-except",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_try_except", "exception": "IndexError"}
            ]
          },
          {
            "name": "use_slice",
            "description": "Use slice notation",
            "condition": "accessing_last_element",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_with", "code": "list[-1]"}
            ]
          }
        ]
      },
      "tuple_index_out_of_range": {
        "message": "tuple index out of range",
        "fixes": [
          {
            "name": "check_tuple_length",
            "description": "Verify tuple length",
            "confidence": 0.9,
            "actions": [
              {"type": "add_length_check"}
            ]
          }
        ]
      }
    },
    "FileNotFoundError": {
      "no_such_file": {
        "message": "[Errno 2] No such file or directory: '{0}'",
        "category": "IO",
        "severity": "Error",
        "fixes": [
          {
            "name": "check_file_exists",
            "description": "Add file existence check",
            "confidence": 0.95,
            "actions": [
              {"type": "add_check", "code": "os.path.exists('{0}')"}
            ]
          },
          {
            "name": "create_file",
            "description": "Create the file if missing",
            "condition": "is_write_mode",
            "confidence": 0.85,
            "actions": [
              {"type": "create_empty_file", "path": "{0}"}
            ]
          },
          {
            "name": "fix_path",
            "description": "Fix file path",
            "condition": "has_path_issue({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "normalize_path", "path": "{0}"}
            ]
          },
          {
            "name": "use_absolute_path",
            "description": "Convert to absolute path",
            "confidence": 0.75,
            "actions": [
              {"type": "convert_to_absolute", "path": "{0}"}
            ]
          }
        ]
      }
    },
    "PermissionError": {
      "permission_denied": {
        "message": "[Errno 13] Permission denied: '{0}'",
        "category": "IO",
        "severity": "Error",
        "fixes": [
          {
            "name": "check_permissions",
            "description": "Check file permissions",
            "confidence": 0.8,
            "actions": [
              {"type": "verify_permissions", "path": "{0}"}
            ]
          },
          {
            "name": "run_as_admin",
            "description": "Suggest running with elevated privileges",
            "condition": "requires_admin",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest", "message": "Run with sudo or as administrator"}
            ]
          }
        ]
      }
    },
    "ZeroDivisionError": {
      "division_by_zero": {
        "message": "division by zero",
        "category": "Arithmetic",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_zero_check",
            "description": "Add division by zero check",
            "confidence": 0.95,
            "actions": [
              {"type": "add_condition", "check": "divisor != 0"}
            ]
          },
          {
            "name": "use_safe_division",
            "description": "Return default on zero division",
            "confidence": 0.9,
            "actions": [
              {"type": "create_safe_division_function"}
            ]
          }
        ]
      }
    },
    "RecursionError": {
      "maximum_recursion_depth": {
        "message": "maximum recursion depth exceeded",
        "category": "Runtime",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_base_case",
            "description": "Add or fix base case",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_recursion"},
              {"type": "suggest_base_case"}
            ]
          },
          {
            "name": "increase_recursion_limit",
            "description": "Increase recursion limit",
            "condition": "algorithm_requires_deep_recursion",
            "confidence": 0.7,
            "actions": [
              {"type": "add_import", "module": "sys"},
              {"type": "add_line", "code": "sys.setrecursionlimit(10000)"}
            ]
          },
          {
            "name": "convert_to_iterative",
            "description": "Convert to iterative approach",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest_iterative_solution"}
            ]
          }
        ]
      }
    },
    "MemoryError": {
      "memory_error": {
        "message": "",
        "category": "Runtime",
        "severity": "Error",
        "fixes": [
          {
            "name": "use_generator",
            "description": "Use generator instead of list",
            "condition": "creating_large_list",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_generator"}
            ]
          },
          {
            "name": "process_in_chunks",
            "description": "Process data in chunks",
            "confidence": 0.8,
            "actions": [
              {"type": "implement_chunking"}
            ]
          }
        ]
      }
    },
    "StopIteration": {
      "stop_iteration": {
        "message": "",
        "category": "Iterator",
        "severity": "Error",
        "fixes": [
          {
            "name": "use_next_default",
            "description": "Use next() with default value",
            "confidence": 0.9,
            "actions": [
              {"type": "add_default_to_next"}
            ]
          },
          {
            "name": "check_iterator_empty",
            "description": "Check if iterator is empty",
            "confidence": 0.85,
            "actions": [
              {"type": "add_iterator_check"}
            ]
          }
        ]
      }
    },
    "AssertionError": {
      "assertion_failed": {
        "message": "",
        "category": "Assertion",
        "severity": "Error",
        "fixes": [
          {
            "name": "check_assertion_condition",
            "description": "Debug assertion condition",
            "confidence": 0.7,
            "actions": [
              {"type": "add_debug_print"},
              {"type": "analyze_assertion"}
            ]
          },
          {
            "name": "add_assertion_message",
            "description": "Add descriptive message",
            "confidence": 0.85,
            "actions": [
              {"type": "enhance_assertion"}
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
generate_python_patterns > "$SCRIPT_DIR/patterns/databases/python/comprehensive_patterns.json"
echo "Generated comprehensive Python patterns"