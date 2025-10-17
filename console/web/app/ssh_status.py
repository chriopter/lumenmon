#!/usr/bin/env python3
# SSH connection status checking for agents.
# Detects active SSH connections by checking sshd processes.

import subprocess

def is_ssh_connected(agent_id):
    """Check if agent user has an active SSH connection by checking sshd processes."""
    try:
        # Check for active sshd processes with the agent username
        # Agents connect via SSH with @notty (no TTY), so 'who' won't show them
        # Look for processes like: "sshd: id_XXXXX@notty"
        result = subprocess.run(
            ['ps', 'aux'],
            capture_output=True,
            text=True,
            timeout=1
        )

        if result.returncode == 0:
            # Look for sshd processes with this agent_id
            search_pattern = f'sshd: {agent_id}@notty'
            for line in result.stdout.splitlines():
                if search_pattern in line:
                    return True

        return False
    except Exception:
        # If we can't check, assume no connection
        return False
