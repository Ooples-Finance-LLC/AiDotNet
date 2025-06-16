# BuildFixAgents Quick Reference Card

## 🚀 Essential Commands

### Basic Operations
```bash
# Fix all errors
./autofix.sh

# Fix specific error type
./autofix.sh CS0101

# Run in batch mode (fast)
./autofix_batch.sh run

# Start self-improving system
./start_self_improving_system.sh auto

# Interactive mode
./start_self_improving_system.sh
```

### Debug Commands
```bash
# Enable debug mode
DEBUG=true ./autofix.sh

# Full verbosity
DEBUG=true VERBOSE=true ./autofix.sh

# Trace execution
bash -x ./autofix.sh

# Test mode (no modifications)
TEST_MODE=true ./autofix.sh
```

### Agent Management
```bash
# Initialize coordinator
./enhanced_coordinator_v2.sh init

# Deploy agents
./enhanced_coordinator_v2.sh deploy

# Check status
./enhanced_coordinator_v2.sh status

# Generate reports
./enhanced_coordinator_v2.sh report
```

## 📁 Key File Locations

### Core Scripts
```
autofix.sh                    # Main fix orchestrator
autofix_batch.sh             # Batch processing
enhanced_coordinator_v2.sh    # Agent coordinator
start_self_improving_system.sh # Full system launcher
```

### Agent Scripts
```
# Management Layer
architect_agent_v2.sh        # Strategic planning
project_manager_agent.sh     # Project oversight
scrum_master_agent.sh        # Team coordination

# Operational Layer
performance_agent_v2.sh      # Performance monitoring
learning_agent.sh            # Pattern learning
metrics_collector_agent.sh   # Metrics collection

# Implementation Layer
dev_agent_core_fix.sh       # Core fixes
dev_agent_patterns.sh       # Pattern management
generic_error_agent.sh      # Error detection
```

### Configuration & State
```
state/
├── state_info.json         # Global state
├── agent_specifications.json # Agent configs
├── hardware_profile.json   # System capabilities
├── coordinator/           # Coordination state
├── learning/             # Learning data
└── metrics/              # Performance metrics

patterns/
├── csharp_patterns.json   # C# patterns
├── python_patterns.json   # Python patterns
└── [language]_patterns.json

logs/
├── agent_coordination.log # Main log
├── error_detection.log   # Error logs
└── performance.log       # Performance logs
```

## 🛠️ Environment Variables

```bash
# Core Variables
DEBUG=true              # Enable debug output
VERBOSE=true           # Verbose logging
TEST_MODE=true         # No file modifications
DISABLE_FILE_MOD=true  # Disable file changes

# Performance Tuning
BATCH_SIZE=10          # Errors per batch
MAX_TIME=120           # Max execution time (seconds)
PARALLEL_AGENTS=4      # Concurrent agents

# Feature Flags
ENABLE_LEARNING=true   # Enable learning system
ENABLE_METRICS=true    # Enable metrics collection
ENABLE_CACHE=true      # Enable caching
```

## 🔧 Common Tasks

### Adding a New Error Pattern
```bash
# 1. Edit pattern file
vim patterns/csharp_patterns.json

# 2. Add pattern entry
{
  "CS0XXX": {
    "description": "Error description",
    "pattern": "regex pattern",
    "fix": "fix template",
    "confidence": 0.9
  }
}

# 3. Validate pattern
./pattern_validator.sh validate CS0XXX

# 4. Test fix
./test_single_fix.sh CS0XXX
```

### Creating a New Agent
```bash
# 1. Copy template
cp templates/agent_template.sh my_agent.sh

# 2. Implement agent logic
vim my_agent.sh

# 3. Register agent
./enhanced_coordinator_v2.sh register my_agent

# 4. Test agent
./test_agent.sh my_agent
```

### Debugging Issues
```bash
# Check recent errors
tail -f logs/error_detection.log

# Monitor agent communication
watch -n 1 'jq .messages state/scrum_master/communications/message_board.json'

# View agent status
cat state/architecture/agent_manifest.json | jq

# Check performance metrics
./performance_agent_v2.sh report
```

## 📊 Key Metrics

### Success Metrics
```bash
# View success rates
jq '.metrics.success_rate' state/learning/learning_model.json

# Error fix count
jq '.total_errors_fixed' state/state_info.json

# Performance stats
cat state/performance/performance_report.json
```

### System Health
```bash
# Quick health check
./health_check.sh

# Detailed diagnostics
./diagnostic_tool.sh --full

# Resource usage
./performance_agent_v2.sh diagnose
```

## 🚨 Troubleshooting

### Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| "No errors found" | Clear cache: `rm -rf state/.error_count_cache` |
| Agent not responding | Reset: `./enhanced_coordinator_v2.sh reset` |
| Fix not working | Check patterns: `./pattern_validator.sh check` |
| Slow performance | Reduce batch size: `BATCH_SIZE=5 ./autofix_batch.sh` |
| File not modified | Check permissions and `DISABLE_FILE_MOD` variable |

### Emergency Commands
```bash
# Kill all agents
pkill -f "agent.sh"

# Reset all state
./reset_system.sh --full

# Restore from backup
./restore_backup.sh --latest

# Safe mode
SAFE_MODE=true ./autofix.sh
```

## 💡 Pro Tips

1. **Use batch mode for speed**: `./autofix_batch.sh` is 10x faster
2. **Enable caching**: Significantly improves performance
3. **Monitor metrics**: Use dashboard for real-time insights
4. **Test patterns first**: Always validate before deploying
5. **Check logs**: Most issues are logged with solutions

## 🔗 Useful Links

- **Developer Guide**: `DEVELOPER_GUIDE.md`
- **Architecture**: `TECHNICAL_ARCHITECTURE.md`
- **Contributing**: `CONTRIBUTING.md`
- **API Docs**: `docs/API.md`
- **Pattern Guide**: `patterns/PATTERN_GUIDE.md`

---

*Keep this reference handy for quick lookups during development!*