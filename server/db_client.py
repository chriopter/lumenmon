#!/usr/bin/env python3
"""
Lumenmon Database Client - HTTP client for database service
"""

import json
import urllib.request
import urllib.parse
from datetime import datetime

class DatabaseClient:
    def __init__(self, base_url="http://localhost:8082"):
        self.base_url = base_url
    
    def _make_request(self, endpoint, data):
        """Make HTTP request to database service"""
        try:
            url = f"{self.base_url}{endpoint}"
            json_data = json.dumps(data).encode()
            
            req = urllib.request.Request(url, data=json_data)
            req.add_header('Content-Type', 'application/json')
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode())
                return result
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def query(self, sql, params=None):
        """Execute SELECT query"""
        data = {'query': sql, 'params': params}
        return self._make_request('/query', data)
    
    def execute(self, sql, params=None):
        """Execute INSERT/UPDATE/DELETE"""
        data = {'query': sql, 'params': params}
        return self._make_request('/execute', data)
    
    def approve_client(self, fingerprint):
        """Approve a pending client"""
        data = {'fingerprint': fingerprint}
        return self._make_request('/approve', data)
    
    def sync_ssh_keys(self):
        """Sync SSH keys"""
        return self._make_request('/sync_keys', {})
    
    def get_clients(self, status=None):
        """Get clients list"""
        if status:
            return self.query("SELECT * FROM clients WHERE status = ? ORDER BY last_seen DESC", [status])
        else:
            return self.query("SELECT * FROM clients ORDER BY last_seen DESC")
    
    def get_pending_registrations(self):
        """Get pending registrations"""
        return self.query("SELECT * FROM pending_registrations ORDER BY last_seen DESC")
    
    def get_client_by_fingerprint(self, fingerprint):
        """Get client by fingerprint"""
        return self.query("SELECT * FROM clients WHERE fingerprint = ? LIMIT 1", [fingerprint])
    
    def insert_metric(self, table_name, metric_name, metric_value, metric_text, metric_type, interval_seconds, hostname):
        """Insert metric into client-specific table"""
        # First ensure the table exists
        create_result = self.execute(f'''CREATE TABLE IF NOT EXISTS {table_name} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            metric_name TEXT NOT NULL,
            metric_value REAL,
            metric_text TEXT,
            type TEXT DEFAULT 'float',
            interval_seconds INTEGER DEFAULT 0,
            hostname TEXT DEFAULT 'localhost'
        )''')
        
        if not create_result['success']:
            return create_result
        
        # Insert the metric
        return self.execute(f'''INSERT INTO {table_name} 
            (metric_name, metric_value, metric_text, type, interval_seconds, hostname)
            VALUES (?, ?, ?, ?, ?, ?)''', 
            [metric_name, metric_value, metric_text, metric_type, interval_seconds, hostname])
    
    def update_client_last_seen(self, client_id):
        """Update client last seen timestamp"""
        return self.execute("UPDATE clients SET last_seen = CURRENT_TIMESTAMP WHERE id = ?", [client_id])
    
    def add_pending_registration(self, fingerprint, hostname, pubkey):
        """Add or update pending registration"""
        # Check if exists
        existing = self.query("SELECT attempt_count FROM pending_registrations WHERE fingerprint = ?", [fingerprint])
        
        if existing['success'] and existing['data']:
            # Update existing
            attempt_count = existing['data'][0]['attempt_count'] + 1
            return self.execute('''UPDATE pending_registrations 
                SET last_seen = CURRENT_TIMESTAMP, attempt_count = ?
                WHERE fingerprint = ?''', [attempt_count, fingerprint])
        else:
            # Insert new
            return self.execute('''INSERT INTO pending_registrations 
                (fingerprint, hostname, pubkey, attempt_count)
                VALUES (?, ?, ?, 1)''', [fingerprint, hostname, pubkey])

# Global instance
db = DatabaseClient()