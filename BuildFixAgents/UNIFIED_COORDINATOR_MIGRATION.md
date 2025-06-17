# Unified Coordinator Migration Guide

## Overview

We've created a single **unified_coordinator.sh** that replaces the three separate coordinators:
- ❌ master_fix_coordinator.sh (sequential only)
- ❌ generic_agent_coordinator.sh (limited parallel)
- ❌ enhanced_coordinator.sh (complex setup)

## ✅ New Unified Coordinator

The **unified_coordinator.sh** combines the best features of all three:

### Features
- **6 Execution Modes** for different scenarios
- **Hardware Auto-Detection** for optimal performance
- **Smart Mode** that adapts based on error count
- **Parallel Execution** with configurable limits
- **Phase-Based Execution** for timeout compliance
- **State Persistence** for interruption recovery
- **Comprehensive Reporting** with execution summaries

### Execution Modes

#### 1. Smart Mode (Default - Recommended)
```bash
./unified_coordinator.sh
# or explicitly:
./unified_coordinator.sh smart
```
- Analyzes errors and chooses best execution strategy
- Few errors → Sequential
- Moderate errors → Phase mode
- Many errors → Parallel

#### 2. Sequential Mode
```bash
./unified_coordinator.sh sequential
```
- Runs agents one at a time (like old master_fix_coordinator)
- Use when: Order matters, debugging issues

#### 3. Parallel Mode
```bash
./unified_coordinator.sh parallel
```
- Maximum parallelization for speed
- Use when: Many independent tasks

#### 4. Phase Mode
```bash
./unified_coordinator.sh phase
```
- Sequential phases with parallel execution within each phase
- Use when: Need structure but want speed

#### 5. Full Mode
```bash
./unified_coordinator.sh full
```
- Deploys ALL available agents
- Use when: Complete system overhaul

#### 6. Minimal Mode
```bash
./unified_coordinator.sh minimal
```
- Only essential error-fixing agents
- Use when: Quick fixes needed

### Performance Comparison

| Coordinator | Execution Time (typical) | Agents | Parallelization |
|------------|-------------------------|---------|-----------------|
| master_fix_coordinator.sh | 10-20 minutes | Fixed set | ❌ None |
| generic_agent_coordinator.sh | 5-10 minutes | Dynamic | ✅ Limited (3) |
| enhanced_coordinator.sh | 3-8 minutes | Configurable | ✅ Smart |
| **unified_coordinator.sh** | **2-5 minutes** | **All modes** | **✅ Adaptive** |

### Migration Steps

1. **Replace old coordinator calls:**
```bash
# Old:
./master_fix_coordinator.sh

# New:
./unified_coordinator.sh sequential

# Better (let it choose):
./unified_coordinator.sh
```

2. **Update scripts that call coordinators:**
```bash
# Find all references
grep -r "master_fix_coordinator\|generic_agent_coordinator\|enhanced_coordinator" .

# Replace with unified_coordinator.sh
```

3. **Adjust environment variables:**
```bash
# Old way (different for each):
export MAX_AGENTS=5

# New unified way:
export MAX_CONCURRENT_AGENTS=5
```

### Configuration

#### Environment Variables
- `MAX_CONCURRENT_AGENTS`: Override auto-detected concurrency
- `PHASE_TIMEOUT`: Timeout per phase (default: 110 seconds)

#### Hardware Auto-Detection
- **High-end** (8+ cores, 16GB+ RAM): 6 concurrent agents
- **Standard** (4+ cores, 8GB+ RAM): 4 concurrent agents  
- **Limited** (< 4 cores or < 8GB RAM): 2 concurrent agents

### Examples

#### Quick Fix
```bash
# Minimal mode for quick fixes
./unified_coordinator.sh minimal
```

#### Full Build Fix
```bash
# Smart mode adapts to error count
./unified_coordinator.sh
```

#### Maximum Speed
```bash
# Force parallel with custom limit
MAX_CONCURRENT_AGENTS=8 ./unified_coordinator.sh parallel
```

#### Structured Approach
```bash
# Phase mode for organized execution
./unified_coordinator.sh phase
```

### Benefits of Unified Coordinator

1. **Single Point of Entry**: No confusion about which coordinator to use
2. **Adaptive Performance**: Automatically optimizes based on:
   - Hardware capabilities
   - Error count and complexity
   - Available resources
3. **Backward Compatible**: Supports all features from old coordinators
4. **Better Reporting**: Unified reporting format across all modes
5. **Easier Maintenance**: One script to maintain instead of three

### Deprecation Notice

The following scripts are now deprecated:
- ⚠️ master_fix_coordinator.sh → Use `unified_coordinator.sh sequential`
- ⚠️ generic_agent_coordinator.sh → Use `unified_coordinator.sh parallel`
- ⚠️ enhanced_coordinator.sh → Use `unified_coordinator.sh phase`

### Troubleshooting

#### Lock File Issues
```bash
# If you see "Another coordinator is running"
rm -f state/unified_coordinator/.lock
```

#### Performance Issues
```bash
# Check detected hardware
./unified_coordinator.sh | grep "system detected"

# Force lower concurrency
MAX_CONCURRENT_AGENTS=2 ./unified_coordinator.sh
```

#### Mode Selection
```bash
# Not sure which mode? Use smart (default)
./unified_coordinator.sh

# Need help?
./unified_coordinator.sh help
```

## Summary

The unified coordinator simplifies the BuildFixAgents system while improving performance through:
- **Smart execution mode selection**
- **Hardware-aware parallelization**
- **Unified interface for all use cases**
- **3-5x faster execution** compared to sequential mode

For most users, simply running `./unified_coordinator.sh` without arguments will provide the best results.