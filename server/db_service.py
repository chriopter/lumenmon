#!/usr/bin/env python3
"""
Lumenmon Database Service - Central SQLite connector
Eliminates database locking issues by providing single DB access point
"""

import sqlite3
import json
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

# Configuration
DB_PATH = '/app/data/lumenmon.db'
PORT = 8082

# Global database connection
db_lock = threading.Lock()

class DatabaseService:
    def __init__(self, db_path):
        self.db_path = db_path
        self.init_database()
    
    def get_connection(self):
        """Get database connection with proper settings"""
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=30000") 
        conn.execute("PRAGMA synchronous=NORMAL")
        return conn
    
    def init_database(self):
        """Initialize database with all required tables"""
        with db_lock:
            conn = self.get_connection()
            c = conn.cursor()
            
            # Main metrics table
            c.execute('''CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                metric_name TEXT NOT NULL,
                metric_value REAL,
                metric_text TEXT,
                type TEXT DEFAULT 'float',
                interval_seconds INTEGER DEFAULT 0,
                hostname TEXT DEFAULT 'localhost'
            )''')
            
            # Clients table
            c.execute('''CREATE TABLE IF NOT EXISTS clients (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hostname TEXT NOT NULL,
                pubkey TEXT NOT NULL UNIQUE,
                fingerprint TEXT NOT NULL UNIQUE,
                status TEXT DEFAULT 'pending',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                approved_at DATETIME,
                last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
            )''')
            
            # Pending registrations table
            c.execute('''CREATE TABLE IF NOT EXISTS pending_registrations (
                fingerprint TEXT PRIMARY KEY,
                hostname TEXT NOT NULL,
                pubkey TEXT NOT NULL,
                first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
                attempt_count INTEGER DEFAULT 1
            )''')
            
            # Create indexes
            c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_time ON metrics(timestamp)')
            c.execute('CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name)')
            c.execute('CREATE INDEX IF NOT EXISTS idx_clients_status ON clients(status)')
            
            conn.commit()
            conn.close()
    
    def execute_query(self, query, params=None):
        """Execute SELECT query and return results"""
        with db_lock:
            conn = self.get_connection()
            try:
                c = conn.cursor()
                if params:
                    c.execute(query, params)
                else:
                    c.execute(query)
                
                # Fetch all results with column names
                results = c.fetchall()
                columns = [desc[0] for desc in c.description] if c.description else []
                
                # Convert to list of dicts
                rows = []
                for row in results:
                    rows.append(dict(zip(columns, row)))
                
                return {'success': True, 'data': rows, 'count': len(rows)}
            except Exception as e:
                return {'success': False, 'error': str(e)}
            finally:
                conn.close()
    
    def execute_command(self, query, params=None):
        """Execute INSERT/UPDATE/DELETE command"""
        with db_lock:
            conn = self.get_connection()
            try:
                c = conn.cursor()
                if params:
                    c.execute(query, params)
                else:
                    c.execute(query)
                
                conn.commit()
                return {'success': True, 'rowcount': c.rowcount, 'lastrowid': c.lastrowid}
            except Exception as e:
                return {'success': False, 'error': str(e)}
            finally:
                conn.close()
    
    def approve_client(self, fingerprint):
        """Approve a pending client registration"""
        with db_lock:
            conn = self.get_connection()
            try:
                c = conn.cursor()
                
                # Get pending registration
                c.execute("SELECT hostname, pubkey FROM pending_registrations WHERE fingerprint = ?", (fingerprint,))
                pending = c.fetchone()
                
                if not pending:
                    return {'success': False, 'error': 'Registration not found'}
                
                hostname, pubkey = pending
                
                # Move to clients table
                c.execute("""
                    INSERT OR REPLACE INTO clients (hostname, pubkey, fingerprint, status, created_at, last_seen)
                    VALUES (?, ?, ?, 'approved', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (hostname, pubkey, fingerprint))
                
                # Remove from pending
                c.execute("DELETE FROM pending_registrations WHERE fingerprint = ?", (fingerprint,))
                
                # Sync SSH keys
                self.sync_ssh_keys(c)
                
                conn.commit()
                return {'success': True, 'message': 'Client approved and SSH keys synced'}
            except Exception as e:
                return {'success': False, 'error': str(e)}
            finally:
                conn.close()
    
    def sync_ssh_keys(self, cursor=None):
        """Sync approved client SSH keys to authorized_keys file"""
        try:
            if cursor:
                c = cursor
            else:
                conn = self.get_connection()
                c = conn.cursor()
            
            c.execute("SELECT pubkey FROM clients WHERE status = 'approved'")
            approved_keys = c.fetchall()
            
            if not cursor:
                conn.close()
            
            # Write authorized_keys file
            ssh_dir = '/home/metrics/.ssh'
            os.makedirs(ssh_dir, exist_ok=True)
            auth_file = os.path.join(ssh_dir, 'authorized_keys')
            
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Writing {len(approved_keys)} keys to {auth_file}")
            
            with open(auth_file, 'w') as f:
                for i, key_row in enumerate(approved_keys):
                    if key_row[0]:  # Ensure key is not None
                        key = key_row[0].strip()
                        f.write(f"{key}\n")
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Added key {i+1}: {key[:50]}...")
            
            # Set correct permissions
            os.chmod(auth_file, 0o600)
            os.system(f"chown metrics:metrics {auth_file}")
            
            # Verify the file was written
            with open(auth_file, 'r') as f:
                lines = f.readlines()
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Verified {len(lines)} keys in {auth_file}")
            
            # Debug: Show file permissions and contents
            import subprocess
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] === SSH DEBUG INFO ===")
            result = subprocess.run(['ls', '-la', '/home/metrics/.ssh/'], capture_output=True, text=True)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Directory listing:\n{result.stdout}")
            
            result = subprocess.run(['cat', auth_file], capture_output=True, text=True)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] authorized_keys contents:\n{result.stdout}")
            
            result = subprocess.run(['id', 'metrics'], capture_output=True, text=True)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] metrics user info: {result.stdout.strip()}")
            
            # Reload SSH daemon to pick up new keys
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Reloading SSH daemon...")
            result = subprocess.run(['killall', '-HUP', 'sshd'], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] ✅ SSH daemon reloaded")
            else:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] ⚠️ Could not reload SSH: {result.stderr}")
            
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] === END DEBUG INFO ===")
            
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] ✅ SSH keys sync complete")
            return True
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Error syncing SSH keys: {e}")
            return False

# Global service instance
db_service = DatabaseService(DB_PATH)

class DatabaseHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Suppress default HTTP logging"""
        pass
    
    def do_POST(self):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode())
            
            if self.path == '/query':
                # Execute SELECT query
                query = data.get('query')
                params = data.get('params')
                result = db_service.execute_query(query, params)
                
            elif self.path == '/execute':
                # Execute INSERT/UPDATE/DELETE
                query = data.get('query')
                params = data.get('params')
                result = db_service.execute_command(query, params)
                
            elif self.path == '/approve':
                # Approve client
                fingerprint = data.get('fingerprint')
                result = db_service.approve_client(fingerprint)
                
            elif self.path == '/sync_keys':
                # Sync SSH keys
                success = db_service.sync_ssh_keys()
                result = {'success': success}
                
            else:
                self.send_response(404)
                self.end_headers()
                return
            
            # Send response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
            
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = {'success': False, 'error': str(e)}
            self.wfile.write(json.dumps(error_response).encode())
    
    def do_GET(self):
        if self.path == '/health':
            # Health check
            try:
                result = db_service.execute_query("SELECT COUNT(*) as count FROM metrics")
                if result['success']:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'status': 'healthy', 'metrics_count': result['data'][0]['count']}).encode())
                else:
                    raise Exception(result['error'])
            except Exception as e:
                self.send_response(503)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'status': 'unhealthy', 'error': str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    """Run the database service HTTP server"""
    server = HTTPServer(('0.0.0.0', PORT), DatabaseHandler)
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Database service starting on port {PORT}")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [DB] Database path: {DB_PATH}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] [DB] Database service shutting down")
        server.shutdown()

if __name__ == '__main__':
    run_server()