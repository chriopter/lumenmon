#!/usr/bin/env python3
# Agent API endpoints - clean version using agent_registry.
# NO legacy table name parsing.

from flask import Blueprint, jsonify
import time
from metrics import get_agent_metrics, get_all_agents, get_agent_tables
from db import get_db_connection
from pending_invites import get_invite

agents_bp = Blueprint('agents', __name__)

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

@agents_bp.route('/api/entities', methods=['GET'])
def get_entities():
    """Get all entities (agents + invites) from agent_registry."""
    # Get all agents
    agents = get_all_agents()

    # Get MQTT credentials (for pending invites)
    MQTT_PASSWD_FILE = "/data/mqtt/passwd"
    mqtt_users = set()

    try:
        with open(MQTT_PASSWD_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if ':' in line:
                    username = line.split(':', 1)[0]
                    if username.startswith('id_'):
                        mqtt_users.add(username)
    except Exception:
        pass

    # Add metrics to each agent
    entities = []
    for agent in agents:
        agent_data = get_agent_metrics(agent['id'])

        # Check for pending invite
        pending_invite = get_invite(agent['id'])
        if pending_invite:
            agent_data['pending_invite'] = pending_invite

        # Set type
        agent_data['type'] = 'agent'
        agent_data['valid'] = agent_data['status'] == 'online'

        entities.append(agent_data)

    # Sort by status
    entities.sort(key=lambda x: (
        0 if x.get('status') == 'online' else 1,
        x.get('id', '')
    ))

    return jsonify({
        'entities': entities,
        'count': len(entities),
        'timestamp': int(time.time())
    })
