#!/usr/bin/env python3
"""Metrics sink that receives and stores data in SQLite with proper concurrency handling"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import sqlite3
import json
from datetime import datetime, timedelta
import os
import threading
import time
import subprocess

# Get database path - use shared data directory
DB_DIR = '/app/data'
DB_PATH = os.path.join(DB_DIR, 'lumenmon.db')

# Create data directory if it doesn't exist
os.makedirs(DB_DIR, exist_ok=True)

# Thread-local storage for database connections
thread_local = threading.local()

# In-memory storage for pending registrations (not yet approved)
# Protected by lock for thread safety
pending_registrations = {}
pending_lock = threading.Lock()
REGISTRATION_EXPIRY_MINUTES = 10

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
    
    # Clients table for SSH key management
    c.execute('''CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT NOT NULL,
        pubkey TEXT NOT NULL,
        fingerprint TEXT,
        status TEXT DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        approved_at DATETIME,
        last_seen DATETIME,
        UNIQUE(pubkey)
    )''')
    
    # Create indexes
    c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_time ON metrics(timestamp)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_clients_status ON clients(status)')
    
    # Try to create type index - may fail on old databases
    try:
        c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_type ON metrics(type)')
    except sqlite3.OperationalError:
        # Old database without type column - that's ok
        pass
    
    conn.commit()
    conn.close()
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Database initialized with WAL mode")

def sync_authorized_keys():
    """Sync approved client SSH keys from database to authorized_keys file"""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        
        # Get all approved client keys
        c.execute("SELECT pubkey FROM clients WHERE status = 'approved'")
        approved_keys = c.fetchall()
        conn.close()
        
        # Ensure .ssh directory exists
        ssh_dir = '/home/metrics/.ssh'
        os.makedirs(ssh_dir, exist_ok=True)
        
        # Write authorized_keys file
        auth_file = os.path.join(ssh_dir, 'authorized_keys')
        with open(auth_file, 'w') as f:
            for key_row in approved_keys:
                f.write(f"{key_row[0]}\n")
        
        # Set proper permissions
        os.chmod(auth_file, 0o600)
        os.chown(auth_file, 1000, 1000)  # metrics user
        
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Synced {len(approved_keys)} approved keys to authorized_keys")
        return True
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Error syncing authorized_keys: {e}")
        return False

def calculate_fingerprint(pubkey):
    """Calculate SSH key fingerprint"""
    import tempfile
    import hashlib
    import base64
    
    # Ensure pubkey is a string
    if isinstance(pubkey, bytes):
        pubkey = pubkey.decode('utf-8')
    
    try:
        # Try using ssh-keygen first
        with tempfile.NamedTemporaryFile(mode='w', suffix='.pub', delete=False) as f:
            f.write(pubkey)
            temp_path = f.name
        
        result = subprocess.run(
            ['ssh-keygen', '-lf', temp_path],
            capture_output=True,
            text=True
        )
        
        os.unlink(temp_path)
        
        if result.returncode == 0:
            # Format: "2048 SHA256:xxx... comment"
            parts = result.stdout.strip().split()
            if len(parts) >= 2:
                return parts[1]
    except Exception:
        pass  # Silently fall through to Python implementation
    
    # Fallback: Calculate SHA256 fingerprint manually
    try:
        # Extract the base64 key part (skip ssh-rsa prefix and comment)
        key_parts = pubkey.strip().split()
        if len(key_parts) >= 2:
            key_data = key_parts[1]
            # Decode base64 and hash
            decoded = base64.b64decode(key_data)
            sha256 = hashlib.sha256(decoded).digest()
            fingerprint = "SHA256:" + base64.b64encode(sha256).decode('ascii').rstrip('=')
            return fingerprint
    except Exception as e:
        print(f"[ERROR] Failed to calculate fingerprint: {e}")
    
    return None

def cleanup_expired_registrations():
    """Remove registration attempts older than REGISTRATION_EXPIRY_MINUTES"""
    with pending_lock:
        now = datetime.now()
        expired_keys = []
        for key, data in pending_registrations.items():
            # Handle both datetime objects and ISO strings
            first_seen = data['first_seen']
            if isinstance(first_seen, str):
                first_seen = datetime.fromisoformat(first_seen)
            
            if now - first_seen > timedelta(minutes=REGISTRATION_EXPIRY_MINUTES):
                expired_keys.append(key)
        
        for key in expired_keys:
            del pending_registrations[key]
        
        if expired_keys:
            print(f"[{now.strftime('%H:%M:%S')}] Cleaned up {len(expired_keys)} expired registration attempts")

def get_pending_registrations():
    """Get all pending registrations for dashboard display"""
    cleanup_expired_registrations()
    with pending_lock:
        return list(pending_registrations.values())

class MetricsSink(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/register':
            # Client registration endpoint for SSH key submission
            try:
                content = self.rfile.read(int(self.headers['Content-Length']))
                data = json.loads(content)
                hostname = data.get('hostname', 'unknown')
                pubkey = data.get('pubkey', '')
                
                if pubkey:
                    # Calculate fingerprint
                    fingerprint = calculate_fingerprint(pubkey)
                    
                    # Check if already approved in database
                    conn = get_db_connection()
                    c = conn.cursor()
                    c.execute("SELECT status, id FROM clients WHERE pubkey = ?", (pubkey,))
                    db_result = c.fetchone()
                    
                    if db_result:
                        # Client already in database (approved or rejected)
                        status, client_id = db_result
                        self.send_response(200)
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps({
                            'status': status,
                            'message': f'Client already registered with status: {status}',
                            'client_id': client_id
                        }).encode())
                    else:
                        # New client - store in memory only
                        now = datetime.now()
                        
                        # Use fingerprint as key (or hash of pubkey if no fingerprint)
                        reg_key = fingerprint or str(hash(pubkey))
                        
                        with pending_lock:
                            if reg_key in pending_registrations:
                                # Update existing registration attempt
                                pending_registrations[reg_key]['last_seen'] = now
                                pending_registrations[reg_key]['attempt_count'] += 1
                                attempt_count = pending_registrations[reg_key]['attempt_count']
                            else:
                                # New registration attempt
                                pending_registrations[reg_key] = {
                                    'hostname': hostname,
                                    'pubkey': pubkey,
                                    'fingerprint': fingerprint,
                                    'first_seen': now,
                                    'last_seen': now,
                                    'attempt_count': 1,
                                    'key': reg_key
                                }
                                attempt_count = 1
                        
                        # Clean up old entries periodically
                        if len(pending_registrations) % 10 == 0:
                            cleanup_expired_registrations()
                        
                        print(f"[{now.strftime('%H:%M:%S')}] REGISTRATION ATTEMPT: {hostname} (fingerprint: {fingerprint}, attempts: {attempt_count})")
                        
                        self.send_response(202)  # Accepted for processing
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps({
                            'status': 'pending',
                            'message': 'SSH key submitted for approval. Admin will review.',
                            'fingerprint': fingerprint,
                            'attempts': attempt_count
                        }).encode())
                else:
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b'Missing public key')
            except Exception as e:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Registration error: {e}")
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f'Error: {e}'.encode())
        
        elif self.path == '/metrics':
            # Receive metrics from collectors
            content = self.rfile.read(int(self.headers['Content-Length']))
            
            # Get thread-local connection
            conn = get_db_connection()
            c = conn.cursor()
            
            try:
                # Parse metrics - supports JSON and old format
                for line in content.decode().split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Try JSON format first
                    if line.startswith('{'):
                        try:
                            data = json.loads(line)
                            name = data.get('name', '')
                            value = data.get('value', '')
                            type_ = data.get('type', 'string')
                            interval = data.get('interval', 0)
                            
                            # Decode base64 for blob types
                            if type_ == 'blob':
                                try:
                                    import base64
                                    value = base64.b64decode(value).decode('utf-8')
                                except Exception:
                                    # If decode fails, keep as is
                                    pass
                            
                            # Store based on type
                            if type_ in ['float', 'int']:
                                numeric_value = float(value)
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_value, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, numeric_value, type_, interval))
                            else:
                                # Text types (string, blob) go to metric_text
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_text, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, str(value), type_, interval))
                            continue
                        except (json.JSONDecodeError, ValueError) as e:
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] JSON parse error: {e}")
                    
                    # Fallback to old colon format for backward compatibility
                    if ':' in line:
                        parts = line.split(':', 1)
                        if len(parts) == 2:
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
        elif self.path == '/api/pending':
            # Return pending registrations for dashboard
            import copy
            pending = get_pending_registrations()
            # Make a copy and convert datetime objects to strings for JSON serialization
            pending_json = []
            for reg in pending:
                reg_copy = copy.deepcopy(reg)
                if isinstance(reg_copy['first_seen'], datetime):
                    reg_copy['first_seen'] = reg_copy['first_seen'].isoformat()
                if isinstance(reg_copy['last_seen'], datetime):
                    reg_copy['last_seen'] = reg_copy['last_seen'].isoformat()
                pending_json.append(reg_copy)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(pending_json).encode())
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

def periodic_registration_cleanup():
    """Background thread to clean up expired registrations"""
    while True:
        time.sleep(60)  # Run every minute
        cleanup_expired_registrations()

if __name__ == '__main__':
    init_database()
    
    # Start cleanup threads
    cleanup_thread = threading.Thread(target=cleanup_old_data, daemon=True)
    cleanup_thread.start()
    
    registration_cleanup_thread = threading.Thread(target=periodic_registration_cleanup, daemon=True)
    registration_cleanup_thread.start()
    
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