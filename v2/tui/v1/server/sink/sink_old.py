#!/usr/bin/env python3
"""Metrics sink that receives and stores data via database service"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime, timedelta
import os
import sys

# Add parent directory to path for imports
sys.path.append('/app')
from db_client import db

# Create data directory if it doesn't exist
os.makedirs('/app/data', exist_ok=True)

def init_database():
    """Database initialization is now handled by db_service"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Database initialization handled by db_service")
    return True

def sync_authorized_keys():
    """Sync SSH keys via database service"""
    result = db.sync_ssh_keys()
    return result.get('success', False)
        
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

def sync_ssh_keys():
    """Sync approved client SSH keys to authorized_keys file"""
    try:
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT pubkey FROM clients WHERE status = 'approved'")
        approved_keys = c.fetchall()
        conn.close()
        
        # Write authorized_keys file
        ssh_dir = '/home/metrics/.ssh'
        os.makedirs(ssh_dir, exist_ok=True)
        auth_file = os.path.join(ssh_dir, 'authorized_keys')
        
        with open(auth_file, 'w') as f:
            for key_row in approved_keys:
                if key_row[0]:  # Ensure key is not None
                    f.write(f"{key_row[0]}\n")
        
        # Set correct permissions
        os.chmod(auth_file, 0o600)
        os.system(f"chown metrics:metrics {auth_file}")
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Synced {len(approved_keys)} SSH keys to authorized_keys")
        return True
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Error syncing SSH keys: {e}")
        return False

def get_pending_registrations():
    """Get all pending registrations for dashboard display"""
    cleanup_expired_registrations()
    with pending_lock:
        return list(pending_registrations.values())

def validate_metric_data(name, value, type_, source_ip='unknown'):
    """Validate metric data before insertion
    Returns: (is_valid, error_reason)
    """
    # Check required fields
    if not name:
        return False, "Missing metric name"
    
    # Validate type
    valid_types = ['int', 'float', 'string', 'blob']
    if type_ not in valid_types:
        return False, f"Invalid type '{type_}'. Must be one of: {', '.join(valid_types)}"
    
    # Validate numeric types
    if type_ in ['int', 'float']:
        if value is None or value == '':
            return False, f"Empty value for numeric type '{type_}'"
        try:
            float_val = float(value)
            if type_ == 'int':
                # Check if it's actually an integer
                if not float_val.is_integer():
                    return False, f"Value '{value}' is not an integer"
        except (ValueError, TypeError):
            return False, f"Invalid {type_} value '{value}'"
    
    # Validate string length (prevent DoS)
    if type_ in ['string', 'blob']:
        if isinstance(value, str) and len(value) > 10000:
            return False, f"Value too long ({len(value)} chars, max 10000)"
    
    # Validate metric name format
    if len(name) > 255:
        return False, f"Metric name too long ({len(name)} chars, max 255)"
    
    return True, None

def log_rejected_metric(conn, raw_data, error_reason, source_ip='unknown'):
    """Log rejected metrics to database for debugging"""
    try:
        c = conn.cursor()
        # Truncate raw_data if too long
        if len(raw_data) > 1000:
            raw_data = raw_data[:1000] + '...(truncated)'
        
        c.execute("""
            INSERT INTO rejected_metrics (raw_data, error_reason, source_ip)
            VALUES (?, ?, ?)
        """, (raw_data, error_reason, source_ip))
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Failed to log rejected metric: {e}")

class MetricsSink(BaseHTTPRequestHandler):
    def do_GET(self):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] GET request received: {self.path}")
        
        if self.path == '/pending':
            # Return pending registrations for dashboard
            with pending_lock:
                # Clean up expired registrations
                cleanup_expired_registrations()
                
                # Format pending registrations
                pending_list = []
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Pending registrations: {len(pending_registrations)}")
                for fingerprint, info in pending_registrations.items():
                    pending_list.append({
                        'hostname': info['hostname'],
                        'fingerprint': fingerprint,
                        'pubkey': info['pubkey'],
                        'first_seen': info['first_seen'].isoformat(),
                        'attempt_count': info['attempt_count']
                    })
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(pending_list).encode())
        elif self.path.startswith('/approve/'):
            # Approve a pending registration
            fingerprint = self.path.split('/approve/')[1]
            
            with pending_lock:
                if fingerprint in pending_registrations:
                    info = pending_registrations[fingerprint]
                    
                    # Add to database as approved
                    conn = get_db_connection()
                    c = conn.cursor()
                    try:
                        c.execute("""
                            INSERT INTO clients (hostname, pubkey, fingerprint, status, created_at)
                            VALUES (?, ?, ?, 'approved', CURRENT_TIMESTAMP)
                        """, (info['hostname'], info['pubkey'], fingerprint))
                        conn.commit()
                        
                        # Remove from pending
                        del pending_registrations[fingerprint]
                        
                        # Sync SSH keys immediately
                        sync_ssh_keys()
                        
                        self.send_response(200)
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps({'status': 'approved'}).encode())
                    except sqlite3.IntegrityError:
                        self.send_response(409)
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps({'error': 'Client already exists'}).encode())
                else:
                    self.send_response(404)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'error': 'Registration not found'}).encode())
        elif self.path == '/test':
            # Simple test endpoint
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"GET handler is working!")
        elif self.path == '/health':
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
            print(f"[{datetime.now().strftime('%H:%M:%S')}] 404 for path: {self.path}")
            self.send_response(404)
            self.end_headers()
    
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
                        
                        # If approved, ensure SSH keys are synced
                        if status == 'approved':
                            sync_ssh_keys()
                        
                        self.send_response(200)
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps({
                            'status': status,
                            'message': f'Client already registered with status: {status}',
                            'client_id': client_id
                        }).encode())
                    else:
                        # New client - store in pending_registrations table
                        now = datetime.now()
                        
                        # Check if already in pending
                        c.execute("SELECT attempt_count FROM pending_registrations WHERE fingerprint = ?", (fingerprint,))
                        pending_result = c.fetchone()
                        
                        if pending_result:
                            # Update existing pending registration
                            attempt_count = pending_result[0] + 1
                            c.execute("""
                                UPDATE pending_registrations 
                                SET last_seen = CURRENT_TIMESTAMP, attempt_count = ?
                                WHERE fingerprint = ?
                            """, (attempt_count, fingerprint))
                        else:
                            # New pending registration
                            attempt_count = 1
                            c.execute("""
                                INSERT INTO pending_registrations (fingerprint, hostname, pubkey, attempt_count)
                                VALUES (?, ?, ?, ?)
                            """, (fingerprint, hostname, pubkey, attempt_count))
                            
                            # Count total pending
                            c.execute("SELECT COUNT(*) FROM pending_registrations")
                            total_pending = c.fetchone()[0]
                            print(f"[{now.strftime('%H:%M:%S')}] NEW PENDING REGISTRATION: {hostname} ({fingerprint[:20]}...) - Total pending: {total_pending}")
                        
                        conn.commit()
                        
                        # Clean up old entries periodically (older than 10 minutes)
                        c.execute("""
                            DELETE FROM pending_registrations 
                            WHERE datetime(last_seen) < datetime('now', '-10 minutes')
                        """)
                        
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
            
            # Get source IP for logging
            source_ip = self.client_address[0] if self.client_address else 'unknown'
            
            # Get thread-local connection
            conn = get_db_connection()
            c = conn.cursor()
            
            # Track metrics processing
            metrics_received = 0
            metrics_accepted = 0
            metrics_rejected = 0
            
            try:
                # Parse metrics - supports JSON and old format
                for line in content.decode().split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Try JSON format first
                    if line.startswith('{'):
                        try:
                            metrics_received += 1
                            data = json.loads(line)
                            name = data.get('name', '')
                            value = data.get('value', '')
                            type_ = data.get('type', 'string')
                            interval = data.get('interval', 0)
                            hostname = data.get('hostname', 'unknown')
                            fingerprint = data.get('fingerprint', '')
                            
                            # Validate metric data
                            is_valid, error_reason = validate_metric_data(name, value, type_, source_ip)
                            if not is_valid:
                                metrics_rejected += 1
                                log_rejected_metric(conn, line, error_reason, source_ip)
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] Rejected metric '{name}': {error_reason}")
                                continue
                            
                            # Decode base64 for blob types
                            if type_ == 'blob':
                                try:
                                    import base64
                                    value = base64.b64decode(value).decode('utf-8')
                                except Exception:
                                    # If decode fails, keep as is
                                    pass
                            
                            # ZERO-TRUST: Require valid fingerprint for ALL metrics
                            if not fingerprint:
                                metrics_rejected += 1
                                error_reason = "No fingerprint provided - zero-trust policy requires authentication"
                                log_rejected_metric(conn, line, error_reason, source_ip)
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Rejected metric '{name}' from {hostname}: {error_reason}")
                                continue
                            
                            # Debug: Log received data
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] Received metric: name={name}, hostname={hostname}, fingerprint={fingerprint[:16]}...")
                            
                            # Look up client by fingerprint
                            c.execute("""
                                SELECT id, hostname, status FROM clients 
                                WHERE fingerprint = ?
                            """, (fingerprint,))
                            client_result = c.fetchone()
                            
                            if not client_result:
                                # Unknown fingerprint, reject
                                metrics_rejected += 1
                                error_reason = f"Unknown client fingerprint: {fingerprint}"
                                log_rejected_metric(conn, line, error_reason, source_ip)
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] ⚠️ {error_reason}")
                                continue
                            
                            client_id, db_hostname, status = client_result
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] Found client: id={client_id}, hostname={db_hostname}, status={status}")
                            
                            if status != 'approved':
                                # Client not approved, reject
                                metrics_rejected += 1
                                error_reason = f"Client not approved: {hostname} (status={status})"
                                log_rejected_metric(conn, line, error_reason, source_ip)
                                print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ {error_reason}")
                                continue
                            
                            # Client is approved - use client-specific table
                            table_name = f'metrics_{client_id}'
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] Creating/using table: {table_name}")
                            
                            # Create table if it doesn't exist
                            c.execute(f"""
                                CREATE TABLE IF NOT EXISTS {table_name} (
                                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                                    metric_name TEXT NOT NULL,
                                    metric_value REAL,
                                    metric_text TEXT,
                                    type TEXT DEFAULT 'float',
                                    interval INTEGER
                                )
                            """)
                            
                            # Create indexes for client table
                            c.execute(f'CREATE INDEX IF NOT EXISTS idx_{table_name}_time ON {table_name}(timestamp DESC)')
                            c.execute(f'CREATE INDEX IF NOT EXISTS idx_{table_name}_name ON {table_name}(metric_name)')
                            
                            # Update last_seen for client
                            c.execute("""
                                UPDATE clients SET last_seen = CURRENT_TIMESTAMP 
                                WHERE id = ?
                            """, (client_id,))
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Client approved, using table {table_name}")
                            
                            # Store based on type in appropriate table
                            if type_ in ['float', 'int']:
                                numeric_value = float(value)
                                c.execute(f"""
                                    INSERT INTO {table_name} 
                                    (metric_name, metric_value, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, numeric_value, type_, interval))
                            else:
                                # Text types (string, blob) go to metric_text
                                c.execute(f"""
                                    INSERT INTO {table_name} 
                                    (metric_name, metric_text, type, interval) 
                                    VALUES (?, ?, ?, ?)
                                """, (name, str(value), type_, interval))
                            metrics_accepted += 1
                            continue
                        except json.JSONDecodeError as e:
                            metrics_rejected += 1
                            log_rejected_metric(conn, line, f"JSON parse error: {e}", source_ip)
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] JSON parse error: {e}")
                        except Exception as e:
                            metrics_rejected += 1
                            log_rejected_metric(conn, line, f"Processing error: {e}", source_ip)
                            print(f"[{datetime.now().strftime('%H:%M:%S')}] Metric processing error: {e}")
                    
                    # Fallback to old colon format for backward compatibility
                    if ':' in line:
                        metrics_received += 1
                        parts = line.split(':', 1)
                        if len(parts) == 2:
                            name, value = parts
                            name = name.strip()
                            value = value.strip()
                            
                            # Auto-detect type for old format
                            try:
                                # Try to store as numeric
                                numeric_value = float(value.replace('%', ''))
                                type_ = 'float'
                                
                                # Validate before inserting
                                is_valid, error_reason = validate_metric_data(name, numeric_value, type_, source_ip)
                                if not is_valid:
                                    metrics_rejected += 1
                                    log_rejected_metric(conn, line, error_reason, source_ip)
                                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Rejected metric '{name}': {error_reason}")
                                    continue
                                
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_value, type) 
                                    VALUES (?, ?, ?)
                                """, (name, numeric_value, type_))
                                metrics_accepted += 1
                            except ValueError:
                                # Store as text
                                type_ = 'string'
                                
                                # Validate before inserting
                                is_valid, error_reason = validate_metric_data(name, value, type_, source_ip)
                                if not is_valid:
                                    metrics_rejected += 1
                                    log_rejected_metric(conn, line, error_reason, source_ip)
                                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Rejected metric '{name}': {error_reason}")
                                    continue
                                
                                c.execute("""
                                    INSERT INTO metrics 
                                    (metric_name, metric_text, type) 
                                    VALUES (?, ?, ?)
                                """, (name, value, type_))
                                metrics_accepted += 1
                
                conn.commit()
                
                # Return appropriate status based on results
                if metrics_received > 0 and metrics_accepted == 0:
                    # All metrics were rejected
                    self.send_response(422)  # Unprocessable Entity
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({
                        'status': 'error',
                        'message': 'All metrics rejected',
                        'received': metrics_received,
                        'accepted': metrics_accepted,
                        'rejected': metrics_rejected
                    }).encode())
                else:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({
                        'status': 'ok',
                        'received': metrics_received,
                        'accepted': metrics_accepted,
                        'rejected': metrics_rejected
                    }).encode())
                
                if metrics_received > 0:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Metrics: {metrics_accepted}/{metrics_received} accepted, {metrics_rejected} rejected")
                
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
    
    # REMOVED - Merged with first do_GET above
    def do_GET_old(self):
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
        """Log HTTP requests for debugging"""
        # Temporarily enable to debug
        if "/pending" in format or "GET" in format:
            print(f"[HTTP] {format % args}")
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