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

# Keep trying to connect until successful
echo "[agent] Waiting for registration on $CONSOLE_HOST:$CONSOLE_PORT..."
echo "[agent] Add this agent via TUI using the public key shown above"

while true; do
    # Try to open SSH tunnel
    if ssh -M -N -f \
        -S "$SSH_SOCKET" \
        -i "$SSH_KEY" \
        -o ControlPersist=yes \
        -o ServerAliveInterval=30 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=publickey \
        -o PasswordAuthentication=no \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -p "$CONSOLE_PORT" \
        "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null; then

        # Verify connection
        if ssh -S "$SSH_SOCKET" -O check "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null; then
            echo "[agent] SSH tunnel established!"
            break
        fi
    fi

    # Clean up failed socket
    [ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

    echo "[agent] Not registered yet. Retrying in 10 seconds..."
    sleep 10
done