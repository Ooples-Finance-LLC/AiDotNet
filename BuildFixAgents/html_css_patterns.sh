#!/bin/bash

# Comprehensive HTML/CSS Validation Pattern Generator
# Generates detailed patterns for HTML/CSS validation errors

generate_html_css_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "html_css",
  "pattern_count": 100,
  "patterns": {
    "HTML": {
      "unclosed_tag": {
        "message": "End tag for '{0}' omitted",
        "category": "Structure",
        "severity": "Error",
        "fixes": [
          {
            "name": "close_tag",
            "description": "Add closing tag",
            "confidence": 0.95,
            "actions": [
              {"type": "add_closing_tag", "tag": "{0}"}
            ]
          },
          {
            "name": "self_close",
            "description": "Self-close tag",
            "condition": "is_void_element({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "self_close_tag"}
            ]
          }
        ]
      },
      "missing_required_attribute": {
        "message": "Required attribute '{0}' not specified",
        "fixes": [
          {
            "name": "add_attribute",
            "description": "Add required attribute",
            "confidence": 0.9,
            "actions": [
              {"type": "add_attribute", "name": "{0}", "value": ""}
            ]
          },
          {
            "name": "add_with_default",
            "description": "Add with default value",
            "condition": "has_default_value({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_attribute_with_default", "name": "{0}"}
            ]
          }
        ]
      },
      "invalid_nesting": {
        "message": "Element '{0}' not allowed as child of element '{1}'",
        "fixes": [
          {
            "name": "restructure_elements",
            "description": "Fix element nesting",
            "confidence": 0.85,
            "actions": [
              {"type": "move_to_valid_parent", "element": "{0}"}
            ]
          },
          {
            "name": "change_element",
            "description": "Change to valid element",
            "condition": "has_alternative({0}, {1})",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_element", "with": "valid_alternative"}
            ]
          }
        ]
      },
      "duplicate_id": {
        "message": "Duplicate ID '{0}'",
        "fixes": [
          {
            "name": "make_unique",
            "description": "Make ID unique",
            "confidence": 0.95,
            "actions": [
              {"type": "append_to_id", "suffix": "_2"}
            ]
          },
          {
            "name": "use_class",
            "description": "Convert to class",
            "condition": "multiple_elements_need_same_style",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_id_to_class"}
            ]
          }
        ]
      },
      "missing_alt": {
        "message": "Missing 'alt' attribute on image",
        "fixes": [
          {
            "name": "add_alt",
            "description": "Add alt attribute",
            "confidence": 0.95,
            "actions": [
              {"type": "add_attribute", "name": "alt", "value": ""}
            ]
          },
          {
            "name": "add_descriptive_alt",
            "description": "Add descriptive alt text",
            "condition": "can_infer_from_src",
            "confidence": 0.8,
            "actions": [
              {"type": "generate_alt_from_filename"}
            ]
          }
        ]
      },
      "invalid_attribute": {
        "message": "Attribute '{0}' not allowed on element '{1}'",
        "fixes": [
          {
            "name": "remove_attribute",
            "description": "Remove invalid attribute",
            "confidence": 0.9,
            "actions": [
              {"type": "remove_attribute", "name": "{0}"}
            ]
          },
          {
            "name": "use_data_attribute",
            "description": "Convert to data attribute",
            "condition": "custom_attribute",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_data_attribute", "name": "{0}"}
            ]
          }
        ]
      },
      "obsolete_element": {
        "message": "Element '{0}' is obsolete",
        "fixes": [
          {
            "name": "use_modern_element",
            "description": "Replace with modern element",
            "condition": "has_modern_replacement({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "replace_obsolete_element"}
            ]
          },
          {
            "name": "use_css",
            "description": "Replace with CSS",
            "condition": "presentational_element({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_css_styling"}
            ]
          }
        ]
      },
      "missing_doctype": {
        "message": "Missing DOCTYPE declaration",
        "fixes": [
          {
            "name": "add_html5_doctype",
            "description": "Add HTML5 DOCTYPE",
            "confidence": 0.95,
            "actions": [
              {"type": "prepend", "text": "<!DOCTYPE html>"}
            ]
          }
        ]
      },
      "invalid_entity": {
        "message": "Invalid character entity '{0}'",
        "fixes": [
          {
            "name": "fix_entity",
            "description": "Fix character entity",
            "confidence": 0.85,
            "actions": [
              {"type": "correct_entity_syntax"}
            ]
          },
          {
            "name": "use_unicode",
            "description": "Use Unicode character",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_with_unicode"}
            ]
          }
        ]
      }
    },
    "CSS": {
      "invalid_property": {
        "message": "Unknown property '{0}'",
        "category": "Property",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_typo",
            "description": "Fix property name typo",
            "condition": "has_similar_property({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "correct_property_name"}
            ]
          },
          {
            "name": "add_vendor_prefix",
            "description": "Add vendor prefix",
            "condition": "needs_prefix({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_vendor_prefixes"}
            ]
          },
          {
            "name": "remove_property",
            "description": "Remove unknown property",
            "confidence": 0.8,
            "actions": [
              {"type": "remove_declaration"}
            ]
          }
        ]
      },
      "invalid_value": {
        "message": "Invalid value '{0}' for property '{1}'",
        "fixes": [
          {
            "name": "fix_value",
            "description": "Fix property value",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest_valid_values", "property": "{1}"}
            ]
          },
          {
            "name": "add_unit",
            "description": "Add missing unit",
            "condition": "needs_unit({1})",
            "confidence": 0.9,
            "actions": [
              {"type": "add_unit", "default": "px"}
            ]
          },
          {
            "name": "fix_color",
            "description": "Fix color value",
            "condition": "is_color_property({1})",
            "confidence": 0.85,
            "actions": [
              {"type": "validate_color_format"}
            ]
          }
        ]
      },
      "syntax_error": {
        "message": "CSS syntax error: {0}",
        "fixes": [
          {
            "name": "fix_syntax",
            "description": "Fix CSS syntax",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_css_syntax", "error": "{0}"}
            ]
          },
          {
            "name": "close_block",
            "description": "Close unclosed block",
            "condition": "unclosed_block",
            "confidence": 0.9,
            "actions": [
              {"type": "add_closing_brace"}
            ]
          },
          {
            "name": "add_semicolon",
            "description": "Add missing semicolon",
            "condition": "missing_semicolon",
            "confidence": 0.95,
            "actions": [
              {"type": "append", "text": ";"}
            ]
          }
        ]
      },
      "duplicate_property": {
        "message": "Duplicate property '{0}'",
        "fixes": [
          {
            "name": "remove_duplicate",
            "description": "Remove duplicate declaration",
            "confidence": 0.9,
            "actions": [
              {"type": "keep_last_declaration"}
            ]
          },
          {
            "name": "merge_values",
            "description": "Merge property values",
            "condition": "can_merge({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "merge_declarations"}
            ]
          }
        ]
      },
      "invalid_selector": {
        "message": "Invalid selector '{0}'",
        "fixes": [
          {
            "name": "fix_selector",
            "description": "Fix selector syntax",
            "confidence": 0.85,
            "actions": [
              {"type": "validate_selector_syntax"}
            ]
          },
          {
            "name": "escape_special_chars",
            "description": "Escape special characters",
            "condition": "has_special_chars",
            "confidence": 0.8,
            "actions": [
              {"type": "escape_selector_chars"}
            ]
          }
        ]
      },
      "unsupported_feature": {
        "message": "'{0}' is not supported in {1}",
        "fixes": [
          {
            "name": "use_fallback",
            "description": "Add fallback for older browsers",
            "confidence": 0.85,
            "actions": [
              {"type": "add_fallback_declaration"}
            ]
          },
          {
            "name": "use_polyfill",
            "description": "Suggest polyfill",
            "condition": "has_polyfill({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_polyfill"}
            ]
          }
        ]
      },
      "invalid_media_query": {
        "message": "Invalid media query",
        "fixes": [
          {
            "name": "fix_media_syntax",
            "description": "Fix media query syntax",
            "confidence": 0.85,
            "actions": [
              {"type": "correct_media_query_syntax"}
            ]
          }
        ]
      },
      "missing_semicolon": {
        "message": "Missing semicolon after declaration",
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
      "invalid_import": {
        "message": "Invalid @import rule",
        "fixes": [
          {
            "name": "fix_import",
            "description": "Fix import syntax",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_import_syntax"}
            ]
          },
          {
            "name": "move_to_top",
            "description": "Move import to top",
            "condition": "not_at_top",
            "confidence": 0.9,
            "actions": [
              {"type": "move_import_to_top"}
            ]
          }
        ]
      }
    },
    "Accessibility": {
      "missing_label": {
        "message": "Form control without label",
        "category": "A11y",
        "severity": "Warning",
        "fixes": [
          {
            "name": "add_label",
            "description": "Add label element",
            "confidence": 0.9,
            "actions": [
              {"type": "add_label_element"}
            ]
          },
          {
            "name": "add_aria_label",
            "description": "Add aria-label",
            "confidence": 0.85,
            "actions": [
              {"type": "add_attribute", "name": "aria-label", "value": ""}
            ]
          }
        ]
      },
      "missing_lang": {
        "message": "Missing 'lang' attribute on html element",
        "fixes": [
          {
            "name": "add_lang",
            "description": "Add language attribute",
            "confidence": 0.95,
            "actions": [
              {"type": "add_to_html_tag", "attr": "lang", "value": "en"}
            ]
          }
        ]
      },
      "empty_heading": {
        "message": "Empty heading element",
        "fixes": [
          {
            "name": "add_content",
            "description": "Add heading content",
            "confidence": 0.85,
            "actions": [
              {"type": "add_placeholder_text"}
            ]
          },
          {
            "name": "remove_heading",
            "description": "Remove empty heading",
            "confidence": 0.8,
            "actions": [
              {"type": "remove_element"}
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
mkdir -p "$SCRIPT_DIR/patterns/databases/html_css"
generate_html_css_patterns > "$SCRIPT_DIR/patterns/databases/html_css/comprehensive_patterns.json"
echo "Generated comprehensive HTML/CSS patterns"