#!/usr/bin/env python3
# Agent metrics API endpoints.
# Provides JSON endpoints for agent data and unified entities view.

from flask import Blueprint, jsonify
import time
import os
from metrics import get_agent_tables, get_agent_metrics
from db import get_db_connection
from pending_invites import get_invite

agents_bp = Blueprint('agents', __name__)

# Simple cache for entities endpoint (reduces DB queries when multiple clients poll)
_entities_cache = {'data': None, 'timestamp': 0}
_CACHE_TTL = 1  # 1 second cache

@agents_bp.route('/api/agents/<agent_id>/tables', methods=['GET'])
def get_agent_tables_endpoint(agent_id):
    """Get all metric tables and their latest data for a specific agent."""
    tables = get_agent_tables(agent_id)
    return jsonify({
        'agent_id': agent_id,
        'tables': tables,
        'count': len(tables),
        'timestamp': int(time.time())
    })

def get_all_entities():
    """Get all entities (agents + invites) with comprehensive validation status (MQTT architecture)."""
    entities = {}

    # 1. Get all MQTT users from passwd file (id_* agents and reg_* invites)
    MQTT_PASSWD_FILE = "/data/mqtt/passwd"
    try:
        if os.path.isfile(MQTT_PASSWD_FILE):
            with open(MQTT_PASSWD_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if ':' in line:
                        username = line.split(':', 1)[0]
                        # Only include agent users (id_*) and invite users (reg_*)
                        if username.startswith('id_') or username.startswith('reg_'):
                            entities[username] = {
                                'id': username,
                                'has_mqtt_user': True,
                                'has_table': False
                            }
    except Exception as e:
        print(f"Error reading MQTT passwd file: {e}")

    # 2. Get all agent IDs from SQLite tables
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
                            'has_mqtt_user': False,
                            'has_table': True
                        }
                    else:
                        entities[agent_id]['has_table'] = True

        conn.close()
    except Exception as e:
        print(f"Error reading SQLite tables: {e}")

    # 3. Determine type and validity for each entity
    result = []
    for entity_id, checks in entities.items():
        # Determine type based on username prefix
        entity_type = 'invite' if entity_id.startswith('reg_') else 'agent'

        # Determine validity based on type (MQTT architecture)
        if entity_type == 'invite':
            # Invite needs: MQTT user entry in passwd file
            valid = checks['has_mqtt_user']
        else:
            # Agent needs: database tables (has_table is sufficient - metrics are flowing)
            valid = checks['has_table']

        entity_data = {
            'id': entity_id,
            'type': entity_type,
            'valid': valid,
            'has_mqtt_user': checks['has_mqtt_user'],
            'has_table': checks['has_table']
        }

        # Check for pending invite (held in RAM until first data arrives)
        pending_invite = get_invite(entity_id)
        if pending_invite:
            entity_data['pending_invite'] = pending_invite

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
                    'uptime': metrics.get('uptime', ''),
                    'heartbeat': metrics.get('heartbeat', 0),
                    'cpuSparkline': metrics.get('cpuSparkline', ''),
                    'memSparkline': metrics.get('memSparkline', ''),
                    'diskSparkline': metrics.get('diskSparkline', ''),
                    'cpuHistory': metrics.get('cpuHistory', []),
                    'memHistory': metrics.get('memHistory', []),
                    'diskHistory': metrics.get('diskHistory', [])
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
    global _entities_cache

    now = time.time()
    # Return cached data if fresh (within TTL)
    if _entities_cache['data'] is not None and (now - _entities_cache['timestamp']) < _CACHE_TTL:
        return jsonify(_entities_cache['data'])

    entities = get_all_entities()
    result = {
        'entities': entities,
        'count': len(entities),
        'timestamp': int(now)
    }

    # Update cache
    _entities_cache = {'data': result, 'timestamp': now}

    return jsonify(result)
