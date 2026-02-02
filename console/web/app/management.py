#!/usr/bin/env python3
# Agent management API endpoints.
# Provides deletion endpoint for removing agents completely (tables, MQTT credentials).

from flask import Blueprint, jsonify
import subprocess
import re
import os
import shutil
from datetime import datetime
from db import get_db_connection

management_bp = Blueprint('management', __name__)

DB_PATH = "/data/metrics.db"
LOG_FILE = "/data/agents.log"
MQTT_PASSWD_FILE = "/data/mqtt/passwd"

def log_message(message):
    """Log deletion operations to file."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_msg = f"[{timestamp}] {message}\n"
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(log_msg)
    except Exception:
        pass

@management_bp.route('/api/agents/<agent_id>', methods=['DELETE'])
def delete_agent(agent_id):
    """Delete an agent completely: database tables and MQTT credentials."""

    # Validate agent_id format (must start with id_)
    if not re.match(r'^id_[a-f0-9]+$', agent_id):
        return jsonify({
            'success': False,
            'message': 'Invalid agent_id format'
        }), 400

    log_message(f"Starting deletion for agent: {agent_id}")

    errors = []

    try:
        # 1. Drop all database tables
        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            # Get all tables for this agent
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
                (f"{agent_id}_%",)
            )
            tables = cursor.fetchall()

            if tables:
                for (table_name,) in tables:
                    cursor.execute(f'DROP TABLE IF EXISTS "{table_name}"')
                    log_message(f"  Dropped table: {table_name}")
                conn.commit()
            else:
                log_message(f"  No tables found for {agent_id}")

            conn.close()
        except Exception as e:
            errors.append(f"Database cleanup error: {str(e)}")

        # 2. Remove MQTT credentials from passwd file
        try:
            if os.path.exists(MQTT_PASSWD_FILE):
                # Read current passwd file
                with open(MQTT_PASSWD_FILE, 'r') as f:
                    lines = f.readlines()

                # Filter out lines for this agent
                new_lines = [line for line in lines if not line.startswith(f"{agent_id}:")]

                # Write back
                with open(MQTT_PASSWD_FILE, 'w') as f:
                    f.writelines(new_lines)

                if len(new_lines) < len(lines):
                    log_message(f"  Removed MQTT credentials for {agent_id}")
                else:
                    log_message(f"  No MQTT credentials found for {agent_id}")
            else:
                log_message(f"  MQTT passwd file does not exist")
        except Exception as e:
            errors.append(f"MQTT credential cleanup error: {str(e)}")

        # 3. Reload mosquitto to apply password file changes
        try:
            # Publish reload message via Python MQTT client
            result = subprocess.run(
                ['python3', '/app/core/mqtt/mqtt_publish.py', 'admin/reload_passwd', 'reload'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                log_message(f"  Triggered mosquitto password reload")
            else:
                log_message(f"  Warning: mosquitto reload may have failed: {result.stderr.strip()}")
        except Exception as e:
            errors.append(f"Mosquitto reload error: {str(e)}")

        log_message(f"Deletion complete for agent: {agent_id}")

        if errors:
            return jsonify({
                'success': True,
                'message': f'Agent {agent_id} deleted with warnings',
                'warnings': errors
            })
        else:
            return jsonify({
                'success': True,
                'message': f'Agent {agent_id} deleted successfully'
            })

    except Exception as e:
        log_message(f"ERROR during deletion of {agent_id}: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Deletion failed: {str(e)}'
        }), 500


@management_bp.route('/api/agents/<agent_id>/metrics/<metric_name>', methods=['DELETE'])
def delete_metric(agent_id, metric_name):
    """Delete a single metric table for an agent."""

    # Validate agent_id format
    if not re.match(r'^id_[a-f0-9]+$', agent_id):
        return jsonify({'success': False, 'message': 'Invalid agent_id format'}), 400

    # Validate metric_name (alphanumeric and underscores only)
    if not re.match(r'^[a-zA-Z0-9_]+$', metric_name):
        return jsonify({'success': False, 'message': 'Invalid metric_name format'}), 400

    table_name = f"{agent_id}_{metric_name}"

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Check if table exists
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,)
        )
        if not cursor.fetchone():
            conn.close()
            return jsonify({'success': False, 'message': 'Metric not found'}), 404

        # Drop the table
        cursor.execute(f'DROP TABLE IF EXISTS "{table_name}"')
        conn.commit()
        conn.close()

        log_message(f"Deleted metric table: {table_name}")

        return jsonify({
            'success': True,
            'message': f'Metric {metric_name} deleted'
        })

    except Exception as e:
        log_message(f"ERROR deleting metric {table_name}: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500
