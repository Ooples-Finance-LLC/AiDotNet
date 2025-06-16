// Build Fix Agent Dashboard App

const { createApp } = Vue;

createApp({
    data() {
        return {
            currentView: 'overview',
            wsConnected: false,
            ws: null,
            
            // System data
            systemStatus: {
                status: 'running',
                uptime: '2d 14h 32m'
            },
            
            stats: {
                activeAgents: 3,
                errorsFixed: 1247,
                successRate: 94.2
            },
            
            recentActivity: [],
            agents: [],
            metrics: {},
            experiments: [],
            plugins: [],
            
            // Settings
            settings: {
                maxConcurrentAgents: 3,
                autoCommit: false,
                autoPR: false,
                securityEnabled: true,
                telemetryEnabled: true,
                apiKey: ''
            },
            
            // UI state
            metricsTimeRange: '1h',
            charts: {},
            
            // Collaboration
            collabTab: 'sessions',
            collabSessions: [],
            activeSession: null,
            activeFile: null,
            chatMessages: [],
            chatInput: '',
            otherCursors: [],
            canEdit: true
        };
    },
    
    mounted() {
        this.initWebSocket();
        this.loadData();
        this.initCharts();
        
        // Periodic refresh
        setInterval(() => {
            this.refreshData();
        }, 5000);
    },
    
    methods: {
        // WebSocket connection
        initWebSocket() {
            const wsUrl = `ws://${window.location.host}/ws`;
            this.ws = new WebSocket(wsUrl);
            
            this.ws.onopen = () => {
                this.wsConnected = true;
                console.log('WebSocket connected');
            };
            
            this.ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                this.handleWebSocketMessage(data);
            };
            
            this.ws.onclose = () => {
                this.wsConnected = false;
                console.log('WebSocket disconnected');
                // Reconnect after 5 seconds
                setTimeout(() => this.initWebSocket(), 5000);
            };
        },
        
        handleWebSocketMessage(data) {
            switch (data.type) {
                case 'activity':
                    this.recentActivity.unshift(data.payload);
                    if (this.recentActivity.length > 50) {
                        this.recentActivity.pop();
                    }
                    break;
                    
                case 'metrics':
                    this.updateMetrics(data.payload);
                    break;
                    
                case 'agent_status':
                    this.updateAgentStatus(data.payload);
                    break;
                    
                case 'collab_update':
                    this.handleCollaborationUpdate(data.payload);
                    break;
                    
                case 'code_update':
                    this.handleRemoteCodeUpdate(data.payload);
                    break;
                    
                case 'cursor_position':
                    this.updateCursorPosition(data.payload);
                    break;
                    
                case 'chat_message':
                    this.receiveChatMessage(data.payload);
                    break;
            }
        },
        
        // Data loading
        async loadData() {
            try {
                // Load agents
                const agentsResponse = await fetch('/api/v1/agents');
                this.agents = await agentsResponse.json();
                
                // Load metrics
                const metricsResponse = await fetch('/api/v1/metrics');
                this.metrics = await metricsResponse.json();
                
                // Load experiments
                const experimentsResponse = await fetch('/api/v1/experiments');
                this.experiments = await experimentsResponse.json();
                
                // Load plugins
                const pluginsResponse = await fetch('/api/v1/plugins');
                this.plugins = await pluginsResponse.json();
                
                // Load recent activity
                const activityResponse = await fetch('/api/v1/activity');
                this.recentActivity = await activityResponse.json();
            } catch (error) {
                console.error('Error loading data:', error);
            }
        },
        
        refreshData() {
            if (this.currentView === 'overview') {
                this.updateStats();
            } else if (this.currentView === 'agents') {
                this.refreshAgents();
            } else if (this.currentView === 'metrics') {
                this.updateCharts();
            }
        },
        
        async updateStats() {
            try {
                const response = await fetch('/api/v1/status');
                const data = await response.json();
                this.systemStatus = data.system;
                this.stats = data.stats;
            } catch (error) {
                console.error('Error updating stats:', error);
            }
        },
        
        // Chart initialization
        initCharts() {
            // Performance chart
            const perfCtx = document.getElementById('performanceChart');
            if (perfCtx) {
                this.charts.performance = new Chart(perfCtx, {
                    type: 'line',
                    data: {
                        labels: [],
                        datasets: [{
                            label: 'CPU Usage',
                            data: [],
                            borderColor: 'rgb(75, 192, 192)',
                            tension: 0.1
                        }, {
                            label: 'Memory Usage',
                            data: [],
                            borderColor: 'rgb(255, 99, 132)',
                            tension: 0.1
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false
                    }
                });
            }
        },
        
        updateCharts() {
            // Update chart data
            if (this.charts.performance && this.metrics.performance) {
                this.charts.performance.data.labels = this.metrics.performance.timestamps;
                this.charts.performance.data.datasets[0].data = this.metrics.performance.cpu;
                this.charts.performance.data.datasets[1].data = this.metrics.performance.memory;
                this.charts.performance.update();
            }
        },
        
        // Agent management
        async startAllAgents() {
            try {
                await fetch('/api/v1/agents/start-all', { method: 'POST' });
                this.refreshAgents();
            } catch (error) {
                console.error('Error starting agents:', error);
            }
        },
        
        async stopAllAgents() {
            try {
                await fetch('/api/v1/agents/stop-all', { method: 'POST' });
                this.refreshAgents();
            } catch (error) {
                console.error('Error stopping agents:', error);
            }
        },
        
        async toggleAgent(agent) {
            const action = agent.status === 'running' ? 'stop' : 'start';
            try {
                await fetch(`/api/v1/agents/${agent.id}/${action}`, { method: 'POST' });
                this.refreshAgents();
            } catch (error) {
                console.error('Error toggling agent:', error);
            }
        },
        
        async refreshAgents() {
            try {
                const response = await fetch('/api/v1/agents');
                this.agents = await response.json();
            } catch (error) {
                console.error('Error refreshing agents:', error);
            }
        },
        
        viewAgentLogs(agent) {
            window.open(`/api/v1/agents/${agent.id}/logs`, '_blank');
        },
        
        // Experiments
        createExperiment() {
            // Show experiment creation dialog
            alert('Experiment creation dialog would appear here');
        },
        
        viewExperiment(exp) {
            window.open(`/experiments/${exp.id}`, '_blank');
        },
        
        async stopExperiment(exp) {
            try {
                await fetch(`/api/v1/experiments/${exp.id}/stop`, { method: 'POST' });
                this.loadData();
            } catch (error) {
                console.error('Error stopping experiment:', error);
            }
        },
        
        // Plugins
        installPlugin() {
            // Show plugin installation dialog
            alert('Plugin installation dialog would appear here');
        },
        
        browseMarketplace() {
            window.open('/marketplace', '_blank');
        },
        
        async togglePlugin(plugin) {
            const action = plugin.enabled ? 'disable' : 'enable';
            try {
                await fetch(`/api/v1/plugins/${plugin.id}/${action}`, { method: 'POST' });
                this.loadData();
            } catch (error) {
                console.error('Error toggling plugin:', error);
            }
        },
        
        configurePlugin(plugin) {
            window.open(`/plugins/${plugin.id}/config`, '_blank');
        },
        
        async uninstallPlugin(plugin) {
            if (confirm(`Are you sure you want to uninstall ${plugin.name}?`)) {
                try {
                    await fetch(`/api/v1/plugins/${plugin.id}`, { method: 'DELETE' });
                    this.loadData();
                } catch (error) {
                    console.error('Error uninstalling plugin:', error);
                }
            }
        },
        
        // Settings
        async saveSettings() {
            try {
                await fetch('/api/v1/settings', {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.settings)
                });
                alert('Settings saved successfully');
            } catch (error) {
                console.error('Error saving settings:', error);
                alert('Error saving settings');
            }
        },
        
        // Metrics
        async exportMetrics() {
            const format = prompt('Export format (json/csv):') || 'json';
            window.open(`/api/v1/metrics/export?format=${format}&range=${this.metricsTimeRange}`, '_blank');
        },
        
        // Utilities
        formatTime(timestamp) {
            const date = new Date(timestamp);
            return date.toLocaleTimeString();
        },
        
        // Collaboration methods
        async loadCollaborationSessions() {
            try {
                const response = await fetch('/api/v1/collaboration/sessions');
                this.collabSessions = await response.json();
            } catch (error) {
                console.error('Error loading collaboration sessions:', error);
            }
        },
        
        async createCollabSession() {
            const name = prompt('Session name:');
            if (!name) return;
            
            try {
                const response = await fetch('/api/v1/collaboration/sessions', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name })
                });
                const session = await response.json();
                this.collabSessions.unshift(session);
                this.joinSession(session);
            } catch (error) {
                console.error('Error creating session:', error);
            }
        },
        
        async joinSession(session) {
            try {
                const response = await fetch(`/api/v1/collaboration/sessions/${session.id}/join`, {
                    method: 'POST'
                });
                
                if (response.ok) {
                    this.activeSession = await response.json();
                    this.collabTab = 'active';
                    
                    // Send WebSocket message to join
                    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                        this.ws.send(JSON.stringify({
                            type: 'join_session',
                            sessionId: session.id
                        }));
                    }
                }
            } catch (error) {
                console.error('Error joining session:', error);
            }
        },
        
        async leaveSession() {
            if (!this.activeSession) return;
            
            try {
                await fetch(`/api/v1/collaboration/sessions/${this.activeSession.id}/leave`, {
                    method: 'POST'
                });
                
                // Send WebSocket message to leave
                if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                    this.ws.send(JSON.stringify({
                        type: 'leave_session',
                        sessionId: this.activeSession.id
                    }));
                }
                
                this.activeSession = null;
                this.activeFile = null;
                this.chatMessages = [];
                this.otherCursors = [];
                this.collabTab = 'sessions';
                this.refreshSessions();
            } catch (error) {
                console.error('Error leaving session:', error);
            }
        },
        
        viewSession(session) {
            window.open(`/collaboration/session/${session.id}`, '_blank');
        },
        
        refreshSessions() {
            this.loadCollaborationSessions();
        },
        
        selectFile(file) {
            this.activeFile = file;
        },
        
        handleCodeChange() {
            if (!this.activeSession || !this.activeFile) return;
            
            // Send code update via WebSocket
            if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify({
                    type: 'code_update',
                    sessionId: this.activeSession.id,
                    fileId: this.activeFile.id,
                    changes: {
                        content: this.activeFile.content
                    }
                }));
            }
        },
        
        sendChatMessage() {
            if (!this.chatInput.trim() || !this.activeSession) return;
            
            const message = {
                id: Date.now(),
                user: 'You',
                text: this.chatInput,
                timestamp: Date.now()
            };
            
            this.chatMessages.push(message);
            
            // Send via WebSocket
            if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify({
                    type: 'chat_message',
                    sessionId: this.activeSession.id,
                    message: message
                }));
            }
            
            this.chatInput = '';
        },
        
        // Collaboration tools
        async shareTerminal() {
            if (!this.activeSession) {
                alert('Please join a session first');
                return;
            }
            
            try {
                await fetch(`/api/v1/collaboration/sessions/${this.activeSession.id}/terminal`, {
                    method: 'POST'
                });
                alert('Terminal sharing started');
            } catch (error) {
                console.error('Error sharing terminal:', error);
            }
        },
        
        async startDebugSession() {
            if (!this.activeSession) {
                alert('Please join a session first');
                return;
            }
            
            const command = prompt('Debug command:');
            if (!command) return;
            
            try {
                await fetch(`/api/v1/collaboration/sessions/${this.activeSession.id}/debug`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command })
                });
                alert('Debug session started');
            } catch (error) {
                console.error('Error starting debug session:', error);
            }
        },
        
        async startPairProgramming() {
            if (!this.activeSession) {
                alert('Please join a session first');
                return;
            }
            
            const role = confirm('Start as driver? (OK = Driver, Cancel = Navigator)') ? 'driver' : 'navigator';
            
            try {
                await fetch(`/api/v1/collaboration/sessions/${this.activeSession.id}/pair-program`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ role })
                });
                alert(`Pair programming started as ${role}`);
            } catch (error) {
                console.error('Error starting pair programming:', error);
            }
        },
        
        async monitorActivity() {
            if (!this.activeSession) {
                alert('Please join a session first');
                return;
            }
            
            window.open(`/collaboration/monitor/${this.activeSession.id}`, '_blank');
        },
        
        // WebSocket handlers for collaboration
        handleCollaborationUpdate(data) {
            if (data.sessionId === this.activeSession?.id) {
                // Update session data
                Object.assign(this.activeSession, data.updates);
            }
        },
        
        handleRemoteCodeUpdate(data) {
            if (data.sessionId === this.activeSession?.id && data.fileId === this.activeFile?.id) {
                // Update code content
                this.activeFile.content = data.changes.content;
            }
        },
        
        updateCursorPosition(data) {
            if (data.sessionId !== this.activeSession?.id) return;
            
            // Update or add cursor position
            const cursorIndex = this.otherCursors.findIndex(c => c.userId === data.userId);
            if (cursorIndex >= 0) {
                this.otherCursors[cursorIndex] = data.position;
            } else {
                this.otherCursors.push(data.position);
            }
        },
        
        receiveChatMessage(data) {
            if (data.sessionId === this.activeSession?.id) {
                this.chatMessages.push(data.message);
            }
        }
    }
}).mount('#app');
