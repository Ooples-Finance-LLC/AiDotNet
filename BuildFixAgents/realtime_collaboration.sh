#!/bin/bash

# Real-time Collaboration Tools for Build Fix Agents
# Enables teams to collaborate in real-time on build fixes and code improvements

set -euo pipefail

# Configuration
COLLABORATION_DIR="${BUILD_FIX_HOME:-$HOME/.buildfix}/collaboration"
SESSION_DIR="$COLLABORATION_DIR/sessions"
WORKSPACE_DIR="$COLLABORATION_DIR/workspaces"
LOG_DIR="$COLLABORATION_DIR/logs"
CONFIG_FILE="$COLLABORATION_DIR/config.json"

# WebSocket configuration
WS_PORT="${WS_PORT:-8081}"
WS_HOST="${WS_HOST:-0.0.0.0}"

# Session management
declare -A active_sessions
declare -A user_sessions
declare -A session_participants

# Initialize collaboration system
init_collaboration() {
    mkdir -p "$SESSION_DIR" "$WORKSPACE_DIR" "$LOG_DIR"
    
    # Create default configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
    "websocket": {
        "port": $WS_PORT,
        "host": "$WS_HOST",
        "heartbeat_interval": 30,
        "max_connections": 100
    },
    "collaboration": {
        "max_participants_per_session": 10,
        "session_timeout": 3600,
        "enable_screen_sharing": true,
        "enable_voice_chat": false,
        "enable_video_chat": false
    },
    "features": {
        "live_code_sharing": true,
        "collaborative_debugging": true,
        "shared_terminal": true,
        "cursor_tracking": true,
        "presence_awareness": true,
        "chat": true
    },
    "security": {
        "require_authentication": true,
        "encryption_enabled": true,
        "session_recording": false
    }
}
EOF
    fi
    
    log_info "Real-time collaboration system initialized"
}

# WebSocket server for real-time communication
start_websocket_server() {
    local port="${1:-$WS_PORT}"
    local host="${2:-$WS_HOST}"
    
    # Create WebSocket server script
    cat > "$COLLABORATION_DIR/ws_server.js" <<'EOF'
const WebSocket = require('ws');
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Configuration
const config = JSON.parse(fs.readFileSync(process.env.CONFIG_FILE || 'config.json', 'utf8'));

// Session store
const sessions = new Map();
const userConnections = new Map();

// Create HTTP server
const server = http.createServer();

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// Message types
const MessageType = {
    // Connection management
    JOIN_SESSION: 'join_session',
    LEAVE_SESSION: 'leave_session',
    SESSION_INFO: 'session_info',
    
    // Code collaboration
    CODE_UPDATE: 'code_update',
    CURSOR_POSITION: 'cursor_position',
    SELECTION_CHANGE: 'selection_change',
    
    // Debugging
    BREAKPOINT_SET: 'breakpoint_set',
    BREAKPOINT_REMOVE: 'breakpoint_remove',
    DEBUG_STEP: 'debug_step',
    VARIABLE_INSPECT: 'variable_inspect',
    
    // Communication
    CHAT_MESSAGE: 'chat_message',
    VOICE_SIGNAL: 'voice_signal',
    
    // Terminal sharing
    TERMINAL_INPUT: 'terminal_input',
    TERMINAL_OUTPUT: 'terminal_output',
    
    // Presence
    USER_PRESENCE: 'user_presence',
    USER_STATUS: 'user_status',
    
    // System
    HEARTBEAT: 'heartbeat',
    ERROR: 'error'
};

// Session class
class CollaborationSession {
    constructor(id, creator) {
        this.id = id;
        this.creator = creator;
        this.participants = new Map();
        this.workspace = {
            files: new Map(),
            activeFile: null,
            breakpoints: new Map(),
            terminals: new Map()
        };
        this.chat = [];
        this.createdAt = Date.now();
        this.lastActivity = Date.now();
    }
    
    addParticipant(userId, ws) {
        this.participants.set(userId, {
            id: userId,
            ws: ws,
            cursor: null,
            selection: null,
            status: 'active',
            joinedAt: Date.now()
        });
        this.lastActivity = Date.now();
    }
    
    removeParticipant(userId) {
        this.participants.delete(userId);
        this.lastActivity = Date.now();
    }
    
    broadcast(message, excludeUser = null) {
        const data = JSON.stringify(message);
        this.participants.forEach((participant, userId) => {
            if (userId !== excludeUser && participant.ws.readyState === WebSocket.OPEN) {
                participant.ws.send(data);
            }
        });
    }
    
    updateCode(fileId, changes, userId) {
        if (!this.workspace.files.has(fileId)) {
            this.workspace.files.set(fileId, {
                content: '',
                version: 0,
                history: []
            });
        }
        
        const file = this.workspace.files.get(fileId);
        file.content = changes.content;
        file.version++;
        file.history.push({
            userId,
            changes,
            timestamp: Date.now()
        });
        
        this.lastActivity = Date.now();
    }
}

// Handle WebSocket connections
wss.on('connection', (ws, req) => {
    const userId = crypto.randomUUID();
    let currentSession = null;
    
    console.log(`New connection: ${userId}`);
    
    // Send welcome message
    ws.send(JSON.stringify({
        type: 'welcome',
        userId: userId,
        config: config.collaboration
    }));
    
    // Handle messages
    ws.on('message', (data) => {
        try {
            const message = JSON.parse(data);
            handleMessage(ws, userId, message, currentSession);
        } catch (error) {
            console.error('Error handling message:', error);
            ws.send(JSON.stringify({
                type: MessageType.ERROR,
                error: error.message
            }));
        }
    });
    
    // Handle disconnect
    ws.on('close', () => {
        console.log(`Connection closed: ${userId}`);
        if (currentSession) {
            handleLeaveSession(userId, currentSession);
        }
        userConnections.delete(userId);
    });
    
    // Store connection
    userConnections.set(userId, { ws, currentSession: null });
});

// Message handler
function handleMessage(ws, userId, message, currentSession) {
    switch (message.type) {
        case MessageType.JOIN_SESSION:
            currentSession = handleJoinSession(ws, userId, message);
            break;
            
        case MessageType.LEAVE_SESSION:
            handleLeaveSession(userId, currentSession);
            currentSession = null;
            break;
            
        case MessageType.CODE_UPDATE:
            handleCodeUpdate(userId, message, currentSession);
            break;
            
        case MessageType.CURSOR_POSITION:
            handleCursorPosition(userId, message, currentSession);
            break;
            
        case MessageType.SELECTION_CHANGE:
            handleSelectionChange(userId, message, currentSession);
            break;
            
        case MessageType.BREAKPOINT_SET:
            handleBreakpointSet(userId, message, currentSession);
            break;
            
        case MessageType.CHAT_MESSAGE:
            handleChatMessage(userId, message, currentSession);
            break;
            
        case MessageType.TERMINAL_INPUT:
            handleTerminalInput(userId, message, currentSession);
            break;
            
        case MessageType.USER_STATUS:
            handleUserStatus(userId, message, currentSession);
            break;
            
        case MessageType.HEARTBEAT:
            ws.send(JSON.stringify({ type: MessageType.HEARTBEAT }));
            break;
    }
}

// Session handlers
function handleJoinSession(ws, userId, message) {
    const { sessionId, create } = message;
    let session;
    
    if (create) {
        // Create new session
        session = new CollaborationSession(sessionId || crypto.randomUUID(), userId);
        sessions.set(session.id, session);
    } else {
        // Join existing session
        session = sessions.get(sessionId);
        if (!session) {
            ws.send(JSON.stringify({
                type: MessageType.ERROR,
                error: 'Session not found'
            }));
            return null;
        }
    }
    
    // Add participant
    session.addParticipant(userId, ws);
    
    // Update user connection
    const userConn = userConnections.get(userId);
    if (userConn) {
        userConn.currentSession = session.id;
    }
    
    // Send session info
    ws.send(JSON.stringify({
        type: MessageType.SESSION_INFO,
        session: {
            id: session.id,
            participants: Array.from(session.participants.keys()),
            workspace: session.workspace,
            chat: session.chat.slice(-50) // Last 50 messages
        }
    }));
    
    // Notify other participants
    session.broadcast({
        type: MessageType.USER_PRESENCE,
        action: 'joined',
        userId: userId,
        timestamp: Date.now()
    }, userId);
    
    return session;
}

function handleLeaveSession(userId, session) {
    if (!session) return;
    
    const sessionObj = sessions.get(session.id || session);
    if (!sessionObj) return;
    
    // Remove participant
    sessionObj.removeParticipant(userId);
    
    // Notify other participants
    sessionObj.broadcast({
        type: MessageType.USER_PRESENCE,
        action: 'left',
        userId: userId,
        timestamp: Date.now()
    });
    
    // Clean up empty sessions
    if (sessionObj.participants.size === 0) {
        sessions.delete(sessionObj.id);
    }
}

// Code collaboration handlers
function handleCodeUpdate(userId, message, currentSession) {
    if (!currentSession) return;
    
    const session = sessions.get(currentSession.id || currentSession);
    if (!session) return;
    
    const { fileId, changes } = message;
    
    // Update code in session
    session.updateCode(fileId, changes, userId);
    
    // Broadcast to other participants
    session.broadcast({
        type: MessageType.CODE_UPDATE,
        fileId,
        changes,
        userId,
        version: session.workspace.files.get(fileId).version
    }, userId);
}

function handleCursorPosition(userId, message, currentSession) {
    if (!currentSession) return;
    
    const session = sessions.get(currentSession.id || currentSession);
    if (!session) return;
    
    const participant = session.participants.get(userId);
    if (participant) {
        participant.cursor = message.position;
    }
    
    // Broadcast to other participants
    session.broadcast({
        type: MessageType.CURSOR_POSITION,
        userId,
        position: message.position
    }, userId);
}

// Start server
server.listen(config.websocket.port, config.websocket.host, () => {
    console.log(`WebSocket server listening on ${config.websocket.host}:${config.websocket.port}`);
});

// Cleanup on exit
process.on('SIGINT', () => {
    console.log('Shutting down WebSocket server...');
    wss.close(() => {
        process.exit(0);
    });
});
EOF

    # Install dependencies if needed
    if [[ ! -d "$COLLABORATION_DIR/node_modules" ]]; then
        cd "$COLLABORATION_DIR"
        npm init -y >/dev/null 2>&1
        npm install ws >/dev/null 2>&1
    fi
    
    # Start server
    cd "$COLLABORATION_DIR"
    CONFIG_FILE="$CONFIG_FILE" node ws_server.js &
    local ws_pid=$!
    
    echo "$ws_pid" > "$COLLABORATION_DIR/ws_server.pid"
    log_info "WebSocket server started on $host:$port (PID: $ws_pid)"
}

# Create a new collaboration session
create_session() {
    local session_name="${1:-}"
    local creator="${2:-$USER}"
    local session_id=$(generate_session_id)
    
    # Create session directory
    local session_path="$SESSION_DIR/$session_id"
    mkdir -p "$session_path"
    
    # Initialize session metadata
    cat > "$session_path/metadata.json" <<EOF
{
    "id": "$session_id",
    "name": "$session_name",
    "creator": "$creator",
    "created_at": $(date +%s),
    "participants": ["$creator"],
    "workspace": "$WORKSPACE_DIR/$session_id",
    "status": "active",
    "features": {
        "code_sharing": true,
        "debugging": true,
        "terminal_sharing": true,
        "chat": true
    }
}
EOF
    
    # Create workspace
    mkdir -p "$WORKSPACE_DIR/$session_id"
    
    active_sessions[$session_id]="$session_name"
    user_sessions[$creator]="$session_id"
    
    log_info "Created collaboration session: $session_id"
    echo "$session_id"
}

# Join an existing session
join_session() {
    local session_id="$1"
    local user="${2:-$USER}"
    
    if [[ ! -d "$SESSION_DIR/$session_id" ]]; then
        log_error "Session not found: $session_id"
        return 1
    fi
    
    # Update session metadata
    local metadata_file="$SESSION_DIR/$session_id/metadata.json"
    local participants=$(jq -r '.participants[]' "$metadata_file" | grep -v "^$user$" | tr '\n' ' ')
    participants="$participants $user"
    
    jq ".participants = [$(echo $participants | xargs -n1 | sed 's/.*/"&"/' | paste -sd,)]" \
        "$metadata_file" > "${metadata_file}.tmp" && mv "${metadata_file}.tmp" "$metadata_file"
    
    user_sessions[$user]="$session_id"
    session_participants[$session_id]="$participants"
    
    log_info "User $user joined session: $session_id"
}

# Share code in real-time
share_code() {
    local session_id="${1:-${user_sessions[$USER]:-}}"
    local file_path="$2"
    
    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    # Copy file to shared workspace
    local workspace="$WORKSPACE_DIR/$session_id"
    local relative_path="${file_path#$PWD/}"
    local shared_file="$workspace/$relative_path"
    
    mkdir -p "$(dirname "$shared_file")"
    cp "$file_path" "$shared_file"
    
    # Create file metadata
    cat > "${shared_file}.meta" <<EOF
{
    "original_path": "$file_path",
    "shared_by": "$USER",
    "shared_at": $(date +%s),
    "last_modified": $(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path"),
    "permissions": "rw",
    "locks": []
}
EOF
    
    # Notify participants via WebSocket
    send_collaboration_event "$session_id" "file_shared" "{
        \"file\": \"$relative_path\",
        \"user\": \"$USER\",
        \"action\": \"shared\"
    }"
    
    log_info "Shared file: $relative_path in session $session_id"
}

# Enable collaborative debugging
start_debug_session() {
    local session_id="${1:-${user_sessions[$USER]:-}}"
    local command="$2"
    local debug_port="${3:-9229}"
    
    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi
    
    # Create debug configuration
    local debug_config="$SESSION_DIR/$session_id/debug.json"
    cat > "$debug_config" <<EOF
{
    "session_id": "$session_id",
    "command": "$command",
    "port": $debug_port,
    "started_by": "$USER",
    "started_at": $(date +%s),
    "breakpoints": [],
    "watchers": [],
    "participants": []
}
EOF
    
    # Start debug adapter
    if command -v node >/dev/null 2>&1; then
        # Node.js debugging
        node --inspect-brk=$debug_port $command &
        local debug_pid=$!
        echo "$debug_pid" > "$SESSION_DIR/$session_id/debug.pid"
        
        # Notify participants
        send_collaboration_event "$session_id" "debug_started" "{
            \"command\": \"$command\",
            \"port\": $debug_port,
            \"pid\": $debug_pid
        }"
        
        log_info "Started collaborative debugging on port $debug_port"
    else
        log_error "Debug adapter not available"
        return 1
    fi
}

# Terminal sharing
share_terminal() {
    local session_id="${1:-${user_sessions[$USER]:-}}"
    local terminal_name="${2:-shared}"
    
    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi
    
    # Create named pipe for terminal sharing
    local terminal_pipe="$SESSION_DIR/$session_id/terminal_${terminal_name}"
    mkfifo "$terminal_pipe" 2>/dev/null || true
    
    # Start terminal multiplexer
    if command -v tmux >/dev/null 2>&1; then
        # Create tmux session
        tmux new-session -d -s "collab_${session_id}_${terminal_name}" \
            "cat $terminal_pipe | bash 2>&1 | tee ${terminal_pipe}.out"
        
        # Allow others to attach
        tmux set-option -t "collab_${session_id}_${terminal_name}" -g default-command \
            "bash --init-file <(echo 'PS1=\"[SHARED] \\u@\\h:\\w\\$ \"')"
        
        log_info "Started shared terminal: $terminal_name"
        
        # Notify participants
        send_collaboration_event "$session_id" "terminal_shared" "{
            \"terminal\": \"$terminal_name\",
            \"user\": \"$USER\",
            \"session\": \"collab_${session_id}_${terminal_name}\"
        }"
    else
        log_error "tmux not found. Install tmux for terminal sharing."
        return 1
    fi
}

# Pair programming mode
start_pair_programming() {
    local session_id="${1:-${user_sessions[$USER]:-}}"
    local role="${2:-driver}" # driver or navigator
    
    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi
    
    # Update session for pair programming
    local pair_config="$SESSION_DIR/$session_id/pair_programming.json"
    cat > "$pair_config" <<EOF
{
    "mode": "pair_programming",
    "driver": "$USER",
    "navigator": null,
    "rotation_interval": 900,
    "last_rotation": $(date +%s),
    "rules": {
        "driver_can_type": true,
        "navigator_can_type": false,
        "navigator_can_highlight": true,
        "navigator_can_comment": true
    }
}
EOF
    
    # Set up VS Code Live Share integration if available
    if command -v code >/dev/null 2>&1; then
        # Check for Live Share extension
        if code --list-extensions | grep -q "ms-vsliveshare.vsliveshare"; then
            # Start Live Share session
            code --command "liveshare.start" &
            
            log_info "Started VS Code Live Share for pair programming"
        fi
    fi
    
    # Notify participants
    send_collaboration_event "$session_id" "pair_programming_started" "{
        \"driver\": \"$USER\",
        \"role\": \"$role\",
        \"mode\": \"pair_programming\"
    }"
    
    log_info "Started pair programming session as $role"
}

# Multi-user session management
list_sessions() {
    local filter="${1:-active}"
    
    echo "=== Collaboration Sessions ==="
    echo
    
    for session_file in "$SESSION_DIR"/*/metadata.json; do
        [[ -f "$session_file" ]] || continue
        
        local session_data=$(cat "$session_file")
        local status=$(echo "$session_data" | jq -r '.status')
        
        if [[ "$filter" == "all" ]] || [[ "$status" == "$filter" ]]; then
            echo "$session_data" | jq -r '
                "ID: \(.id)",
                "Name: \(.name)",
                "Creator: \(.creator)",
                "Created: \(.created_at | strftime("%Y-%m-%d %H:%M:%S"))",
                "Participants: \(.participants | join(", "))",
                "Status: \(.status)",
                ""
            '
        fi
    done
}

# Activity monitoring
monitor_session_activity() {
    local session_id="${1:-${user_sessions[$USER]:-}}"
    
    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi
    
    # Create activity log
    local activity_log="$LOG_DIR/session_${session_id}_activity.log"
    
    echo "Monitoring session activity: $session_id"
    echo "Press Ctrl+C to stop monitoring"
    echo
    
    # Monitor file changes
    if command -v inotifywait >/dev/null 2>&1; then
        inotifywait -m -r -e modify,create,delete \
            "$WORKSPACE_DIR/$session_id" \
            --format '%T %w%f %e' \
            --timefmt '%Y-%m-%d %H:%M:%S' | while read line; do
            echo "$line" | tee -a "$activity_log"
            
            # Parse event
            local timestamp=$(echo "$line" | cut -d' ' -f1-2)
            local file=$(echo "$line" | cut -d' ' -f3)
            local event=$(echo "$line" | cut -d' ' -f4)
            
            # Send event notification
            send_collaboration_event "$session_id" "file_activity" "{
                \"file\": \"$file\",
                \"event\": \"$event\",
                \"timestamp\": \"$timestamp\"
            }"
        done
    else
        log_error "inotifywait not found. Install inotify-tools for file monitoring."
        return 1
    fi
}

# Helper functions
generate_session_id() {
    local timestamp=$(date +%s)
    local random=$(openssl rand -hex 4)
    echo "session_${timestamp}_${random}"
}

send_collaboration_event() {
    local session_id="$1"
    local event_type="$2"
    local data="$3"
    
    # Send via WebSocket if server is running
    if [[ -f "$COLLABORATION_DIR/ws_server.pid" ]]; then
        local ws_pid=$(cat "$COLLABORATION_DIR/ws_server.pid")
        if kill -0 "$ws_pid" 2>/dev/null; then
            # Send event via WebSocket
            echo "{\"type\": \"$event_type\", \"session\": \"$session_id\", \"data\": $data}" | \
                nc -w1 localhost "$WS_PORT" 2>/dev/null || true
        fi
    fi
    
    # Also log to file
    echo "$(date -Iseconds) [$session_id] $event_type: $data" >> \
        "$LOG_DIR/collaboration_events.log"
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_DIR/collaboration.log"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_DIR/collaboration.log" >&2
}

# Main function
main() {
    case "${1:-}" in
        init)
            init_collaboration
            ;;
        start-server)
            start_websocket_server "${2:-}" "${3:-}"
            ;;
        create-session)
            create_session "${2:-}" "${3:-}"
            ;;
        join-session)
            join_session "$2" "${3:-}"
            ;;
        share-code)
            share_code "${2:-}" "$3"
            ;;
        debug)
            start_debug_session "${2:-}" "$3" "${4:-}"
            ;;
        share-terminal)
            share_terminal "${2:-}" "${3:-}"
            ;;
        pair-program)
            start_pair_programming "${2:-}" "${3:-}"
            ;;
        list)
            list_sessions "${2:-active}"
            ;;
        monitor)
            monitor_session_activity "${2:-}"
            ;;
        *)
            cat <<EOF
Real-time Collaboration Tools for Build Fix Agents

Usage: $0 <command> [options]

Commands:
    init                    Initialize collaboration system
    start-server [port]     Start WebSocket server
    create-session [name]   Create new collaboration session
    join-session <id>       Join existing session
    share-code [file]       Share code file in session
    debug <cmd> [port]      Start collaborative debugging
    share-terminal [name]   Share terminal session
    pair-program [role]     Start pair programming mode
    list [filter]          List collaboration sessions
    monitor [session]      Monitor session activity

Examples:
    # Start collaboration server
    $0 start-server 8081
    
    # Create new session
    SESSION_ID=\$($0 create-session "Fix API bugs")
    
    # Share code
    $0 share-code src/api/handler.js
    
    # Start debugging
    $0 debug "node app.js" 9229
    
    # Share terminal
    $0 share-terminal main
    
    # Start pair programming
    $0 pair-program driver

EOF
            ;;
    esac
}

main "$@"