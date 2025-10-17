#!/usr/bin/env python3
# Debug API endpoints for system diagnostics.
# Lists users, table prefixes, and identifies mismatches between agents and database tables.

from flask import Blueprint, jsonify
import pwd
from db import get_db_connection

debug_bp = Blueprint('debug', __name__)

@debug_bp.route('/api/debug/system', methods=['GET'])
def get_system_debug():
    """Get system debug information: users, table prefixes, and mismatches."""

    # Get all agent users from system (users starting with id_)
    system_users = []
    try:
        for user in pwd.getpwall():
            username = user.pw_name
            if username.startswith('id_'):
                system_users.append({
                    'username': username,
                    'uid': user.pw_uid,
                    'home': user.pw_dir
                })
    except Exception:
        pass

    system_user_names = set(u['username'] for u in system_users)

    # Get all agent IDs from database table prefixes
    table_agents = set()
    tables_by_agent = {}

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get all tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

        for row in cursor.fetchall():
            table_name = row[0]
            # Extract agent ID from table name (format: id_xxx_metric_name)
            if table_name.startswith('id_'):
                parts = table_name.split('_', 2)  # Split into ['id', 'xxx', 'metric_name']
                if len(parts) >= 3:
                    agent_id = f"{parts[0]}_{parts[1]}"  # Reconstruct id_xxx
                    table_agents.add(agent_id)

                    if agent_id not in tables_by_agent:
                        tables_by_agent[agent_id] = []
                    tables_by_agent[agent_id].append(table_name)

        conn.close()
    except Exception as e:
        pass

    # Find mismatches
    users_without_tables = system_user_names - table_agents
    tables_without_users = table_agents - system_user_names
    matched = system_user_names & table_agents

    # Build agent list with table counts
    agents_with_tables = []
    for agent_id in sorted(table_agents):
        agents_with_tables.append({
            'agent_id': agent_id,
            'table_count': len(tables_by_agent.get(agent_id, [])),
            'tables': tables_by_agent.get(agent_id, []),
            'has_user': agent_id in system_user_names
        })

    return jsonify({
        'system_users': {
            'count': len(system_users),
            'users': sorted(system_users, key=lambda x: x['username'])
        },
        'database_agents': {
            'count': len(table_agents),
            'agents': agents_with_tables
        },
        'matched': {
            'count': len(matched),
            'agent_ids': sorted(list(matched))
        },
        'mismatches': {
            'users_without_tables': {
                'count': len(users_without_tables),
                'users': sorted(list(users_without_tables))
            },
            'tables_without_users': {
                'count': len(tables_without_users),
                'agents': sorted(list(tables_without_users))
            }
        }
    })
