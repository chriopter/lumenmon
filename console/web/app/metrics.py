#!/usr/bin/env python3
# Agent metrics reading and aggregation.
# Reads metrics from SQLite database and generates formatted metrics for agents.

import time
import re
from db import get_db_connection, table_exists
from ssh_status import is_ssh_connected
from formatters import generate_tui_sparkline, format_age

def _format_duration(seconds):
    """Format duration in seconds to human-readable string."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m"
    elif seconds < 86400:
        return f"{seconds // 3600}h"
    else:
        return f"{seconds // 86400}d"

def _format_timestamp_age(timestamp):
    """Format how long ago a timestamp was."""
    age = int(time.time()) - timestamp
    return _format_duration(age) + " ago"

def get_history_from_db(agent_id, metric_name):
    """Read all history for a metric from SQLite."""
    history = []
    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return history

        cursor = conn.cursor()
        cursor.execute(
            f'SELECT timestamp, value FROM "{table_name}" ORDER BY timestamp'
        )

        for row in cursor.fetchall():
            # Try to convert to float, if it fails keep as string
            try:
                value = round(float(row[1]), 1)
            except (ValueError, TypeError):
                value = row[1]

            history.append({
                'timestamp': row[0],
                'value': value
            })

        conn.close()

        # Downsample if needed
        if len(history) > 100:
            step = max(1, len(history) // 100)
            history = history[::step]

    except Exception:
        pass

    return history

def get_latest_value(agent_id, metric_name):
    """Get the most recent value and timestamp for a metric."""
    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return None, None

        cursor = conn.cursor()
        cursor.execute(
            f'SELECT timestamp, value FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'
        )

        row = cursor.fetchone()
        conn.close()

        if row:
            # Try to convert to float
            try:
                value = round(float(row[1]), 1)
            except (ValueError, TypeError):
                value = row[1]
            return row[0], value
    except Exception:
        pass

    return None, None

def get_latest_hostname(agent_id):
    """Get the most recent hostname value."""
    table_name = f"{agent_id}_generic_hostname"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return ''

        cursor = conn.cursor()
        cursor.execute(
            f'SELECT value FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'
        )

        row = cursor.fetchone()
        conn.close()

        if row:
            # Value is stored as string for hostname
            return str(row[0])
    except Exception:
        pass

    return ''

def get_agent_metrics(agent_id):
    """Read all metrics for a specific agent."""
    metrics = {
        'id': agent_id,
        'cpu': 0.0,
        'memory': 0.0,
        'disk': 0.0,
        'hostname': '',
        'age': 0,
        'status': 'offline',
        'lastUpdate': 0,
        'cpuHistory': [],
        'memHistory': [],
        'diskHistory': []
    }

    # Read CPU
    timestamp, value = get_latest_value(agent_id, 'generic_cpu')
    if timestamp and value is not None:
        metrics['cpu'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
    metrics['cpuHistory'] = get_history_from_db(agent_id, 'generic_cpu')

    # Read Memory
    timestamp, value = get_latest_value(agent_id, 'generic_mem')
    if timestamp and value is not None:
        metrics['memory'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
    metrics['memHistory'] = get_history_from_db(agent_id, 'generic_mem')

    # Read Disk
    timestamp, value = get_latest_value(agent_id, 'generic_disk')
    if timestamp and value is not None:
        metrics['disk'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
    metrics['diskHistory'] = get_history_from_db(agent_id, 'generic_disk')

    # Read Hostname
    metrics['hostname'] = get_latest_hostname(agent_id)

    # Calculate age and status based on SSH connection + data freshness
    current_time = int(time.time())
    ssh_connected = is_ssh_connected(agent_id)

    if metrics['lastUpdate'] > 0:
        metrics['age'] = current_time - metrics['lastUpdate']

        # Determine status based on SSH connection AND data freshness
        if ssh_connected and metrics['age'] < 10:
            # SSH connected + fresh data = online
            metrics['status'] = 'online'
        elif ssh_connected and metrics['age'] < 60:
            # SSH connected but data getting stale = warning
            metrics['status'] = 'stale'
        elif not ssh_connected and metrics['age'] < 10:
            # No SSH but very recent data (just disconnected?) = stale
            metrics['status'] = 'stale'
        else:
            # No SSH connection or very old data = offline
            metrics['status'] = 'offline'
    else:
        # No data at all
        metrics['status'] = 'offline' if not ssh_connected else 'stale'

    # Add formatted fields for HTML templates
    metrics['age_formatted'] = format_age(metrics['age'])

    # Generate sparklines from history values only
    cpu_values = [h['value'] for h in metrics['cpuHistory']]
    mem_values = [h['value'] for h in metrics['memHistory']]
    disk_values = [h['value'] for h in metrics['diskHistory']]
    metrics['cpuSparkline'] = generate_tui_sparkline(cpu_values)
    metrics['memSparkline'] = generate_tui_sparkline(mem_values)
    metrics['diskSparkline'] = generate_tui_sparkline(disk_values)

    return metrics

def get_agent_tsv_files(agent_id):
    """Get all metric tables for an agent with their latest data and schema info."""
    tables = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find all tables for this agent with their schema
        cursor.execute(
            "SELECT name, sql FROM sqlite_master WHERE type='table' AND name LIKE ?",
            (f"{agent_id}_%",)
        )

        for row in cursor.fetchall():
            table_name = row[0]
            table_sql = row[1]

            # Extract metric name (remove agent_id_ prefix)
            metric_name = table_name[len(agent_id)+1:]

            # Extract type from schema: "value TYPE" in CREATE TABLE statement
            value_type = "TEXT"  # Default
            if table_sql:
                type_match = re.search(r'value\s+(TEXT|REAL|INTEGER)', table_sql, re.IGNORECASE)
                if type_match:
                    value_type = type_match.group(1).upper()

            # Get latest value and count
            cursor.execute(f'SELECT timestamp, value FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1')
            latest = cursor.fetchone()

            cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
            count = cursor.fetchone()[0]

            # Get oldest timestamp for data span calculation
            cursor.execute(f'SELECT timestamp FROM "{table_name}" ORDER BY timestamp ASC LIMIT 1')
            oldest = cursor.fetchone()

            if latest:
                # Format timestamp age and data span
                timestamp_age = _format_timestamp_age(latest[0])
                data_span = _format_duration(latest[0] - oldest[0]) if oldest else "N/A"

                # Format value based on type
                formatted_value = latest[1]
                if value_type in ('REAL', 'INTEGER') and isinstance(latest[1], (int, float)):
                    formatted_value = round(latest[1], 1)

                tables.append({
                    'filename': f"{metric_name}.tsv",
                    'metric_name': metric_name,
                    'table_name': table_name,
                    'type': value_type,
                    'lastLine': f"{latest[0]} - {latest[1]}",
                    'timestamp': latest[0],
                    'timestamp_age': timestamp_age,
                    'value': formatted_value,
                    'line_count': count,
                    'data_span': data_span
                })

        conn.close()
    except Exception:
        pass

    return tables

def get_all_agents():
    """Get metrics for all agents from SQLite, sorted by status."""
    agents = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get all unique agent IDs from table names
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

        agent_ids = set()
        for row in cursor.fetchall():
            table_name = row[0]
            # Extract agent ID from table name (format: id_<fingerprint>_metric_name)
            # Agent ID can have multiple underscores (e.g., id_IRw_VhJwXnck1l)
            # Metric names always start with 'generic_' so we can find the split point
            if table_name.startswith('id_'):
                # Find the last occurrence of '_generic_' to split agent ID from metric name
                generic_idx = table_name.rfind('_generic_')
                if generic_idx > 0:
                    agent_id = table_name[:generic_idx]
                    agent_ids.add(agent_id)

        conn.close()

        # Get metrics for each agent
        for agent_id in agent_ids:
            metrics = get_agent_metrics(agent_id)
            agents.append(metrics)

    except Exception:
        pass  # Return empty list on error

    # Sort by status (online first) then by ID
    status_order = {'online': 0, 'stale': 1, 'offline': 2}
    agents.sort(key=lambda x: (status_order.get(x['status'], 3), x['id']))

    return agents
