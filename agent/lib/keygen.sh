#!/bin/bash
# Generate SSH key and calculate fingerprint

set -euo pipefail

# Check for SSH key - generate if needed
SSH_KEY="/home/metrics/.ssh/id_ed25519"

# Also check for legacy RSA key
if [ -f "/home/metrics/.ssh/id_rsa" ] && [ ! -f "$SSH_KEY" ]; then
    SSH_KEY="/home/metrics/.ssh/id_rsa"
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "[agent] Generating SSH keypair..."
    SSH_KEY="/home/metrics/.ssh/id_ed25519"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""

    # Calculate and save fingerprint with id_ prefix
    FINGERPRINT="id_$(ssh-keygen -lf "${SSH_KEY}.pub" | awk '{print $2}' | cut -d: -f2 | tr '/+' '_-' | cut -c1-14)"
    echo "$FINGERPRINT" > "${SSH_KEY}.username"

    echo "[agent] ======================================"
    echo "[agent] Agent identity: $FINGERPRINT"
    echo "[agent] Public key (add to console):"
    echo "[agent] ======================================"
    cat "${SSH_KEY}.pub"
    echo "[agent] ======================================"
    echo "[agent] Configure agent with: AGENT_USER=$FINGERPRINT"
    echo "[agent] ======================================"
fi

# Read saved username
if [ -f "${SSH_KEY}.username" ]; then
    AGENT_USER=$(cat "${SSH_KEY}.username")
else
    # For existing keys, calculate fingerprint
    FINGERPRINT="id_$(ssh-keygen -lf "${SSH_KEY}.pub" | awk '{print $2}' | cut -d: -f2 | tr '/+' '_-' | cut -c1-14)"
    echo "$FINGERPRINT" > "${SSH_KEY}.username"
    AGENT_USER="$FINGERPRINT"
    echo "[agent] Calculated identity: $AGENT_USER"
fi

# Export for other scripts
export SSH_KEY AGENT_USER