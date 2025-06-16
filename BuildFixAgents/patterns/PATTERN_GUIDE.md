# BuildFixAgents Pattern Library Guide

## Overview
The pattern library provides automated fix strategies for common compilation errors across multiple languages.

## Pattern Structure

Each pattern contains:
- `code`: The error code (e.g., CS0101)
- `description`: Human-readable description
- `pattern`: Regex pattern for matching
- `detection`: How to detect the error
- `fix_strategy`: The approach to fix
- `replacement`: Optional replacement template

## Supported Languages

### C# (.NET)
- 10 common error patterns
- Automatic using statement addition
- Duplicate definition removal
- Interface implementation

### Python
- 4 common error patterns
- Import fixes
- Indentation corrections

### JavaScript
- 3 common error patterns  
- Variable declarations
- Null checks

### Java
- 2 common error patterns
- Import management
- Type conversions

## Adding New Patterns

To add a new pattern:
1. Edit the appropriate language JSON file
2. Add pattern object with all required fields
3. Test with sample code
4. Document the fix strategy

## Pattern Matching Process

1. Error code extracted from build output
2. Pattern matched against database
3. Fix strategy determined
4. Fix applied with backup
5. Build verification
6. Rollback if needed

## Best Practices

- Keep patterns specific but flexible
- Always create backups
- Verify fixes compile
- Document edge cases
- Test thoroughly
