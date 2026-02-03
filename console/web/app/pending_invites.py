#!/usr/bin/env python3
# Pending invite storage - imported by unified_server.py and invites.py.
# Keeps invites in RAM until agent connects (cleared on first MQTT message).

# In-memory storage - lost on container restart (intentional security feature)
_pending_invites = {}

def store_invite(agent_id, invite_data):
    """Store invite data in RAM until agent connects.

    SECURITY: Stored in RAM only (lost on restart), cleared when agent connects.
    This allows the detail view to display invite URLs for current session,
    but they're not persistently stored and disappear on container restart.

    Args:
        agent_id: Agent identifier (e.g., 'reg_abc123')
        invite_data: Dict with 'username', 'fingerprint', 'invite_url', 'install_command'
    """
    _pending_invites[agent_id] = invite_data

def get_invite(agent_id):
    """Retrieve pending invite data for an agent.

    Returns:
        Dict with invite data, or None if no pending invite exists
    """
    return _pending_invites.get(agent_id)

def clear_invite(agent_id):
    """Clear pending invite data for an agent (called on first data received)."""
    if agent_id in _pending_invites:
        del _pending_invites[agent_id]
        return True
    return False

def get_all_pending():
    """Get list of all agent IDs with pending invites."""
    return list(_pending_invites.keys())
