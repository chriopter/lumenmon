#!/usr/bin/env python3
# Agent management API endpoints.
# Provides deletion endpoint for removing agents completely (tables, users, SSH access).

from flask import Blueprint, jsonify
import subprocess
import re

management_bp = Blueprint('management', __name__)

@management_bp.route('/api/agents/<agent_id>', methods=['DELETE'])
def delete_agent(agent_id):
    """Delete an agent completely: database tables, system user, and SSH access."""

    # Validate agent_id format (must start with id_)
    if not re.match(r'^id_[A-Za-z0-9_-]+$', agent_id):
        return jsonify({
            'success': False,
            'message': 'Invalid agent_id format'
        }), 400

    try:
        # Call deletion script
        result = subprocess.run(
            ['/app/core/management/agent_delete.sh', agent_id],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': f'Agent {agent_id} deleted successfully',
                'output': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Deletion script failed',
                'error': result.stderr
            }), 500

    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'message': 'Deletion timed out'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Deletion failed: {str(e)}'
        }), 500
