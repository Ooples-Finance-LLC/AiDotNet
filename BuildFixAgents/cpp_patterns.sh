#!/bin/bash

# Comprehensive C++ Error Pattern Generator
# Generates detailed patterns for C++ compiler errors (GCC/Clang/MSVC)

generate_cpp_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "cpp",
  "pattern_count": 200,
  "patterns": {
    "undefined_reference": {
      "message": "undefined reference to `{0}'",
      "category": "Linker",
      "severity": "Error",
      "fixes": [
        {
          "name": "implement_function",
          "description": "Implement the function",
          "condition": "is_declared({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "generate_function_implementation", "function": "{0}"}
          ]
        },
        {
          "name": "link_library",
          "description": "Link required library",
          "condition": "is_library_function({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_link_flag", "library": "auto_detect({0})"}
          ]
        },
        {
          "name": "add_source_file",
          "description": "Add source file to build",
          "condition": "exists_in_project({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "add_to_build", "file": "find_implementation({0})"}
          ]
        }
      ]
    },
    "no_matching_function": {
      "message": "no matching function for call to '{0}'",
      "category": "Overload",
      "severity": "Error",
      "fixes": [
        {
          "name": "fix_arguments",
          "description": "Fix function arguments",
          "confidence": 0.85,
          "actions": [
            {"type": "match_function_signature", "function": "{0}"}
          ]
        },
        {
          "name": "add_overload",
          "description": "Add function overload",
          "confidence": 0.8,
          "actions": [
            {"type": "generate_overload", "based_on": "call_site"}
          ]
        },
        {
          "name": "explicit_cast",
          "description": "Add explicit casts",
          "confidence": 0.75,
          "actions": [
            {"type": "add_argument_casts"}
          ]
        },
        {
          "name": "check_namespace",
          "description": "Check namespace qualification",
          "condition": "in_namespace",
          "confidence": 0.8,
          "actions": [
            {"type": "qualify_with_namespace"}
          ]
        }
      ]
    },
    "use_of_undeclared_identifier": {
      "message": "use of undeclared identifier '{0}'",
      "category": "Declaration",
      "severity": "Error",
      "fixes": [
        {
          "name": "include_header",
          "description": "Include required header",
          "condition": "is_standard_identifier({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "add_include", "header": "find_header({0})"}
          ]
        },
        {
          "name": "declare_variable",
          "description": "Declare the variable",
          "condition": "is_variable({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_declaration", "code": "auto {0} = {};"}
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
          "name": "using_namespace",
          "description": "Add using namespace",
          "condition": "is_std_identifier({0})",
          "confidence": 0.75,
          "actions": [
            {"type": "add_using", "namespace": "std"}
          ]
        }
      ]
    },
    "invalid_conversion": {
      "message": "invalid conversion from '{0}' to '{1}'",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "static_cast",
          "description": "Add static_cast",
          "confidence": 0.85,
          "actions": [
            {"type": "wrap_with", "template": "static_cast<{1}>()"}
          ]
        },
        {
          "name": "reinterpret_cast",
          "description": "Add reinterpret_cast",
          "condition": "pointer_conversion",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap_with", "template": "reinterpret_cast<{1}>()"}
          ]
        },
        {
          "name": "const_cast",
          "description": "Add const_cast",
          "condition": "const_mismatch",
          "confidence": 0.85,
          "actions": [
            {"type": "wrap_with", "template": "const_cast<{1}>()"}
          ]
        }
      ]
    },
    "no_member_named": {
      "message": "no member named '{0}' in '{1}'",
      "category": "Member",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_member",
          "description": "Add member to class",
          "condition": "is_user_class({1})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_class_member", "name": "{0}", "type": "auto"}
          ]
        },
        {
          "name": "fix_member_name",
          "description": "Fix member name typo",
          "condition": "has_similar_member({1}, {0})",
          "confidence": 0.9,
          "actions": [
            {"type": "correct_member_name"}
          ]
        },
        {
          "name": "check_access",
          "description": "Check member access",
          "condition": "is_private_member({1}, {0})",
          "confidence": 0.8,
          "actions": [
            {"type": "suggest_getter_setter"}
          ]
        }
      ]
    },
    "expected_semicolon": {
      "message": "expected ';' after {0}",
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
    "redefinition": {
      "message": "redefinition of '{0}'",
      "category": "Definition",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_duplicate",
          "description": "Remove duplicate definition",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_duplicate_definition"}
          ]
        },
        {
          "name": "use_header_guard",
          "description": "Add header guard",
          "condition": "in_header_file",
          "confidence": 0.95,
          "actions": [
            {"type": "add_header_guard"}
          ]
        },
        {
          "name": "use_pragma_once",
          "description": "Add #pragma once",
          "condition": "in_header_file",
          "confidence": 0.9,
          "actions": [
            {"type": "add_pragma_once"}
          ]
        }
      ]
    },
    "incomplete_type": {
      "message": "incomplete type '{0}'",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "include_definition",
          "description": "Include type definition",
          "confidence": 0.85,
          "actions": [
            {"type": "include_header_with_definition", "type": "{0}"}
          ]
        },
        {
          "name": "forward_declaration",
          "description": "Add forward declaration",
          "condition": "pointer_or_reference",
          "confidence": 0.8,
          "actions": [
            {"type": "add_forward_declaration", "type": "{0}"}
          ]
        }
      ]
    },
    "cannot_convert": {
      "message": "cannot convert '{0}' to '{1}'",
      "category": "Conversion",
      "severity": "Error",
      "fixes": [
        {
          "name": "explicit_conversion",
          "description": "Add explicit conversion",
          "confidence": 0.85,
          "actions": [
            {"type": "add_conversion", "from": "{0}", "to": "{1}"}
          ]
        },
        {
          "name": "constructor_call",
          "description": "Use constructor",
          "condition": "has_constructor({1}, {0})",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap_with_constructor", "type": "{1}"}
          ]
        }
      ]
    },
    "private_member": {
      "message": "'{0}' is a private member of '{1}'",
      "category": "Access",
      "severity": "Error",
      "fixes": [
        {
          "name": "make_public",
          "description": "Make member public",
          "condition": "can_modify_class({1})",
          "confidence": 0.7,
          "actions": [
            {"type": "change_access", "to": "public"}
          ]
        },
        {
          "name": "add_getter",
          "description": "Add getter method",
          "confidence": 0.85,
          "actions": [
            {"type": "generate_getter", "member": "{0}"}
          ]
        },
        {
          "name": "friend_declaration",
          "description": "Add friend declaration",
          "confidence": 0.75,
          "actions": [
            {"type": "add_friend", "class": "current_class"}
          ]
        }
      ]
    },
    "no_matching_constructor": {
      "message": "no matching constructor for initialization of '{0}'",
      "category": "Constructor",
      "severity": "Error",
      "fixes": [
        {
          "name": "fix_constructor_args",
          "description": "Fix constructor arguments",
          "confidence": 0.85,
          "actions": [
            {"type": "match_constructor_signature"}
          ]
        },
        {
          "name": "add_constructor",
          "description": "Add matching constructor",
          "condition": "is_user_class({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "generate_constructor"}
          ]
        },
        {
          "name": "use_default_constructor",
          "description": "Use default constructor",
          "condition": "has_default_constructor({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "remove_arguments"}
          ]
        }
      ]
    },
    "ambiguous_overload": {
      "message": "call of overloaded '{0}' is ambiguous",
      "category": "Overload",
      "severity": "Error",
      "fixes": [
        {
          "name": "explicit_cast",
          "description": "Add explicit cast to resolve ambiguity",
          "confidence": 0.85,
          "actions": [
            {"type": "add_disambiguating_cast"}
          ]
        },
        {
          "name": "qualify_call",
          "description": "Fully qualify function call",
          "confidence": 0.8,
          "actions": [
            {"type": "add_explicit_qualification"}
          ]
        }
      ]
    },
    "deleted_function": {
      "message": "use of deleted function '{0}'",
      "category": "Deleted",
      "severity": "Error",
      "fixes": [
        {
          "name": "provide_implementation",
          "description": "Provide implementation",
          "condition": "is_user_function({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "remove_delete", "implement": true}
          ]
        },
        {
          "name": "use_alternative",
          "description": "Use alternative method",
          "condition": "has_alternative({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "suggest_alternative"}
          ]
        }
      ]
    },
    "pure_virtual": {
      "message": "cannot instantiate abstract class",
      "category": "Abstract",
      "severity": "Error",
      "fixes": [
        {
          "name": "implement_pure_virtual",
          "description": "Implement pure virtual functions",
          "confidence": 0.9,
          "actions": [
            {"type": "implement_all_pure_virtuals"}
          ]
        },
        {
          "name": "create_concrete_class",
          "description": "Create concrete derived class",
          "confidence": 0.85,
          "actions": [
            {"type": "generate_concrete_class"}
          ]
        }
      ]
    },
    "template_argument": {
      "message": "template argument deduction/substitution failed",
      "category": "Template",
      "severity": "Error",
      "fixes": [
        {
          "name": "explicit_template_args",
          "description": "Provide explicit template arguments",
          "confidence": 0.85,
          "actions": [
            {"type": "add_template_arguments"}
          ]
        },
        {
          "name": "fix_template_syntax",
          "description": "Fix template syntax",
          "confidence": 0.8,
          "actions": [
            {"type": "correct_template_syntax"}
          ]
        }
      ]
    },
    "multiple_definition": {
      "message": "multiple definition of '{0}'",
      "category": "Linker",
      "severity": "Error",
      "fixes": [
        {
          "name": "make_inline",
          "description": "Make function inline",
          "condition": "in_header",
          "confidence": 0.9,
          "actions": [
            {"type": "add_inline"}
          ]
        },
        {
          "name": "move_to_source",
          "description": "Move to source file",
          "condition": "in_header",
          "confidence": 0.85,
          "actions": [
            {"type": "move_implementation_to_cpp"}
          ]
        },
        {
          "name": "use_header_guard",
          "description": "Add header guard",
          "confidence": 0.9,
          "actions": [
            {"type": "add_include_guard"}
          ]
        }
      ]
    },
    "const_qualifier": {
      "message": "passing '{0}' as '{1}' argument discards qualifiers",
      "category": "Const",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_const",
          "description": "Add const to parameter",
          "confidence": 0.9,
          "actions": [
            {"type": "add_const_to_parameter"}
          ]
        },
        {
          "name": "remove_const",
          "description": "Remove const with const_cast",
          "confidence": 0.8,
          "actions": [
            {"type": "add_const_cast"}
          ]
        },
        {
          "name": "copy_value",
          "description": "Make a copy",
          "confidence": 0.75,
          "actions": [
            {"type": "create_non_const_copy"}
          ]
        }
      ]
    },
    "out_of_line_definition": {
      "message": "out-of-line definition of '{0}' does not match",
      "category": "Definition",
      "severity": "Error",
      "fixes": [
        {
          "name": "match_declaration",
          "description": "Match declaration signature",
          "confidence": 0.9,
          "actions": [
            {"type": "sync_with_declaration"}
          ]
        },
        {
          "name": "fix_qualifiers",
          "description": "Fix const/volatile qualifiers",
          "confidence": 0.85,
          "actions": [
            {"type": "match_cv_qualifiers"}
          ]
        }
      ]
    },
    "array_bound": {
      "message": "array subscript is out of bounds",
      "category": "Bounds",
      "severity": "Warning",
      "fixes": [
        {
          "name": "add_bounds_check",
          "description": "Add bounds check",
          "confidence": 0.9,
          "actions": [
            {"type": "add_bounds_check"}
          ]
        },
        {
          "name": "use_vector",
          "description": "Use std::vector instead",
          "confidence": 0.85,
          "actions": [
            {"type": "replace_with_vector"}
          ]
        },
        {
          "name": "use_array",
          "description": "Use std::array",
          "condition": "fixed_size",
          "confidence": 0.8,
          "actions": [
            {"type": "replace_with_std_array"}
          ]
        }
      ]
    },
    "uninitialized_variable": {
      "message": "variable '{0}' is uninitialized",
      "category": "Initialization",
      "severity": "Warning",
      "fixes": [
        {
          "name": "initialize_default",
          "description": "Initialize with default value",
          "confidence": 0.95,
          "actions": [
            {"type": "add_initialization", "value": "{}"}
          ]
        },
        {
          "name": "initialize_zero",
          "description": "Initialize to zero",
          "condition": "numeric_type",
          "confidence": 0.9,
          "actions": [
            {"type": "add_initialization", "value": "0"}
          ]
        },
        {
          "name": "initialize_nullptr",
          "description": "Initialize to nullptr",
          "condition": "pointer_type",
          "confidence": 0.95,
          "actions": [
            {"type": "add_initialization", "value": "nullptr"}
          ]
        }
      ]
    },
    "unused_variable": {
      "message": "unused variable '{0}'",
      "category": "Unused",
      "severity": "Warning",
      "fixes": [
        {
          "name": "remove_variable",
          "description": "Remove unused variable",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_declaration"}
          ]
        },
        {
          "name": "mark_unused",
          "description": "Mark as unused",
          "confidence": 0.85,
          "actions": [
            {"type": "add_attribute", "attr": "[[maybe_unused]]"}
          ]
        },
        {
          "name": "cast_to_void",
          "description": "Cast to void",
          "confidence": 0.8,
          "actions": [
            {"type": "add_statement", "code": "(void){0};"}
          ]
        }
      ]
    },
    "implicit_conversion": {
      "message": "implicit conversion from '{0}' to '{1}'",
      "category": "Conversion",
      "severity": "Warning",
      "fixes": [
        {
          "name": "explicit_cast",
          "description": "Make conversion explicit",
          "confidence": 0.9,
          "actions": [
            {"type": "add_explicit_cast", "to": "{1}"}
          ]
        },
        {
          "name": "change_type",
          "description": "Change variable type",
          "confidence": 0.85,
          "actions": [
            {"type": "change_variable_type", "to": "{0}"}
          ]
        }
      ]
    },
    "switch_enum": {
      "message": "enumeration value '{0}' not handled in switch",
      "category": "Switch",
      "severity": "Warning",
      "fixes": [
        {
          "name": "add_case",
          "description": "Add case for enum value",
          "confidence": 0.95,
          "actions": [
            {"type": "add_switch_case", "value": "{0}"}
          ]
        },
        {
          "name": "add_default",
          "description": "Add default case",
          "confidence": 0.9,
          "actions": [
            {"type": "add_default_case"}
          ]
        }
      ]
    },
    "deprecated": {
      "message": "'{0}' is deprecated",
      "category": "Deprecated",
      "severity": "Warning",
      "fixes": [
        {
          "name": "use_modern_alternative",
          "description": "Use modern alternative",
          "condition": "has_modern_alternative({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "replace_with_modern"}
          ]
        },
        {
          "name": "suppress_warning",
          "description": "Suppress deprecation warning",
          "confidence": 0.7,
          "actions": [
            {"type": "add_pragma", "pragma": "GCC diagnostic ignored \"-Wdeprecated\""}
          ]
        }
      ]
    },
    "memory_leak": {
      "message": "potential memory leak",
      "category": "Memory",
      "severity": "Warning",
      "fixes": [
        {
          "name": "use_smart_pointer",
          "description": "Use smart pointer",
          "confidence": 0.9,
          "actions": [
            {"type": "replace_with_unique_ptr"}
          ]
        },
        {
          "name": "add_delete",
          "description": "Add delete statement",
          "confidence": 0.85,
          "actions": [
            {"type": "add_delete_statement"}
          ]
        },
        {
          "name": "use_raii",
          "description": "Use RAII pattern",
          "confidence": 0.85,
          "actions": [
            {"type": "wrap_in_raii_class"}
          ]
        }
      ]
    }
  }
}
EOF
}

# Generate pattern file
mkdir -p "$SCRIPT_DIR/patterns/databases/cpp"
generate_cpp_patterns > "$SCRIPT_DIR/patterns/databases/cpp/comprehensive_patterns.json"
echo "Generated comprehensive C++ patterns"