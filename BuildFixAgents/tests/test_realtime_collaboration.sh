#!/bin/bash

# Test suite for Real-time Collaboration Tools

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/buildfix_collab_test_$$"
export BUILD_FIX_HOME="$TEST_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLAB_SCRIPT="$SCRIPT_DIR/realtime_collaboration.sh"

# Test utilities
test_count=0
passed_count=0
failed_count=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    test_count=$((test_count + 1))
    echo -n "Running $test_name... "
    
    if $test_function >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        passed_count=$((passed_count + 1))
    else
        echo -e "${RED}FAILED${NC}"
        failed_count=$((failed_count + 1))
    fi
}

# Setup and teardown
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
}

teardown() {
    # Kill any running WebSocket servers
    if [[ -f "$BUILD_FIX_HOME/collaboration/ws_server.pid" ]]; then
        local pid=$(cat "$BUILD_FIX_HOME/collaboration/ws_server.pid")
        kill "$pid" 2>/dev/null || true
    fi
    
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

# Test functions
test_initialization() {
    "$COLLAB_SCRIPT" init
    
    # Check directories created
    [[ -d "$BUILD_FIX_HOME/collaboration/sessions" ]] || return 1
    [[ -d "$BUILD_FIX_HOME/collaboration/workspaces" ]] || return 1
    [[ -d "$BUILD_FIX_HOME/collaboration/logs" ]] || return 1
    
    # Check config file
    [[ -f "$BUILD_FIX_HOME/collaboration/config.json" ]] || return 1
    
    # Validate config content
    local ws_port=$(jq -r '.websocket.port' "$BUILD_FIX_HOME/collaboration/config.json")
    [[ "$ws_port" == "8081" ]] || return 1
    
    return 0
}

test_create_session() {
    "$COLLAB_SCRIPT" init
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Test Session")
    [[ -n "$session_id" ]] || return 1
    
    # Check session directory
    [[ -d "$BUILD_FIX_HOME/collaboration/sessions/$session_id" ]] || return 1
    
    # Check metadata
    local metadata_file="$BUILD_FIX_HOME/collaboration/sessions/$session_id/metadata.json"
    [[ -f "$metadata_file" ]] || return 1
    
    # Validate metadata
    local session_name=$(jq -r '.name' "$metadata_file")
    [[ "$session_name" == "Test Session" ]] || return 1
    
    return 0
}

test_join_session() {
    "$COLLAB_SCRIPT" init
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Join Test")
    
    # Join session as different user
    "$COLLAB_SCRIPT" join-session "$session_id" "testuser"
    
    # Check participants
    local metadata_file="$BUILD_FIX_HOME/collaboration/sessions/$session_id/metadata.json"
    local participants=$(jq -r '.participants | length' "$metadata_file")
    [[ "$participants" -ge 2 ]] || return 1
    
    return 0
}

test_share_code() {
    "$COLLAB_SCRIPT" init
    
    # Create test file
    mkdir -p src
    echo "function test() { return 42; }" > src/test.js
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Code Share Test")
    
    # Share code
    "$COLLAB_SCRIPT" share-code "$session_id" "src/test.js"
    
    # Check shared file
    local shared_file="$BUILD_FIX_HOME/collaboration/workspaces/$session_id/src/test.js"
    [[ -f "$shared_file" ]] || return 1
    
    # Check metadata
    [[ -f "${shared_file}.meta" ]] || return 1
    
    return 0
}

test_websocket_server() {
    "$COLLAB_SCRIPT" init
    
    # Start server with custom port to avoid conflicts
    WS_PORT=18081 "$COLLAB_SCRIPT" start-server 18081 &
    local server_pid=$!
    
    # Wait for server to start
    sleep 2
    
    # Check if server is running
    if ! kill -0 "$server_pid" 2>/dev/null; then
        return 1
    fi
    
    # Check pid file
    [[ -f "$BUILD_FIX_HOME/collaboration/ws_server.pid" ]] || return 1
    
    # Kill server
    kill "$server_pid" 2>/dev/null || true
    
    return 0
}

test_share_terminal() {
    "$COLLAB_SCRIPT" init
    
    # Check if tmux is available
    if ! command -v tmux >/dev/null 2>&1; then
        echo -e "${YELLOW}SKIPPED (tmux not installed)${NC}"
        return 0
    fi
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Terminal Test")
    
    # Share terminal
    "$COLLAB_SCRIPT" share-terminal "$session_id" "test_terminal"
    
    # Check tmux session exists
    tmux has-session -t "collab_${session_id}_test_terminal" 2>/dev/null || return 1
    
    # Clean up tmux session
    tmux kill-session -t "collab_${session_id}_test_terminal" 2>/dev/null || true
    
    return 0
}

test_list_sessions() {
    "$COLLAB_SCRIPT" init
    
    # Create multiple sessions
    "$COLLAB_SCRIPT" create-session "Session 1" >/dev/null
    "$COLLAB_SCRIPT" create-session "Session 2" >/dev/null
    
    # List sessions
    local output=$("$COLLAB_SCRIPT" list)
    
    # Check output contains sessions
    echo "$output" | grep -q "Session 1" || return 1
    echo "$output" | grep -q "Session 2" || return 1
    
    return 0
}

test_debug_session() {
    "$COLLAB_SCRIPT" init
    
    # Check if node is available
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${YELLOW}SKIPPED (node not installed)${NC}"
        return 0
    fi
    
    # Create test script
    echo "console.log('debug test');" > test_debug.js
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Debug Test")
    
    # Start debug session
    "$COLLAB_SCRIPT" debug "$session_id" "test_debug.js" 19229 &
    local debug_pid=$!
    
    # Wait a moment
    sleep 1
    
    # Check debug config created
    [[ -f "$BUILD_FIX_HOME/collaboration/sessions/$session_id/debug.json" ]] || return 1
    
    # Kill debug process
    kill "$debug_pid" 2>/dev/null || true
    
    return 0
}

test_pair_programming() {
    "$COLLAB_SCRIPT" init
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Pair Programming Test")
    
    # Start pair programming
    "$COLLAB_SCRIPT" pair-program "$session_id" "driver"
    
    # Check pair programming config
    local pair_config="$BUILD_FIX_HOME/collaboration/sessions/$session_id/pair_programming.json"
    [[ -f "$pair_config" ]] || return 1
    
    # Validate config
    local driver=$(jq -r '.driver' "$pair_config")
    [[ "$driver" == "$USER" ]] || return 1
    
    return 0
}

test_activity_monitoring() {
    "$COLLAB_SCRIPT" init
    
    # Check if inotifywait is available
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo -e "${YELLOW}SKIPPED (inotify-tools not installed)${NC}"
        return 0
    fi
    
    # Create session
    local session_id=$("$COLLAB_SCRIPT" create-session "Monitor Test")
    
    # Start monitoring in background
    "$COLLAB_SCRIPT" monitor "$session_id" &
    local monitor_pid=$!
    
    # Wait for monitoring to start
    sleep 1
    
    # Create activity
    mkdir -p "$BUILD_FIX_HOME/collaboration/workspaces/$session_id"
    echo "test" > "$BUILD_FIX_HOME/collaboration/workspaces/$session_id/test.txt"
    
    # Wait for event
    sleep 1
    
    # Kill monitor
    kill "$monitor_pid" 2>/dev/null || true
    
    # Check activity log exists
    [[ -f "$BUILD_FIX_HOME/collaboration/logs/session_${session_id}_activity.log" ]] || return 1
    
    return 0
}

# Run all tests
main() {
    echo "=== Real-time Collaboration Test Suite ==="
    echo
    
    # Set up test environment
    setup
    
    # Run tests
    run_test "Initialization" test_initialization
    run_test "Create Session" test_create_session
    run_test "Join Session" test_join_session
    run_test "Share Code" test_share_code
    run_test "WebSocket Server" test_websocket_server
    run_test "Share Terminal" test_share_terminal
    run_test "List Sessions" test_list_sessions
    run_test "Debug Session" test_debug_session
    run_test "Pair Programming" test_pair_programming
    run_test "Activity Monitoring" test_activity_monitoring
    
    # Clean up
    teardown
    
    # Summary
    echo
    echo "=== Test Summary ==="
    echo "Total tests: $test_count"
    echo -e "Passed: ${GREEN}$passed_count${NC}"
    echo -e "Failed: ${RED}$failed_count${NC}"
    
    if [[ $failed_count -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi