#!/bin/bash

# Comprehensive SQL Error Pattern Generator
# Generates detailed patterns for SQL errors across multiple databases

generate_sql_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "sql",
  "pattern_count": 120,
  "patterns": {
    "Syntax": {
      "syntax_error": {
        "message": "syntax error at or near '{0}'",
        "category": "Syntax",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_syntax",
            "description": "Fix SQL syntax",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_sql_syntax", "near": "{0}"}
            ]
          },
          {
            "name": "add_missing_keyword",
            "description": "Add missing SQL keyword",
            "condition": "missing_keyword",
            "confidence": 0.85,
            "actions": [
              {"type": "insert_keyword"}
            ]
          },
          {
            "name": "fix_quotes",
            "description": "Fix quote mismatch",
            "condition": "unmatched_quotes",
            "confidence": 0.9,
            "actions": [
              {"type": "balance_quotes"}
            ]
          }
        ]
      },
      "missing_comma": {
        "message": "missing comma",
        "fixes": [
          {
            "name": "add_comma",
            "description": "Add missing comma",
            "confidence": 0.95,
            "actions": [
              {"type": "insert_comma_between_columns"}
            ]
          }
        ]
      },
      "unexpected_end": {
        "message": "unexpected end of SQL command",
        "fixes": [
          {
            "name": "complete_statement",
            "description": "Complete SQL statement",
            "confidence": 0.85,
            "actions": [
              {"type": "analyze_incomplete_statement"}
            ]
          },
          {
            "name": "add_semicolon",
            "description": "Add terminating semicolon",
            "confidence": 0.9,
            "actions": [
              {"type": "append", "text": ";"}
            ]
          }
        ]
      }
    },
    "Reference": {
      "column_not_exist": {
        "message": "column '{0}' does not exist",
        "category": "Reference",
        "severity": "Error",
        "fixes": [
          {
            "name": "fix_column_name",
            "description": "Fix column name typo",
            "condition": "has_similar_column({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "correct_column_name"}
            ]
          },
          {
            "name": "add_table_prefix",
            "description": "Add table alias/prefix",
            "condition": "ambiguous_column",
            "confidence": 0.85,
            "actions": [
              {"type": "qualify_column_name"}
            ]
          },
          {
            "name": "check_case",
            "description": "Fix column name case",
            "condition": "case_sensitive_db",
            "confidence": 0.85,
            "actions": [
              {"type": "fix_identifier_case"}
            ]
          }
        ]
      },
      "table_not_exist": {
        "message": "relation '{0}' does not exist",
        "fixes": [
          {
            "name": "fix_table_name",
            "description": "Fix table name typo",
            "condition": "has_similar_table({0})",
            "confidence": 0.9,
            "actions": [
              {"type": "correct_table_name"}
            ]
          },
          {
            "name": "add_schema",
            "description": "Add schema prefix",
            "condition": "table_in_different_schema({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "add_schema_prefix"}
            ]
          },
          {
            "name": "create_table",
            "description": "Create missing table",
            "confidence": 0.7,
            "actions": [
              {"type": "suggest_create_table"}
            ]
          }
        ]
      },
      "ambiguous_column": {
        "message": "column reference '{0}' is ambiguous",
        "fixes": [
          {
            "name": "qualify_column",
            "description": "Add table qualifier",
            "confidence": 0.95,
            "actions": [
              {"type": "add_table_qualifier", "column": "{0}"}
            ]
          }
        ]
      },
      "unknown_function": {
        "message": "function {0} does not exist",
        "fixes": [
          {
            "name": "fix_function_name",
            "description": "Fix function name",
            "condition": "has_similar_function({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "correct_function_name"}
            ]
          },
          {
            "name": "use_alternative",
            "description": "Use alternative function",
            "condition": "has_alternative_function({0})",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_alternative_function"}
            ]
          }
        ]
      }
    },
    "Type": {
      "type_mismatch": {
        "message": "operator does not exist: {0} {1} {2}",
        "category": "Type",
        "severity": "Error",
        "fixes": [
          {
            "name": "cast_type",
            "description": "Add type cast",
            "confidence": 0.85,
            "actions": [
              {"type": "add_type_cast"}
            ]
          },
          {
            "name": "convert_value",
            "description": "Convert value format",
            "confidence": 0.8,
            "actions": [
              {"type": "convert_value_format"}
            ]
          }
        ]
      },
      "invalid_input_syntax": {
        "message": "invalid input syntax for type {0}: \"{1}\"",
        "fixes": [
          {
            "name": "fix_format",
            "description": "Fix value format",
            "confidence": 0.85,
            "actions": [
              {"type": "format_for_type", "type": "{0}"}
            ]
          },
          {
            "name": "use_null",
            "description": "Use NULL for empty value",
            "condition": "empty_string",
            "confidence": 0.8,
            "actions": [
              {"type": "replace_with_null"}
            ]
          }
        ]
      },
      "datatype_mismatch": {
        "message": "column \"{0}\" is of type {1} but expression is of type {2}",
        "fixes": [
          {
            "name": "cast_expression",
            "description": "Cast expression to column type",
            "confidence": 0.9,
            "actions": [
              {"type": "cast_to", "type": "{1}"}
            ]
          },
          {
            "name": "alter_column",
            "description": "Alter column type",
            "condition": "can_alter_table",
            "confidence": 0.7,
            "actions": [
              {"type": "suggest_alter_column"}
            ]
          }
        ]
      }
    },
    "Constraint": {
      "unique_violation": {
        "message": "duplicate key value violates unique constraint",
        "category": "Constraint",
        "severity": "Error",
        "fixes": [
          {
            "name": "use_upsert",
            "description": "Use INSERT ... ON CONFLICT",
            "condition": "supports_upsert",
            "confidence": 0.9,
            "actions": [
              {"type": "convert_to_upsert"}
            ]
          },
          {
            "name": "check_exists",
            "description": "Check existence before insert",
            "confidence": 0.85,
            "actions": [
              {"type": "add_existence_check"}
            ]
          },
          {
            "name": "update_existing",
            "description": "Update existing record",
            "confidence": 0.8,
            "actions": [
              {"type": "change_to_update"}
            ]
          }
        ]
      },
      "foreign_key_violation": {
        "message": "violates foreign key constraint",
        "fixes": [
          {
            "name": "check_reference",
            "description": "Ensure referenced record exists",
            "confidence": 0.85,
            "actions": [
              {"type": "add_reference_check"}
            ]
          },
          {
            "name": "insert_parent",
            "description": "Insert parent record first",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_parent_insert"}
            ]
          },
          {
            "name": "cascade_option",
            "description": "Add CASCADE option",
            "condition": "delete_operation",
            "confidence": 0.75,
            "actions": [
              {"type": "add_cascade"}
            ]
          }
        ]
      },
      "not_null_violation": {
        "message": "null value in column \"{0}\" violates not-null constraint",
        "fixes": [
          {
            "name": "provide_value",
            "description": "Provide value for column",
            "confidence": 0.9,
            "actions": [
              {"type": "add_column_value", "column": "{0}"}
            ]
          },
          {
            "name": "use_default",
            "description": "Use DEFAULT value",
            "condition": "has_default({0})",
            "confidence": 0.85,
            "actions": [
              {"type": "use_default_keyword"}
            ]
          }
        ]
      },
      "check_violation": {
        "message": "new row violates check constraint",
        "fixes": [
          {
            "name": "fix_value",
            "description": "Fix value to satisfy constraint",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_check_constraint"}
            ]
          }
        ]
      }
    },
    "Permission": {
      "permission_denied": {
        "message": "permission denied for {0} {1}",
        "category": "Permission",
        "severity": "Error",
        "fixes": [
          {
            "name": "grant_permission",
            "description": "Grant required permission",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest_grant", "object": "{1}", "permission": "{0}"}
            ]
          },
          {
            "name": "use_different_user",
            "description": "Connect as privileged user",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_user_change"}
            ]
          }
        ]
      }
    },
    "Transaction": {
      "deadlock_detected": {
        "message": "deadlock detected",
        "category": "Transaction",
        "severity": "Error",
        "fixes": [
          {
            "name": "retry_transaction",
            "description": "Retry the transaction",
            "confidence": 0.9,
            "actions": [
              {"type": "add_retry_logic"}
            ]
          },
          {
            "name": "reorder_operations",
            "description": "Reorder operations",
            "confidence": 0.8,
            "actions": [
              {"type": "suggest_operation_order"}
            ]
          }
        ]
      },
      "lock_timeout": {
        "message": "canceling statement due to lock timeout",
        "fixes": [
          {
            "name": "increase_timeout",
            "description": "Increase lock timeout",
            "confidence": 0.85,
            "actions": [
              {"type": "set_lock_timeout", "value": "higher"}
            ]
          },
          {
            "name": "use_nowait",
            "description": "Use NOWAIT option",
            "confidence": 0.8,
            "actions": [
              {"type": "add_nowait"}
            ]
          }
        ]
      }
    },
    "Performance": {
      "statement_timeout": {
        "message": "canceling statement due to statement timeout",
        "category": "Performance",
        "severity": "Error",
        "fixes": [
          {
            "name": "optimize_query",
            "description": "Optimize query performance",
            "confidence": 0.8,
            "actions": [
              {"type": "analyze_query_plan"}
            ]
          },
          {
            "name": "add_index",
            "description": "Add index for better performance",
            "condition": "missing_index",
            "confidence": 0.85,
            "actions": [
              {"type": "suggest_index"}
            ]
          },
          {
            "name": "increase_timeout",
            "description": "Increase statement timeout",
            "confidence": 0.75,
            "actions": [
              {"type": "set_statement_timeout", "value": "higher"}
            ]
          }
        ]
      }
    },
    "Join": {
      "missing_from_clause": {
        "message": "missing FROM-clause entry for table \"{0}\"",
        "category": "Join",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_to_from",
            "description": "Add table to FROM clause",
            "confidence": 0.9,
            "actions": [
              {"type": "add_table_to_from", "table": "{0}"}
            ]
          },
          {
            "name": "add_join",
            "description": "Add proper JOIN",
            "confidence": 0.85,
            "actions": [
              {"type": "convert_to_join"}
            ]
          }
        ]
      },
      "invalid_reference": {
        "message": "invalid reference to FROM-clause entry",
        "fixes": [
          {
            "name": "fix_join_condition",
            "description": "Fix JOIN condition",
            "confidence": 0.85,
            "actions": [
              {"type": "correct_join_syntax"}
            ]
          }
        ]
      }
    },
    "Aggregate": {
      "must_appear_in_group_by": {
        "message": "column \"{0}\" must appear in the GROUP BY clause",
        "category": "Aggregate",
        "severity": "Error",
        "fixes": [
          {
            "name": "add_to_group_by",
            "description": "Add column to GROUP BY",
            "confidence": 0.95,
            "actions": [
              {"type": "add_to_group_by", "column": "{0}"}
            ]
          },
          {
            "name": "use_aggregate",
            "description": "Use aggregate function",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_with_aggregate", "function": "MAX"}
            ]
          }
        ]
      },
      "aggregate_in_where": {
        "message": "aggregate functions are not allowed in WHERE",
        "fixes": [
          {
            "name": "use_having",
            "description": "Move to HAVING clause",
            "confidence": 0.95,
            "actions": [
              {"type": "move_to_having"}
            ]
          },
          {
            "name": "use_subquery",
            "description": "Use subquery",
            "confidence": 0.85,
            "actions": [
              {"type": "wrap_in_subquery"}
            ]
          }
        ]
      }
    },
    "Subquery": {
      "subquery_returns_multiple": {
        "message": "more than one row returned by a subquery",
        "category": "Subquery",
        "severity": "Error",
        "fixes": [
          {
            "name": "use_limit",
            "description": "Add LIMIT 1",
            "confidence": 0.85,
            "actions": [
              {"type": "add_limit", "value": "1"}
            ]
          },
          {
            "name": "use_any_all",
            "description": "Use ANY/ALL operator",
            "confidence": 0.9,
            "actions": [
              {"type": "change_operator_to_any"}
            ]
          },
          {
            "name": "use_in",
            "description": "Change = to IN",
            "confidence": 0.9,
            "actions": [
              {"type": "replace", "from": "=", "to": "IN"}
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
mkdir -p "$SCRIPT_DIR/patterns/databases/sql"
generate_sql_patterns > "$SCRIPT_DIR/patterns/databases/sql/comprehensive_patterns.json"
echo "Generated comprehensive SQL patterns"