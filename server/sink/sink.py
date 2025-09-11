#!/usr/bin/env python3
"""Metrics sink that receives and stores data in SQLite with proper concurrency handling"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import sqlite3
import json
from datetime import datetime
import os
import threading
import time

# Get database path - use shared data directory
DB_DIR = '/app/data'
DB_PATH = os.path.join(DB_DIR, 'lumenmon.db')

# Create data directory if it doesn't exist
os.makedirs(DB_DIR, exist_ok=True)

# Thread-local storage for database connections
thread_local = threading.local()

def get_db_connection():
    """Get a thread-local database connection with proper settings"""
    if not hasattr(thread_local, 'conn'):
        thread_local.conn = sqlite3.connect(DB_PATH, timeout=30.0)
        thread_local.conn.execute("PRAGMA journal_mode=WAL")
        thread_local.conn.execute("PRAGMA busy_timeout=30000")
        thread_local.conn.execute("PRAGMA synchronous=NORMAL")
    return thread_local.conn

def init_database():
    """Initialize database with tables and enable WAL mode"""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")  # Enable WAL mode for better concurrency
    conn.execute("PRAGMA busy_timeout=30000")
    c = conn.cursor()
    
    # Metrics table with type field
    c.execute('''CREATE TABLE IF NOT EXISTS metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        metric_name TEXT NOT NULL,
        metric_value REAL,
        metric_text TEXT,
        type TEXT DEFAULT 'float',
        tempo TEXT,
        interval INTEGER,
        host TEXT DEFAULT 'localhost'
    )''')
    
    # Messages table
    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        source TEXT,
        message TEXT
    )''')
    
    # Create indexes
    c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_time ON metrics(timestamp)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_type ON metrics(type)')
    
    conn.commit()
    conn.close()
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Database initialized with WAL mode")

class MetricsSink(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/metrics':
            # Receive metrics from collectors
            content = self.rfile.read(int(self.headers['Content-Length']))
            
            # Get thread-local connection
            conn = get_db_connection()
            c = conn.cursor()
            
            try:
                # Parse metrics - supports both old and new format
                lines = content.decode().split('\n')
                i = 0
                while i < len(lines):
                    line = lines[i]
                    if ':' in line and not line.startswith('#'):
                        parts = line.strip().split(':', 3)
                        
                        if len(parts) == 4:
                            # New format: name:value:type:interval
                            name, value, type_, interval = parts
                            name = name.strip()
                            value = value.strip()
                            type_ = type_.strip()
                            interval = interval.strip()
                            
                            # Handle multi-line blob data
                            if type_ == 'blob':
                                # Collect all lines until we hit the next metric or end
                                blob_lines = [value]
                                i += 1
                                while i < len(lines) and ':' not in lines[i]:
                                    blob_lines.append(lines[i])
                                    i += 1
                                i -= 1  # Back up one since we'll increment at the end
                                value = '\n'.join(blob_lines)
                            
                            # Store based on type - very readable!
                            if type_ in ['float', 'int']:
                                # Numeric types go to metric_value
                                numeric_value = float(value)
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_value, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, numeric_value, type_, int(interval)))
                            else:
                                # Text types (string, blob) go to metric_text
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_text, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, value, type_, int(interval)))
                        
                        elif len(parts) == 2:
                            # Old format backward compatibility: name:value
                            name, value = parts
                            name = name.strip()
                            value = value.strip()
                            
                            try:
                                # Try to store as numeric
                                numeric_value = float(value.replace('%', ''))
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_value, type) 
                                    VALUES (?, ?, 'float')
                                """, (name, numeric_value))
                            except ValueError:
                                # Store as text
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_text, type) 
                                    VALUES (?, ?, 'string')
                                """, (name, value))
                    i += 1
                
                conn.commit()
                
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Metrics received")
                
            except sqlite3.OperationalError as e:
                if "database is locked" in str(e):
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Database locked, retrying...")
                    time.sleep(0.1)
                    # Try once more
                    try:
                        conn.commit()
                        self.send_response(200)
                        self.end_headers()
                        self.wfile.write(b'OK')
                    except:
                        self.send_response(503)
                        self.end_headers()
                        self.wfile.write(b'Database busy, please retry')
                else:
                    raise
            except Exception as e:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Error: {e}")
                conn.rollback()
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f'Error: {e}'.encode())
        
        elif self.path == '/api/feed':
            # Store webhook/email messages
            try:
                content = json.loads(
                    self.rfile.read(int(self.headers['Content-Length']))
                )
                
                conn = get_db_connection()
                c = conn.cursor()
                c.execute(
                    "INSERT INTO messages (source, message) VALUES (?, ?)",
                    (content.get('source', 'unknown'), content.get('message', ''))
                )
                conn.commit()
                
                self.send_response(200)
                self.end_headers()
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Message from {content.get('source')}")
            except Exception as e:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Feed error: {e}")
                self.send_response(500)
                self.end_headers()
    
    def do_GET(self):
        if self.path == '/health':
            # Health check endpoint
            try:
                conn = get_db_connection()
                c = conn.cursor()
                c.execute("SELECT COUNT(*) FROM metrics")
                count = c.fetchone()[0]
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'status': 'healthy',
                    'metrics_count': count,
                    'database': DB_PATH
                }).encode())
            except Exception as e:
                self.send_response(503)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'status': 'unhealthy',
                    'error': str(e)
                }).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default HTTP logging"""
        pass

def cleanup_old_data():
    """Background thread to clean up old data periodically"""
    while True:
        try:
            time.sleep(3600)  # Run every hour
            conn = sqlite3.connect(DB_PATH, timeout=30.0)
            conn.execute("PRAGMA journal_mode=WAL")
            c = conn.cursor()
            
            # Delete metrics older than 30 days
            c.execute("DELETE FROM metrics WHERE timestamp < datetime('now', '-30 days')")
            deleted = c.rowcount
            
            # Delete messages older than 7 days
            c.execute("DELETE FROM messages WHERE timestamp < datetime('now', '-7 days')")
            deleted_msgs = c.rowcount
            
            # Vacuum periodically to reclaim space
            if deleted > 1000:
                conn.execute("VACUUM")
            
            conn.commit()
            conn.close()
            
            if deleted > 0 or deleted_msgs > 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Cleaned up {deleted} metrics and {deleted_msgs} messages")
                
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Cleanup error: {e}")

if __name__ == '__main__':
    init_database()
    
    # Start cleanup thread
    cleanup_thread = threading.Thread(target=cleanup_old_data, daemon=True)
    cleanup_thread.start()
    
    server = HTTPServer(('0.0.0.0', 8080), MetricsSink)
    print('Lumenmon Sink running on http://0.0.0.0:8080')
    print(f'Database: {DB_PATH}')
    print('Endpoints: POST /metrics, POST /api/feed, GET /health')
    print('WAL mode enabled for better concurrency')
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()