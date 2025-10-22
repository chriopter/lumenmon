#!/usr/bin/env python3
# SQL debug viewer - provides raw access to SQLite tables for debugging.
# Lists all tables and allows viewing raw table data.

from flask import Blueprint, jsonify
import sqlite3
import os

sql_debug_bp = Blueprint('sql_debug', __name__)

DB_PATH = '/data/metrics.db'

@sql_debug_bp.route('/api/sql/tables', methods=['GET'])
def list_tables():
    """List all tables in the database."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Get all tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = [row[0] for row in cursor.fetchall()]

        # Get row count for each table
        table_info = []
        for table_name in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            row_count = cursor.fetchone()[0]
            table_info.append({
                'name': table_name,
                'rows': row_count
            })

        conn.close()

        return jsonify({
            'success': True,
            'tables': table_info
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@sql_debug_bp.route('/api/sql/table/<table_name>', methods=['GET'])
def get_table_data(table_name):
    """Get all data from a specific table."""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # Validate table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
        if not cursor.fetchone():
            return jsonify({
                'success': False,
                'error': 'Table not found'
            }), 404

        # Get table schema
        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = [row[1] for row in cursor.fetchall()]

        # Get all rows (limit to 1000 for safety)
        cursor.execute(f"SELECT * FROM {table_name} ORDER BY timestamp DESC LIMIT 1000")
        rows = cursor.fetchall()

        # Convert rows to list of dicts
        data = []
        for row in rows:
            data.append(dict(row))

        conn.close()

        return jsonify({
            'success': True,
            'table': table_name,
            'columns': columns,
            'rows': data,
            'count': len(data)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
