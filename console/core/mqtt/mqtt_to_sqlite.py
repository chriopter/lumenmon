#!/usr/bin/env python3
# MQTT to SQLite bridge - subscribes to metrics/# and writes directly to database.
# Replaces gateway.py ForceCommand pattern. Parses topic for agent_id and metric_name.

import paho.mqtt.client as mqtt
import sqlite3
import re
import sys
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

def on_connect(client, userdata, flags, rc):
    """Callback when connected to MQTT broker"""
    if rc == 0:
        log('mqtt', 'Connected to MQTT broker')
        client.subscribe("metrics/#")
        log('mqtt', 'Subscribed to metrics/#')
    else:
        log('mqtt', f'Connection failed with code {rc}')

def on_message(client, userdata, msg):
    """Callback when MQTT message received - write to SQLite"""
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

        # Extract value and type from JSON
        if 'value' not in data:
            log(agent_id, f'Missing "value" field in payload')
            return

        value = data['value']
        data_type = data.get('type', 'REAL')  # Default to REAL if not specified

        # Validate type
        if data_type not in ['REAL', 'INTEGER', 'TEXT']:
            log(agent_id, f'Invalid type: {data_type}')
            return

        # Generate timestamp (server-side)
        timestamp = int(datetime.now().timestamp())

        # Write to SQLite (same logic as gateway.py)
        table_name = f"{agent_id}_{metric_name}"

        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Check if table exists with correct schema
        cursor.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,)
        )
        existing = cursor.fetchone()

        if existing:
            existing_sql = existing[0]
            # Check if value column type matches
            if f'value {data_type}' not in existing_sql:
                log(agent_id, f'Schema mismatch for {table_name}, dropping and recreating')
                cursor.execute(f'DROP TABLE "{table_name}"')

        # Create table with appropriate type (simplified schema)
        cursor.execute(f'''
            CREATE TABLE IF NOT EXISTS "{table_name}" (
                timestamp INTEGER PRIMARY KEY,
                value {data_type}
            )
        ''')

        # Insert data
        cursor.execute(
            f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value) VALUES (?, ?)',
            (timestamp, value)
        )

        conn.commit()
        conn.close()

        # Clear pending invite on first data received (held in RAM until connected)
        clear_invite(agent_id)

        log(agent_id, f'{metric_name} = {value}')

    except Exception as e:
        log('error', f'Exception in on_message: {type(e).__name__}: {str(e)}')

def main():
    print("[mqtt-sqlite] Starting MQTT to SQLite bridge...")
    print(f"[mqtt-sqlite] Database: {DB_PATH}")

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect("localhost", 1883, 60)
        print("[mqtt-sqlite] Starting event loop...")
        client.loop_forever()
    except KeyboardInterrupt:
        print("[mqtt-sqlite] Shutting down...")
        client.disconnect()
    except Exception as e:
        print(f"[mqtt-sqlite] ERROR: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
