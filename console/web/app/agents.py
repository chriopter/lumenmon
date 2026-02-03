#!/usr/bin/env python3
# Agent metrics API endpoints.
# Provides JSON endpoints for agent data and unified entities view.

from flask import Blueprint, jsonify, request
import time
import os
from metrics import get_agent_tables, get_agent_metrics, count_failed_collectors, calculate_host_status, calculate_staleness
from db import get_db_connection, get_all_host_display_names, set_host_display_name
from pending_invites import get_invite

agents_bp = Blueprint('agents', __name__)

# Simple cache for entities endpoint (reduces DB queries when multiple clients poll)
_entities_cache = {'data': None, 'timestamp': 0}
_CACHE_TTL = 2  # 2 second cache - balances responsiveness with performance
_MAX_AGENTS = 100  # Limit agents to prevent memory exhaustion

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
                                'has_table': False,
                                'has_mail': False
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
                            'has_table': True,
                            'has_mail': False
                        }
                    else:
                        entities[agent_id]['has_table'] = True

        # 3. Get mail-only hosts from messages table (hosts that have received mail but no agent)
        cursor.execute("SELECT DISTINCT agent_id FROM messages WHERE agent_id LIKE 'id_%'")
        for row in cursor.fetchall():
            agent_id = row[0]
            if agent_id not in entities:
                # Mail-only host - no MQTT user, no metric tables, but has messages
                entities[agent_id] = {
                    'id': agent_id,
                    'has_mqtt_user': False,
                    'has_table': False,
                    'has_mail': True
                }
            else:
                entities[agent_id]['has_mail'] = True

        conn.close()
    except Exception as e:
        print(f"Error reading SQLite tables: {e}")

    # 4. Get custom display names
    display_names = get_all_host_display_names()

    # 5. Determine type and validity for each entity (limited to prevent memory exhaustion)
    result = []
    agent_count = 0
    for entity_id, checks in entities.items():
        # Determine type based on username prefix
        entity_type = 'invite' if entity_id.startswith('reg_') else 'agent'

        # Determine validity based on type (MQTT architecture)
        if entity_type == 'invite':
            # Invite needs: MQTT user entry in passwd file
            valid = checks['has_mqtt_user']
        else:
            # Agent needs: database tables OR mail messages (mail-only hosts are valid too)
            valid = checks['has_table'] or checks.get('has_mail', False)

        # Get custom display name if set
        custom_name = display_names.get(entity_id)

        entity_data = {
            'id': entity_id,
            'type': entity_type,
            'valid': valid,
            'has_mqtt_user': checks['has_mqtt_user'],
            'has_table': checks['has_table'],
            'has_mail': checks.get('has_mail', False),
            'mail_only': not checks['has_table'] and checks.get('has_mail', False),
            'display_name': custom_name  # Custom editable name
        }

        # Check for pending invite (held in RAM until first data arrives)
        pending_invite = get_invite(entity_id)
        if pending_invite:
            entity_data['pending_invite'] = pending_invite

        # Add metrics for valid agents (with limit to prevent overload)
        if entity_type == 'agent' and valid:
            # Mail-only hosts don't have metrics, just mark them specially
            if entity_data.get('mail_only'):
                entity_data['status'] = 'mail-only'
                entity_data['hostname'] = ''  # No hostname from agent
                result.append(entity_data)
                continue

            agent_count += 1
            if agent_count > _MAX_AGENTS:
                # Skip metrics for agents beyond limit (still show in list but without data)
                entity_data['status'] = 'limited'
                result.append(entity_data)
                continue
            try:
                metrics = get_agent_metrics(entity_id)

                # Calculate host status from collector health (hierarchical status system)
                heartbeat = metrics.get('heartbeat', 0)
                heartbeat_staleness = calculate_staleness(heartbeat, 10)  # Heartbeat interval ~10s
                failed_collectors, total_collectors = count_failed_collectors(entity_id)
                host_status = calculate_host_status(
                    heartbeat_staleness['is_stale'],
                    failed_collectors,
                    total_collectors
                )

                entity_data.update({
                    'cpu': metrics.get('cpu', 0),
                    'memory': metrics.get('memory', 0),
                    'disk': metrics.get('disk', 0),
                    'hostname': metrics.get('hostname', ''),
                    'status': host_status,
                    'failed_collectors': failed_collectors,
                    'total_collectors': total_collectors,
                    'age': metrics.get('age', 0),
                    'age_formatted': metrics.get('age_formatted', ''),
                    'lastUpdate': metrics.get('lastUpdate', 0),
                    'uptime': metrics.get('uptime', ''),
                    'heartbeat': heartbeat,
                    'cpuSparkline': metrics.get('cpuSparkline', ''),
                    'memSparkline': metrics.get('memSparkline', ''),
                    'diskSparkline': metrics.get('diskSparkline', ''),
                    'cpuHistory': metrics.get('cpuHistory', []),
                    'memHistory': metrics.get('memHistory', []),
                    'diskHistory': metrics.get('diskHistory', []),
                    'agent_version': metrics.get('agent_version', '')
                })
            except Exception as e:
                print(f"Error getting metrics for {entity_id}: {e}")

        result.append(entity_data)

    # Sort: regular agents alphabetically, then mail-only hosts, then invites at bottom
    def sort_key(entity):
        # Get display name for sorting (lowercase for case-insensitive sort)
        name = (entity.get('display_name') or entity.get('hostname') or entity['id']).lower()

        if entity['type'] == 'invite':
            # Invites at the very bottom (group 2)
            return (2, name)
        elif entity.get('mail_only'):
            # Mail-only hosts before invites (group 1)
            return (1, name)
        else:
            # Regular agents first (group 0), sorted alphabetically
            return (0, name)

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

@agents_bp.route('/api/agents/<agent_id>/name', methods=['PUT', 'POST'])
def update_agent_name(agent_id):
    """Update the display name for an agent (useful for mail-only hosts)."""
    global _entities_cache

    data = request.get_json() or {}
    display_name = data.get('name', '').strip()

    # Allow empty string to clear the name
    if set_host_display_name(agent_id, display_name if display_name else None):
        # Clear cache to reflect change immediately
        _entities_cache = {'data': None, 'timestamp': 0}
        return jsonify({
            'success': True,
            'agent_id': agent_id,
            'display_name': display_name if display_name else None
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Failed to update display name'
        }), 500
