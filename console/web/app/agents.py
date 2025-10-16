#!/usr/bin/env python3
# Agent metrics API endpoints.
# Provides JSON and HTML fragment endpoints for agent data.

from flask import Blueprint, jsonify, render_template
import time
from metrics import get_all_agents

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
    response = render_template('table_rows.html', agents=agents)
    return response, 200, {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
    }
