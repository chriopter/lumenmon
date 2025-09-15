#!/usr/bin/env python3
"""
Lumenmon Metrics Sink - Database Service Version
Simple metrics receiver that uses central database service
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime
import os
import sys
import subprocess

# Add parent directory to path for imports
sys.path.append('/app')
from db_client import db

def calculate_fingerprint(pubkey):
    """Calculate SSH key fingerprint using ssh-keygen"""
    try:
        # Create temporary key file
        temp_file = '/tmp/temp_pubkey'
        with open(temp_file, 'w') as f:
            f.write(pubkey)
        
        # Calculate fingerprint
        result = subprocess.run(['ssh-keygen', '-lf', temp_file], 
                              capture_output=True, text=True)
        
        # Clean up temp file
        os.unlink(temp_file)
        
        if result.returncode == 0:
            # Extract fingerprint (second field)
            fingerprint = result.stdout.split()[1]
            return fingerprint
        else:
            print(f"[SINK] ssh-keygen error: {result.stderr}")
            return None
    except Exception as e:
        print(f"[SINK] Error calculating fingerprint: {e}")
        return None

def validate_metric_data(name, value, type_, source_ip='unknown'):
    """Validate metric data before insertion"""
    if not name:
        return False, "Missing metric name"
    
    valid_types = ['int', 'float', 'string', 'blob']
    if type_ not in valid_types:
        return False, f"Invalid type '{type_}'"
    
    if type_ in ['int', 'float']:
        if value is None or value == '':
            return False, f"Empty value for numeric type '{type_}'"
        try:
            float_val = float(value)
            if type_ == 'int' and not float_val.is_integer():
                return False, f"Value '{value}' is not an integer"
        except (ValueError, TypeError):
            return False, f"Invalid {type_} value '{value}'"
    
    if type_ in ['string', 'blob'] and isinstance(value, str) and len(value) > 10000:
        return False, f"Value too long ({len(value)} chars, max 10000)"
    
    return True, None

class SinkHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Suppress default HTTP logging"""
        pass
    
    def do_POST(self):
        if self.path == '/register':
            self.handle_registration()
        elif self.path == '/metrics':
            self.handle_metrics()
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy'}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def handle_registration(self):
        """Handle client SSH key registration"""
        try:
            content = self.rfile.read(int(self.headers['Content-Length']))
            data = json.loads(content)
            hostname = data.get('hostname', 'unknown')
            pubkey = data.get('pubkey', '')
            
            if not pubkey:
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': 'Missing public key'}).encode())
                return
            
            # Calculate fingerprint
            fingerprint = calculate_fingerprint(pubkey)
            if not fingerprint:
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': 'Invalid public key'}).encode())
                return
            
            # Check if already approved
            existing = db.get_client_by_fingerprint(fingerprint)
            if existing['success'] and existing['data']:
                client = existing['data'][0]
                status = client['status']
                
                # If approved, sync SSH keys
                if status == 'approved':
                    db.sync_ssh_keys()
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'status': status,
                    'message': f'Client already registered with status: {status}',
                    'client_id': client['id']
                }).encode())
            else:
                # Add to pending registrations
                result = db.add_pending_registration(fingerprint, hostname, pubkey)
                if result['success']:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] NEW REGISTRATION: {hostname} ({fingerprint[:20]}...)")
                    self.send_response(202)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({
                        'status': 'pending',
                        'message': 'SSH key submitted for approval',
                        'fingerprint': fingerprint
                    }).encode())
                else:
                    self.send_response(500)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'error': result['error']}).encode())
                    
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Registration error: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f'Error: {e}'.encode())
    
    def handle_metrics(self):
        """Handle metrics submission"""
        try:
            content = self.rfile.read(int(self.headers['Content-Length']))
            source_ip = self.client_address[0] if self.client_address else 'unknown'
            
            metrics_received = 0
            metrics_accepted = 0
            metrics_rejected = 0
            
            # Parse each line as JSON metric
            for line in content.decode().strip().split('\n'):
                if not line.strip():
                    continue
                
                metrics_received += 1
                
                try:
                    metric = json.loads(line)
                    name = metric.get('name', '')
                    value = metric.get('value')
                    type_ = metric.get('type', 'float')
                    interval_seconds = metric.get('interval', 0)
                    hostname = metric.get('hostname', 'unknown')
                    fingerprint = metric.get('fingerprint', '')
                    
                    # ZERO-TRUST: Require valid fingerprint
                    if not fingerprint:
                        metrics_rejected += 1
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Rejected '{name}' from {hostname}: No fingerprint")
                        continue
                    
                    # Validate metric data
                    is_valid, error_reason = validate_metric_data(name, value, type_, source_ip)
                    if not is_valid:
                        metrics_rejected += 1
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Rejected '{name}': {error_reason}")
                        continue
                    
                    # Get client by fingerprint
                    client_result = db.get_client_by_fingerprint(fingerprint)
                    if not client_result['success'] or not client_result['data']:
                        metrics_rejected += 1
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Rejected '{name}': Unknown fingerprint {fingerprint[:20]}...")
                        continue
                    
                    client = client_result['data'][0]
                    if client['status'] != 'approved':
                        metrics_rejected += 1
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Rejected '{name}': Client not approved")
                        continue
                    
                    # Insert into client-specific table
                    table_name = f"metrics_{client['id']}"
                    
                    # Prepare values based on type
                    if type_ in ['int', 'float']:
                        metric_value = float(value)
                        metric_text = None
                    else:
                        metric_value = None
                        metric_text = str(value)
                    
                    # Insert metric
                    insert_result = db.insert_metric(table_name, name, metric_value, metric_text, type_, interval_seconds, hostname)
                    if insert_result['success']:
                        metrics_accepted += 1
                        
                        # Update client last seen
                        db.update_client_last_seen(client['id'])
                    else:
                        metrics_rejected += 1
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Failed to insert '{name}': {insert_result['error']}")
                
                except json.JSONDecodeError:
                    metrics_rejected += 1
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Invalid JSON: {line[:100]}")
                except Exception as e:
                    metrics_rejected += 1
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Error processing metric: {e}")
            
            # Send response
            if metrics_accepted > 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Metrics: {metrics_accepted}/{metrics_received} accepted, {metrics_rejected} rejected")
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'status': 'success',
                    'received': metrics_received,
                    'accepted': metrics_accepted,
                    'rejected': metrics_rejected
                }).encode())
            else:
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'status': 'error',
                    'message': 'All metrics rejected',
                    'received': metrics_received,
                    'accepted': metrics_accepted,
                    'rejected': metrics_rejected
                }).encode())
                
        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Metrics handler error: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f'Error: {e}'.encode())

def run_sink():
    """Run the metrics sink server"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [SINK] Starting metrics sink on port 8080")
    
    server = HTTPServer(('0.0.0.0', 8080), SinkHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] [SINK] Shutting down")
        server.shutdown()

if __name__ == '__main__':
    run_sink()