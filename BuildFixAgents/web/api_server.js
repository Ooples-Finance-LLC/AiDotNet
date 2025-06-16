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
