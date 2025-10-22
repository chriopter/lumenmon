#!/usr/bin/env python3
# Reads active invite information and provides invite creation endpoints.
# Mirrors tui/readers/invites.sh functionality for web interface.

from flask import Blueprint, jsonify
import subprocess
import glob
import os
from pending_invites import store_invite, get_invite, clear_invite

invites_bp = Blueprint('invites', __name__)

def get_active_invites():
    """Get list of active MQTT agent credentials (without passwords)."""
    invites = []

    # Read mosquitto password file to list registered agents
    passwd_file = '/data/mqtt/passwd'
    if os.path.isfile(passwd_file):
        with open(passwd_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and ':' in line:
                    username = line.split(':')[0]
                    # Only include agent IDs (skip anonymous or other users)
                    if username.startswith('id_'):
                        invites.append({
                            'username': username,
                            'status': 'active'
                        })

    return invites

@invites_bp.route('/api/invites', methods=['GET'])
def list_invites():
    """List all active invites."""
    invites = get_active_invites()

    return jsonify({
        'invites': invites,
        'count': len(invites)
    })

@invites_bp.route('/api/invites/create', methods=['POST'])
def create_invite():
    """Create a new MQTT registration invite with certificate pinning.

    SECURITY: Returns invite URL with password ONCE. Never stored or retrievable again.
    """
    try:
        # Call the invite creation script
        result = subprocess.run(
            ['/app/core/enrollment/invite_create.sh'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            # Read machine-readable JSON output (one-time use)
            import json
            with open('/tmp/last_invite.json', 'r') as f:
                invite_data = json.load(f)

            # SECURITY: Immediately delete temp file containing password
            try:
                os.remove('/tmp/last_invite.json')
            except:
                pass  # Best effort cleanup

            # Store invite in RAM until agent connects (shown in detail view)
            agent_id = invite_data['username']
            store_invite(agent_id, {
                'username': invite_data['username'],
                'invite_url': invite_data['url'],
                'fingerprint': invite_data['fingerprint']
            })

            return jsonify({
                'success': True,
                'username': invite_data['username'],
                'invite_url': invite_data['url'],
                'fingerprint': invite_data['fingerprint'],
                'message': 'Invite created successfully. Copy this URL now - it will not be shown again.'
            })
        else:
            return jsonify({
                'success': False,
                'error': result.stderr.strip()
            }), 500

    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Invite creation timed out'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@invites_bp.route('/api/invites/create/full', methods=['POST'])
def create_invite_full():
    """Create invite and return full one-click install command.

    SECURITY: Returns invite URL with password ONCE. Never stored or retrievable again.
    """
    try:
        # Call the invite creation script
        result = subprocess.run(
            ['/app/core/enrollment/invite_create.sh'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            # Read machine-readable JSON output (one-time use)
            import json
            with open('/tmp/last_invite.json', 'r') as f:
                invite_data = json.load(f)

            # SECURITY: Immediately delete temp file containing password
            try:
                os.remove('/tmp/last_invite.json')
            except:
                pass  # Best effort cleanup

            # Store invite in RAM until agent connects (shown in detail view)
            agent_id = invite_data['username']
            store_invite(agent_id, {
                'username': invite_data['username'],
                'invite_url': invite_data['url'],
                'fingerprint': invite_data['fingerprint']
            })

            # Return full one-click install command
            one_click = f'curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | LUMENMON_INVITE="{invite_data["url"]}" bash'

            return jsonify({
                'success': True,
                'username': invite_data['username'],
                'invite_url': invite_data['url'],
                'one_click_install': one_click,
                'fingerprint': invite_data['fingerprint'],
                'message': 'Invite created successfully. Copy this command now - it will not be shown again.'
            })
        else:
            return jsonify({
                'success': False,
                'error': result.stderr.strip()
            }), 500

    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Invite creation timed out'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Note: No endpoint to retrieve passwords after creation - security best practice
# Invite URLs with passwords are shown ONCE at creation time only
