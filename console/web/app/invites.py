#!/usr/bin/env python3
# Reads active invite information and provides invite creation endpoints.
# Mirrors tui/readers/invites.sh functionality for web interface.

from flask import Blueprint, jsonify
import subprocess
import glob
import os

invites_bp = Blueprint('invites', __name__)

def get_active_invites():
    """Get list of active invites from user home directories."""
    invites = []

    # Look for all reg_* home directories
    agent_dirs = glob.glob('/home/reg_*')
    for homedir in agent_dirs:
        if os.path.isdir(homedir):
            username = os.path.basename(homedir)
            password_file = os.path.join(homedir, '.invite_password')

            # Check if password file exists
            if os.path.isfile(password_file):
                invites.append({
                    'username': username,
                    'password_file': password_file
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
    """Create a new registration invite."""
    try:
        # Call the invite creation script
        result = subprocess.run(
            ['/app/core/enrollment/invite_create.sh'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            invite_url = result.stdout.strip()

            return jsonify({
                'success': True,
                'invite_url': invite_url,
                'message': 'Invite created successfully'
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
    """Create invite with full install command."""
    try:
        # Call with --full flag for complete install command
        result = subprocess.run(
            ['/app/core/enrollment/invite_create.sh', '--full'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            install_command = result.stdout.strip()

            return jsonify({
                'success': True,
                'install_command': install_command,
                'message': 'Invite created successfully'
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

@invites_bp.route('/api/invites/<username>/url', methods=['GET'])
def get_invite_url(username):
    """Get the invite URL for a specific invite user (for copying)."""
    try:
        # Read password from user's home directory
        password_file = f"/home/{username}/.invite_password"

        if not os.path.isfile(password_file):
            return jsonify({
                'success': False,
                'error': 'Invite not found or expired'
            }), 404

        with open(password_file, 'r') as f:
            password = f.read().strip()

        # Get host key
        with open('/data/ssh/ssh_host_ed25519_key.pub', 'r') as f:
            parts = f.read().strip().split()
            hostkey = f"{parts[0]}_{parts[1]}"

        # Get host from environment or default to localhost
        invite_host = os.environ.get('CONSOLE_HOST', 'localhost')
        invite_port = os.environ.get('CONSOLE_PORT', '2345')

        # Build invite URL
        invite_url = f"ssh://{username}:{password}@{invite_host}:{invite_port}/#{hostkey}"

        # Build full install command
        install_command = f"curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | LUMENMON_INVITE='{invite_url}' bash"

        return jsonify({
            'success': True,
            'username': username,
            'invite_url': invite_url,
            'install_command': install_command
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
