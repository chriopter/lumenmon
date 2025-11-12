#!/usr/bin/env python3
# Clean metrics API for Glances data - NO legacy custom client code.
# Simple, direct metric reading from agent_registry and metric tables.

import time
from db import get_db_connection

def get_metric(agent_id, metric_pattern):
    """Get latest value for a metric matching pattern.

    Example: get_metric('id_abc123', 'cpu_total') finds table ending with 'cpu_total'
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find table matching pattern
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? AND name LIKE ?",
            (f"{agent_id}_%", f"%{metric_pattern}")
        )

        table = cursor.fetchone()
        if table:
            cursor.execute(f'SELECT value FROM "{table[0]}" ORDER BY timestamp DESC LIMIT 1')
            row = cursor.fetchone()
            conn.close()

            if row:
                # Try to convert to number
                try:
                    return round(float(row[0]), 1)
                except (ValueError, TypeError):
                    return row[0]

        conn.close()
    except Exception:
        pass

    return None

def get_all_agents():
    """Get all agents from registry with online status."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute('''
            SELECT agent_id, hostname, last_seen
            FROM agent_registry
            ORDER BY last_seen DESC
        ''')

        agents = []
        current_time = int(time.time())

        for row in cursor.fetchall():
            agent_id, hostname, last_seen = row
            age = current_time - last_seen

            agents.append({
                'id': agent_id,
                'hostname': hostname,
                'status': 'online' if age < 10 else 'offline',
                'age': age,
                'lastUpdate': last_seen
            })

        conn.close()
        return agents
    except Exception as e:
        print(f"Error getting agents: {e}")
        return []

def get_agent_metrics(agent_id):
    """Get key metrics for an agent (Glances featured metrics)."""
    # Query agent from registry
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            'SELECT hostname, last_seen FROM agent_registry WHERE agent_id = ?',
            (agent_id,)
        )

        row = cursor.fetchone()
        conn.close()

        if not row:
            return {
                'id': agent_id,
                'status': 'offline',
                'hostname': '',
                'cpu': 0.0,
                'memory': 0.0,
                'disk': 0.0
            }

        hostname, last_seen = row
        current_time = int(time.time())
        age = current_time - last_seen

        # Get featured Glances metrics
        cpu = get_metric(agent_id, 'cpu_total') or 0.0
        memory = get_metric(agent_id, 'mem_percent') or 0.0

        # Disk - try common mount points
        disk = get_metric(agent_id, 'fs__data_percent')
        if disk is None:
            disk = get_metric(agent_id, 'fs__percent')
        if disk is None:
            disk = 0.0

        return {
            'id': agent_id,
            'hostname': hostname,
            'status': 'online' if age < 10 else 'offline',
            'age': age,
            'lastUpdate': last_seen,
            'cpu': cpu,
            'memory': memory,
            'disk': disk
        }

    except Exception as e:
        print(f"Error getting metrics for {agent_id}: {e}")
        return {
            'id': agent_id,
            'status': 'offline',
            'hostname': '',
            'cpu': 0.0,
            'memory': 0.0,
            'disk': 0.0
        }

def get_agent_tables(agent_id):
    """Get all metric tables for an agent with their latest values."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find all tables for this agent
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? ORDER BY name",
            (f"{agent_id}_%",)
        )

        tables = []
        current_time = int(time.time())

        for table_row in cursor.fetchall():
            table_name = table_row[0]

            # Extract metric name (strip agent_id prefix)
            # Format: id_abc123_hostname_metric_name -> metric_name
            parts = table_name.split('_', 2)
            if len(parts) >= 3:
                metric_name = parts[2]
            else:
                metric_name = table_name

            # Get latest value, timestamp, interval
            try:
                cursor.execute(f'SELECT timestamp, value, interval FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1')
                row = cursor.fetchone()

                if row:
                    timestamp, value, interval = row
                    age = current_time - timestamp

                    tables.append({
                        'metric_name': metric_name,
                        'columns': {
                            'timestamp': timestamp,
                            'value': value,
                            'interval': interval
                        },
                        'staleness': {
                            'is_stale': age > (interval + 1) if interval > 0 else False,
                            'next_update_in': (timestamp + interval) - current_time if interval > 0 else 0
                        },
                        'metadata': {
                            'type': 'REAL' if isinstance(value, float) else 'INTEGER' if isinstance(value, int) else 'TEXT',
                            'timestamp_age': f"{age}s ago"
                        }
                    })
            except Exception as e:
                print(f"Error reading table {table_name}: {e}")

        conn.close()
        return tables

    except Exception as e:
        print(f"Error getting tables for {agent_id}: {e}")
        return []
