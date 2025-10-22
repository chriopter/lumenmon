#!/usr/bin/env python3
# SSH ForceCommand handler that receives metric data from agents and writes directly to SQLite.
# Reads filename and TSV data from stdin, validates input, and inserts into per-agent metric tables.

import os
import re
import sys
import sqlite3
from datetime import datetime

DB_PATH = "/data/metrics.db"
LOG_FILE = "/data/gateway.log"

def log_debug(agent_id, message):
    """Write debug log to both stderr and log file."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_msg = f"[gateway] [{timestamp}] [{agent_id}] {message}\n"

    # Write to stderr
    print(log_msg.rstrip(), file=sys.stderr, flush=True)

    # Also write to log file
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(log_msg)
    except Exception:
        pass  # Don't fail if log file can't be written

def main():
    # Get agent ID from SSH user
    agent_id = os.environ.get('USER', '')
    if not agent_id:
        log_debug('unknown', 'ERROR: No USER env var')
        sys.exit(1)

    log_debug(agent_id, 'Gateway started')

    # Read header from first line of stdin: filename.tsv [TYPE]
    header = sys.stdin.readline().strip()
    log_debug(agent_id, f'Received header: {header}')

    # Parse filename and optional type
    parts = header.split()
    if len(parts) < 1:
        log_debug(agent_id, 'ERROR: Empty header')
        sys.exit(1)

    filename = parts[0]
    data_type = parts[1] if len(parts) > 1 else 'TEXT'  # Default to TEXT for backward compatibility

    # Validate filename format (alphanumeric, dash, underscore, must end with .tsv)
    if not re.match(r'^[a-zA-Z0-9_-]+\.tsv$', filename):
        log_debug(agent_id, f'ERROR: Invalid filename format: {filename}')
        sys.exit(1)

    # Validate data type (must be valid SQLite type)
    valid_types = {'TEXT', 'REAL', 'INTEGER'}
    if data_type not in valid_types:
        log_debug(agent_id, f'ERROR: Invalid data type: {data_type}, must be one of {valid_types}')
        sys.exit(1)

    log_debug(agent_id, f'Parsed filename: {filename}, type: {data_type}')

    # Extract metric name (strip .tsv extension)
    metric_name = filename[:-4]  # Remove .tsv

    # Table name: agentid_metricname
    table_name = f"{agent_id}_{metric_name}"
    log_debug(agent_id, f'Table name: {table_name}')

    # Sanitize table name (should already be safe from validation above)
    if not re.match(r'^[a-zA-Z0-9_-]+$', table_name):
        log_debug(agent_id, f'ERROR: Invalid table name: {table_name}')
        sys.exit(1)

    # Connect to database
    try:
        log_debug(agent_id, f'Connecting to database: {DB_PATH}')
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Check if table exists and has matching schema
        cursor.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,)
        )
        existing = cursor.fetchone()

        if existing:
            existing_sql = existing[0]
            # Check if the value column type matches
            # Schema format: CREATE TABLE "name" ( ... value TYPE ... )
            if f'value {data_type}' not in existing_sql:
                log_debug(agent_id, f'Schema mismatch detected, dropping table: {table_name}')
                log_debug(agent_id, f'Old schema: {existing_sql}')
                cursor.execute(f'DROP TABLE "{table_name}"')
                log_debug(agent_id, 'Table dropped, will recreate with new type')

        # Create table with specified data type
        log_debug(agent_id, f'Creating table: {table_name} with type {data_type}')
        cursor.execute(f'''
            CREATE TABLE IF NOT EXISTS "{table_name}" (
                timestamp INTEGER PRIMARY KEY,
                interval INTEGER,
                value {data_type}
            )
        ''')

        # Read and insert all TSV lines in a single transaction
        rows_to_insert = []
        line_count = 0
        for line in sys.stdin:
            line_count += 1
            line = line.strip()
            if not line:
                log_debug(agent_id, f'Line {line_count}: empty, skipping')
                continue

            # Parse TSV line: timestamp interval value
            parts = line.split()
            if len(parts) < 3:
                log_debug(agent_id, f'Line {line_count}: insufficient parts ({len(parts)}), skipping')
                continue

            try:
                timestamp = int(parts[0])
                interval = int(parts[1])  # Store interval for staleness detection
                # Value can be numeric or string (for hostname)
                value = ' '.join(parts[2:])  # Join remaining parts for multi-word values
                rows_to_insert.append((timestamp, interval, value))
                log_debug(agent_id, f'Line {line_count}: parsed ts={timestamp}, interval={interval}, val={value}')
            except (ValueError, IndexError) as e:
                log_debug(agent_id, f'Line {line_count}: parse error: {e}')
                continue

        # Batch insert all rows
        if rows_to_insert:
            log_debug(agent_id, f'Inserting {len(rows_to_insert)} rows')
            cursor.executemany(
                f'INSERT OR REPLACE INTO "{table_name}" (timestamp, interval, value) VALUES (?, ?, ?)',
                rows_to_insert
            )
            log_debug(agent_id, 'Insert successful')
        else:
            log_debug(agent_id, 'No rows to insert')

        conn.commit()
        log_debug(agent_id, 'Commit successful')
        conn.close()
        log_debug(agent_id, 'Database closed, gateway complete')

    except Exception as e:
        log_debug(agent_id, f'EXCEPTION: {type(e).__name__}: {str(e)}')
        sys.exit(1)

    sys.exit(0)

if __name__ == '__main__':
    main()
