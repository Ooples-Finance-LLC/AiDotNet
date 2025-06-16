#!/bin/bash

# State Maintenance Script
# Run periodically to keep state clean and valid

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/state"

# Source validators
source "$SCRIPT_DIR/state_validator.sh"
source "$SCRIPT_DIR/state_sync.sh"

echo "=== State Maintenance Starting ==="

# 1. Validate structure
echo "Validating state structure..."
validate_state_structure

# 2. Clean stale files
echo "Cleaning stale state files..."
clean_stale_state 1440  # 24 hours

# 3. Repair any issues
echo "Repairing state issues..."
repair_state

# 4. Update state metadata
cat > "$STATE_DIR/state_info.json" << JSON
{
  "last_maintenance": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "2.0",
  "health": "good"
}
JSON

echo "=== State Maintenance Complete ==="
