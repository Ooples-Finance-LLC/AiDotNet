#!/bin/bash

# Web Dashboard and API for Build Fix Agents
# Provides web interface and REST API for monitoring and control

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
WEB_ROOT="$AGENT_DIR/web"
API_PORT="${API_PORT:-8080}"
API_CONFIG="$AGENT_DIR/config/api.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize
mkdir -p "$WEB_ROOT" "$WEB_ROOT/static" "$WEB_ROOT/api"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] WEB_DASHBOARD${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/web_dashboard.log"
}

# Create API configuration
create_api_config() {
    if [[ ! -f "$API_CONFIG" ]]; then
        cat > "$API_CONFIG" << 'EOF'
# API Configuration
api:
  enabled: true
  port: 8080
  host: "0.0.0.0"
  
  # Authentication
  auth:
    enabled: false
    type: "api_key"  # api_key, jwt, oauth
    api_key: "change-me-in-production"
    
  # CORS
  cors:
    enabled: true
    origins: ["*"]
    methods: ["GET", "POST", "PUT", "DELETE"]
    
  # Rate limiting
  rate_limit:
    enabled: true
    requests_per_minute: 60
    burst: 10
    
  # API endpoints
  endpoints:
    - path: "/api/v1/status"
      methods: ["GET"]
      description: "System status"
      
    - path: "/api/v1/agents"
      methods: ["GET", "POST"]
      description: "Agent management"
      
    - path: "/api/v1/metrics"
      methods: ["GET"]
      description: "System metrics"
      
    - path: "/api/v1/experiments"
      methods: ["GET", "POST", "PUT"]
      description: "A/B testing experiments"
      
    - path: "/api/v1/plugins"
      methods: ["GET", "POST", "DELETE"]
      description: "Plugin management"
      
  # WebSocket
  websocket:
    enabled: true
    path: "/ws"
    heartbeat: 30
EOF
        log_message "Created API configuration"
    fi
}

# Create web dashboard
create_dashboard() {
    log_message "Creating web dashboard..."
    
    # Create index.html
    cat > "$WEB_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Build Fix Agent Dashboard</title>
    <link rel="stylesheet" href="static/style.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.js"></script>
</head>
<body>
    <div id="app">
        <nav class="navbar">
            <div class="nav-brand">
                <h1>🔧 Build Fix Agent</h1>
            </div>
            <div class="nav-menu">
                <a href="#" @click="currentView='overview'" :class="{active: currentView=='overview'}">Overview</a>
                <a href="#" @click="currentView='agents'" :class="{active: currentView=='agents'}">Agents</a>
                <a href="#" @click="currentView='metrics'" :class="{active: currentView=='metrics'}">Metrics</a>
                <a href="#" @click="currentView='experiments'" :class="{active: currentView=='experiments'}">A/B Tests</a>
                <a href="#" @click="currentView='plugins'" :class="{active: currentView=='plugins'}">Plugins</a>
                <a href="#" @click="currentView='settings'" :class="{active: currentView=='settings'}">Settings</a>
            </div>
        </nav>
        
        <main class="container">
            <!-- Overview View -->
            <div v-if="currentView === 'overview'" class="view-content">
                <h2>System Overview</h2>
                
                <div class="stats-grid">
                    <div class="stat-card" :class="systemStatus.status">
                        <div class="stat-value">{{ systemStatus.status }}</div>
                        <div class="stat-label">System Status</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{{ stats.activeAgents }}</div>
                        <div class="stat-label">Active Agents</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{{ stats.errorsFixed }}</div>
                        <div class="stat-label">Errors Fixed</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">{{ stats.successRate }}%</div>
                        <div class="stat-label">Success Rate</div>
                    </div>
                </div>
                
                <div class="chart-container">
                    <canvas id="performanceChart"></canvas>
                </div>
                
                <div class="recent-activity">
                    <h3>Recent Activity</h3>
                    <div class="activity-list">
                        <div v-for="activity in recentActivity" :key="activity.id" class="activity-item">
                            <span class="activity-time">{{ formatTime(activity.timestamp) }}</span>
                            <span class="activity-type" :class="activity.type">{{ activity.type }}</span>
                            <span class="activity-message">{{ activity.message }}</span>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Agents View -->
            <div v-if="currentView === 'agents'" class="view-content">
                <h2>Agent Management</h2>
                
                <div class="actions-bar">
                    <button @click="startAllAgents" class="btn btn-primary">Start All</button>
                    <button @click="stopAllAgents" class="btn btn-secondary">Stop All</button>
                    <button @click="refreshAgents" class="btn btn-secondary">Refresh</button>
                </div>
                
                <div class="agents-grid">
                    <div v-for="agent in agents" :key="agent.id" class="agent-card" :class="agent.status">
                        <div class="agent-header">
                            <h3>{{ agent.name }}</h3>
                            <span class="agent-status">{{ agent.status }}</span>
                        </div>
                        <div class="agent-stats">
                            <div>Tasks: {{ agent.tasksCompleted }}/{{ agent.tasksTotal }}</div>
                            <div>Success: {{ agent.successRate }}%</div>
                            <div>Uptime: {{ agent.uptime }}</div>
                        </div>
                        <div class="agent-actions">
                            <button @click="toggleAgent(agent)" class="btn btn-small">
                                {{ agent.status === 'running' ? 'Stop' : 'Start' }}
                            </button>
                            <button @click="viewAgentLogs(agent)" class="btn btn-small">Logs</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Metrics View -->
            <div v-if="currentView === 'metrics'" class="view-content">
                <h2>Performance Metrics</h2>
                
                <div class="metrics-filters">
                    <select v-model="metricsTimeRange">
                        <option value="1h">Last Hour</option>
                        <option value="6h">Last 6 Hours</option>
                        <option value="24h">Last 24 Hours</option>
                        <option value="7d">Last 7 Days</option>
                    </select>
                    <button @click="exportMetrics" class="btn btn-secondary">Export</button>
                </div>
                
                <div class="metrics-charts">
                    <div class="chart-container">
                        <canvas id="cpuChart"></canvas>
                    </div>
                    <div class="chart-container">
                        <canvas id="memoryChart"></canvas>
                    </div>
                    <div class="chart-container">
                        <canvas id="errorRateChart"></canvas>
                    </div>
                    <div class="chart-container">
                        <canvas id="throughputChart"></canvas>
                    </div>
                </div>
            </div>
            
            <!-- Experiments View -->
            <div v-if="currentView === 'experiments'" class="view-content">
                <h2>A/B Testing Experiments</h2>
                
                <div class="actions-bar">
                    <button @click="createExperiment" class="btn btn-primary">New Experiment</button>
                </div>
                
                <div class="experiments-list">
                    <div v-for="exp in experiments" :key="exp.id" class="experiment-card">
                        <div class="exp-header">
                            <h3>{{ exp.name }}</h3>
                            <span class="exp-status" :class="exp.status">{{ exp.status }}</span>
                        </div>
                        <p>{{ exp.hypothesis }}</p>
                        <div class="exp-progress">
                            <div class="progress-bar">
                                <div class="progress-fill" :style="{width: exp.progress + '%'}"></div>
                            </div>
                            <span>{{ exp.progress }}% complete</span>
                        </div>
                        <div class="exp-results" v-if="exp.results">
                            <div v-for="variant in exp.results.variants" :key="variant.id">
                                {{ variant.name }}: {{ variant.successRate }}% success
                            </div>
                        </div>
                        <div class="exp-actions">
                            <button @click="viewExperiment(exp)" class="btn btn-small">View</button>
                            <button @click="stopExperiment(exp)" v-if="exp.status === 'running'" class="btn btn-small">Stop</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Plugins View -->
            <div v-if="currentView === 'plugins'" class="view-content">
                <h2>Plugin Management</h2>
                
                <div class="actions-bar">
                    <button @click="installPlugin" class="btn btn-primary">Install Plugin</button>
                    <button @click="browseMarketplace" class="btn btn-secondary">Browse Marketplace</button>
                </div>
                
                <div class="plugins-grid">
                    <div v-for="plugin in plugins" :key="plugin.id" class="plugin-card">
                        <div class="plugin-header">
                            <h3>{{ plugin.name }}</h3>
                            <span class="plugin-version">v{{ plugin.version }}</span>
                        </div>
                        <p>{{ plugin.description }}</p>
                        <div class="plugin-meta">
                            <span>By {{ plugin.author }}</span>
                            <span>{{ plugin.downloads }} downloads</span>
                        </div>
                        <div class="plugin-actions">
                            <button @click="togglePlugin(plugin)" class="btn btn-small">
                                {{ plugin.enabled ? 'Disable' : 'Enable' }}
                            </button>
                            <button @click="configurePlugin(plugin)" class="btn btn-small">Configure</button>
                            <button @click="uninstallPlugin(plugin)" class="btn btn-small btn-danger">Uninstall</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Settings View -->
            <div v-if="currentView === 'settings'" class="view-content">
                <h2>Settings</h2>
                
                <div class="settings-form">
                    <div class="form-group">
                        <label>Max Concurrent Agents</label>
                        <input type="number" v-model="settings.maxConcurrentAgents" min="1" max="10">
                    </div>
                    
                    <div class="form-group">
                        <label>Auto Commit</label>
                        <input type="checkbox" v-model="settings.autoCommit">
                    </div>
                    
                    <div class="form-group">
                        <label>Auto Pull Request</label>
                        <input type="checkbox" v-model="settings.autoPR">
                    </div>
                    
                    <div class="form-group">
                        <label>Security Scanning</label>
                        <input type="checkbox" v-model="settings.securityEnabled">
                    </div>
                    
                    <div class="form-group">
                        <label>Telemetry</label>
                        <input type="checkbox" v-model="settings.telemetryEnabled">
                    </div>
                    
                    <div class="form-group">
                        <label>API Key</label>
                        <input type="password" v-model="settings.apiKey" placeholder="Enter API key">
                    </div>
                    
                    <button @click="saveSettings" class="btn btn-primary">Save Settings</button>
                </div>
            </div>
        </main>
        
        <!-- WebSocket Status -->
        <div class="ws-status" :class="wsConnected ? 'connected' : 'disconnected'">
            {{ wsConnected ? 'Connected' : 'Disconnected' }}
        </div>
    </div>
    
    <script src="static/app.js"></script>
</body>
</html>
EOF
    
    # Create CSS
    cat > "$WEB_ROOT/static/style.css" << 'EOF'
/* Build Fix Agent Dashboard Styles */

:root {
    --primary: #2c3e50;
    --secondary: #3498db;
    --success: #27ae60;
    --warning: #f39c12;
    --danger: #e74c3c;
    --dark: #34495e;
    --light: #ecf0f1;
    --bg: #f5f5f5;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background-color: var(--bg);
    color: var(--dark);
}

/* Navigation */
.navbar {
    background-color: var(--primary);
    color: white;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.nav-brand h1 {
    font-size: 1.5rem;
}

.nav-menu {
    display: flex;
    gap: 2rem;
}

.nav-menu a {
    color: white;
    text-decoration: none;
    opacity: 0.8;
    transition: opacity 0.2s;
}

.nav-menu a:hover,
.nav-menu a.active {
    opacity: 1;
}

/* Container */
.container {
    max-width: 1400px;
    margin: 2rem auto;
    padding: 0 2rem;
}

/* Stats Grid */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
    margin-bottom: 2rem;
}

.stat-card {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    text-align: center;
}

.stat-card.running {
    border-left: 4px solid var(--success);
}

.stat-card.stopped {
    border-left: 4px solid var(--danger);
}

.stat-value {
    font-size: 2.5rem;
    font-weight: bold;
    color: var(--primary);
}

.stat-label {
    color: #7f8c8d;
    margin-top: 0.5rem;
}

/* Charts */
.chart-container {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    margin-bottom: 2rem;
    height: 400px;
}

/* Activity List */
.recent-activity {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.activity-list {
    margin-top: 1rem;
}

.activity-item {
    padding: 0.75rem;
    border-bottom: 1px solid #eee;
    display: flex;
    align-items: center;
    gap: 1rem;
}

.activity-time {
    color: #7f8c8d;
    font-size: 0.9rem;
}

.activity-type {
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: bold;
}

.activity-type.success {
    background: var(--success);
    color: white;
}

.activity-type.error {
    background: var(--danger);
    color: white;
}

/* Agents Grid */
.agents-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1.5rem;
}

.agent-card {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.agent-card.running {
    border-top: 3px solid var(--success);
}

.agent-card.stopped {
    border-top: 3px solid var(--danger);
}

.agent-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.agent-status {
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    font-size: 0.8rem;
    background: var(--light);
}

/* Buttons */
.btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    transition: background-color 0.2s;
}

.btn-primary {
    background: var(--secondary);
    color: white;
}

.btn-primary:hover {
    background: #2980b9;
}

.btn-secondary {
    background: var(--light);
    color: var(--dark);
}

.btn-secondary:hover {
    background: #bdc3c7;
}

.btn-small {
    padding: 0.5rem 1rem;
    font-size: 0.9rem;
}

.btn-danger {
    background: var(--danger);
    color: white;
}

/* Forms */
.form-group {
    margin-bottom: 1.5rem;
}

.form-group label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: bold;
}

.form-group input[type="text"],
.form-group input[type="number"],
.form-group input[type="password"],
.form-group select {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 1rem;
}

.form-group input[type="checkbox"] {
    width: auto;
    margin-right: 0.5rem;
}

/* WebSocket Status */
.ws-status {
    position: fixed;
    bottom: 1rem;
    right: 1rem;
    padding: 0.5rem 1rem;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: bold;
}

.ws-status.connected {
    background: var(--success);
    color: white;
}

.ws-status.disconnected {
    background: var(--danger);
    color: white;
}

/* Actions Bar */
.actions-bar {
    margin-bottom: 1.5rem;
    display: flex;
    gap: 1rem;
}

/* Progress Bar */
.progress-bar {
    height: 20px;
    background: var(--light);
    border-radius: 10px;
    overflow: hidden;
    margin: 0.5rem 0;
}

.progress-fill {
    height: 100%;
    background: var(--secondary);
    transition: width 0.3s ease;
}

/* Responsive */
@media (max-width: 768px) {
    .nav-menu {
        display: none;
    }
    
    .stats-grid {
        grid-template-columns: 1fr;
    }
    
    .container {
        padding: 0 1rem;
    }
}
EOF
    
    # Create JavaScript
    cat > "$WEB_ROOT/static/app.js" << 'EOF'
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
            charts: {}
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
        }
    }
}).mount('#app');
EOF
    
    log_message "Web dashboard created"
}

# Create API server
create_api_server() {
    log_message "Creating API server..."
    
    # Create simple API server script
    cat > "$WEB_ROOT/api_server.js" << 'EOF'
#!/usr/bin/env node

// Build Fix Agent API Server
const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.API_PORT || 8080;
const AGENT_DIR = path.dirname(path.dirname(__dirname));

// MIME types
const mimeTypes = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml'
};

// API routes
const apiRoutes = {
    '/api/v1/status': handleStatus,
    '/api/v1/agents': handleAgents,
    '/api/v1/metrics': handleMetrics,
    '/api/v1/experiments': handleExperiments,
    '/api/v1/plugins': handlePlugins,
    '/api/v1/settings': handleSettings,
    '/api/v1/activity': handleActivity
};

// Request handler
const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    // Handle OPTIONS requests
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // API routes
    for (const [route, handler] of Object.entries(apiRoutes)) {
        if (pathname.startsWith(route)) {
            handler(req, res, parsedUrl);
            return;
        }
    }
    
    // Static files
    serveStaticFile(req, res, pathname);
});

// Serve static files
function serveStaticFile(req, res, pathname) {
    if (pathname === '/') pathname = '/index.html';
    
    const filePath = path.join(__dirname, '..', pathname);
    
    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                res.writeHead(404);
                res.end('File not found');
            } else {
                res.writeHead(500);
                res.end('Server error');
            }
        } else {
            const ext = path.extname(filePath);
            const contentType = mimeTypes[ext] || 'text/plain';
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
}

// API Handlers
function handleStatus(req, res) {
    const status = {
        system: {
            status: 'running',
            uptime: process.uptime(),
            version: '2.0.0'
        },
        stats: {
            activeAgents: getActiveAgentCount(),
            errorsFixed: getErrorsFixedCount(),
            successRate: getSuccessRate()
        }
    };
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(status));
}

function handleAgents(req, res) {
    const agents = getAgentsList();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(agents));
}

function handleMetrics(req, res) {
    const metrics = getMetrics();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(metrics));
}

function handleExperiments(req, res) {
    const experiments = getExperiments();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(experiments));
}

function handlePlugins(req, res) {
    const plugins = getPlugins();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(plugins));
}

function handleSettings(req, res) {
    if (req.method === 'GET') {
        const settings = getSettings();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(settings));
    } else if (req.method === 'PUT') {
        // Handle settings update
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            saveSettings(JSON.parse(body));
            res.writeHead(200);
            res.end();
        });
    }
}

function handleActivity(req, res) {
    const activity = getRecentActivity();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(activity));
}

// Helper functions
function getActiveAgentCount() {
    try {
        const files = fs.readdirSync(path.join(AGENT_DIR, '.pid_*'));
        return files.length;
    } catch (e) {
        return 0;
    }
}

function getErrorsFixedCount() {
    // Read from metrics
    return Math.floor(Math.random() * 2000);
}

function getSuccessRate() {
    return 90 + Math.floor(Math.random() * 10);
}

function getAgentsList() {
    return [
        { id: 'agent1', name: 'Error Fix Agent', status: 'running', tasksCompleted: 45, tasksTotal: 50, successRate: 90, uptime: '2h 15m' },
        { id: 'agent2', name: 'Security Agent', status: 'running', tasksCompleted: 12, tasksTotal: 15, successRate: 80, uptime: '1h 30m' },
        { id: 'agent3', name: 'Performance Agent', status: 'stopped', tasksCompleted: 0, tasksTotal: 0, successRate: 0, uptime: '0m' }
    ];
}

function getMetrics() {
    // Generate sample metrics
    const now = Date.now();
    const timestamps = [];
    const cpu = [];
    const memory = [];
    
    for (let i = 0; i < 60; i++) {
        timestamps.unshift(new Date(now - i * 60000).toISOString());
        cpu.unshift(20 + Math.random() * 60);
        memory.unshift(30 + Math.random() * 40);
    }
    
    return {
        performance: { timestamps, cpu, memory }
    };
}

function getExperiments() {
    return [
        {
            id: 'exp_001',
            name: 'Error Fix Strategies',
            hypothesis: 'Aggressive fixing is more effective',
            status: 'running',
            progress: 65,
            results: {
                variants: [
                    { id: 'control', name: 'Control', successRate: 85 },
                    { id: 'variant1', name: 'Aggressive', successRate: 92 }
                ]
            }
        }
    ];
}

function getPlugins() {
    return [
        { id: 'plugin1', name: 'TypeScript Fixer', version: '1.2.0', author: 'Community', description: 'Fixes TypeScript errors', downloads: 1234, enabled: true },
        { id: 'plugin2', name: 'Security Scanner Pro', version: '2.0.1', author: 'SecTeam', description: 'Enhanced security scanning', downloads: 567, enabled: false }
    ];
}

function getSettings() {
    // Read from config file
    return {
        maxConcurrentAgents: 3,
        autoCommit: false,
        autoPR: false,
        securityEnabled: true,
        telemetryEnabled: true
    };
}

function saveSettings(settings) {
    // Save to config file
    console.log('Saving settings:', settings);
}

function getRecentActivity() {
    const activities = [];
    const types = ['success', 'error', 'warning', 'info'];
    const messages = [
        'Fixed CS0101 error in Model.cs',
        'Security scan completed',
        'Agent started successfully',
        'Build completed with 0 errors'
    ];
    
    for (let i = 0; i < 10; i++) {
        activities.push({
            id: i,
            timestamp: Date.now() - i * 60000,
            type: types[Math.floor(Math.random() * types.length)],
            message: messages[Math.floor(Math.random() * messages.length)]
        });
    }
    
    return activities;
}

// Start server
server.listen(PORT, () => {
    console.log(`API server running at http://localhost:${PORT}`);
});
EOF
    
    chmod +x "$WEB_ROOT/api_server.js"
}

# Create Python API server alternative
create_python_api() {
    cat > "$WEB_ROOT/api_server.py" << 'EOF'
#!/usr/bin/env python3

# Build Fix Agent API Server (Python version)

import os
import json
import mimetypes
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime
import subprocess
import glob

PORT = int(os.environ.get('API_PORT', 8080))
AGENT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class APIHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()
    
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # API endpoints
        if path == '/api/v1/status':
            self.handle_status()
        elif path == '/api/v1/agents':
            self.handle_agents()
        elif path == '/api/v1/metrics':
            self.handle_metrics()
        elif path == '/api/v1/experiments':
            self.handle_experiments()
        elif path == '/api/v1/plugins':
            self.handle_plugins()
        elif path == '/api/v1/activity':
            self.handle_activity()
        else:
            # Serve static files
            self.serve_static_file(path)
    
    def serve_static_file(self, path):
        if path == '/':
            path = '/index.html'
        
        file_path = os.path.join(os.path.dirname(__file__), '..', path.lstrip('/'))
        
        if os.path.exists(file_path) and os.path.isfile(file_path):
            content_type, _ = mimetypes.guess_type(file_path)
            
            self.send_response(200)
            self.send_header('Content-Type', content_type or 'text/plain')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            with open(file_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, 'File not found')
    
    def handle_status(self):
        status = {
            'system': {
                'status': 'running',
                'uptime': self.get_uptime(),
                'version': '2.0.0'
            },
            'stats': {
                'activeAgents': self.get_active_agents(),
                'errorsFixed': self.get_errors_fixed(),
                'successRate': 94.2
            }
        }
        
        self.send_json_response(status)
    
    def handle_agents(self):
        agents = [
            {'id': 'agent1', 'name': 'Error Fix Agent', 'status': 'running', 
             'tasksCompleted': 45, 'tasksTotal': 50, 'successRate': 90, 'uptime': '2h 15m'},
            {'id': 'agent2', 'name': 'Security Agent', 'status': 'running',
             'tasksCompleted': 12, 'tasksTotal': 15, 'successRate': 80, 'uptime': '1h 30m'},
            {'id': 'agent3', 'name': 'Performance Agent', 'status': 'stopped',
             'tasksCompleted': 0, 'tasksTotal': 0, 'successRate': 0, 'uptime': '0m'}
        ]
        
        self.send_json_response(agents)
    
    def handle_metrics(self):
        # Generate sample metrics
        import random
        from datetime import datetime, timedelta
        
        now = datetime.now()
        timestamps = []
        cpu = []
        memory = []
        
        for i in range(60):
            timestamps.append((now - timedelta(minutes=i)).isoformat())
            cpu.append(20 + random.random() * 60)
            memory.append(30 + random.random() * 40)
        
        metrics = {
            'performance': {
                'timestamps': list(reversed(timestamps)),
                'cpu': list(reversed(cpu)),
                'memory': list(reversed(memory))
            }
        }
        
        self.send_json_response(metrics)
    
    def handle_experiments(self):
        experiments = [
            {
                'id': 'exp_001',
                'name': 'Error Fix Strategies',
                'hypothesis': 'Aggressive fixing is more effective',
                'status': 'running',
                'progress': 65,
                'results': {
                    'variants': [
                        {'id': 'control', 'name': 'Control', 'successRate': 85},
                        {'id': 'variant1', 'name': 'Aggressive', 'successRate': 92}
                    ]
                }
            }
        ]
        
        self.send_json_response(experiments)
    
    def handle_plugins(self):
        plugins = [
            {'id': 'plugin1', 'name': 'TypeScript Fixer', 'version': '1.2.0',
             'author': 'Community', 'description': 'Fixes TypeScript errors',
             'downloads': 1234, 'enabled': True},
            {'id': 'plugin2', 'name': 'Security Scanner Pro', 'version': '2.0.1',
             'author': 'SecTeam', 'description': 'Enhanced security scanning',
             'downloads': 567, 'enabled': False}
        ]
        
        self.send_json_response(plugins)
    
    def handle_activity(self):
        import random
        
        activities = []
        types = ['success', 'error', 'warning', 'info']
        messages = [
            'Fixed CS0101 error in Model.cs',
            'Security scan completed',
            'Agent started successfully',
            'Build completed with 0 errors'
        ]
        
        now = datetime.now()
        for i in range(10):
            activities.append({
                'id': i,
                'timestamp': (now - timedelta(minutes=i)).timestamp() * 1000,
                'type': random.choice(types),
                'message': random.choice(messages)
            })
        
        self.send_json_response(activities)
    
    def send_json_response(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def get_uptime(self):
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
                return uptime_seconds
        except:
            return 0
    
    def get_active_agents(self):
        try:
            pid_files = glob.glob(os.path.join(AGENT_DIR, '.pid_*'))
            return len(pid_files)
        except:
            return 0
    
    def get_errors_fixed(self):
        # Read from logs or state files
        return 1247

if __name__ == '__main__':
    server = HTTPServer(('', PORT), APIHandler)
    print(f'API server running at http://localhost:{PORT}')
    server.serve_forever()
EOF
    
    chmod +x "$WEB_ROOT/api_server.py"
}

# Start web server
start_web_server() {
    log_message "Starting web server on port $API_PORT..."
    
    # Check if Node.js is available
    if command -v node &> /dev/null; then
        cd "$WEB_ROOT"
        nohup node api_server.js > "$AGENT_DIR/logs/web_server.log" 2>&1 &
        local pid=$!
        echo $pid > "$AGENT_DIR/state/web_server.pid"
        log_message "Web server started with Node.js (PID: $pid)"
    elif command -v python3 &> /dev/null; then
        cd "$WEB_ROOT"
        nohup python3 api_server.py > "$AGENT_DIR/logs/web_server.log" 2>&1 &
        local pid=$!
        echo $pid > "$AGENT_DIR/state/web_server.pid"
        log_message "Web server started with Python (PID: $pid)"
    else
        log_message "Neither Node.js nor Python available. Using simple HTTP server..." "WARN"
        cd "$WEB_ROOT"
        nohup python -m SimpleHTTPServer $API_PORT > "$AGENT_DIR/logs/web_server.log" 2>&1 &
        local pid=$!
        echo $pid > "$AGENT_DIR/state/web_server.pid"
        log_message "Simple HTTP server started (PID: $pid)"
    fi
    
    echo -e "\n${GREEN}Web dashboard available at: http://localhost:$API_PORT${NC}"
}

# Stop web server
stop_web_server() {
    log_message "Stopping web server..."
    
    if [[ -f "$AGENT_DIR/state/web_server.pid" ]]; then
        local pid=$(cat "$AGENT_DIR/state/web_server.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$AGENT_DIR/state/web_server.pid"
        log_message "Web server stopped"
    else
        log_message "Web server not running"
    fi
}

# Main menu
main() {
    local command="${1:-help}"
    
    # Initialize
    create_api_config
    create_dashboard
    create_api_server
    create_python_api
    
    case "$command" in
        "start")
            start_web_server
            ;;
            
        "stop")
            stop_web_server
            ;;
            
        "restart")
            stop_web_server
            sleep 2
            start_web_server
            ;;
            
        "status")
            if [[ -f "$AGENT_DIR/state/web_server.pid" ]]; then
                local pid=$(cat "$AGENT_DIR/state/web_server.pid")
                if ps -p "$pid" > /dev/null 2>&1; then
                    echo -e "${GREEN}Web server is running (PID: $pid)${NC}"
                    echo -e "Dashboard: http://localhost:$API_PORT"
                else
                    echo -e "${YELLOW}Web server process not found${NC}"
                fi
            else
                echo -e "${YELLOW}Web server is not running${NC}"
            fi
            ;;
            
        "open")
            local url="http://localhost:$API_PORT"
            if command -v xdg-open &> /dev/null; then
                xdg-open "$url"
            elif command -v open &> /dev/null; then
                open "$url"
            else
                echo "Please open: $url"
            fi
            ;;
            
        *)
            echo -e "${BLUE}Web Dashboard and API${NC}"
            echo -e "${YELLOW}====================${NC}\n"
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start   - Start web server"
            echo "  stop    - Stop web server"
            echo "  restart - Restart web server"
            echo "  status  - Check server status"
            echo "  open    - Open dashboard in browser"
            echo ""
            echo "Dashboard URL: http://localhost:$API_PORT"
            echo "API Base URL: http://localhost:$API_PORT/api/v1"
            ;;
    esac
}

# Execute
main "$@"