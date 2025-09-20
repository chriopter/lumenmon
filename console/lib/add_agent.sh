#!/bin/bash
# Add new agent - creates user and folder from public key

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 'ssh-ed25519 AAAA...'"
    exit 1
fi

PUBLIC_KEY="$1"

# Validate it's a valid SSH key
if ! echo "$PUBLIC_KEY" | ssh-keygen -lf - >/dev/null 2>&1; then
    echo "ERROR: Invalid SSH key"
    exit 1
fi

# Generate fingerprint with id_ prefix
FINGERPRINT="id_$(echo "$PUBLIC_KEY" | ssh-keygen -lf - | awk '{print $2}' | cut -d: -f2 | tr '/+' '_-' | cut -c1-14)"

# Check if already exists
if id "$FINGERPRINT" &>/dev/null; then
    echo "Agent already exists: $FINGERPRINT"
    exit 0
fi

# Ensure base directory exists
mkdir -p "/data/agents"

# Create Linux user with home directory in /data/agents
useradd -m -d "/data/agents/$FINGERPRINT" -s /bin/false "$FINGERPRINT"

# Setup SSH access (already in home)
mkdir -p "/data/agents/$FINGERPRINT/.ssh"
echo "$PUBLIC_KEY" > "/data/agents/$FINGERPRINT/.ssh/authorized_keys"
chown -R "$FINGERPRINT:$FINGERPRINT" "/data/agents/$FINGERPRINT"
chmod 700 "/data/agents/$FINGERPRINT" "/data/agents/$FINGERPRINT/.ssh"
chmod 600 "/data/agents/$FINGERPRINT/.ssh/authorized_keys"

# Log
echo "[$(date)] Added agent: $FINGERPRINT" >> /data/agents.log

echo "Agent ready: $FINGERPRINT"
echo "Configure agent with: AGENT_USER=$FINGERPRINT"