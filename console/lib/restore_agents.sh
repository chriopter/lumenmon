#!/bin/bash
# Restore agent users from persistent directories
set -euo pipefail

echo "[console] Restoring agent users from /data/agents/..."

# Groups already exist from Docker build

# Recreate users for existing agent directories
for agent_dir in /data/agents/id_*; do
    if [ -d "$agent_dir" ]; then
        AGENT_ID=$(basename "$agent_dir")

        # Skip if user already exists
        if id "$AGENT_ID" &>/dev/null; then
            echo "[console] Agent user already exists: $AGENT_ID"
            continue
        fi

        # Create user for this agent
        echo "[console] Recreating agent user: $AGENT_ID"
        useradd -d "/data/agents/$AGENT_ID" -s /bin/sh -G agents "$AGENT_ID"
        usermod -p '' "$AGENT_ID"  # Unlock account

        # Fix ownership
        chown -R "$AGENT_ID:$AGENT_ID" "$agent_dir"

    fi
done

echo "[console] Agent restoration complete"