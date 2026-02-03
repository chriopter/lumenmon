#!/usr/bin/env python3
# Agent metrics reading and aggregation.
# Reads metrics from SQLite database and generates formatted metrics for agents.

import time
from db import get_db_connection, table_exists, validate_identifier
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

def calculate_host_status(heartbeat_stale, failed_collectors, total_collectors):
    """
    Hierarchical status system - host status derived from collector health.

    Status tree:
        HOST
        ├── online (green)   = heartbeat OK + all collectors healthy
        ├── degraded (yellow) = heartbeat OK + some collectors failed
        └── offline (red)    = heartbeat stale (agent disconnected)

    Collector is "failed" if: stale OR out_of_bounds
    """
    if heartbeat_stale:
        return 'offline'
    elif failed_collectors > 0:
        return 'degraded'
    else:
        return 'online'


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

def get_history_from_db(agent_id, metric_name, max_points=100):
    """Read recent history for a metric from SQLite (limited to max_points)."""
    history = []

    # Validate inputs before constructing table name (SQL injection prevention)
    if not validate_identifier(agent_id) or not validate_identifier(metric_name):
        return history

    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return history

        cursor = conn.cursor()
        # Use COALESCE to get value from whichever column is populated
        cursor.execute(
            f'SELECT timestamp, COALESCE(value_real, value_int, value_text) FROM "{table_name}" ORDER BY timestamp DESC LIMIT ?',
            (max_points,)
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

        # Reverse to get chronological order (we fetched DESC)
        history.reverse()

    except Exception:
        pass

    return history

def get_latest_value(agent_id, metric_name, value_type=None):
    """Get the most recent value, timestamp, and interval for a metric.
    value_type: 'text' to return raw value without float conversion."""

    # Validate inputs before constructing table name (SQL injection prevention)
    if not validate_identifier(agent_id) or not validate_identifier(metric_name):
        return None, None, None

    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return None, None, None

        cursor = conn.cursor()
        # Unified schema - use COALESCE to get value from whichever column is populated
        cursor.execute(
            f'SELECT timestamp, COALESCE(value_real, value_int, value_text), interval FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'
        )

        row = cursor.fetchone()
        conn.close()

        if row:
            # Return raw value for text type, otherwise try float conversion
            if value_type == 'text':
                value = row[1]
            else:
                try:
                    value = round(float(row[1]), 1)
                except (ValueError, TypeError):
                    value = row[1]

            interval = row[2] if row[2] is not None else 60  # Default 60s, preserve 0 for one-time
            return row[0], value, interval
    except Exception:
        pass

    return None, None, None

def get_latest_hostname(agent_id):
    """Get the most recent hostname value."""

    # Validate agent_id before constructing table name (SQL injection prevention)
    if not validate_identifier(agent_id):
        return ''

    table_name = f"{agent_id}_generic_hostname"

    try:
        conn = get_db_connection()

        # Check if table exists
        if not table_exists(conn, table_name):
            conn.close()
            return ''

        cursor = conn.cursor()
        # Hostname is stored in value_text column
        cursor.execute(
            f'SELECT value_text FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'
        )

        row = cursor.fetchone()
        conn.close()

        if row and row[0]:
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
        'diskHistory': [],
        'minInterval': 60  # Track minimum interval for staleness detection
    }

    # Read CPU
    timestamp, value, interval = get_latest_value(agent_id, 'generic_cpu')
    if timestamp and value is not None:
        metrics['cpu'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
        metrics['minInterval'] = min(metrics['minInterval'], interval)
    metrics['cpuHistory'] = get_history_from_db(agent_id, 'generic_cpu', max_points=30)

    # Read Memory
    timestamp, value, interval = get_latest_value(agent_id, 'generic_memory')
    if timestamp and value is not None:
        metrics['memory'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
        metrics['minInterval'] = min(metrics['minInterval'], interval)
    metrics['memHistory'] = get_history_from_db(agent_id, 'generic_memory', max_points=30)

    # Read Disk
    timestamp, value, interval = get_latest_value(agent_id, 'generic_disk')
    if timestamp and value is not None:
        metrics['disk'] = value
        metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)
        metrics['minInterval'] = min(metrics['minInterval'], interval)
    metrics['diskHistory'] = get_history_from_db(agent_id, 'generic_disk', max_points=30)

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

    # Read Agent Version
    timestamp, value, interval = get_latest_value(agent_id, 'generic_agent_version', value_type='text')
    metrics['agent_version'] = value if value else ''

    # Calculate age and status based on data freshness
    current_time = int(time.time())

    if metrics['lastUpdate'] > 0:
        metrics['age'] = current_time - metrics['lastUpdate']

        # Check if heartbeat is stale (agent disconnected)
        heartbeat_staleness = calculate_staleness(metrics.get('heartbeat', 0), 1)  # Heartbeat is 1s

        # Check staleness of core metrics (CPU, Memory, Disk) without expensive get_agent_tables call
        # Use minInterval which tracks the fastest metric interval
        core_staleness = calculate_staleness(metrics['lastUpdate'], metrics['minInterval'])

        # Determine status using centralized staleness logic
        # Green (online): Heartbeat fresh AND core metrics fresh
        # Yellow (stale): Heartbeat fresh BUT core metrics stale
        # Red (offline): Heartbeat stale (agent disconnected)
        if heartbeat_staleness['is_stale']:
            # No heartbeat = agent disconnected
            metrics['status'] = 'offline'
        elif core_staleness['is_stale']:
            # Heartbeat OK but core metrics overdue = degraded
            metrics['status'] = 'stale'
        else:
            # All metrics fresh = healthy
            metrics['status'] = 'online'
    else:
        # No data at all
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


def count_failed_collectors(agent_id):
    """
    Efficiently count failed collectors for host status calculation.
    A collector is failed if: stale OR out_of_bounds.
    Returns (failed_count, total_count).
    """
    failed = 0
    total = 0

    # Validate agent_id (SQL injection prevention)
    if not validate_identifier(agent_id):
        return 0, 0

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find all tables for this agent
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
            (f"{agent_id}_%",)
        )

        for row in cursor.fetchall():
            table_name = row[0]
            # Skip non-metric tables
            if '_registration_test' in table_name:
                continue

            # Validate table name from database (SQL injection prevention)
            if not validate_identifier(table_name):
                continue

            total += 1

            # Get latest row
            cursor.execute(
                f'''SELECT timestamp, value_real, value_int, interval, min_value, max_value
                    FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'''
            )
            latest = cursor.fetchone()

            if latest:
                timestamp, value_real, value_int, interval, min_value, max_value = latest
                interval = interval if interval is not None else 60

                # Check staleness
                staleness = calculate_staleness(timestamp, interval)
                is_stale = staleness['is_stale']

                # Check bounds
                current_value = value_real if value_real is not None else value_int
                is_out_of_bounds = False
                if current_value is not None:
                    if min_value is not None and current_value < min_value:
                        is_out_of_bounds = True
                    elif max_value is not None and current_value > max_value:
                        is_out_of_bounds = True

                if is_stale or is_out_of_bounds:
                    failed += 1

        conn.close()
    except Exception:
        pass

    return failed, total


def get_agent_tables(agent_id):
    """Get all metric tables for an agent with their latest data and schema info."""
    tables = []

    # Validate agent_id (SQL injection prevention)
    if not validate_identifier(agent_id):
        return tables

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find all tables for this agent
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
            (f"{agent_id}_%",)
        )

        for row in cursor.fetchall():
            table_name = row[0]

            # Validate table name from database (SQL injection prevention)
            if not validate_identifier(table_name):
                continue

            # Extract metric name (remove agent_id_ prefix)
            metric_name = table_name[len(agent_id)+1:]

            # Get latest row with unified schema
            cursor.execute(
                f'''SELECT timestamp, value_real, value_int, value_text, interval, min_value, max_value
                    FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1'''
            )
            latest = cursor.fetchone()

            cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
            count = cursor.fetchone()[0]

            # Get oldest timestamp for data span calculation
            cursor.execute(f'SELECT timestamp FROM "{table_name}" ORDER BY timestamp ASC LIMIT 1')
            oldest = cursor.fetchone()

            if latest:
                timestamp, value_real, value_int, value_text, interval, min_value, max_value = latest

                # Determine type based on which column is populated
                if value_real is not None:
                    value_type = "REAL"
                elif value_int is not None:
                    value_type = "INTEGER"
                else:
                    value_type = "TEXT"

                # Build columns dict with all three value columns
                columns = {
                    'timestamp': timestamp,
                    'value_real': round(value_real, 1) if value_real is not None else None,
                    'value_int': value_int,
                    'value_text': value_text,
                    'min_value': min_value,
                    'max_value': max_value,
                    'interval': interval if interval is not None else 60,
                    # Also provide coalesced value for widgets
                    'value': round(value_real, 1) if value_real is not None else (value_int if value_int is not None else value_text)
                }

                # Calculate staleness using centralized function
                staleness = calculate_staleness(timestamp, interval if interval is not None else 60)

                # Validate value against min/max bounds
                current_value = value_real if value_real is not None else value_int
                is_out_of_bounds = False
                bounds_error = None
                if current_value is not None:
                    if min_value is not None and current_value < min_value:
                        is_out_of_bounds = True
                        bounds_error = f"value {current_value} < min {min_value}"
                    elif max_value is not None and current_value > max_value:
                        is_out_of_bounds = True
                        bounds_error = f"value {current_value} > max {max_value}"

                # Calculate metadata
                timestamp_age = _format_timestamp_age(timestamp)
                data_span = _format_duration(timestamp - oldest[0]) if oldest else "N/A"

                tables.append({
                    'metric_name': metric_name,
                    'table_name': table_name,
                    'columns': columns,
                    'staleness': staleness,
                    'health': {
                        'is_failed': is_out_of_bounds or staleness['is_stale'],
                        'out_of_bounds': is_out_of_bounds,
                        'bounds_error': bounds_error,
                        'is_stale': staleness['is_stale']
                    },
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
