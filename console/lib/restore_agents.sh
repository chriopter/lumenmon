#!/bin/bash
# Restore agent users from persistent directories
set -euo pipefail

echo "[console] Restoring agent users from /data/agents/..."

# Create agents group if it doesn't exist
if ! getent group agents > /dev/null 2>&1; then
    groupadd agents
fi

# Recreate users for existing agent directories
for agent_dir in /data/agents/id_*; do
    if [ -d "$agent_dir" ]; then
        AGENT_ID=$(basename "$agent_dir")

        # Skip if user already exists
        if id "$AGENT_ID" &>/dev/null; then
            continue
        fi

        # Create user for this agent
        useradd -d "/data/agents/$AGENT_ID" -s /bin/sh -G agents "$AGENT_ID"
        usermod -p '' "$AGENT_ID"  # Unlock account

        # Fix ownership
        chown -R "$AGENT_ID:$AGENT_ID" "$agent_dir"

        echo "[console] Restored agent user: $AGENT_ID"
    fi
done

echo "[console] Agent restoration complete"