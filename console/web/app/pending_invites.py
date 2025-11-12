#!/usr/bin/env python3
# Manages pending invite storage (file-based for multi-process access).
# Invites are shown once in WebUI and cleared when agent sends first data.

import json
import os
from pathlib import Path

# File-based storage for multi-process access (Flask + MQTT bridge)
PENDING_INVITES_FILE = "/tmp/pending_invites.json"

def _load_invites():
    """Load pending invites from file."""
    if os.path.exists(PENDING_INVITES_FILE):
        try:
            with open(PENDING_INVITES_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}
    return {}

def _save_invites(invites):
    """Save pending invites to file."""
    try:
        with open(PENDING_INVITES_FILE, 'w') as f:
            json.dump(invites, f)
    except IOError:
        pass  # Best effort

def store_invite(agent_id, invite_data):
    """Store invite data until agent connects.

    SECURITY: Stored in /tmp (lost on restart), cleared when agent connects.
    This allows the detail view to display invite URLs for current session,
    but they're not persistently stored and disappear on container restart.

    Args:
        agent_id: Agent identifier (e.g., 'id_abc123')
        invite_data: Dict with 'username', 'fingerprint', 'invite_url', 'install_command'
    """
    invites = _load_invites()
    invites[agent_id] = invite_data
    _save_invites(invites)

def get_invite(agent_id):
    """Retrieve pending invite data for an agent.

    Returns:
        Dict with invite data, or None if no pending invite exists
    """
    invites = _load_invites()
    return invites.get(agent_id)

def clear_invite(agent_id):
    """Clear pending invite data for an agent (called on first data received)."""
    invites = _load_invites()
    if agent_id in invites:
        del invites[agent_id]
        _save_invites(invites)
        return True
    return False

def get_all_pending():
    """Get list of all agent IDs with pending invites."""
    invites = _load_invites()
    return list(invites.keys())
