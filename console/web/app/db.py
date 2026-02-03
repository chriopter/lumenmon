#!/usr/bin/env python3
# Database connection and utility functions.
# Provides SQLite connection management and table existence checking.

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
