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
