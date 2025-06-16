# Claude Code Integration Guide

This guide explains how to use the Build Fix Agent with your Claude Code subscription, without needing API keys.

## Quick Start

If you're using Claude Code, the agent automatically detects it and switches to interactive mode:

```bash
./autofix.sh
```

## Features

### 1. Interactive Mode (Default)

When running inside Claude Code, the agent:
- Detects your project language automatically
- Runs the build and captures all errors
- Generates a formatted request you can paste into Claude
- Provides clear instructions for applying fixes

```bash
# Run interactive mode explicitly
./autofix.sh claude interactive

# Or just
./claude_code_integration.sh
```

### 2. Apply Fixes from Claude

After Claude provides fixes, save them to a file and apply:

```bash
./autofix.sh claude apply-fixes response.md
```

### 3. MCP Server Integration (Advanced)

For seamless integration, set up the MCP server:

```bash
# Generate configuration
./autofix.sh claude mcp-setup

# Add to your Claude Code settings.json:
{
  "mcp.servers": {
    "build-fix": {
      "command": "/path/to/BuildFixAgents/claude_code_integration.sh",
      "args": ["mcp-serve"]
    }
  }
}
```

Then in Claude Code, you can use commands like:
- `@build-fix analyze-errors`
- `@build-fix apply-fix [file] [line] [fix]`
- `@build-fix run-build`

## How It Works

1. **Error Detection**: The agent runs your build command and captures all errors
2. **Context Gathering**: It collects relevant code snippets around each error
3. **Request Generation**: Creates a structured request with all error details
4. **Interactive Fix**: You paste this into Claude Code for analysis
5. **Automated Application**: Claude's fixes can be automatically applied

## Supported Languages

- C# (.NET)
- Python
- JavaScript/TypeScript
- Go
- Rust
- Java
- C/C++

## Example Workflow

1. Run the agent:
   ```bash
   ./autofix.sh
   ```

2. Copy the generated request and paste into Claude Code

3. Claude analyzes and provides fixes in JSON format:
   ```json
   {
     "fixes": [
       {
         "file": "src/Example.cs",
         "line": 42,
         "error": "CS0246",
         "original": "List<string>",
         "fixed": "System.Collections.Generic.List<string>",
         "explanation": "Adding full namespace qualification"
       }
     ]
   }
   ```

4. Save Claude's response to a file and apply:
   ```bash
   ./autofix.sh claude apply-fixes claude_response.md
   ```

## Benefits

- **No API Keys Required**: Uses your existing Claude Code subscription
- **Context-Aware**: Claude sees your full code context
- **Interactive**: You can ask follow-up questions
- **Safe**: Review fixes before applying
- **Multi-Language**: Works with any supported language

## Troubleshooting

### Claude Code Not Detected

If the agent doesn't auto-detect Claude Code:
```bash
# Force Claude mode
./autofix.sh claude interactive
```

### MCP Server Issues

Check the MCP server is running:
```bash
# Test MCP server
echo '{"method":"run-build","id":1}' | ./claude_code_integration.sh mcp-serve
```

### Build Command Not Found

The agent tries to auto-detect your build command. Override if needed:
```bash
# Set custom build command
export BUILD_COMMAND="npm run build"
./autofix.sh
```

## Advanced Usage

### Custom Error Patterns

Create `.claude_patterns.json` in your project:
```json
{
  "patterns": {
    "custom_error": {
      "regex": "MyError: (.*)",
      "fix_hint": "Check configuration file"
    }
  }
}
```

### Batch Processing

For large projects, process in batches:
```bash
# Limit to specific directories
export FIX_PATHS="src/core src/utils"
./autofix.sh
```

## Security Notes

- The agent never sends code to external APIs when in Claude Code mode
- All processing happens locally or through your Claude Code interface
- No credentials or API keys are stored or transmitted

## Getting Help

- Run `./autofix.sh help` for command options
- Check `logs/ai_fixer.log` for detailed logs
- Report issues at the project repository