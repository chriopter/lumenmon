#!/usr/bin/env python3
# Agent metrics reading and aggregation.
# Reads metrics from SQLite database and generates formatted metrics for agents.

import time
import re
from db import get_db_connection, table_exists
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

def calculate_staleness(timestamp, interval):
    """
    Single source of truth for staleness calculation (DRY principle).

    Returns dict with:
        - age: seconds since last update
        - is_stale: data older than 2x expected interval (False if interval=0)
        - next_update: when next update is expected (unix timestamp, 0 if interval=0)
        - next_update_in: seconds until next update (negative if overdue, 0 if interval=0)
    """
    current_time = int(time.time())
    age = current_time - timestamp if timestamp else 0

    # Special case: interval=0 means one-time value (never stale)
    if interval == 0:
        return {
            'age': age,
            'is_stale': False,
            'next_update': 0,
            'next_update_in': 0
        }

    # Calculate next expected update
    next_update = timestamp + interval if timestamp else 0
    next_update_in = next_update - current_time

    # Staleness: missed expected update + 1s grace period
    # is_stale if: now > timestamp + interval + grace
    # Simplified: age > interval + grace
    grace_period = 1
    is_stale = age > (interval + grace_period)

    return {
        'age': age,
        'is_stale': is_stale,
        'next_update': next_update,
        'next_update_in': next_update_in
    }

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

def get_metric_value(agent_id, metric_name):
    """Get just the value of a metric (helper for status checks).

    Searches for table matching pattern: {agent_id}_%{metric_name}
    Example: id_abc123_agent-glances_availability or id_abc123_generic_availability
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find table that ends with the metric name (handles hostname prefix)
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? AND name LIKE ?",
            (f"{agent_id}_%", f"%{metric_name}")
        )

        result = cursor.fetchone()
        if result:
            table_name = result[0]
            cursor.execute(f'SELECT value FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1')
            value_row = cursor.fetchone()
            conn.close()
            return value_row[0] if value_row else None

        conn.close()
    except Exception:
        pass

    return None

def get_metric_timestamp(agent_id, metric_name):
    """Get the timestamp of a metric's latest value (for freshness checking).

    Searches for table matching pattern: {agent_id}_%{metric_name}
    Returns: timestamp (int) or None
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find table that ends with the metric name (handles hostname prefix)
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? AND name LIKE ?",
            (f"{agent_id}_%", f"%{metric_name}")
        )

        result = cursor.fetchone()
        if result:
            table_name = result[0]
            cursor.execute(f'SELECT timestamp FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1')
            ts_row = cursor.fetchone()
            conn.close()
            return ts_row[0] if ts_row else None

        conn.close()
    except Exception:
        pass

    return None

def get_latest_value(agent_id, metric_name):
    """Get the most recent value, timestamp, and interval for a metric."""
    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return None, None, None

        cursor = conn.cursor()
        # Check if interval column exists
        cursor.execute(f'PRAGMA table_info("{table_name}")')
        columns = [col[1] for col in cursor.fetchall()]
        has_interval = 'interval' in columns

        if has_interval:
            cursor.execute(
                f'SELECT timestamp, value, interval FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'
            )
        else:
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

            interval = row[2] if has_interval and len(row) > 2 else 60  # Default 60s
            return row[0], value, interval
    except Exception:
        pass

    return None, None, None

def get_latest_hostname(agent_id):
    """Get the most recent hostname value (Glances: system_hostname)."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find hostname table (Glances uses system_hostname)
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? AND name LIKE '%hostname%' AND name NOT LIKE '%fs_%'",
            (f"{agent_id}_%",)
        )

        table = cursor.fetchone()
        if table:
            cursor.execute(f'SELECT value FROM "{table[0]}" ORDER BY timestamp DESC LIMIT 1')
            row = cursor.fetchone()
            conn.close()
            return str(row[0]) if row else ''

        conn.close()
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
        'diskHistory': [],
        'minInterval': 60  # Track minimum interval for staleness detection
    }

    # Read CPU (Glances: cpu_total)
    cpu_value = get_metric_value(agent_id, 'cpu_total')
    if cpu_value is not None:
        try:
            metrics['cpu'] = round(float(cpu_value), 1)
        except:
            pass

    # Read Memory (Glances: mem_percent)
    mem_value = get_metric_value(agent_id, 'mem_percent')
    if mem_value is not None:
        try:
            metrics['memory'] = round(float(mem_value), 1)
        except:
            pass

    # Read Disk (Glances: fs__data_percent for root filesystem)
    disk_value = get_metric_value(agent_id, 'fs__data_percent')
    if disk_value is None:
        # Fallback: try any fs_percent table
        disk_value = get_metric_value(agent_id, 'fs__percent')
    if disk_value is not None:
        try:
            metrics['disk'] = round(float(disk_value), 1)
        except:
            pass

    # Read Hostname
    metrics['hostname'] = get_latest_hostname(agent_id)

    # Read Uptime
    timestamp, value, interval = get_latest_value(agent_id, 'generic_sys_uptime')
    if timestamp and value is not None:
        metrics['uptime'] = str(value)
    else:
        metrics['uptime'] = ''

    # Read Heartbeat timestamp (use this for minInterval too)
    timestamp, value, interval = get_latest_value(agent_id, 'generic_heartbeat')
    if timestamp:
        metrics['heartbeat'] = timestamp
        metrics['minInterval'] = min(metrics['minInterval'], interval)
    else:
        metrics['heartbeat'] = 0

    # Calculate age and status based on data freshness
    current_time = int(time.time())

    # SIMPLE: Check uptime_seconds timestamp to determine if online
    # If uptime data is less than 10 seconds old = online, else offline
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find uptime_seconds table
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ? AND name LIKE '%uptime%'",
            (f"{agent_id}_%",)
        )

        uptime_table = cursor.fetchone()
        if uptime_table:
            cursor.execute(f'SELECT timestamp FROM "{uptime_table[0]}" ORDER BY timestamp DESC LIMIT 1')
            ts_row = cursor.fetchone()

            if ts_row:
                age = current_time - ts_row[0]
                metrics['status'] = 'online' if age < 10 else 'offline'
                metrics['age'] = age
            else:
                metrics['status'] = 'offline'
        else:
            metrics['status'] = 'offline'

        conn.close()
    except Exception as e:
        print(f"Status check error: {e}")
        metrics['status'] = 'offline'

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

def get_agent_tables(agent_id):
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

            # Get schema columns dynamically
            cursor.execute(f'PRAGMA table_info("{table_name}")')
            schema_columns = cursor.fetchall()
            column_names = [col[1] for col in schema_columns]  # col[1] is column name

            # Get latest row with all columns
            columns_str = ', '.join(column_names)
            cursor.execute(f'SELECT {columns_str} FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1')
            latest = cursor.fetchone()

            cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
            count = cursor.fetchone()[0]

            # Get oldest timestamp for data span calculation
            cursor.execute(f'SELECT timestamp FROM "{table_name}" ORDER BY timestamp ASC LIMIT 1')
            oldest = cursor.fetchone()

            if latest:
                # Build columns dict dynamically from schema
                columns = {}
                for idx, col_name in enumerate(column_names):
                    raw_value = latest[idx]
                    # Format based on column type
                    if isinstance(raw_value, float):
                        columns[col_name] = round(raw_value, 1)
                    else:
                        columns[col_name] = raw_value

                # Calculate staleness using centralized function
                timestamp = columns.get('timestamp', 0)
                interval = columns.get('interval', 60)
                staleness = calculate_staleness(timestamp, interval)

                # Calculate metadata
                timestamp_age = _format_timestamp_age(latest[0])
                data_span = _format_duration(latest[0] - oldest[0]) if oldest else "N/A"

                tables.append({
                    'metric_name': metric_name,
                    'table_name': table_name,
                    'columns': columns,  # All raw DB columns dynamically
                    'staleness': staleness,  # Centralized staleness calculation
                    'metadata': {
                        'type': value_type,
                        'timestamp_age': timestamp_age,
                        'data_span': data_span,
                        'line_count': count
                    }
                })

        conn.close()
    except Exception:
        pass

    # Sort alphabetically by metric name
    tables.sort(key=lambda x: x['metric_name'].lower())

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
