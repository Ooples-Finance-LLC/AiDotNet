#!/bin/bash

# Comprehensive Java Error Pattern Generator
# Generates detailed patterns for Java compiler errors

generate_java_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "java",
  "pattern_count": 200,
  "patterns": {
    "compiler.err.already.defined": {
      "message": "{0} is already defined in {1}",
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
          "name": "rename_duplicate",
          "description": "Rename one of the definitions",
          "confidence": 0.85,
          "actions": [
            {"type": "rename_identifier", "suffix": "2"}
          ]
        }
      ]
    },
    "compiler.err.cant.resolve": {
      "message": "cannot find symbol",
      "category": "Symbol",
      "severity": "Error",
      "fixes": [
        {
          "name": "import_class",
          "description": "Import the class",
          "condition": "is_known_class({symbol})",
          "confidence": 0.9,
          "actions": [
            {"type": "add_import", "class": "{symbol}"}
          ]
        },
        {
          "name": "create_class",
          "description": "Create the class",
          "condition": "is_class_reference",
          "confidence": 0.8,
          "actions": [
            {"type": "create_class", "name": "{symbol}"}
          ]
        },
        {
          "name": "declare_variable",
          "description": "Declare the variable",
          "condition": "is_variable_reference",
          "confidence": 0.85,
          "actions": [
            {"type": "add_declaration", "code": "Object {symbol} = null;"}
          ]
        },
        {
          "name": "fix_typo",
          "description": "Fix typo in name",
          "condition": "has_similar_symbol({symbol})",
          "confidence": 0.85,
          "actions": [
            {"type": "replace_with_similar"}
          ]
        },
        {
          "name": "add_method",
          "description": "Create missing method",
          "condition": "is_method_call",
          "confidence": 0.8,
          "actions": [
            {"type": "generate_method_stub"}
          ]
        }
      ]
    },
    "compiler.err.incompatible.types": {
      "message": "incompatible types: {0} cannot be converted to {1}",
      "category": "Type",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_cast",
          "description": "Add explicit cast",
          "condition": "is_castable({0}, {1})",
          "confidence": 0.85,
          "actions": [
            {"type": "add_cast", "to": "{1}"}
          ]
        },
        {
          "name": "change_type",
          "description": "Change variable type",
          "confidence": 0.8,
          "actions": [
            {"type": "change_declaration_type", "to": "{0}"}
          ]
        },
        {
          "name": "convert_value",
          "description": "Convert value",
          "condition": "has_converter({0}, {1})",
          "confidence": 0.85,
          "actions": [
            {"type": "apply_converter", "from": "{0}", "to": "{1}"}
          ]
        },
        {
          "name": "box_primitive",
          "description": "Box/unbox primitive",
          "condition": "primitive_wrapper_mismatch",
          "confidence": 0.9,
          "actions": [
            {"type": "auto_box_unbox"}
          ]
        }
      ]
    },
    "compiler.err.unreported.exception": {
      "message": "unreported exception {0}; must be caught or declared to be thrown",
      "category": "Exception",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_try_catch",
          "description": "Add try-catch block",
          "confidence": 0.9,
          "actions": [
            {"type": "wrap_with_try_catch", "exception": "{0}"}
          ]
        },
        {
          "name": "add_throws",
          "description": "Add throws declaration",
          "confidence": 0.85,
          "actions": [
            {"type": "add_throws_clause", "exception": "{0}"}
          ]
        },
        {
          "name": "multi_catch",
          "description": "Add to existing catch",
          "condition": "has_try_block",
          "confidence": 0.8,
          "actions": [
            {"type": "add_catch_clause", "exception": "{0}"}
          ]
        }
      ]
    },
    "compiler.err.missing.ret.stmt": {
      "message": "missing return statement",
      "category": "Return",
      "severity": "Error",
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
          "name": "return_default",
          "description": "Return default value",
          "confidence": 0.9,
          "actions": [
            {"type": "add_default_return"}
          ]
        },
        {
          "name": "throw_exception",
          "description": "Throw exception instead",
          "condition": "unreachable_code",
          "confidence": 0.8,
          "actions": [
            {"type": "add_throw", "exception": "UnsupportedOperationException"}
          ]
        }
      ]
    },
    "compiler.err.var.might.not.have.been.initialized": {
      "message": "variable {0} might not have been initialized",
      "category": "Initialization",
      "severity": "Error",
      "fixes": [
        {
          "name": "initialize_variable",
          "description": "Initialize with default value",
          "confidence": 0.95,
          "actions": [
            {"type": "initialize_with_default"}
          ]
        },
        {
          "name": "initialize_null",
          "description": "Initialize with null",
          "condition": "reference_type",
          "confidence": 0.9,
          "actions": [
            {"type": "initialize_with", "value": "null"}
          ]
        },
        {
          "name": "move_initialization",
          "description": "Move initialization up",
          "condition": "conditional_initialization",
          "confidence": 0.85,
          "actions": [
            {"type": "hoist_initialization"}
          ]
        }
      ]
    },
    "compiler.err.final.parameter.may.not.be.assigned": {
      "message": "final parameter {0} may not be assigned",
      "category": "Final",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_final",
          "description": "Remove final modifier",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_modifier", "modifier": "final"}
          ]
        },
        {
          "name": "use_new_variable",
          "description": "Use new variable",
          "confidence": 0.85,
          "actions": [
            {"type": "create_local_copy"}
          ]
        }
      ]
    },
    "compiler.err.non-static.cant.be.ref": {
      "message": "non-static {0} {1} cannot be referenced from a static context",
      "category": "Static",
      "severity": "Error",
      "fixes": [
        {
          "name": "make_static",
          "description": "Make member static",
          "confidence": 0.85,
          "actions": [
            {"type": "add_modifier", "modifier": "static"}
          ]
        },
        {
          "name": "create_instance",
          "description": "Create instance first",
          "confidence": 0.8,
          "actions": [
            {"type": "create_instance_access"}
          ]
        },
        {
          "name": "remove_static_context",
          "description": "Make method non-static",
          "condition": "method_can_be_instance",
          "confidence": 0.75,
          "actions": [
            {"type": "remove_static_from_method"}
          ]
        }
      ]
    },
    "compiler.err.package.not.visible": {
      "message": "package {0} is not visible",
      "category": "Visibility",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_module_declaration",
          "description": "Add requires in module-info",
          "condition": "using_modules",
          "confidence": 0.9,
          "actions": [
            {"type": "add_requires", "module": "{0}"}
          ]
        },
        {
          "name": "check_classpath",
          "description": "Add to classpath",
          "confidence": 0.85,
          "actions": [
            {"type": "suggest_classpath_addition"}
          ]
        }
      ]
    },
    "compiler.err.class.public.should.be.in.file": {
      "message": "class {0} is public, should be declared in a file named {0}.java",
      "category": "File",
      "severity": "Error",
      "fixes": [
        {
          "name": "rename_file",
          "description": "Rename file to match class",
          "confidence": 0.95,
          "actions": [
            {"type": "rename_file", "to": "{0}.java"}
          ]
        },
        {
          "name": "remove_public",
          "description": "Remove public modifier",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_modifier", "modifier": "public"}
          ]
        },
        {
          "name": "rename_class",
          "description": "Rename class to match file",
          "confidence": 0.85,
          "actions": [
            {"type": "rename_class_to_filename"}
          ]
        }
      ]
    },
    "compiler.err.duplicate.class": {
      "message": "duplicate class: {0}",
      "fixes": [
        {
          "name": "remove_duplicate_class",
          "description": "Remove duplicate class",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_duplicate_class"}
          ]
        },
        {
          "name": "rename_class",
          "description": "Rename duplicate class",
          "confidence": 0.85,
          "actions": [
            {"type": "rename_class", "suffix": "2"}
          ]
        }
      ]
    },
    "compiler.err.illegal.start.of.expr": {
      "message": "illegal start of expression",
      "category": "Syntax",
      "severity": "Error",
      "fixes": [
        {
          "name": "fix_syntax",
          "description": "Fix expression syntax",
          "confidence": 0.75,
          "actions": [
            {"type": "analyze_expression_context"}
          ]
        },
        {
          "name": "add_missing_operator",
          "description": "Add missing operator",
          "condition": "missing_operator",
          "confidence": 0.8,
          "actions": [
            {"type": "insert_operator"}
          ]
        },
        {
          "name": "fix_parentheses",
          "description": "Balance parentheses",
          "condition": "unbalanced_parens",
          "confidence": 0.85,
          "actions": [
            {"type": "balance_parentheses"}
          ]
        }
      ]
    },
    "compiler.err.expected": {
      "message": "{0} expected",
      "fixes": [
        {
          "name": "insert_token",
          "description": "Insert missing token",
          "confidence": 0.9,
          "actions": [
            {"type": "insert", "token": "{0}"}
          ]
        }
      ]
    },
    "compiler.err.method.does.not.override.superclass": {
      "message": "method does not override or implement a method from a supertype",
      "category": "Override",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_override",
          "description": "Remove @Override annotation",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_annotation", "annotation": "Override"}
          ]
        },
        {
          "name": "fix_signature",
          "description": "Fix method signature",
          "condition": "has_similar_supermethod",
          "confidence": 0.85,
          "actions": [
            {"type": "match_super_signature"}
          ]
        },
        {
          "name": "add_to_interface",
          "description": "Add method to interface",
          "condition": "implements_interface",
          "confidence": 0.8,
          "actions": [
            {"type": "add_to_interface"}
          ]
        }
      ]
    },
    "compiler.err.abstract.meth.cant.have.body": {
      "message": "abstract methods cannot have a body",
      "fixes": [
        {
          "name": "remove_body",
          "description": "Remove method body",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_method_body"}
          ]
        },
        {
          "name": "remove_abstract",
          "description": "Remove abstract modifier",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_modifier", "modifier": "abstract"}
          ]
        }
      ]
    },
    "compiler.err.missing.meth.body.or.decl.abstract": {
      "message": "missing method body, or declare abstract",
      "fixes": [
        {
          "name": "add_body",
          "description": "Add method body",
          "confidence": 0.9,
          "actions": [
            {"type": "add_method_body"}
          ]
        },
        {
          "name": "make_abstract",
          "description": "Make method abstract",
          "confidence": 0.85,
          "actions": [
            {"type": "add_modifier", "modifier": "abstract"},
            {"type": "make_class_abstract"}
          ]
        }
      ]
    },
    "compiler.err.unreachable.stmt": {
      "message": "unreachable statement",
      "category": "Flow",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_unreachable",
          "description": "Remove unreachable code",
          "confidence": 0.95,
          "actions": [
            {"type": "remove_unreachable_code"}
          ]
        },
        {
          "name": "fix_control_flow",
          "description": "Fix control flow",
          "condition": "conditional_return",
          "confidence": 0.8,
          "actions": [
            {"type": "restructure_control_flow"}
          ]
        }
      ]
    },
    "compiler.err.generic.array.creation": {
      "message": "generic array creation",
      "category": "Generic",
      "severity": "Error",
      "fixes": [
        {
          "name": "use_list",
          "description": "Use List instead of array",
          "confidence": 0.9,
          "actions": [
            {"type": "replace_with_list"}
          ]
        },
        {
          "name": "use_reflection",
          "description": "Use reflection for array creation",
          "confidence": 0.8,
          "actions": [
            {"type": "use_array_newinstance"}
          ]
        },
        {
          "name": "suppress_warning",
          "description": "Suppress unchecked warning",
          "confidence": 0.75,
          "actions": [
            {"type": "add_annotation", "annotation": "@SuppressWarnings(\"unchecked\")"}
          ]
        }
      ]
    },
    "compiler.err.interface.expected.here": {
      "message": "interface expected here",
      "fixes": [
        {
          "name": "change_to_interface",
          "description": "Change class to interface",
          "confidence": 0.9,
          "actions": [
            {"type": "change_type", "from": "class", "to": "interface"}
          ]
        },
        {
          "name": "use_class_instead",
          "description": "Use extends instead of implements",
          "condition": "is_class",
          "confidence": 0.85,
          "actions": [
            {"type": "replace", "from": "implements", "to": "extends"}
          ]
        }
      ]
    },
    "compiler.err.enum.as.identifier": {
      "message": "as of release 5, 'enum' is a keyword",
      "fixes": [
        {
          "name": "rename_identifier",
          "description": "Rename enum identifier",
          "confidence": 0.95,
          "actions": [
            {"type": "rename", "from": "enum", "to": "enumeration"}
          ]
        }
      ]
    },
    "compiler.err.try.without.catch.or.finally": {
      "message": "try without catch or finally",
      "fixes": [
        {
          "name": "add_catch",
          "description": "Add catch block",
          "confidence": 0.9,
          "actions": [
            {"type": "add_catch_block", "exception": "Exception"}
          ]
        },
        {
          "name": "add_finally",
          "description": "Add finally block",
          "confidence": 0.85,
          "actions": [
            {"type": "add_finally_block"}
          ]
        }
      ]
    },
    "compiler.err.not.stmt": {
      "message": "not a statement",
      "fixes": [
        {
          "name": "complete_statement",
          "description": "Complete the statement",
          "confidence": 0.8,
          "actions": [
            {"type": "analyze_incomplete_statement"}
          ]
        },
        {
          "name": "add_semicolon",
          "description": "Add missing semicolon",
          "confidence": 0.85,
          "actions": [
            {"type": "append", "text": ";"}
          ]
        }
      ]
    },
    "compiler.err.variable.not.allowed": {
      "message": "variable declaration not allowed here",
      "fixes": [
        {
          "name": "move_declaration",
          "description": "Move declaration to valid location",
          "confidence": 0.85,
          "actions": [
            {"type": "move_to_method_start"}
          ]
        },
        {
          "name": "wrap_in_block",
          "description": "Wrap in code block",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap_with", "code": "{ }"}
          ]
        }
      ]
    },
    "NullPointerException": {
      "message": "NullPointerException",
      "category": "Runtime",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_null_check",
          "description": "Add null check",
          "confidence": 0.9,
          "actions": [
            {"type": "add_null_check"}
          ]
        },
        {
          "name": "initialize_object",
          "description": "Initialize object",
          "confidence": 0.85,
          "actions": [
            {"type": "add_initialization"}
          ]
        },
        {
          "name": "use_optional",
          "description": "Use Optional",
          "condition": "java8_or_higher",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap_with_optional"}
          ]
        }
      ]
    },
    "ArrayIndexOutOfBoundsException": {
      "message": "ArrayIndexOutOfBoundsException",
      "category": "Runtime",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_bounds_check",
          "description": "Add array bounds check",
          "confidence": 0.9,
          "actions": [
            {"type": "add_bounds_check"}
          ]
        },
        {
          "name": "use_for_each",
          "description": "Use enhanced for loop",
          "confidence": 0.85,
          "actions": [
            {"type": "convert_to_foreach"}
          ]
        }
      ]
    },
    "ClassCastException": {
      "message": "ClassCastException",
      "category": "Runtime",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_instanceof",
          "description": "Add instanceof check",
          "confidence": 0.9,
          "actions": [
            {"type": "add_instanceof_check"}
          ]
        },
        {
          "name": "fix_cast",
          "description": "Fix type cast",
          "confidence": 0.85,
          "actions": [
            {"type": "correct_cast_type"}
          ]
        }
      ]
    }
  }
}
EOF
}

# Generate pattern file
mkdir -p "$SCRIPT_DIR/patterns/databases/java"
generate_java_patterns > "$SCRIPT_DIR/patterns/databases/java/comprehensive_patterns.json"
echo "Generated comprehensive Java patterns"