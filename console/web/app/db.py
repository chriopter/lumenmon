#!/usr/bin/env python3
# Database helpers for Flask blueprints (messages.py, management.py).
# NOTE: Main API endpoints (/api/entities, /api/agents) use unified_server.py
# which keeps state in RAM. This module is only used by secondary blueprints.

import sqlite3
import time
import re

DB_PATH = "/data/metrics.db"

# Retention: keep last 24 hours of data (86400 seconds)
RETENTION_SECONDS = 86400

# Validation patterns for SQL identifiers (prevents SQL injection)
AGENT_ID_PATTERN = re.compile(r'^[a-zA-Z0-9_-]+$')
METRIC_NAME_PATTERN = re.compile(r'^[a-zA-Z0-9_-]+$')
TABLE_NAME_PATTERN = re.compile(r'^[a-zA-Z0-9_-]+$')

def validate_identifier(value, pattern=TABLE_NAME_PATTERN):
    """Validate a SQL identifier matches expected pattern.

    Returns True if valid, False otherwise.
    Used to prevent SQL injection when table names must be interpolated.
    """
    if not value or not isinstance(value, str):
        return False
    return bool(pattern.match(value))

def get_db_connection():
    """Get SQLite database connection with timeout to prevent blocking."""
    conn = sqlite3.connect(DB_PATH, timeout=5.0)  # 5 second timeout
    conn.row_factory = sqlite3.Row
    return conn

def table_exists(conn, table_name):
    """Check if a table exists in the database."""
    cursor = conn.cursor()
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table_name,)
    )
    return cursor.fetchone() is not None

def init_host_settings_table():
    """Create host_settings table if not exists, with group support."""
    conn = get_db_connection()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS host_settings (
            agent_id TEXT PRIMARY KEY,
            display_name TEXT,
            group_name TEXT,
            group_order INTEGER DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    # Add group columns if they don't exist (for upgrades)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(host_settings)")
    columns = [row[1] for row in cursor.fetchall()]
    if 'group_name' not in columns:
        conn.execute('ALTER TABLE host_settings ADD COLUMN group_name TEXT')
    if 'group_order' not in columns:
        conn.execute('ALTER TABLE host_settings ADD COLUMN group_order INTEGER DEFAULT 0')
    conn.commit()
    conn.close()

def get_host_display_name(agent_id):
    """Get custom display name for a host, or None if not set."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT display_name FROM host_settings WHERE agent_id = ?", (agent_id,))
        row = cursor.fetchone()
        conn.close()
        return row['display_name'] if row else None
    except Exception:
        return None

def set_host_display_name(agent_id, display_name):
    """Set custom display name for a host."""
    try:
        init_host_settings_table()
        conn = get_db_connection()
        conn.execute('''
            INSERT INTO host_settings (agent_id, display_name, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(agent_id) DO UPDATE SET
                display_name = excluded.display_name,
                updated_at = CURRENT_TIMESTAMP
        ''', (agent_id, display_name if display_name else None))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"Error setting display name: {e}")
        return False

def get_all_host_display_names():
    """Get all custom display names as a dict."""
    try:
        init_host_settings_table()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT agent_id, display_name FROM host_settings WHERE display_name IS NOT NULL")
        result = {row['agent_id']: row['display_name'] for row in cursor.fetchall()}
        conn.close()
        return result
    except Exception:
        return {}

def set_host_group(agent_id, group_name):
    """Set the group for an agent. Pass None or empty string to remove from group."""
    try:
        init_host_settings_table()
        conn = get_db_connection()
        conn.execute('''
            INSERT INTO host_settings (agent_id, group_name, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(agent_id) DO UPDATE SET
                group_name = excluded.group_name,
                updated_at = CURRENT_TIMESTAMP
        ''', (agent_id, group_name if group_name else None))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"Error setting group: {e}")
        return False

def get_all_host_groups():
    """Get all agent groups as a dict {agent_id: group_name}."""
    try:
        init_host_settings_table()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT agent_id, group_name FROM host_settings WHERE group_name IS NOT NULL")
        result = {row['agent_id']: row['group_name'] for row in cursor.fetchall()}
        conn.close()
        return result
    except Exception:
        return {}

def cleanup_old_metrics():
    """Delete metrics older than RETENTION_SECONDS from all tables.

    Always preserves the most recent record per table, even if older than cutoff.
    This ensures we always have the last known value for offline agents.
    """
    cutoff = int(time.time()) - RETENTION_SECONDS
    deleted_total = 0

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get all metric tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]

        for table_name in tables:
            try:
                # Validate table name before using in query (SQL injection prevention)
                if not validate_identifier(table_name):
                    continue
                # Delete old records BUT always keep the most recent one
                cursor.execute(
                    f'''DELETE FROM "{table_name}"
                        WHERE timestamp < ?
                        AND timestamp != (SELECT MAX(timestamp) FROM "{table_name}")''',
                    (cutoff,)
                )
                deleted_total += cursor.rowcount
            except Exception:
                pass  # Skip tables without timestamp column

        conn.commit()
        conn.close()
    except Exception:
        pass

    return deleted_total
