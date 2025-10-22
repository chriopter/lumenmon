#!/usr/bin/env python3
# Agent metrics API endpoints.
# Provides JSON endpoints for agent data and unified entities view.

from flask import Blueprint, jsonify
import time
import os
import glob
import pwd
from metrics import get_agent_tsv_files, get_agent_metrics
from db import get_db_connection

agents_bp = Blueprint('agents', __name__)

@agents_bp.route('/api/agents/<agent_id>/tsv', methods=['GET'])
def get_agent_tsv(agent_id):
    """Get all TSV files and their latest data for a specific agent."""
    tsv_files = get_agent_tsv_files(agent_id)
    return jsonify({
        'agent_id': agent_id,
        'tsv_files': tsv_files,
        'count': len(tsv_files),
        'timestamp': int(time.time())
    })

def get_all_entities():
    """Get all entities (agents + invites) with comprehensive validation status."""
    entities = {}

    # 1. Get all agent/invite users (id_* and reg_* only)
    try:
        for user in pwd.getpwall():
            username = user.pw_name
            # Only include agent users (id_*) and invite users (reg_*)
            if username.startswith('id_') or username.startswith('reg_'):
                entities[username] = {
                    'id': username,
                    'has_user': True,
                    'has_folder': False,
                    'has_table': False,
                    'has_password': False
                }
    except Exception as e:
        print(f"Error reading users: {e}")

    # 2. Get all agent directories
    try:
        for agent_dir in glob.glob('/data/agents/*'):
            if os.path.isdir(agent_dir):
                agent_id = os.path.basename(agent_dir)
                if agent_id not in entities:
                    entities[agent_id] = {
                        'id': agent_id,
                        'has_user': False,
                        'has_folder': True,
                        'has_table': False,
                        'has_password': False
                    }
                else:
                    entities[agent_id]['has_folder'] = True
    except Exception as e:
        print(f"Error reading agent directories: {e}")

    # 3. Get all agent IDs from SQLite tables
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

        for row in cursor.fetchall():
            table_name = row[0]
            # Extract agent ID from table name (format: id_<fingerprint>_metric_name)
            if table_name.startswith('id_'):
                generic_idx = table_name.rfind('_generic_')
                if generic_idx > 0:
                    agent_id = table_name[:generic_idx]
                    if agent_id not in entities:
                        entities[agent_id] = {
                            'id': agent_id,
                            'has_user': False,
                            'has_folder': False,
                            'has_table': True,
                            'has_password': False
                        }
                    else:
                        entities[agent_id]['has_table'] = True

        conn.close()
    except Exception as e:
        print(f"Error reading SQLite tables: {e}")

    # 4. Check for password files in home directories (for invites)
    for entity_id in list(entities.keys()):
        password_file = f"/home/{entity_id}/.invite_password"
        if os.path.isfile(password_file):
            entities[entity_id]['has_password'] = True

    # 5. Determine type and validity for each entity
    result = []
    for entity_id, checks in entities.items():
        # Determine type based on username prefix
        entity_type = 'invite' if entity_id.startswith('reg_') else 'agent'

        # Determine validity based on type
        if entity_type == 'invite':
            # Invite needs: user + password file
            valid = checks['has_user'] and checks['has_password']
        else:
            # Agent needs: user + folder + table
            valid = checks['has_user'] and checks['has_folder'] and checks['has_table']

        entity_data = {
            'id': entity_id,
            'type': entity_type,
            'valid': valid,
            'has_user': checks['has_user'],
            'has_folder': checks['has_folder'],
            'has_table': checks['has_table'],
            'has_password': checks['has_password']
        }

        # Add metrics for valid agents
        if entity_type == 'agent' and valid:
            try:
                metrics = get_agent_metrics(entity_id)
                entity_data.update({
                    'cpu': metrics.get('cpu', 0),
                    'memory': metrics.get('memory', 0),
                    'disk': metrics.get('disk', 0),
                    'hostname': metrics.get('hostname', ''),
                    'status': metrics.get('status', 'offline'),
                    'age': metrics.get('age', 0),
                    'age_formatted': metrics.get('age_formatted', ''),
                    'lastUpdate': metrics.get('lastUpdate', 0),
                    'cpuSparkline': metrics.get('cpuSparkline', ''),
                    'memSparkline': metrics.get('memSparkline', ''),
                    'diskSparkline': metrics.get('diskSparkline', '')
                })
            except Exception as e:
                print(f"Error getting metrics for {entity_id}: {e}")

        result.append(entity_data)

    # Sort: invites first, then by status (for agents), then by ID
    def sort_key(entity):
        if entity['type'] == 'invite':
            return (0, entity['id'])
        else:
            status_order = {'online': 1, 'stale': 2, 'offline': 3}
            status = entity.get('status', 'offline')
            return (status_order.get(status, 4), entity['id'])

    result.sort(key=sort_key)

    return result

@agents_bp.route('/api/entities', methods=['GET'])
def get_entities():
    """Get all entities (agents + invites) with comprehensive validation."""
    entities = get_all_entities()

    return jsonify({
        'entities': entities,
        'count': len(entities),
        'timestamp': int(time.time())
    })
