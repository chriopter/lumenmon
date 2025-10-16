#!/usr/bin/env python3
# Agent metrics API endpoints.
# Provides JSON and HTML fragment endpoints for agent data.

from flask import Blueprint, jsonify, render_template
import time
from metrics import get_all_agents, get_agent_tsv_files

agents_bp = Blueprint('agents', __name__)

@agents_bp.route('/api/agents', methods=['GET'])
def get_agents():
    """Get all connected agents with their metrics as JSON."""
    agents = get_all_agents()

    return jsonify({
        'agents': agents,
        'timestamp': int(time.time()),
        'count': len(agents)
    })

@agents_bp.route('/api/agents/table', methods=['GET'])
def get_agents_table():
    """Get agents table as HTML fragment."""
    agents = get_all_agents()
    return render_template('table_rows.html', agents=agents)

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
