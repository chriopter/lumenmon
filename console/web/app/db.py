#!/usr/bin/env python3
# Database connection and utility functions.
# Provides SQLite connection management and table existence checking.

import sqlite3
import time

DB_PATH = "/data/metrics.db"

# Retention: keep last 24 hours of data (86400 seconds)
RETENTION_SECONDS = 86400

def get_db_connection():
    """Get SQLite database connection."""
    conn = sqlite3.connect(DB_PATH)
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
    """Delete metrics older than RETENTION_SECONDS from all tables."""
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
                cursor.execute(
                    f'DELETE FROM "{table_name}" WHERE timestamp < ?',
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
