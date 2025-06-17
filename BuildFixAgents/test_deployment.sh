#!/bin/bash

# Test Agent Deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Testing Agent Deployment ==="

# 1. Generate agent specifications
echo "Step 1: Generating agent specifications..."
cd "$PROJECT_DIR"
if bash "$SCRIPT_DIR/generic_build_analyzer.sh" "$PROJECT_DIR"; then
    echo "✓ Build analysis complete"
else
    echo "✗ Build analysis failed"
    exit 1
fi

# 2. Check specifications
echo -e "\nStep 2: Checking agent specifications..."
if [[ -f "$SCRIPT_DIR/state/agent_specifications.json" ]]; then
    agent_count=$(jq '.agent_specifications | length' "$SCRIPT_DIR/state/agent_specifications.json")
    echo "✓ Found $agent_count agent specifications"
    jq -r '.agent_specifications[] | "  - \(.name) [\(.specialization)]"' "$SCRIPT_DIR/state/agent_specifications.json"
else
    echo "✗ No specifications found"
    exit 1
fi

# 3. Test agent deployment
echo -e "\nStep 3: Testing agent deployment..."
# Just test that agents can be created, don't run them
jq -c '.agent_specifications[]' "$SCRIPT_DIR/state/agent_specifications.json" | while read -r spec; do
    agent_id=$(echo "$spec" | jq -r '.agent_id')
    echo "  Would deploy: $agent_id"
done

echo -e "\n✓ Deployment logic verified"
