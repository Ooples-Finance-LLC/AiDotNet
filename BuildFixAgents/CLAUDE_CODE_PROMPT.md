# Claude Code Build Fix Agent - User Prompts

## 🎯 Simplest Prompt (Recommended)

Just paste this into Claude Code:

```
Please help me fix all build errors in my project using the ZeroDev BuildFixAgents tool (https://github.com/ooples/ZeroDev).
```

That's it! The tool will automatically detect everything and show you fixes before applying them.

## 📋 Alternative Prompts for Specific Needs

### Quick Fix Without Review
```
Please run ZeroDev BuildFixAgents in auto mode to fix all my build errors without asking for confirmation.
```

### Focus on Specific Language
```
Please fix only the Python errors in my project using ZeroDev BuildFixAgents.
```

### Custom Build Command
```
Please fix build errors using ZeroDev BuildFixAgents with the build command: npm run test:unit
```

### Safe Mode (Conservative Fixes Only)
```
Please fix build errors using ZeroDev BuildFixAgents in safe mode - only apply fixes with 95%+ confidence.
```

## Detailed Usage Examples

### When You Have a Complex Multi-Language Project:
```
My project has a React frontend, Python backend, and SQL scripts. Please use ZeroDev BuildFixAgents to fix all build errors across all components.
```

### When Your Build Process is Unique:
```
Please fix build errors using ZeroDev BuildFixAgents. My project uses a custom build script: ./scripts/build.sh --production
```

### When You Want Specific Behavior:
```
Using ZeroDev BuildFixAgents, please:
1. Fix only critical errors (not warnings)
2. Don't modify any test files
3. Preserve my code formatting
4. Show me a summary before applying fixes
```

### When Previous Fixes Didn't Work:
```
The build is still failing after fixes. Please run ZeroDev BuildFixAgents with AI-enhanced mode to handle complex errors that patterns might have missed.
```

## Advanced Options

### With Specific Error Focus:
```
Please run the ZeroDev BuildFixAgents autofix tool focusing on:
- Type errors and missing imports
- Following my project's coding standards
- Preserving existing code style
- Creating minimal, targeted fixes

Build command: [YOUR BUILD COMMAND]
Project path: [YOUR PROJECT PATH]
```

### With Testing After Fixes:
```
Please run the ZeroDev BuildFixAgents autofix tool and after fixing errors:
1. Run the test suite to verify fixes
2. Check for any regression issues  
3. Validate the build succeeds
4. Run linting/formatting checks

Build command: [BUILD COMMAND]
Test command: [TEST COMMAND]
Project path: [PROJECT PATH]
```

## What Happens When You Use These Prompts

When you provide these prompts to Claude Code, it will:

1. **Clone/Access the BuildFixAgents tool** from the ZeroDev repository
2. **Analyze your project** to understand its structure and language
3. **Run your build command** to capture current errors
4. **Apply pattern-based fixes** using the 1,670+ patterns for 11 languages
5. **Use AI for complex errors** that don't match patterns
6. **Show you proposed fixes** in interactive mode before applying
7. **Apply approved fixes** to your codebase
8. **Re-run builds** to verify fixes work
9. **Provide a summary** of all changes made

## Best Practices

1. **Always use interactive mode** for first-time runs to review fixes
2. **Commit your code** before running to easily revert if needed
3. **Specify your exact build command** for best results
4. **Include test commands** to verify fixes don't break functionality
5. **Review the summary** to understand what was changed

## Troubleshooting

If the autofix tool doesn't work as expected, try:

1. Being more specific about your project structure
2. Providing example error messages you're seeing
3. Specifying the exact language version (e.g., Python 3.9, Node 18)
4. Asking Claude Code to run in debug mode for more details

## Example Success Flow

```
You: [Paste one of the prompts above with your project details]

Claude Code: I'll help you fix build errors using the BuildFixAgents tool. Let me:
1. Access the tool from the ZeroDev repository
2. Analyze your project at /your/path
3. Run your build command: dotnet build
4. Detect and fix errors...

[Shows detected errors and proposed fixes]

Would you like me to apply these fixes? (y/n)

You: y

Claude Code: Applying fixes...
✓ Fixed 23 type errors
✓ Added 5 missing imports  
✓ Resolved 3 naming conflicts
✓ Build now succeeds!

Summary: Fixed 31 errors across 12 files.
```

## Privacy & Security

- The tool runs entirely in your Claude Code environment
- No code is sent to external servers
- All fixes are applied locally
- You maintain full control over what changes are accepted

## Getting Help

If you need assistance:
1. Ask Claude Code to explain what the tool is doing
2. Request to see the pattern database for your language
3. Ask for manual review of specific complex errors
4. Request debugging output for troubleshooting