# Build Error Fix Request

**Language:** 
**Project:** /home/ooples/AiDotNet

## Instructions for Claude Code

Please analyze and fix the following build errors. For each error:

1. Identify the root cause
2. Provide the exact fix (code changes)
3. Explain why this fix works

### Output Format Required:

```json
{
  "fixes": [
    {
      "file": "path/to/file.ext",
      "line": 123,
      "error": "CS0246",
      "original": "problematic code",
      "fixed": "corrected code",
      "explanation": "why this fixes it"
    }
  ]
}
```

## Build Errors:

```
[2025-06-16 08:46:16] BUILD_ANALYZER: === GENERIC BUILD ERROR ANALYZER STARTING ===
[2025-06-16 08:46:16] BUILD_ANALYZER: Detected language: csharp
[2025-06-16 08:46:16] BUILD_ANALYZER: Running build command: dotnet build
[2025-06-16 08:46:16] BUILD_ANALYZER: Running build with 600s timeout...
[2025-06-16 08:46:28] BUILD_ANALYZER: Build failed - analyzing errors...
[2025-06-16 08:46:28] BUILD_ANALYZER: Analyzing error patterns for csharp...
[2025-06-16 08:46:28] BUILD_ANALYZER: Error analysis complete - found 3 unique error types
[2025-06-16 08:46:28] BUILD_ANALYZER: Generating agent specifications for csharp
unknown...
[2025-06-16 08:46:28] BUILD_ANALYZER: Generated specifications for 4 specialized agents
[2025-06-16 08:46:28] BUILD_ANALYZER: === BUILD ERROR ANALYSIS COMPLETE ===

Error Category Breakdown:
------------------------

Generated Agent Specifications:
------------------------------
Agent 1: definition_conflicts_specialist
Agent 2: inheritance_override_specialist
Agent 3: definition_conflicts_specialist
Agent 4: inheritance_override_specialist
[2025-06-16 08:46:28] BUILD_ANALYZER: Analysis complete. Agent specifications saved to: /home/ooples/AiDotNet/BuildFixAgents/state/agent_specifications.json
[2025-06-16 08:46:28] BUILD_ANALYZER: Next step: Run generic_agent_coordinator.sh to deploy agents
[2025-06-16 08:46:28] BUILD_ANALYZER: Detected language: csharp
[2025-06-16 08:46:28] BUILD_ANALYZER: Running build command: dotnet build
[2025-06-16 08:46:28] BUILD_ANALYZER: Running build with 600s timeout...
[2025-06-16 08:46:35] BUILD_ANALYZER: Build failed - analyzing errors...
```

## Context Files:

