#!/bin/bash

# Comprehensive Ruby Error Pattern Generator
# Generates detailed patterns for Ruby errors and exceptions

generate_ruby_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "ruby",
  "pattern_count": 120,
  "patterns": {
    "SyntaxError": {
      "unexpected_end": {
        "message": "syntax error, unexpected end-of-input",
        "category": "Syntax",
        "severity": "Error",
        "fixes": [
          {
            "name": "close_block",
            "description": "Close unclosed block",
            "confidence": 0.9,
            "actions": [
              {"type": "add_end_keyword"}
            ]
          },
          {
            "name": "balance_do_end",
            "description": "Balance do-end blocks",
            "confidence": 0.85,
            "actions": [
              {"type": "balance_block_keywords"}
            ]
          }
        ]
      },
      "unexpected_token": {
        "message": "syntax error, unexpected {0}",
        "fixes": [
          {
            "name": "fix_syntax",
            "description": "Fix syntax error",
            "confidence": 0.75,
            "actions": [
              {"type": "analyze_ruby_syntax", "token": "{0}"}
            ]
          },
          {
            "name": "remove_token",
            "description": "Remove unexpected token",
            "condition": "duplicate_token",
            "confidence": 0.8,
            "actions": [
              {"type": "remove_token", "token": "{0}"}
            ]
          }
        ]
      },
      "invalid_syntax": {
        "message": "Invalid syntax",
        "fixes": [
          {
            "name": "fix_string_quotes",
            "description": "Fix string quote mismatch",
            "condition": "unmatched_quotes",
            "confidence": 0.9,
            "actions": [
              {"type": "balance_quotes"}
            ]
          },
          {
            "name": "fix_hash_syntax",
            "description": "Fix hash syntax",
            "condition": "old_hash_syntax",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_new_hash_syntax"}
            ]
          }
        ]
      }
    },
    "NameError": {
      "uninitialized_constant": {
        "message": "uninitialized constant {0}",
        "category": "Name",
        "severity": "Error",
        "fixes": [
          {
            "name": "require_file",
            "description": "Require file with constant",
            "condition": "constant_in_file({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_require", "file": "find_constant_file({0})"}
            ]
          },
          {
            "name": "define_constant",
            "description": "Define the constant",
            "confidence": 0.8,
            "actions": [
              {"type": "add_constant_definition", "name": "{0}"}
            ]
          },
          {
            "name": "fix_constant_name",
            "description": "Fix constant name typo",
            "condition": "has_similar_constant({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "replace_with_similar"}
            ]
          },
          {
            "name": "add_module_prefix",
            "description": "Add module qualification",
            "condition": "constant_in_module({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "qualify_with_module"}
            ]
          }
        ]
      },
      "undefined_local_variable": {
        "message": "undefined local variable or method `{0}'",
        "fixes": [
          {
            "name": "define_variable",
            "description": "Define local variable",
            "confidence": 0.85,
            "actions": [
              {"type": "add_variable_definition", "name": "{0}", "value": "nil"}
            ]
          },
          {
            "name": "fix_variable_name",
            "description": "Fix variable name typo",
            "condition": "has_similar_variable({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "correct_variable_name"}
            ]
          },
          {
            "name": "add_attr_accessor",
            "description": "Add attr_accessor",
            "condition": "in_class_context",
            "confidence": 0.8,
            "actions": [
              {"type": "add_attr_accessor", "name": "{0}"}
            ]
          }
        ]
      }
    },
    "NoMethodError": {
      "undefined_method": {
        "message": "undefined method `{0}' for {1}",
        "category": "Method",
        "severity": "Error",
        "fixes": [
          {
            "name": "define_method",
            "description": "Define the method",
            "condition": "is_user_class({1})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_method_definition", "name": "{0}"}
            ]
          },
          {
            "name": "fix_method_name",
            "description": "Fix method name typo",
            "condition": "has_similar_method({1}, {0})",
            "confidence": 0.9,
            "actions": [
              {"type": "correct_method_name"}
            ]
          },
          {
            "name": "check_nil",
            "description": "Check for nil",
            "condition": "nil_class({1})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_nil_check"}
            ]
          },
          {
            "name": "include_module",
            "description": "Include module with method",
            "condition": "method_in_module({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "include_module", "with_method": "{0}"}
            ]
          }
        ]
      },
      "private_method": {
        "message": "private method `{0}' called",
        "fixes": [
          {
            "name": "make_public",
            "description": "Make method public",
            "confidence": 0.8,
            "actions": [
              {"type": "change_visibility", "to": "public"}
            ]
          },
          {
            "name": "use_send",
            "description": "Use send to call private method",
            "confidence": 0.75,
            "actions": [
              {"type": "use_send_method"}
            ]
          }
        ]
      }
    },
    "ArgumentError": {
      "wrong_number_of_arguments": {
        "message": "wrong number of arguments (given {0}, expected {1})",
        "category": "Argument",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_argument_count",
            "description": "Match expected arguments",
            "confidence": 0.9,
            "actions": [
              {"type": "adjust_arguments", "expected": "{1}"}
            ]
          },
          {
            "name": "add_default_params",
            "description": "Add default parameters",
            "condition": "method_modifiable",
            "confidence": 0.85,
            "actions": [
              {"type": "add_default_parameters"}
            ]
          },
          {
            "name": "use_splat",
            "description": "Use splat operator",
            "condition": "variable_args",
            "confidence": 0.8,
            "actions": [
              {"type": "add_splat_operator"}
            ]
          }
        ]
      },
      "invalid_argument": {
        "message": "invalid argument",
        "fixes": [
          {
            "name": "validate_argument",
            "description": "Validate argument type",
            "confidence": 0.8,
            "actions": [
              {"type": "add_argument_validation"}
            ]
          }
        ]
      }
    },
    "TypeError": {
      "no_implicit_conversion": {
        "message": "no implicit conversion of {0} into {1}",
        "category": "Type",
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
            "name": "to_method",
            "description": "Use to_* method",
            "condition": "has_converter_method({0}, {1})",
            "confidence": 0.9,
            "actions": [
              {"type": "call_converter_method"}
            ]
          }
        ]
      },
      "wrong_argument_type": {
        "message": "wrong argument type {0} (expected {1})",
        "fixes": [
          {
            "name": "convert_type",
            "description": "Convert to expected type",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_argument", "to": "{1}"}
            ]
          },
          {
            "name": "validate_input",
            "description": "Add type validation",
            "confidence": 0.8,
            "actions": [
              {"type": "add_type_check", "expected": "{1}"}
            ]
          }
        ]
      }
    },
    "LoadError": {
      "cannot_load": {
        "message": "cannot load such file -- {0}",
        "category": "Load",
        "severity": "Error",
        "fixes": [
          {
            "name": "gem_install",
            "description": "Install gem",
            "condition": "is_gem({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "command", "command": "gem install {0}"}
            ]
          },
          {
            "name": "add_to_gemfile",
            "description": "Add to Gemfile",
            "condition": "has_gemfile",
            "confidence": 0.85,
            "actions": [
              {"type": "add_to_gemfile", "gem": "{0}"},
              {"type": "command", "command": "bundle install"}
            ]
          },
          {
            "name": "fix_require_path",
            "description": "Fix require path",
            "condition": "file_exists_elsewhere({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "fix_require_path", "file": "{0}"}
            ]
          },
          {
            "name": "use_require_relative",
            "description": "Use require_relative",
            "condition": "local_file({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "change_to_require_relative"}
            ]
          }
        ]
      }
    },
    "RuntimeError": {
      "runtime_error": {
        "message": "{0}",
        "category": "Runtime",
        "severity": "Error",
        "fixes": [
          {
            "name": "handle_error",
            "description": "Add error handling",
            "confidence": 0.8,
            "actions": [
              {"type": "wrap_with_rescue"}
            ]
          }
        ]
      }
    },
    "StandardError": {
      "standard_error": {
        "message": "{0}",
        "category": "Standard",
        "severity": "Error",
        "fixes": [
          {
            "name": "rescue_error",
            "description": "Add rescue block",
            "confidence": 0.85,
            "actions": [
              {"type": "add_rescue_block"}
            ]
          }
        ]
      }
    },
    "ZeroDivisionError": {
      "divided_by_zero": {
        "message": "divided by 0",
        "category": "Math",
        "severity": "Error",
        "fixes": [
          {
            "name": "check_zero",
            "description": "Check for zero before division",
            "confidence": 0.95,
            "actions": [
              {"type": "add_zero_check"}
            ]
          },
          {
            "name": "use_float",
            "description": "Use float division",
            "condition": "integer_division",
            "confidence": 0.8,
            "actions": [
              {"type": "convert_to_float"}
            ]
          }
        ]
      }
    },
    "IndexError": {
      "index_out_of_range": {
        "message": "index {0} out of range",
        "category": "Index",
        "severity": "Error",
        "fixes": [
          {
            "name": "check_bounds",
            "description": "Add bounds check",
            "confidence": 0.9,
            "actions": [
              {"type": "add_bounds_check"}
            ]
          },
          {
            "name": "use_safe_access",
            "description": "Use safe array access",
            "confidence": 0.85,
            "actions": [
              {"type": "use_fetch_with_default"}
            ]
          }
        ]
      }
    },
    "RegexpError": {
      "invalid_regexp": {
        "message": "invalid regular expression",
        "category": "Regexp",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_regexp",
            "description": "Fix regular expression syntax",
            "confidence": 0.8,
            "actions": [
              {"type": "validate_regexp_syntax"}
            ]
          },
          {
            "name": "escape_special_chars",
            "description": "Escape special characters",
            "confidence": 0.85,
            "actions": [
              {"type": "escape_regexp_chars"}
            ]
          }
        ]
      }
    },
    "Encoding::UndefinedConversionError": {
      "undefined_conversion": {
        "message": "undefined conversion from {0} to {1}",
        "category": "Encoding",
        "severity": "Error",
        "fixes": [
          {
            "name": "force_encoding",
            "description": "Force encoding",
            "confidence": 0.85,
            "actions": [
              {"type": "force_encoding", "to": "{1}"}
            ]
          },
          {
            "name": "encode_with_options",
            "description": "Encode with fallback options",
            "confidence": 0.8,
            "actions": [
              {"type": "encode_with_fallback"}
            ]
          }
        ]
      }
    },
    "Gem::LoadError": {
      "gem_not_found": {
        "message": "Could not find {0}",
        "category": "Gem",
        "severity": "Error",
        "fixes": [
          {
            "name": "bundle_install",
            "description": "Run bundle install",
            "confidence": 0.95,
            "actions": [
              {"type": "command", "command": "bundle install"}
            ]
          },
          {
            "name": "add_gem_source",
            "description": "Add gem source",
            "condition": "private_gem",
            "confidence": 0.8,
            "actions": [
              {"type": "add_gem_source"}
            ]
          }
        ]
      }
    },
    "Rails": {
      "uninitialized_constant_controller": {
        "message": "uninitialized constant {0}Controller",
        "category": "Rails",
        "severity": "Error",
        "fixes": [
          {
            "name": "generate_controller",
            "description": "Generate Rails controller",
            "confidence": 0.85,
            "actions": [
              {"type": "command", "command": "rails generate controller {0}"}
            ]
          }
        ]
      },
      "undefined_method_for_nil": {
        "message": "undefined method `{0}' for nil:NilClass",
        "fixes": [
          {
            "name": "add_presence_check",
            "description": "Add presence check",
            "confidence": 0.9,
            "actions": [
              {"type": "add_safe_navigation"}
            ]
          },
          {
            "name": "use_try",
            "description": "Use try method",
            "condition": "rails_app",
            "confidence": 0.85,
            "actions": [
              {"type": "use_try_method"}
            ]
          }
        ]
      },
      "routing_error": {
        "message": "No route matches",
        "fixes": [
          {
            "name": "add_route",
            "description": "Add route to routes.rb",
            "confidence": 0.85,
            "actions": [
              {"type": "add_to_routes"}
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
mkdir -p "$SCRIPT_DIR/patterns/databases/ruby"
generate_ruby_patterns > "$SCRIPT_DIR/patterns/databases/ruby/comprehensive_patterns.json"
echo "Generated comprehensive Ruby patterns"