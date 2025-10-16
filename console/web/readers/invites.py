#!/usr/bin/env python3
# Reads active invite information and provides invite creation endpoints.
# Mirrors tui/readers/invites.sh functionality for web interface.

from flask import Blueprint, jsonify
import subprocess
import glob
import os

invites_bp = Blueprint('invites', __name__)

def get_active_invites():
    """Get list of active invites from /tmp/.invite_* files."""
    invites = []

    invite_files = glob.glob('/tmp/.invite_*')
    for filepath in invite_files:
        if os.path.isfile(filepath):
            username = os.path.basename(filepath).replace('.invite_', '')

            # Read password from file
            try:
                with open(filepath, 'r') as f:
                    password = f.read().strip()

                invites.append({
                    'username': username,
                    'filepath': filepath
                })
            except Exception as e:
                print(f"Error reading invite {filepath}: {e}")

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
