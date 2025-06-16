#!/bin/bash

# C# Error Pattern Generator
# Generates comprehensive patterns for C# compilation errors

generate_csharp_patterns() {
    cat << 'EOF'
{
  "version": "2.0.0",
  "language": "csharp",
  "pattern_count": 50,
  "patterns": {
    "CS0104": {
      "message": "'{0}' is an ambiguous reference between '{1}' and '{2}'",
      "category": "Name Resolution",
      "severity": "Error",
      "fixes": [
        {
          "name": "qualify_with_namespace",
          "description": "Fully qualify the type name",
          "confidence": 0.95,
          "actions": [
            {"type": "replace", "from": "IQuantizedModel<", "to": "AiDotNet.Interfaces.IQuantizedModel<"},
            {"type": "replace", "from": "IPrunedModel<", "to": "AiDotNet.Interfaces.IPrunedModel<"}
          ]
        },
        {
          "name": "add_using_alias",
          "description": "Add using alias",
          "confidence": 0.85,
          "actions": [
            {"type": "insert", "text": "using IQuantizedModel = AiDotNet.Interfaces.IQuantizedModel;", "position": "after_usings"}
          ]
        }
      ]
    },
    "CS0305": {
      "message": "Using the generic type '{0}' requires {1} type arguments",
      "category": "Generic Types",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_type_arguments",
          "description": "Add required type arguments",
          "confidence": 0.9,
          "actions": [
            {"type": "replace", "from": "CalibrationData>", "to": "CalibrationData<T>>"},
            {"type": "replace", "from": "new CalibrationData$", "to": "new CalibrationData<T>"}
          ]
        }
      ]
    },
    "CS0453": {
      "message": "The type '{0}' must be a non-nullable value type in order to use it as parameter '{1}'",
      "category": "Type Constraints",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_struct_constraint",
          "description": "Add struct constraint to type parameter",
          "confidence": 0.85,
          "actions": [
            {"type": "add_constraint", "constraint": "where T : struct"}
          ]
        }
      ]
    },
    "CS0246": {
      "message": "The type or namespace name '{0}' could not be found",
      "category": "Missing Reference",
      "severity": "Error",
      "fixes": [
        {
          "name": "add_using",
          "description": "Add missing using directive",
          "confidence": 0.9,
          "actions": [
            {"type": "add_using", "namespace": "auto_detect"}
          ]
        }
      ]
    },
    "CS0103": {
      "message": "The name '{0}' does not exist in the current context",
      "category": "Name Resolution",
      "severity": "Error",
      "fixes": [
        {
          "name": "fix_typo",
          "description": "Fix possible typo",
          "condition": "has_similar_name",
          "confidence": 0.85,
          "actions": [
            {"type": "replace", "with": "similar_name"}
          ]
        }
      ]
    },
    "CS0029": {
      "message": "Cannot implicitly convert type '{0}' to '{1}'",
      "category": "Type Conversion",
      "severity": "Error",
      "fixes": [
        {
          "name": "explicit_cast",
          "description": "Add explicit cast",
          "confidence": 0.8,
          "actions": [
            {"type": "wrap", "template": "({1})"}
          ]
        }
      ]
    },
    "CS0111": {
      "message": "Type '{0}' already defines a member called '{1}' with the same parameter types",
      "category": "Duplicate Definition",
      "severity": "Error",
      "fixes": [
        {
          "name": "remove_duplicate",
          "description": "Remove duplicate member",
          "confidence": 0.9,
          "actions": [
            {"type": "remove_duplicate_member"}
          ]
        }
      ]
    },
    "CS0462": {
      "message": "The inherited members '{0}' and '{1}' have the same signature in type '{2}'",
      "category": "Inheritance",
      "severity": "Error",
      "fixes": [
        {
          "name": "explicit_implementation",
          "description": "Use explicit interface implementation",
          "confidence": 0.85,
          "actions": [
            {"type": "make_explicit_implementation"}
          ]
        }
      ]
    }
  }
}
EOF
}

# Run the generator
generate_csharp_patterns