# Production Coordinator Guide

## Overview

The **production_coordinator.sh** is an enterprise-grade, production-ready orchestration system that addresses all concerns about parallel execution, reliability, and scalability.

## Key Production Features

### 1. **Intelligent Parallel Execution**
- **Priority-based scheduling**: Agents run in priority groups (1-7)
- **Dependency resolution**: Agents wait for their dependencies
- **Dynamic concurrency**: Adjusts based on system resources
- **Resource-aware**: Monitors CPU, memory, and disk

### 2. **Enterprise Reliability**
- **Retry logic**: Automatic retry with exponential backoff (default: 3 attempts)
- **Health monitoring**: Detects stuck/crashed agents
- **Checkpointing**: Save/restore execution state
- **Structured logging**: JSON logs for analysis
- **Lock management**: Prevents multiple instances

### 3. **Production Monitoring**
- **Real-time metrics**: Track running/completed/failed agents
- **Resource monitoring**: CPU, memory, disk usage
- **Performance tracking**: Execution time per agent
- **Comprehensive reporting**: JSON and Markdown reports

### 4. **Advanced Features**
- **Dry run mode**: Test execution without running agents
- **Hardware detection**: Auto-configures for container/VM/bare metal
- **Graceful shutdown**: Clean termination of all agents
- **State persistence**: Resume interrupted executions

## Architecture

### Agent Registry with Dependencies
```
Build Analyzer (Priority 1)
    ↓
Error Counter (Priority 1) → depends on Build Analyzer
    ↓
Error Agent (Priority 2) → depends on Build Analyzer + Error Counter
    ↓
Architecture Planning (Priority 3) → depends on Analysis
    ↓
Development Agents (Priority 4) → depend on Architecture
    ↓
Fix Specialists (Priority 5) → depend on Error Agent
    ↓
QA Automation (Priority 6) → depends on all Development
    ↓
Final QA (Priority 7) → depends on QA Automation
```

### Parallel Execution Strategy

1. **Priority Groups Execute in Order**:
   - All Priority 1 agents run first (in parallel)
   - Once complete, Priority 2 agents start
   - Continues through all priority levels

2. **Within Each Priority**:
   - Agents run in parallel up to MAX_CONCURRENT_AGENTS
   - Dependencies are checked before starting
   - Failed agents are retried automatically

3. **Resource Management**:
   - High-end system (16+ cores): 12 concurrent agents
   - Standard system (8+ cores): 8 concurrent agents
   - Limited system: 2-4 concurrent agents
   - Container environments: Adjusted limits

## Usage Examples

### Basic Production Usage
```bash
# Smart mode - adapts to error count
./production_coordinator.sh

# Parallel mode - maximum concurrency
./production_coordinator.sh parallel

# Minimal mode - essential agents only
./production_coordinator.sh minimal
```

### Advanced Usage
```bash
# Dry run to preview execution
./production_coordinator.sh smart --dry-run

# Custom concurrency and timeout
./production_coordinator.sh parallel --max-agents 10 --timeout 600

# Disable checkpoints for speed
./production_coordinator.sh --no-checkpoints

# Restore from checkpoint after interruption
./production_coordinator.sh --restore checkpoints/checkpoint_auto_20240614_120000.json
```

### Environment Variables
```bash
# Set maximum concurrent agents
export MAX_CONCURRENT_AGENTS=8

# Set agent timeout (seconds)
export AGENT_TIMEOUT=600

# Set retry attempts
export RETRY_ATTEMPTS=5

# Enable debug logging
export DEBUG=true

# Run with custom settings
./production_coordinator.sh
```

## Production Benefits

### 1. **Speed**
- Parallel execution within priority groups
- Smart dependency resolution
- Resource-optimized concurrency
- Typical execution: 2-5 minutes (vs 15-20 sequential)

### 2. **Reliability**
- Automatic retries for transient failures
- Health monitoring prevents hanging
- Checkpoints enable resume on failure
- Comprehensive error tracking

### 3. **Observability**
- Real-time status updates
- Structured JSON logs
- Performance metrics per agent
- Resource usage monitoring

### 4. **Scalability**
- Adapts to available hardware
- Container/cloud ready
- Configurable concurrency limits
- Priority-based resource allocation

## Monitoring During Execution

### Real-time Status
```bash
# Watch coordinator state
watch -n 1 'jq .metrics state/production_coordinator/coordinator_state.json'

# Monitor agent progress
tail -f state/logs/production_coordinator.jsonl | jq .

# Check specific agent logs
tail -f state/logs/agents/*/attempt_1.log
```

### Post-execution Analysis
```bash
# View summary report
cat state/production_coordinator/production_summary_*.md

# Analyze JSON report
jq '.agents | to_entries[] | select(.value.status == "failed")' \
  state/production_coordinator/production_report_*.json

# Check agent metrics
jq '.metrics' state/production_coordinator/production_report_*.json
```

## Comparison with Other Coordinators

| Feature | unified_coordinator.sh | production_coordinator.sh |
|---------|----------------------|--------------------------|
| Parallel Execution | Basic batching | Priority-based with dependencies |
| Retry Logic | ❌ No | ✅ Yes (with backoff) |
| Health Monitoring | ❌ No | ✅ Yes |
| Checkpointing | ❌ No | ✅ Yes |
| Resource Awareness | Basic | Advanced (CPU/Memory/Disk) |
| Structured Logging | Basic | JSON + Metrics |
| Dependency Resolution | ❌ No | ✅ Yes |
| Production Reports | Basic | Comprehensive JSON/MD |
| Dry Run Mode | ❌ No | ✅ Yes |
| State Persistence | ❌ No | ✅ Yes |

## Best Practices

### 1. **For Production Deployments**
```bash
# Always use production coordinator for critical work
./production_coordinator.sh smart

# Enable all safety features
./production_coordinator.sh --retry 5 --timeout 600
```

### 2. **For Development/Testing**
```bash
# Use dry run first
./production_coordinator.sh smart --dry-run

# Minimal mode for quick tests
./production_coordinator.sh minimal --no-metrics
```

### 3. **For CI/CD Integration**
```bash
# Fail fast with no retries
RETRY_ATTEMPTS=1 AGENT_TIMEOUT=120 ./production_coordinator.sh minimal

# Save artifacts
cp state/production_coordinator/production_report_*.json $ARTIFACTS_DIR/
```

### 4. **For Troubleshooting**
```bash
# Enable debug mode
DEBUG=true ./production_coordinator.sh

# Check failed agents
jq '.agents | to_entries[] | select(.value.status == "failed") | .key' \
  state/production_coordinator/coordinator_state.json

# Review agent logs
ls -la state/logs/agents/*/attempt_*.log
```

## Emergency Procedures

### Agent Stuck/Hanging
```bash
# Check running agents
ps aux | grep agent

# Kill specific agent
kill -TERM <PID>

# Coordinator will detect and handle
```

### Coordinator Crash
```bash
# Find latest checkpoint
ls -lt state/production_coordinator/checkpoints/

# Restore and continue
./production_coordinator.sh --restore checkpoints/checkpoint_auto_LATEST.json
```

### Resource Exhaustion
```bash
# Reduce concurrency
MAX_CONCURRENT_AGENTS=2 ./production_coordinator.sh

# Or use minimal mode
./production_coordinator.sh minimal
```

## Summary

The production coordinator provides:
- **True parallel execution** with intelligent scheduling
- **Production-grade reliability** with retries and monitoring
- **Enterprise features** like checkpointing and structured logging
- **Optimal performance** through resource-aware concurrency

This is the recommended coordinator for all production use cases.