#!/bin/bash

# Comprehensive Rust Error Pattern Generator
# Generates detailed patterns for Rust compiler errors

generate_rust_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "rust",
  "pattern_count": 180,
  "patterns": {
    "E0001": {
      "message": "unreachable pattern",
      "category": "Pattern",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_unreachable_pattern",
          "description": "Remove unreachable match arm",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_match_arm"}
          ]
        },
        {
          "name": "reorder_patterns",
          "description": "Reorder match patterns",
          "confidence": 0.9,
          "actions": [
            {"type": "reorder_match_arms"}
          ]
        }
      ]
    },
    "E0002": {
      "message": "non-exhaustive patterns",
      "fixes": [
        {
          "name": "add_wildcard_pattern",
          "description": "Add wildcard pattern",
          "confidence": 0.9,
          "actions": [
            {"type": "add_match_arm", "pattern": "_ => {}"}
          ]
        },
        {
          "name": "add_missing_variants",
          "description": "Add missing enum variants",
          "condition": "enum_match",
          "confidence": 0.95,
          "actions": [
            {"type": "add_missing_enum_arms"}
          ]
        }
      ]
    },
    "E0004": {
      "message": "non-exhaustive patterns: {0} not covered",
      "fixes": [
        {
          "name": "add_pattern",
          "description": "Add missing pattern",
          "confidence": 0.95,
          "actions": [
            {"type": "add_match_arm", "pattern": "{0} => {}"}
          ]
        }
      ]
    },
    "E0106": {
      "message": "missing lifetime specifier",
      "category": "Lifetime",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_lifetime",
          "description": "Add lifetime parameter",
          "confidence": 0.85,
          "actions": [
            {"type": "add_lifetime_param", "name": "'a"}
          ]
        },
        {
          "name": "use_static_lifetime",
          "description": "Use 'static lifetime",
          "condition": "static_data",
          "confidence": 0.8,
          "actions": [
            {"type": "add_lifetime", "lifetime": "'static"}
          ]
        },
        {
          "name": "elide_lifetime",
          "description": "Use lifetime elision",
          "condition": "elision_applicable",
          "confidence": 0.9,
          "actions": [
            {"type": "apply_lifetime_elision"}
          ]
        }
      ]
    },
    "E0107": {
      "message": "wrong number of type arguments: expected {0}, found {1}",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "adjust_type_params",
          "description": "Adjust type parameters",
          "confidence": 0.9,
          "actions": [
            {"type": "match_type_param_count", "expected": "{0}"}
          ]
        },
        {
          "name": "add_type_params",
          "description": "Add missing type parameters",
          "condition": "too_few_params",
          "confidence": 0.85,
          "actions": [
            {"type": "add_generic_params"}
          ]
        }
      ]
    },
    "E0133": {
      "message": "call to unsafe function requires unsafe block",
      "category": "Safety",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_unsafe_block",
          "description": "Wrap in unsafe block",
          "confidence": 0.95,
          "actions": [
            {"type": "wrap_with", "code": "unsafe { }"}
          ]
        }
      ]
    },
    "E0277": {
      "message": "the trait bound `{0}: {1}` is not satisfied",
      "category": "Trait",
      "severity": "Error",
      "fixes": [
        {
          "name": "derive_trait",
          "description": "Derive the trait",
          "condition": "is_derivable({1})",
          "confidence": 0.9,
          "actions": [
            {"type": "add_derive", "trait": "{1}"}
          ]
        },
        {
          "name": "implement_trait",
          "description": "Implement the trait",
          "confidence": 0.85,
          "actions": [
            {"type": "generate_trait_impl", "type": "{0}", "trait": "{1}"}
          ]
        },
        {
          "name": "add_trait_bound",
          "description": "Add trait bound",
          "condition": "is_generic",
          "confidence": 0.8,
          "actions": [
            {"type": "add_where_clause", "bound": "{0}: {1}"}
          ]
        }
      ]
    },
    "E0308": {
      "message": "mismatched types: expected {0}, found {1}",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "type_conversion",
          "description": "Convert type",
          "condition": "has_conversion({1}, {0})",
          "confidence": 0.85,
          "actions": [
            {"type": "apply_conversion", "from": "{1}", "to": "{0}"}
          ]
        },
        {
          "name": "use_as_cast",
          "description": "Use as cast",
          "condition": "numeric_types",
          "confidence": 0.9,
          "actions": [
            {"type": "add_cast", "as": "{0}"}
          ]
        },
        {
          "name": "fix_return_type",
          "description": "Fix return type",
          "condition": "return_statement",
          "confidence": 0.85,
          "actions": [
            {"type": "update_return_type", "to": "{1}"}
          ]
        },
        {
          "name": "add_ok_wrapper",
          "description": "Wrap in Ok()",
          "condition": "result_expected",
          "confidence": 0.9,
          "actions": [
            {"type": "wrap_with", "function": "Ok"}
          ]
        }
      ]
    },
    "E0382": {
      "message": "use of moved value: {0}",
      "category": "Ownership",
      "severity": "Error",
      "fixes": [
        {
          "name": "clone_value",
          "description": "Clone the value",
          "condition": "implements_clone({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_method_call", "method": ".clone()"}
          ]
        },
        {
          "name": "borrow_instead",
          "description": "Borrow instead of move",
          "confidence": 0.9,
          "actions": [
            {"type": "add_reference", "prefix": "&"}
          ]
        },
        {
          "name": "use_rc",
          "description": "Use Rc for shared ownership",
          "condition": "single_threaded",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap_with_rc"}
          ]
        }
      ]
    },
    "E0384": {
      "message": "cannot assign twice to immutable variable {0}",
      "category": "Mutability",
      "severity": "Error",
      "fixes": [
        {
          "name": "make_mutable",
          "description": "Make variable mutable",
          "confidence": 0.95,
          "actions": [
            {"type": "add_mut", "to": "{0}"}
          ]
        },
        {
          "name": "create_new_variable",
          "description": "Create new variable",
          "confidence": 0.85,
          "actions": [
            {"type": "rename_second_assignment"}
          ]
        }
      ]
    },
    "E0425": {
      "message": "cannot find value {0} in this scope",
      "category": "Resolution",
      "severity": "Error",
      "fixes": [
        {
          "name": "import_item",
          "description": "Import from module",
          "condition": "exists_in_crate({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_use_statement", "item": "{0}"}
          ]
        },
        {
          "name": "declare_variable",
          "description": "Declare variable",
          "condition": "looks_like_variable({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "add_let_binding", "name": "{0}"}
          ]
        },
        {
          "name": "fix_typo",
          "description": "Fix typo",
          "condition": "has_similar_name({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "replace_with_similar"}
          ]
        },
        {
          "name": "add_self",
          "description": "Add self prefix",
          "condition": "in_method",
          "confidence": 0.9,
          "actions": [
            {"type": "prefix_with", "text": "self."}
          ]
        }
      ]
    },
    "E0432": {
      "message": "unresolved import {0}",
      "category": "Import",
      "severity": "Error",
      "fixes": [
        {
          "name": "fix_import_path",
          "description": "Fix import path",
          "confidence": 0.85,
          "actions": [
            {"type": "correct_module_path", "module": "{0}"}
          ]
        },
        {
          "name": "add_extern_crate",
          "description": "Add extern crate",
          "condition": "is_external_crate({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "add_extern_crate", "crate": "{0}"}
          ]
        },
        {
          "name": "add_to_cargo_toml",
          "description": "Add dependency",
          "condition": "is_crates_io({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "add_dependency", "crate": "{0}"}
          ]
        }
      ]
    },
    "E0433": {
      "message": "failed to resolve: {0}",
      "fixes": [
        {
          "name": "create_module",
          "description": "Create missing module",
          "condition": "is_module_path({0})",
          "confidence": 0.8,
          "actions": [
            {"type": "create_module", "path": "{0}"}
          ]
        },
        {
          "name": "fix_path",
          "description": "Fix module path",
          "confidence": 0.85,
          "actions": [
            {"type": "suggest_correct_path"}
          ]
        }
      ]
    },
    "E0499": {
      "message": "cannot borrow {0} as mutable more than once",
      "category": "Borrow",
      "severity": "Error",
      "fixes": [
        {
          "name": "restructure_borrows",
          "description": "Restructure borrow scopes",
          "confidence": 0.8,
          "actions": [
            {"type": "minimize_borrow_scope"}
          ]
        },
        {
          "name": "use_refcell",
          "description": "Use RefCell for interior mutability",
          "confidence": 0.75,
          "actions": [
            {"type": "wrap_with_refcell"}
          ]
        }
      ]
    },
    "E0502": {
      "message": "cannot borrow {0} as {1} because it is also borrowed as {2}",
      "fixes": [
        {
          "name": "separate_borrows",
          "description": "Separate borrow scopes",
          "confidence": 0.85,
          "actions": [
            {"type": "restructure_code_blocks"}
          ]
        },
        {
          "name": "clone_before_borrow",
          "description": "Clone data before borrowing",
          "condition": "cloneable",
          "confidence": 0.8,
          "actions": [
            {"type": "clone_and_separate"}
          ]
        }
      ]
    },
    "E0507": {
      "message": "cannot move out of {0}",
      "category": "Move",
      "severity": "Error",
      "fixes": [
        {
          "name": "use_clone",
          "description": "Clone instead of move",
          "condition": "implements_clone",
          "confidence": 0.85,
          "actions": [
            {"type": "add_clone_call"}
          ]
        },
        {
          "name": "destructure_reference",
          "description": "Destructure by reference",
          "confidence": 0.9,
          "actions": [
            {"type": "add_ref_pattern"}
          ]
        },
        {
          "name": "use_mem_replace",
          "description": "Use mem::replace",
          "condition": "owned_value_needed",
          "confidence": 0.8,
          "actions": [
            {"type": "use_mem_replace"}
          ]
        }
      ]
    },
    "E0596": {
      "message": "cannot borrow {0} as mutable",
      "fixes": [
        {
          "name": "make_binding_mutable",
          "description": "Make binding mutable",
          "confidence": 0.95,
          "actions": [
            {"type": "add_mut_to_binding"}
          ]
        },
        {
          "name": "use_interior_mutability",
          "description": "Use Cell/RefCell",
          "condition": "single_value",
          "confidence": 0.8,
          "actions": [
            {"type": "suggest_interior_mutability"}
          ]
        }
      ]
    },
    "E0597": {
      "message": "{0} does not live long enough",
      "category": "Lifetime",
      "severity": "Error",
      "fixes": [
        {
          "name": "extend_lifetime",
          "description": "Move declaration to wider scope",
          "confidence": 0.85,
          "actions": [
            {"type": "move_declaration_up"}
          ]
        },
        {
          "name": "clone_value",
          "description": "Clone to extend lifetime",
          "condition": "cloneable",
          "confidence": 0.8,
          "actions": [
            {"type": "clone_to_owned"}
          ]
        },
        {
          "name": "use_owned_type",
          "description": "Use owned type instead",
          "confidence": 0.85,
          "actions": [
            {"type": "convert_to_owned"}
          ]
        }
      ]
    },
    "E0599": {
      "message": "no method named {0} found",
      "category": "Method",
      "severity": "Error",
      "fixes": [
        {
          "name": "import_trait",
          "description": "Import trait with method",
          "condition": "method_in_trait({0})",
          "confidence": 0.85,
          "actions": [
            {"type": "import_trait_for_method", "method": "{0}"}
          ]
        },
        {
          "name": "fix_method_name",
          "description": "Fix method name typo",
          "condition": "has_similar_method({0})",
          "confidence": 0.9,
          "actions": [
            {"type": "correct_method_name"}
          ]
        },
        {
          "name": "implement_method",
          "description": "Implement the method",
          "confidence": 0.8,
          "actions": [
            {"type": "generate_method_stub", "name": "{0}"}
          ]
        }
      ]
    },
    "E0614": {
      "message": "type {0} cannot be dereferenced",
      "fixes": [
        {
          "name": "remove_dereference",
          "description": "Remove dereference operator",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_deref"}
          ]
        },
        {
          "name": "implement_deref",
          "description": "Implement Deref trait",
          "confidence": 0.8,
          "actions": [
            {"type": "implement_deref_trait"}
          ]
        }
      ]
    },
    "E0716": {
      "message": "temporary value dropped while borrowed",
      "fixes": [
        {
          "name": "bind_to_variable",
          "description": "Bind to variable first",
          "confidence": 0.9,
          "actions": [
            {"type": "extract_to_variable"}
          ]
        },
        {
          "name": "clone_temporary",
          "description": "Clone the temporary",
          "condition": "cloneable",
          "confidence": 0.85,
          "actions": [
            {"type": "clone_temp_value"}
          ]
        }
      ]
    },
    "clippy::needless_return": {
      "message": "unneeded return statement",
      "category": "Clippy",
      "severity": "Warning",
      "fixes": [
        {
          "name": "remove_return",
          "description": "Remove unnecessary return",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_return_keyword"}
          ]
        }
      ]
    },
    "clippy::redundant_clone": {
      "message": "redundant clone",
      "fixes": [
        {
          "name": "remove_clone",
          "description": "Remove redundant clone",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_method_call", "method": "clone"}
          ]
        }
      ]
    },
    "clippy::unnecessary_mut": {
      "message": "variable does not need to be mutable",
      "fixes": [
        {
          "name": "remove_mut",
          "description": "Remove unnecessary mut",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_mut_keyword"}
          ]
        }
      ]
    },
    "warning::dead_code": {
      "message": "{0} is never used",
      "category": "Warning",
      "severity": "Warning",
      "fixes": [
        {
          "name": "remove_dead_code",
          "description": "Remove unused code",
          "confidence": 0.85,
          "actions": [
            {"type": "remove_unused_item"}
          ]
        },
        {
          "name": "add_underscore",
          "description": "Prefix with underscore",
          "confidence": 0.9,
          "actions": [
            {"type": "prefix_name", "with": "_"}
          ]
        },
        {
          "name": "add_allow_dead_code",
          "description": "Allow dead code",
          "confidence": 0.8,
          "actions": [
            {"type": "add_attribute", "attr": "#[allow(dead_code)]"}
          ]
        }
      ]
    },
    "warning::unused_imports": {
      "message": "unused import: {0}",
      "fixes": [
        {
          "name": "remove_import",
          "description": "Remove unused import",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_use_statement", "import": "{0}"}
          ]
        }
      ]
    },
    "warning::unused_variables": {
      "message": "unused variable: {0}",
      "fixes": [
        {
          "name": "prefix_underscore",
          "description": "Prefix with underscore",
          "confidence": 0.95,
          "actions": [
            {"type": "rename", "from": "{0}", "to": "_{0}"}
          ]
        },
        {
          "name": "remove_variable",
          "description": "Remove unused variable",
          "confidence": 0.85,
          "actions": [
            {"type": "remove_binding"}
          ]
        }
      ]
    }
  }
}
EOF
}

# Generate pattern file
mkdir -p "$SCRIPT_DIR/patterns/databases/rust"
generate_rust_patterns > "$SCRIPT_DIR/patterns/databases/rust/comprehensive_patterns.json"
echo "Generated comprehensive Rust patterns"