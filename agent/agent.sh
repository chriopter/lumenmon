#!/bin/bash
# Lumenmon Agent - Ultra KISS Edition
# Opens ONE SSH connection, starts collectors, done!

set -euo pipefail

# Configuration
CONSOLE_HOST="${CONSOLE_HOST:-console}"
CONSOLE_PORT="${CONSOLE_PORT:-22}"
CONSOLE_USER="${CONSOLE_USER:-collector}"
AGENT_ID="${HOSTNAME:-$(hostname -s)}"
SSH_SOCKET="/tmp/lumenmon.sock"

# Natural Rhythms (centralized!)
PULSE="0.1"      # 10Hz - Rapid heartbeat
BREATHE="1"      # 1Hz - Steady breathing
CYCLE="60"       # 1/min - Full cycle
REPORT="3600"    # 1/hr - Status report

# Export everything for collectors to use
export CONSOLE_HOST CONSOLE_PORT CONSOLE_USER AGENT_ID SSH_SOCKET
export PULSE BREATHE CYCLE REPORT

echo "[agent] Starting Lumenmon Agent: $AGENT_ID"

# Clean up on exit
cleanup() {
    echo "[agent] Shutting down..."
    jobs -p | xargs -r kill 2>/dev/null || true
    [ -S "$SSH_SOCKET" ] && ssh -S "$SSH_SOCKET" -O exit "$CONSOLE_USER@$CONSOLE_HOST" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Wait for console to be reachable
echo "[agent] Waiting for console at $CONSOLE_HOST:$CONSOLE_PORT..."
while ! nc -z "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null; do
    sleep 2
done

# Open SSH ControlMaster connection (the highway!)
echo "[agent] Opening SSH multiplex connection..."
ssh -M -N -f \
    -S "$SSH_SOCKET" \
    -o ControlPersist=yes \
    -o ServerAliveInterval=30 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -p "$CONSOLE_PORT" \
    "$CONSOLE_USER@$CONSOLE_HOST"

# Verify connection
if ! ssh -S "$SSH_SOCKET" -O check "$CONSOLE_USER@$CONSOLE_HOST" 2>/dev/null; then
    echo "[agent] ERROR: Failed to establish SSH connection"
    exit 1
fi

echo "[agent] SSH multiplex established!"

# Start all collectors (they run their own loops)
for collector in collectors/*/*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)
        echo "[agent] Starting $name collector..."
        "$collector" &
    fi
done

echo "[agent] All collectors running. Press Ctrl+C to stop."

# Wait forever (collectors run in background)
wait