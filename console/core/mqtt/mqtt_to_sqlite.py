#!/usr/bin/env python3
# MQTT to SQLite bridge - subscribes to metrics/# and writes directly to database.
# Uses persistent SQLite connection for better performance (~33% latency reduction).

import paho.mqtt.client as mqtt
import sqlite3
import re
import sys
import time
from datetime import datetime

# Add app directory to path for imports
sys.path.insert(0, '/app/web/app')
from pending_invites import clear_invite

DB_PATH = "/data/metrics.db"

def log(agent_id, message):
    """Log messages to stdout (captured by Docker logs with rotation)"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_msg = f"[{timestamp}] [{agent_id}] {message}"
    print(log_msg, flush=True)

class MQTTBridge:
    """MQTT to SQLite bridge with persistent database connection."""

    def __init__(self):
        self.db_conn = None
        self.mqtt_client = None
        self.connect_db()

    def connect_db(self):
        """Establish persistent SQLite connection with optimizations."""
        try:
            self.db_conn = sqlite3.connect(DB_PATH)
            # Optimize for write performance (WAL mode should already be set by console.sh)
            self.db_conn.execute("PRAGMA synchronous=NORMAL")  # Good balance for metrics
            log('db', 'Connected to SQLite with persistent connection')
        except Exception as e:
            log('db', f'ERROR: Failed to connect to database: {e}')
            sys.exit(1)

    def reconnect_db(self):
        """Reconnect to database after error."""
        log('db', 'Reconnecting to database...')
        try:
            if self.db_conn:
                self.db_conn.close()
        except:
            pass
        self.connect_db()

    def on_connect(self, client, userdata, flags, rc):
        """Callback when connected to MQTT broker"""
        if rc == 0:
            log('mqtt', 'Connected to MQTT broker')
            client.subscribe("metrics/#")
            log('mqtt', 'Subscribed to metrics/#')
        else:
            log('mqtt', f'Connection failed with code {rc}')

    def on_message(self, client, userdata, msg):
        """Callback when MQTT message received - write to SQLite with persistent connection."""
        try:
            # Parse topic: metrics/<agent_id>/<metric_name>
            parts = msg.topic.split('/')
            if len(parts) != 3 or parts[0] != 'metrics':
                log('error', f'Invalid topic format: {msg.topic}')
                return

            agent_id = parts[1]
            metric_name = parts[2]

            # Validate agent_id format (security)
            if not re.match(r'^[a-zA-Z0-9_-]+$', agent_id):
                log('error', f'Invalid agent_id: {agent_id}')
                return

            # Validate metric_name format
            if not re.match(r'^[a-zA-Z0-9_-]+$', metric_name):
                log('error', f'Invalid metric_name: {metric_name}')
                return

            # Parse JSON payload
            import json
            try:
                data = json.loads(msg.payload.decode())
            except json.JSONDecodeError as e:
                log(agent_id, f'Invalid JSON payload: {e}')
                return

            # Extract value, type, and interval from JSON
            if 'value' not in data:
                log(agent_id, f'Missing "value" field in payload')
                return

            value = data['value']
            data_type = data.get('type', 'REAL')  # Default to REAL if not specified
            interval = data.get('interval', 60)  # Default to 60s if not specified

            # Validate type
            if data_type not in ['REAL', 'INTEGER', 'TEXT']:
                log(agent_id, f'Invalid type: {data_type}')
                return

            # Generate timestamp (server-side)
            timestamp = int(datetime.now().timestamp())

            # Write to SQLite using persistent connection
            table_name = f"{agent_id}_{metric_name}"

            cursor = self.db_conn.cursor()

            # Check if table exists with correct schema
            cursor.execute(
                "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
                (table_name,)
            )
            existing = cursor.fetchone()

            if existing:
                existing_sql = existing[0]
                # Check if value column type matches or interval column is missing
                if f'value {data_type}' not in existing_sql or 'interval' not in existing_sql:
                    log(agent_id, f'Schema mismatch for {table_name}, dropping and recreating')
                    cursor.execute(f'DROP TABLE "{table_name}"')

            # Create table with appropriate type and interval column
            cursor.execute(f'''
                CREATE TABLE IF NOT EXISTS "{table_name}" (
                    timestamp INTEGER PRIMARY KEY,
                    value {data_type},
                    interval INTEGER
                )
            ''')

            # Insert data
            cursor.execute(
                f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value, interval) VALUES (?, ?, ?)',
                (timestamp, value, interval)
            )

            # Immediate commit for real-time data availability
            self.db_conn.commit()

            # Clear pending invite on first data received (held in RAM until connected)
            clear_invite(agent_id)

            log(agent_id, f'{metric_name} = {value}')

        except sqlite3.OperationalError as e:
            error_msg = str(e).lower()
            if 'locked' in error_msg:
                # Database locked (rare, during checkpoint) - retry once
                log('db', f'Database locked, retrying once: {e}')
                time.sleep(0.01)  # 10ms wait
                try:
                    self.db_conn.commit()
                    log('db', 'Retry successful')
                except Exception as retry_error:
                    log('db', f'Retry failed: {retry_error}')
                    self.reconnect_db()
            elif 'disk' in error_msg or 'i/o' in error_msg:
                log('db', f'CRITICAL: Disk error: {e}')
                self.reconnect_db()
            else:
                log('db', f'Database error: {e}')
                self.reconnect_db()
        except Exception as e:
            log('error', f'Exception in on_message: {type(e).__name__}: {str(e)}')
            # Attempt reconnection on any unexpected error
            self.reconnect_db()

    def run(self):
        """Start MQTT client and run event loop."""
        print("[mqtt-sqlite] Starting MQTT to SQLite bridge...")
        print(f"[mqtt-sqlite] Database: {DB_PATH}")

        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_message = self.on_message

        try:
            self.mqtt_client.connect("localhost", 1883, 60)
            print("[mqtt-sqlite] Starting event loop...")
            self.mqtt_client.loop_forever()
        except KeyboardInterrupt:
            print("[mqtt-sqlite] Shutting down...")
            self.shutdown()
        except Exception as e:
            print(f"[mqtt-sqlite] ERROR: {e}")
            self.shutdown()
            sys.exit(1)

    def shutdown(self):
        """Graceful shutdown - close connections."""
        try:
            if self.mqtt_client:
                self.mqtt_client.disconnect()
        except:
            pass

        try:
            if self.db_conn:
                self.db_conn.close()
                log('db', 'Database connection closed')
        except:
            pass

def main():
    bridge = MQTTBridge()
    bridge.run()

if __name__ == '__main__':
    main()
