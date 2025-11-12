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

    def infer_type_and_interval(self, value, metric_path):
        """Infer SQLite type and interval from value and metric name (for Glances format)."""
        # Infer SQLite type from Python type
        if isinstance(value, bool):
            data_type = 'INTEGER'  # SQLite uses INTEGER for booleans
        elif isinstance(value, int):
            data_type = 'INTEGER'
        elif isinstance(value, float):
            data_type = 'REAL'
        else:
            data_type = 'TEXT'

        # Assign default interval based on metric category
        # Glances doesn't send intervals, so we use reasonable defaults
        metric_lower = metric_path.lower()
        if any(x in metric_lower for x in ['cpu', 'load', 'ctx_switches', 'interrupts']):
            interval = 3  # Fast: CPU-related metrics
        elif any(x in metric_lower for x in ['mem', 'swap', 'network', 'net', 'bytes', 'packets']):
            interval = 10  # Medium: Memory/network metrics
        elif any(x in metric_lower for x in ['disk', 'fs', 'raid', 'zfs', 'smart']):
            interval = 60  # Slow: Disk/filesystem metrics
        elif any(x in metric_lower for x in ['process', 'docker', 'container']):
            interval = 15  # Medium-slow: Process monitoring
        elif any(x in metric_lower for x in ['sensor', 'temp', 'fan', 'battery']):
            interval = 30  # Slow: Hardware sensors
        elif any(x in metric_lower for x in ['hostname', 'version', 'system', 'uptime']):
            interval = 0  # Static: System info (never stale)
        else:
            interval = 60  # Default: Conservative 60s

        return data_type, interval

    def on_message(self, client, userdata, msg):
        """Callback when MQTT message received - write to SQLite with persistent connection.
        Supports both custom Lumenmon format and Glances MQTT format."""
        try:
            import json

            # Parse topic: metrics/<agent_id>/<metric_name>[/submetric]
            parts = msg.topic.split('/')
            if len(parts) < 3 or parts[0] != 'metrics':
                log('error', f'Invalid topic format: {msg.topic}')
                return

            agent_id = parts[1]

            # Validate agent_id format (security)
            if not re.match(r'^[a-zA-Z0-9_-]+$', agent_id):
                log('error', f'Invalid agent_id: {agent_id}')
                return

            # Build metric name from remaining parts (supports nested: cpu/total, disk/sda1/percent)
            metric_parts = parts[2:]
            metric_name = '_'.join(metric_parts)  # Join with underscore: cpu_total, disk_sda1_percent

            # Validate metric_name format
            if not re.match(r'^[a-zA-Z0-9_-]+$', metric_name):
                log('error', f'Invalid metric_name: {metric_name}')
                return

            # Try to decode payload
            try:
                payload_str = msg.payload.decode()
            except UnicodeDecodeError as e:
                log(agent_id, f'Invalid payload encoding: {e}')
                return

            # Detect message format
            is_custom_format = False
            is_glances_perplugin = False
            metrics_to_store = []  # List of (metric_name, value, data_type, interval)

            # Try parsing as JSON first
            try:
                data = json.loads(payload_str)

                # Check if it's custom Lumenmon format (has "value" field)
                if isinstance(data, dict) and 'value' in data:
                    # Custom Lumenmon format: {"value": X, "type": "REAL", "interval": 60}
                    is_custom_format = True
                    value = data['value']
                    data_type = data.get('type', 'REAL')
                    interval = data.get('interval', 60)

                    if data_type not in ['REAL', 'INTEGER', 'TEXT']:
                        log(agent_id, f'Invalid type: {data_type}')
                        return

                    metrics_to_store.append((metric_name, value, data_type, interval))

                elif isinstance(data, dict):
                    # Glances per-plugin format: {"total": 29.0, "user": 24.7, ...}
                    is_glances_perplugin = True
                    for key, value in data.items():
                        # Skip non-metric fields
                        if not isinstance(value, (int, float, str, bool)):
                            continue

                        # Create composite metric name: cpu_total, cpu_user, etc.
                        composite_name = f"{metric_name}_{key}"
                        data_type, interval = self.infer_type_and_interval(value, composite_name)
                        metrics_to_store.append((composite_name, value, data_type, interval))

                elif isinstance(data, (int, float, str, bool)):
                    # Glances per-metric format: JSON-encoded raw value (42, 3.14, "text", true)
                    value = data
                    data_type, interval = self.infer_type_and_interval(value, metric_name)
                    metrics_to_store.append((metric_name, value, data_type, interval))

                else:
                    log(agent_id, f'Unexpected JSON structure: {type(data)}')
                    return

            except json.JSONDecodeError:
                # Glances per-metric format: raw value (not JSON)
                # Parse raw value: could be "29.0", "true", "hello"
                value_str = payload_str.strip()

                # Try to parse as number or boolean
                try:
                    if '.' in value_str or 'e' in value_str.lower():
                        value = float(value_str)
                    else:
                        value = int(value_str)
                except ValueError:
                    # Try boolean
                    if value_str.lower() in ['true', 'false']:
                        value = value_str.lower() == 'true'
                    else:
                        # Treat as string
                        value = value_str

                data_type, interval = self.infer_type_and_interval(value, metric_name)
                metrics_to_store.append((metric_name, value, data_type, interval))

            # Generate timestamp (server-side, consistent for all metrics in this message)
            timestamp = int(datetime.now().timestamp())

            # Store all metrics
            cursor = self.db_conn.cursor()

            for m_name, m_value, m_type, m_interval in metrics_to_store:
                table_name = f"{agent_id}_{m_name}"

                # Check if table exists with correct schema
                cursor.execute(
                    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
                    (table_name,)
                )
                existing = cursor.fetchone()

                if existing:
                    existing_sql = existing[0]
                    # Check if value column type matches or interval column is missing
                    if f'value {m_type}' not in existing_sql or 'interval' not in existing_sql:
                        log(agent_id, f'Schema mismatch for {table_name}, dropping and recreating')
                        cursor.execute(f'DROP TABLE "{table_name}"')

                # Create table with appropriate type and interval column
                cursor.execute(f'''
                    CREATE TABLE IF NOT EXISTS "{table_name}" (
                        timestamp INTEGER PRIMARY KEY,
                        value {m_type},
                        interval INTEGER
                    )
                ''')

                # Insert data
                cursor.execute(
                    f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value, interval) VALUES (?, ?, ?)',
                    (timestamp, m_value, m_interval)
                )

                log(agent_id, f'{m_name} = {m_value}')

            # Immediate commit for real-time data availability
            self.db_conn.commit()

            # Clear pending invite on first data received (held in RAM until connected)
            clear_invite(agent_id)

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
