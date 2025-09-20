#!/bin/bash
# Establish SSH tunnel to console

set -euo pipefail

# Clean up any existing socket
[ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

# Wait for console
echo "[agent] Connecting to $CONSOLE_HOST:$CONSOLE_PORT..."
while ! nc -z "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null; do
    sleep 2
done

# Open SSH tunnel directly (no registration)
echo "[agent] Opening SSH tunnel as $AGENT_USER..."
ssh -M -N -f \
    -S "$SSH_SOCKET" \
    -i "$SSH_KEY" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=30 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o PreferredAuthentications=publickey \
    -o PasswordAuthentication=no \
    -p "$CONSOLE_PORT" \
    "$AGENT_USER@$CONSOLE_HOST"

# Verify connection
if ! ssh -S "$SSH_SOCKET" -O check "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null; then
    echo "[agent] ERROR: SSH connection failed"
    echo "[agent] Make sure agent is added to console with: ./add_agent.sh"
    exit 1
fi

echo "[agent] SSH tunnel established"