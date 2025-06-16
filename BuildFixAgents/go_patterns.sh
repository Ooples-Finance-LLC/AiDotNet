#!/bin/bash

# Comprehensive Go Error Pattern Generator
# Generates detailed patterns for Go compiler and runtime errors

generate_go_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "go",
  "pattern_count": 150,
  "patterns": {
    "compile_errors": {
      "undefined": {
        "message": "undefined: {0}",
        "category": "Compile",
        "severity": "Error",
        "fixes": [
          {
            "name": "import_package",
            "description": "Import required package",
            "condition": "is_standard_library({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "add_import", "package": "auto_detect({0})"}
            ]
          },
          {
            "name": "declare_variable",
            "description": "Declare the variable",
            "condition": "looks_like_variable({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_declaration", "code": "var {0} interface{}"}
            ]
          },
          {
            "name": "fix_typo",
            "description": "Fix identifier typo",
            "condition": "has_similar_identifier({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "replace_with_similar"}
            ]
          },
          {
            "name": "go_get",
            "description": "Get external package",
            "condition": "is_external_package({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "command", "command": "go get {0}"}
            ]
          }
        ]
      },
      "imported_not_used": {
        "message": "imported and not used: \"{0}\"",
        "fixes": [
          {
            "name": "remove_import",
            "description": "Remove unused import",
            "confidence": 0.95,
            "actions": [
              {"type": "remove_import", "package": "{0}"}
            ]
          },
          {
            "name": "add_blank_import",
            "description": "Use blank import for side effects",
            "condition": "has_init_function({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "modify_import", "to": "_ \"{0}\""}
            ]
          }
        ]
      },
      "declared_not_used": {
        "message": "{0} declared and not used",
        "fixes": [
          {
            "name": "remove_declaration",
            "description": "Remove unused declaration",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_declaration", "identifier": "{0}"}
            ]
          },
          {
            "name": "use_blank_identifier",
            "description": "Replace with blank identifier",
            "confidence": 0.85,
            "actions": [
              {"type": "rename", "from": "{0}", "to": "_"}
            ]
          }
        ]
      },
      "cannot_use_type_as_type": {
        "message": "cannot use {0} (type {1}) as type {2}",
        "fixes": [
          {
            "name": "type_conversion",
            "description": "Add type conversion",
            "condition": "is_convertible({1}, {2})",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_conversion", "to": "{2}"}
            ]
          },
          {
            "name": "type_assertion",
            "description": "Add type assertion",
            "condition": "is_interface({2})",
            "confidence": 0.8,
            "actions": [
              {"type": "add_type_assertion", "type": "{2}"}
            ]
          },
          {
            "name": "fix_function_signature",
            "description": "Update function signature",
            "condition": "in_function_call",
            "confidence": 0.75,
            "actions": [
              {"type": "suggest_signature_change"}
            ]
          }
        ]
      },
      "no_new_variables": {
        "message": "no new variables on left side of :=",
        "fixes": [
          {
            "name": "use_assignment",
            "description": "Change := to =",
            "confidence": 0.95,
            "actions": [
              {"type": "replace", "from": ":=", "to": "="}
            ]
          },
          {
            "name": "rename_variable",
            "description": "Use different variable name",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_new_name"}
            ]
          }
        ]
      },
      "multiple_value_single_value": {
        "message": "multiple-value {0} in single-value context",
        "fixes": [
          {
            "name": "handle_error",
            "description": "Handle error return value",
            "condition": "returns_error({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "expand_assignment", "pattern": "value, err := {0}"}
            ]
          },
          {
            "name": "ignore_values",
            "description": "Ignore extra return values",
            "confidence": 0.85,
            "actions": [
              {"type": "add_blank_identifiers"}
            ]
          }
        ]
      },
      "not_enough_arguments": {
        "message": "not enough arguments in call to {0}",
        "fixes": [
          {
            "name": "add_arguments",
            "description": "Add missing arguments",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_function_signature", "function": "{0}"},
              {"type": "add_required_arguments"}
            ]
          },
          {
            "name": "use_default_values",
            "description": "Add zero values",
            "confidence": 0.8,
            "actions": [
              {"type": "add_zero_values"}
            ]
          }
        ]
      },
      "too_many_arguments": {
        "message": "too many arguments in call to {0}",
        "fixes": [
          {
            "name": "remove_excess_arguments",
            "description": "Remove extra arguments",
            "confidence": 0.9,
            "actions": [
              {"type": "match_function_signature", "function": "{0}"}
            ]
          }
        ]
      },
      "missing_return": {
        "message": "missing return at end of function",
        "fixes": [
          {
            "name": "add_return",
            "description": "Add return statement",
            "confidence": 0.95,
            "actions": [
              {"type": "add_return_statement"}
            ]
          },
          {
            "name": "return_zero_values",
            "description": "Return zero values",
            "confidence": 0.9,
            "actions": [
              {"type": "add_zero_value_return"}
            ]
          }
        ]
      },
      "syntax_error": {
        "message": "syntax error: {0}",
        "fixes": [
          {
            "name": "fix_syntax",
            "description": "Fix syntax error",
            "confidence": 0.7,
            "actions": [
              {"type": "analyze_syntax_error", "message": "{0}"}
            ]
          }
        ]
      },
      "cannot_assign": {
        "message": "cannot assign to {0}",
        "fixes": [
          {
            "name": "use_pointer",
            "description": "Use pointer receiver",
            "condition": "is_method_receiver",
            "confidence": 0.85,
            "actions": [
              {"type": "change_to_pointer_receiver"}
            ]
          },
          {
            "name": "create_variable",
            "description": "Assign to new variable",
            "confidence": 0.8,
            "actions": [
              {"type": "create_assignment_variable"}
            ]
          }
        ]
      },
      "redeclared": {
        "message": "{0} redeclared in this block",
        "fixes": [
          {
            "name": "remove_redeclaration",
            "description": "Remove duplicate declaration",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_duplicate_declaration"}
            ]
          },
          {
            "name": "rename_variable",
            "description": "Use different name",
            "confidence": 0.85,
            "actions": [
              {"type": "rename_to_unique"}
            ]
          }
        ]
      },
      "type_has_no_field": {
        "message": "{0} has no field or method {1}",
        "fixes": [
          {
            "name": "add_field",
            "description": "Add field to struct",
            "condition": "is_struct({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "add_struct_field", "name": "{1}", "type": "interface{}"}
            ]
          },
          {
            "name": "fix_field_name",
            "description": "Fix field name typo",
            "condition": "has_similar_field({0}, {1})",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_field_name"}
            ]
          },
          {
            "name": "add_method",
            "description": "Add method to type",
            "condition": "looks_like_method({1})",
            "confidence": 0.75,
            "actions": [
              {"type": "generate_method_stub", "receiver": "{0}", "name": "{1}"}
            ]
          }
        ]
      },
      "invalid_operation": {
        "message": "invalid operation: {0}",
        "fixes": [
          {
            "name": "fix_operation",
            "description": "Fix invalid operation",
            "confidence": 0.75,
            "actions": [
              {"type": "analyze_operation", "operation": "{0}"}
            ]
          }
        ]
      },
      "non_interface_type": {
        "message": "impossible type assertion: {0} does not implement {1}",
        "fixes": [
          {
            "name": "implement_interface",
            "description": "Implement missing methods",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_interface", "interface": "{1}"},
              {"type": "implement_missing_methods"}
            ]
          },
          {
            "name": "remove_assertion",
            "description": "Remove type assertion",
            "confidence": 0.8,
            "actions": [
              {"type": "remove_type_assertion"}
            ]
          }
        ]
      },
      "undefined_method": {
        "message": "{0}.{1} undefined (type {0} has no field or method {1})",
        "fixes": [
          {
            "name": "define_method",
            "description": "Define the method",
            "confidence": 0.85,
            "actions": [
              {"type": "create_method", "receiver": "{0}", "name": "{1}"}
            ]
          },
          {
            "name": "use_pointer_receiver",
            "description": "Check pointer receiver methods",
            "condition": "has_pointer_method({0}, {1})",
            "confidence": 0.8,
            "actions": [
              {"type": "take_address", "of": "{0}"}
            ]
          }
        ]
      }
    },
    "runtime_errors": {
      "nil_pointer_dereference": {
        "message": "runtime error: invalid memory address or nil pointer dereference",
        "category": "Runtime",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_nil_check",
            "description": "Add nil check before use",
            "confidence": 0.9,
            "actions": [
              {"type": "add_nil_check", "pattern": "if x != nil { }"}
            ]
          },
          {
            "name": "initialize_pointer",
            "description": "Initialize pointer",
            "confidence": 0.85,
            "actions": [
              {"type": "initialize_pointer"}
            ]
          }
        ]
      },
      "index_out_of_range": {
        "message": "runtime error: index out of range",
        "fixes": [
          {
            "name": "add_bounds_check",
            "description": "Add bounds check",
            "confidence": 0.9,
            "actions": [
              {"type": "add_bounds_check", "pattern": "if i < len(slice) { }"}
            ]
          },
          {
            "name": "use_range",
            "description": "Use range instead of index",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_range"}
            ]
          }
        ]
      },
      "slice_bounds_out_of_range": {
        "message": "runtime error: slice bounds out of range",
        "fixes": [
          {
            "name": "validate_slice_bounds",
            "description": "Validate slice boundaries",
            "confidence": 0.9,
            "actions": [
              {"type": "add_slice_validation"}
            ]
          }
        ]
      },
      "concurrent_map_access": {
        "message": "fatal error: concurrent map",
        "fixes": [
          {
            "name": "use_sync_map",
            "description": "Use sync.Map",
            "confidence": 0.85,
            "actions": [
              {"type": "replace_with_sync_map"}
            ]
          },
          {
            "name": "add_mutex",
            "description": "Add mutex protection",
            "confidence": 0.9,
            "actions": [
              {"type": "add_mutex", "around": "map_access"}
            ]
          }
        ]
      },
      "deadlock": {
        "message": "fatal error: all goroutines are asleep - deadlock!",
        "fixes": [
          {
            "name": "fix_channel_operations",
            "description": "Fix channel send/receive",
            "confidence": 0.75,
            "actions": [
              {"type": "analyze_channel_usage"},
              {"type": "fix_channel_deadlock"}
            ]
          },
          {
            "name": "add_buffering",
            "description": "Add channel buffer",
            "condition": "unbuffered_channel",
            "confidence": 0.8,
            "actions": [
              {"type": "make_buffered_channel"}
            ]
          }
        ]
      }
    },
    "go_vet": {
      "unreachable_code": {
        "message": "unreachable code",
        "category": "Vet",
        "severity": "Warning",
        "fixes": [
          {
            "name": "remove_unreachable",
            "description": "Remove unreachable code",
            "confidence": 0.95,
            "actions": [
              {"type": "remove_unreachable_code"}
            ]
          }
        ]
      },
      "format_verb": {
        "message": "Printf format %{0} has arg {1} of wrong type {2}",
        "fixes": [
          {
            "name": "fix_format_verb",
            "description": "Use correct format verb",
            "confidence": 0.9,
            "actions": [
              {"type": "fix_printf_verb", "for_type": "{2}"}
            ]
          },
          {
            "name": "convert_argument",
            "description": "Convert argument type",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_printf_arg"}
            ]
          }
        ]
      },
      "composite_literal": {
        "message": "composite literal uses unkeyed fields",
        "fixes": [
          {
            "name": "add_field_keys",
            "description": "Add field names",
            "confidence": 0.95,
            "actions": [
              {"type": "add_struct_field_keys"}
            ]
          }
        ]
      },
      "copy_lock": {
        "message": "assignment copies lock value",
        "fixes": [
          {
            "name": "use_pointer",
            "description": "Use pointer instead",
            "confidence": 0.9,
            "actions": [
              {"type": "convert_to_pointer"}
            ]
          }
        ]
      },
      "unused_result": {
        "message": "result of {0} call not used",
        "fixes": [
          {
            "name": "handle_result",
            "description": "Handle function result",
            "confidence": 0.85,
            "actions": [
              {"type": "assign_result", "pattern": "result := {0}"}
            ]
          },
          {
            "name": "explicitly_ignore",
            "description": "Explicitly ignore result",
            "confidence": 0.9,
            "actions": [
              {"type": "assign_to_blank", "pattern": "_ = {0}"}
            ]
          }
        ]
      }
    },
    "golint": {
      "exported_type_should_have_comment": {
        "message": "exported type {0} should have comment",
        "category": "Lint",
        "severity": "Warning",
        "fixes": [
          {
            "name": "add_comment",
            "description": "Add documentation comment",
            "confidence": 0.95,
            "actions": [
              {"type": "add_doc_comment", "text": "// {0} represents..."}
            ]
          }
        ]
      },
      "receiver_name": {
        "message": "receiver name should be a reflection of its identity",
        "fixes": [
          {
            "name": "fix_receiver_name",
            "description": "Use conventional receiver name",
            "confidence": 0.9,
            "actions": [
              {"type": "rename_receiver"}
            ]
          }
        ]
      },
      "error_strings": {
        "message": "error strings should not be capitalized",
        "fixes": [
          {
            "name": "lowercase_error",
            "description": "Convert to lowercase",
            "confidence": 0.95,
            "actions": [
              {"type": "lowercase_first_char"}
            ]
          }
        ]
      },
      "package_comment": {
        "message": "package comment should be of the form \"Package ...\"",
        "fixes": [
          {
            "name": "fix_package_comment",
            "description": "Fix package comment format",
            "confidence": 0.95,
            "actions": [
              {"type": "format_package_comment"}
            ]
          }
        ]
      }
    },
    "go_modules": {
      "go_mod_init": {
        "message": "go.mod file not found",
        "category": "Module",
        "severity": "Error",
        "fixes": [
          {
            "name": "init_module",
            "description": "Initialize go module",
            "confidence": 0.95,
            "actions": [
              {"type": "command", "command": "go mod init"}
            ]
          }
        ]
      },
      "missing_dependency": {
        "message": "missing go.sum entry for module",
        "fixes": [
          {
            "name": "download_dependencies",
            "description": "Download dependencies",
            "confidence": 0.95,
            "actions": [
              {"type": "command", "command": "go mod download"}
            ]
          },
          {
            "name": "tidy_modules",
            "description": "Tidy module dependencies",
            "confidence": 0.9,
            "actions": [
              {"type": "command", "command": "go mod tidy"}
            ]
          }
        ]
      },
      "module_not_found": {
        "message": "module {0}: no matching versions",
        "fixes": [
          {
            "name": "check_module_path",
            "description": "Verify module path",
            "confidence": 0.85,
            "actions": [
              {"type": "verify_module_exists", "module": "{0}"}
            ]
          },
          {
            "name": "use_latest",
            "description": "Get latest version",
            "confidence": 0.8,
            "actions": [
              {"type": "command", "command": "go get {0}@latest"}
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
mkdir -p "$SCRIPT_DIR/patterns/databases/go"
generate_go_patterns > "$SCRIPT_DIR/patterns/databases/go/comprehensive_patterns.json"
echo "Generated comprehensive Go patterns"