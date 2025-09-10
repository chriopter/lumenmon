#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime
from collections import deque, defaultdict

# Store received data in memory
metrics_data = []

# Store history for graphs (last 60 values per metric)
metrics_history = defaultdict(lambda: deque(maxlen=60))

# Store feed messages (webhook and email)
feed_messages = deque(maxlen=50)


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Serve the monitoring dashboard"""
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = """
<!DOCTYPE html>
<html>
<head>
    <title>Lumenmon Server</title>
    <style>
        body { 
            font-family: 'Segoe UI', -apple-system, sans-serif; 
            padding: 20px; 
            background: #0a0a0a; 
            color: #0f0;
            margin: 0;
        }
        h1 { 
            color: #0f0; 
            text-shadow: 0 0 10px #0f0;
            border-bottom: 2px solid #0f0;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }
        .charts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .chart-container {
            background: #000;
            border: 1px solid #0f0;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.1);
        }
        .chart-title {
            color: #0f0;
            margin: 0 0 10px 0;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        canvas {
            width: 100% !important;
            height: 150px !important;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 20px 0;
            background: #000;
        }
        th { 
            background: #0f0; 
            color: #000; 
            padding: 10px; 
            text-align: left;
            font-weight: bold;
        }
        td { 
            border: 1px solid #0f0; 
            padding: 8px;
            color: #0f0;
            font-family: 'Courier New', monospace;
        }
        .timestamp { 
            color: #666; 
            font-size: 0.9em; 
            margin: 10px 0;
        }
        .metric-value {
            color: #0ff;
            font-weight: bold;
        }
        .status {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 12px;
            margin-left: 10px;
        }
        .status.live { 
            background: #0f0; 
            color: #000;
            animation: pulse 2s infinite;
        }
        .status.stale {
            background: #f00;
            color: #fff;
            animation: pulse-red 1s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        @keyframes pulse-red {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }
        .metric-status {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-left: 8px;
            animation: pulse 2s infinite;
        }
        .metric-status.fresh {
            background: #0f0;
            box-shadow: 0 0 5px #0f0;
        }
        .metric-status.stale {
            background: #f00;
            box-shadow: 0 0 5px #f00;
            animation: pulse-red 1s infinite;
        }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>🖥️ Lumenmon Monitoring Server <span id="liveStatus" class="status live">LIVE</span></h1>
    <div class="timestamp" id="timestamp"></div>
    
    <div class="charts-grid">
        <div class="chart-container">
            <h3 class="chart-title">CPU Usage (%)</h3>
            <canvas id="cpuChart"></canvas>
        </div>
        <div class="chart-container">
            <h3 class="chart-title">Memory Usage (%)</h3>
            <canvas id="memChart"></canvas>
        </div>
        <div class="chart-container">
            <h3 class="chart-title">Disk Usage (%)</h3>
            <canvas id="diskChart"></canvas>
        </div>
        <div class="chart-container">
            <h3 class="chart-title">Load Average</h3>
            <canvas id="loadChart"></canvas>
        </div>
    </div>
    
    <h2>📋 Current Metrics</h2>
    <table id="metricsTable">
        <thead>
            <tr><th>Metric</th><th>Value</th></tr>
        </thead>
        <tbody></tbody>
    </table>
    
    <h2>📨 Message Feed</h2>
    <div id="feedContainer" style="background: #000; border: 1px solid #0f0; padding: 15px; border-radius: 8px; max-height: 300px; overflow-y: auto;">
        <div id="feedMessages" style="font-family: 'Courier New', monospace; font-size: 12px; color: #0f0;">
            <div style="color: #666;">Waiting for messages...</div>
        </div>
    </div>
    
    <script>
        // Chart configuration
        const chartConfig = {
            type: 'line',
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: { duration: 0 },
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    x: {
                        display: false,
                        grid: { display: false }
                    },
                    y: {
                        min: 0,
                        max: 100,
                        grid: { 
                            color: 'rgba(0, 255, 0, 0.1)',
                            borderColor: '#0f0'
                        },
                        ticks: { 
                            color: '#0f0',
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                },
                elements: {
                    line: {
                        borderColor: '#0f0',
                        borderWidth: 2,
                        fill: true,
                        backgroundColor: 'rgba(0, 255, 0, 0.1)',
                        tension: 0.3
                    },
                    point: {
                        radius: 0
                    }
                }
            }
        };
        
        // Initialize charts
        const cpuChart = new Chart(document.getElementById('cpuChart'), {
            ...chartConfig,
            data: { labels: [], datasets: [{ data: [] }] }
        });
        
        const memChart = new Chart(document.getElementById('memChart'), {
            ...chartConfig,
            data: { labels: [], datasets: [{ data: [] }] }
        });
        
        const diskChart = new Chart(document.getElementById('diskChart'), {
            ...chartConfig,
            data: { labels: [], datasets: [{ data: [] }] }
        });
        
        const loadChart = new Chart(document.getElementById('loadChart'), {
            ...chartConfig,
            data: { labels: [], datasets: [{ data: [] }] },
            options: {
                ...chartConfig.options,
                scales: {
                    ...chartConfig.options.scales,
                    y: {
                        ...chartConfig.options.scales.y,
                        min: 0,
                        max: 5,
                        ticks: {
                            color: '#0f0',
                            callback: function(value) { return value.toFixed(1); }
                        }
                    }
                }
            }
        });
        
        // Store history
        let metricsHistory = {
            cpu: [],
            memory: [],
            disk: [],
            load: []
        };
        
        // Track last update time and interval
        let lastUpdateTime = null; // null until first data arrives
        let lastDataReceivedTime = null; // Track when we actually got data from server
        let reportedInterval = 5; // Default assumption
        let hasReceivedData = false;
        let lastDataHash = null; // Track if data actually changed
        
        // Update function
        function updateMetrics() {
            fetch('/api/metrics')
                .then(response => response.json())
                .then(data => {
                    // Create a hash of the data to detect changes
                    const currentDataHash = JSON.stringify(data);
                    const dataChanged = currentDataHash !== lastDataHash;
                    
                    // Check if we have actual new data (not empty AND changed)
                    if (Object.keys(data).length > 0 && dataChanged) {
                        // We have NEW data!
                        const now = Date.now();
                        lastDataReceivedTime = now;
                        hasReceivedData = true;
                        lastDataHash = currentDataHash;
                        
                        // Get reported interval from Lumenmon
                        if (data.generic_lumenmon_interval) {
                            reportedInterval = parseFloat(data.generic_lumenmon_interval);
                        }
                        
                        // Update timestamp
                        document.getElementById('timestamp').textContent = 
                            'Last update: ' + new Date().toLocaleTimeString() + 
                            ' (interval: ' + reportedInterval + 's)';
                    }
                    
                    // Update table
                    const tbody = document.querySelector('#metricsTable tbody');
                    tbody.innerHTML = '';
                    
                    Object.keys(data).sort().forEach(key => {
                        const row = tbody.insertRow();
                        
                        // Metric name cell
                        const nameCell = row.insertCell(0);
                        nameCell.innerHTML = key + '<span class="metric-status fresh"></span>';
                        
                        // Value cell
                        const valueCell = row.insertCell(1);
                        valueCell.textContent = data[key];
                        
                        // Highlight numeric values
                        if (!isNaN(data[key])) {
                            valueCell.className = 'metric-value';
                        }
                    });
                    
                    // Update charts
                    const timestamp = new Date().toLocaleTimeString();
                    
                    // CPU
                    if (data.generic_cpu_usage !== undefined) {
                        metricsHistory.cpu.push(parseFloat(data.generic_cpu_usage));
                        if (metricsHistory.cpu.length > 60) metricsHistory.cpu.shift();
                        
                        cpuChart.data.labels = Array(metricsHistory.cpu.length).fill('');
                        cpuChart.data.datasets[0].data = metricsHistory.cpu;
                        cpuChart.update();
                    }
                    
                    // Memory
                    if (data.generic_memory_percent !== undefined) {
                        metricsHistory.memory.push(parseFloat(data.generic_memory_percent));
                        if (metricsHistory.memory.length > 60) metricsHistory.memory.shift();
                        
                        memChart.data.labels = Array(metricsHistory.memory.length).fill('');
                        memChart.data.datasets[0].data = metricsHistory.memory;
                        memChart.update();
                    }
                    
                    // Disk
                    if (data.generic_disk_root_usage !== undefined) {
                        metricsHistory.disk.push(parseFloat(data.generic_disk_root_usage));
                        if (metricsHistory.disk.length > 60) metricsHistory.disk.shift();
                        
                        diskChart.data.labels = Array(metricsHistory.disk.length).fill('');
                        diskChart.data.datasets[0].data = metricsHistory.disk;
                        diskChart.update();
                    }
                    
                    // Load
                    if (data.generic_cpu_load !== undefined) {
                        metricsHistory.load.push(parseFloat(data.generic_cpu_load));
                        if (metricsHistory.load.length > 60) metricsHistory.load.shift();
                        
                        loadChart.data.labels = Array(metricsHistory.load.length).fill('');
                        loadChart.data.datasets[0].data = metricsHistory.load;
                        loadChart.update();
                    }
                })
                .catch(error => console.error('Error fetching metrics:', error));
        }
        
        // Check staleness independently
        function checkStaleness() {
            const liveStatus = document.getElementById('liveStatus');
            
            // Don't show anything until we get first data
            if (!hasReceivedData) {
                liveStatus.className = 'status';
                liveStatus.textContent = 'WAITING';
                liveStatus.style.background = '#666';
                return;
            }
            
            // Calculate time since last real data
            const now = Date.now();
            const timeSinceLastData = (now - lastDataReceivedTime) / 1000;
            const isStale = timeSinceLastData > (reportedInterval * 1.5);
            
            if (isStale) {
                liveStatus.className = 'status stale';
                liveStatus.textContent = 'STALE (' + Math.floor(timeSinceLastData) + 's ago)';
                
                // Update all metric indicators to stale
                document.querySelectorAll('.metric-status').forEach(el => {
                    el.className = 'metric-status stale';
                });
            } else {
                liveStatus.className = 'status live';
                liveStatus.textContent = 'LIVE';
                
                // Update all metric indicators to fresh
                document.querySelectorAll('.metric-status').forEach(el => {
                    el.className = 'metric-status fresh';
                });
            }
        }
        
        // Update feed messages
        function updateFeed() {
            fetch('/api/feed')
                .then(response => response.json())
                .then(messages => {
                    const feedDiv = document.getElementById('feedMessages');
                    
                    if (messages.length === 0) {
                        feedDiv.innerHTML = '<div style="color: #666;">No messages yet...</div>';
                        return;
                    }
                    
                    // Display messages (newest first)
                    feedDiv.innerHTML = messages.reverse().map(msg => {
                        const sourceColor = msg.source === 'email' ? '#0ff' : '#ff0';
                        const sourceIcon = msg.source === 'email' ? '📧' : '🔔';
                        return `
                            <div style="margin-bottom: 8px; padding: 5px; border-left: 2px solid ${sourceColor};">
                                <span style="color: #666; font-size: 10px;">${msg.timestamp}</span>
                                <span style="color: ${sourceColor}; margin: 0 5px;">${sourceIcon} [${msg.source.toUpperCase()}]</span>
                                <div style="color: #0f0; margin-top: 2px;">${msg.message}</div>
                            </div>
                        `;
                    }).join('');
                    
                    // Auto-scroll to bottom
                    const container = document.getElementById('feedContainer');
                    container.scrollTop = container.scrollHeight;
                })
                .catch(error => console.error('Error fetching feed:', error));
        }
        
        // Update metrics every second
        updateMetrics();
        setInterval(updateMetrics, 1000);
        
        // Update feed every 2 seconds
        updateFeed();
        setInterval(updateFeed, 2000);
        
        // Check staleness every 500ms for responsive feedback
        setInterval(checkStaleness, 500);
    </script>
</body>
</html>
"""
            
            
            self.wfile.write(html.encode())
        
        elif self.path == '/api/feed':
            # API endpoint for feed messages
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(list(feed_messages)).encode())
        
        elif self.path == '/api/metrics':
            # API endpoint for JavaScript to fetch current metrics
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            current_metrics = {}
            if metrics_data:
                latest = metrics_data[-1]
                lines = latest["content"].strip().split('\n')
                
                for line in lines:
                    if ':' in line and not line.startswith('#'):
                        parts = line.split(':', 1)
                        if len(parts) == 2:
                            metric, value = parts
                            current_metrics[metric] = value
            
            self.wfile.write(json.dumps(current_metrics).encode())
        
        elif self.path == '/metrics':
            # Legacy endpoint for raw metrics history
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(metrics_data[-10:]).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Receive metrics data or feed messages"""
        if self.path == '/api/feed':
            # Receive feed messages from forwarders
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                message = json.loads(post_data.decode('utf-8'))
                feed_messages.append({
                    'timestamp': message.get('timestamp', datetime.now().isoformat()),
                    'source': message.get('source', 'unknown'),
                    'message': message.get('message', '')
                })
                
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK')
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Feed message from {message.get('source')}")
            
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())
        
        elif self.path == '/metrics':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                # Debug: Print raw received data
                raw_content = post_data.decode('utf-8')
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Received {len(raw_content)} bytes")
                print("=== RAW DATA START ===")
                print(raw_content[:500])  # Print first 500 chars
                print("=== RAW DATA END ===")
                
                # Store the data with timestamp
                metrics_data.append({
                    'timestamp': datetime.now().isoformat(),
                    'content': raw_content
                })
                
                # Keep only last 100 entries in memory
                if len(metrics_data) > 100:
                    metrics_data.pop(0)
                
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK')
            
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8080), MetricsHandler)
    print('Lumenmon Server running on http://localhost:8080')
    print('POST metrics to http://localhost:8080/metrics')
    print('View dashboard at http://localhost:8080/')
    server.serve_forever()