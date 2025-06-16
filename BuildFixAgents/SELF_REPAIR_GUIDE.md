# BuildFixAgents Self-Repair Guide

## When to Use Each System

### Use BuildFixAgents Directly For:
- Fixing errors in OTHER projects
- Simple syntax errors in its own code
- Pattern-based fixes it already knows

### Use Multi-Agent System For:
- Fixing BuildFixAgents architectural issues
- Working within 2-minute timeout constraints
- Complex multi-step repairs
- Adding new features to BuildFixAgents
- Improving agent coordination logic

## Working Within 2-Minute Timeout

### Batch Processing Strategy
```bash
# Use autofix_batch.sh for general fixes
./autofix_batch.sh

# Use master_fix_coordinator.sh for self-repair
./master_fix_coordinator.sh
```

### Key Commands for 2-Minute Compliance

1. **Batch Mode Autofix** (handles timeout automatically):
   ```bash
   ./autofix_batch.sh
   ```

2. **Multi-Agent Batch Repair** (for fixing BuildFixAgents):
   ```bash
   # Run in phases to stay under 2 minutes
   ./master_fix_coordinator.sh --phase 1  # Analysis
   ./master_fix_coordinator.sh --phase 2  # Planning  
   ./master_fix_coordinator.sh --phase 3  # Implementation
   ./master_fix_coordinator.sh --phase 4  # Testing
   ```

3. **Quick Fix Mode** (for specific errors):
   ```bash
   ./quick_fix_cs0101.sh  # Fast, targeted fixes
   ```

## State Management for Batch Processing

The system maintains state between runs:
- `state/agent_specifications.json` - Current fix plan
- `state/coordinator/coordination_state.json` - Progress tracking
- `state/.error_count_cache` - Error counting cache

## Best Practices

1. **Always use batch mode** when working with large codebases
2. **Run coordinator phases separately** to avoid timeout
3. **Monitor progress** with metrics dashboard:
   ```bash
   ./metrics_collector_agent.sh dashboard
   ```

4. **Use state persistence** to continue from interruptions:
   ```bash
   ./state/state_management/state_sync.sh
   ```

## Example: Fixing BuildFixAgents Within 2-Minute Limit

```bash
# Phase 1: Analysis (< 2 minutes)
timeout 110s ./master_fix_coordinator.sh --phase analysis

# Phase 2: Deploy fix agents (< 2 minutes)  
timeout 110s ./master_fix_coordinator.sh --phase deploy

# Phase 3: Apply fixes in batches (< 2 minutes each)
timeout 110s ./master_fix_coordinator.sh --phase fix --batch 1
timeout 110s ./master_fix_coordinator.sh --phase fix --batch 2

# Phase 4: Validate (< 2 minutes)
timeout 110s ./master_fix_coordinator.sh --phase validate
```

## Monitoring Timeout Usage

Use debug mode to track execution time:
```bash
BUILDFIX_DEBUG=true BUILDFIX_TIMING=true ./autofix_batch.sh
```

This will show:
- Time spent on each operation
- Remaining time before timeout
- Automatic batch size adjustment

## Conclusion

For fixing BuildFixAgents itself, especially with the 2-minute constraint, **always use the multi-agent system** with batch processing. The tool can fix simple issues in its own code, but complex architectural improvements require the full multi-agent coordination system.