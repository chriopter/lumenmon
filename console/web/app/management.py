#!/usr/bin/env python3
# Agent management API endpoints.
# Provides deletion endpoint for removing agents completely (tables, users, SSH sessions).

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
    """Delete an agent or invite completely: database tables, system user, and SSH sessions."""

    # Validate agent_id format (must start with id_ for agents or reg_ for invites)
    if not re.match(r'^(id_|reg_)[A-Za-z0-9_-]+$', agent_id):
        return jsonify({
            'success': False,
            'message': 'Invalid agent_id format'
        }), 400

    # Determine entity type
    entity_type = 'invite' if agent_id.startswith('reg_') else 'agent'
    log_message(f"Starting deletion for {entity_type}: {agent_id}")

    errors = []

    try:
        # 1. Kill all SSH sessions for this user
        try:
            result = subprocess.run(
                ['pkill', '-u', agent_id],
                capture_output=True,
                timeout=5
            )
            if result.returncode == 0:
                log_message(f"  Killed SSH sessions for {agent_id}")
            # returncode 1 means no processes found (which is fine)
        except Exception as e:
            errors.append(f"Failed to kill SSH sessions: {str(e)}")

        # 2. Drop all database tables (only for agents)
        if entity_type == 'agent':
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
        else:
            log_message("  Skipping database tables (invites don't have tables)")

        # 3. Delete system user (removes home directory with -r flag)
        try:
            result = subprocess.run(
                ['userdel', '-r', agent_id],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                log_message(f"  Removed system user: {agent_id}")
            else:
                # User might not exist, that's ok
                log_message(f"  User removal warning: {result.stderr.strip()}")
        except Exception as e:
            errors.append(f"User deletion error: {str(e)}")

        # 4. Clean up agent directory if it still exists (only for agents)
        if entity_type == 'agent':
            agent_dir = f"/data/agents/{agent_id}"
            if os.path.isdir(agent_dir):
                try:
                    shutil.rmtree(agent_dir)
                    log_message(f"  Removed agent directory: {agent_dir}")
                except Exception as e:
                    errors.append(f"Directory cleanup error: {str(e)}")

        log_message(f"Deletion complete for {entity_type}: {agent_id}")

        if errors:
            return jsonify({
                'success': True,
                'message': f'{entity_type.capitalize()} {agent_id} deleted with warnings',
                'warnings': errors
            })
        else:
            return jsonify({
                'success': True,
                'message': f'{entity_type.capitalize()} {agent_id} deleted successfully'
            })

    except Exception as e:
        log_message(f"ERROR during deletion of {agent_id}: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Deletion failed: {str(e)}'
        }), 500
