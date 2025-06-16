# 🚀 Claude Code Build Fix - Quick Start

## Copy & Paste This Into Claude Code:

```
Please help me fix all build errors in my project using the ZeroDev BuildFixAgents tool (https://github.com/ooples/ZeroDev).

Run the autofix tool to detect and fix all compilation errors, showing me proposed fixes before applying them.
```

That's it! The tool will automatically:
- ✅ Use your current project directory
- ✅ Detect your programming language
- ✅ Find the right build command
- ✅ Show you fixes before applying them

## Want to Override Auto-Detection?

Only if needed, you can specify:
```
Please fix build errors using ZeroDev BuildFixAgents with:
- Build command: npm run test  
- Language: typescript
- Mode: auto (apply fixes without asking)
```

## Common Build Commands (Auto-Detected):

- **C#**: `dotnet build`
- **JavaScript/TypeScript**: `npm run build`
- **Python**: `python -m py_compile .`
- **Java**: `mvn compile` or `gradle build`
- **Go**: `go build ./...`
- **Rust**: `cargo build`
- **C++**: `make` or `cmake --build .`

## That's It! 
Claude Code will handle the rest, including:
- ✅ Downloading the fix tool
- ✅ Analyzing your errors  
- ✅ Applying 1,670+ pattern fixes
- ✅ Using AI for complex issues
- ✅ Showing you all changes
- ✅ Verifying fixes work

## Want Non-Interactive Mode?
Just change `Mode: interactive` to `Mode: auto` (but we recommend reviewing fixes first!)

---
*BuildFixAgents by ZeroDev - Enterprise-grade build fixing for everyone*