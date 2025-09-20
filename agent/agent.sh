#!/bin/bash
# Lumenmon Agent - Ultra KISS Edition
# One SSH tunnel, natural rhythms, simple collectors

set -euo pipefail

# Handle --show-key argument
if [ "${1:-}" = "--show-key" ]; then
    # Check for ED25519 key first, then RSA
    KEY_PATH="/home/metrics/.ssh/id_ed25519.pub"
    if [ ! -f "$KEY_PATH" ]; then
        KEY_PATH="/home/metrics/.ssh/id_rsa.pub"
    fi

    if [ -f "$KEY_PATH" ]; then
        echo "======================================"
        echo "Agent Public Key:"
        echo "======================================"
        cat "$KEY_PATH"
        echo "======================================"
    else
        echo "No SSH key found"
        echo "Run the agent first to generate a key"
    fi
    exit 0
fi

# Connection
CONSOLE_HOST="${CONSOLE_HOST:-console}"
CONSOLE_PORT="${CONSOLE_PORT:-22}"
CONSOLE_USER="${CONSOLE_USER:-collector}"
AGENT_ID="${HOSTNAME:-$(hostname -s)}"
SSH_SOCKET="/tmp/lumenmon.sock"

# Natural Rhythms
PULSE="0.1"      # 10Hz   - CPU monitoring
BREATHE="1"      # 1Hz    - Memory tracking
CYCLE="60"       # 1/min  - Disk usage
REPORT="3600"    # 1/hr   - System info

# Setup transport for collectors
LUMENMON_TRANSPORT="ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST '/app/ssh/receiver.sh --host $AGENT_ID' 2>/dev/null"

# Export for collectors
export CONSOLE_HOST CONSOLE_PORT CONSOLE_USER AGENT_ID SSH_SOCKET
export PULSE BREATHE CYCLE REPORT LUMENMON_TRANSPORT

# Startup
echo "[agent] Starting Lumenmon Agent: $AGENT_ID"

# Clean up any existing socket
[ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

# Cleanup handler
cleanup() {
    echo "[agent] Shutting down..."
    jobs -p | xargs -r kill 2>/dev/null || true
    [ -S "$SSH_SOCKET" ] && ssh -S "$SSH_SOCKET" -O exit "$CONSOLE_USER@$CONSOLE_HOST" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Check for SSH key (using ED25519 for shorter keys) - generate before connecting
SSH_KEY="/home/metrics/.ssh/id_ed25519"
# Also check for legacy RSA key
if [ -f "/home/metrics/.ssh/id_rsa" ] && [ ! -f "$SSH_KEY" ]; then
    SSH_KEY="/home/metrics/.ssh/id_rsa"
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "[agent] Generating SSH keypair (ED25519 for shorter keys)..."
    SSH_KEY="/home/metrics/.ssh/id_ed25519"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
    echo "[agent] ======================================"
    echo "[agent] Agent public key (add to console):"
    echo "[agent] ======================================"
    cat "${SSH_KEY}.pub"
    echo "[agent] ======================================"
    echo "[agent] Key saved to: ${SSH_KEY}.pub"
    echo "[agent] ======================================"
fi

# Wait for console
echo "[agent] Connecting to $CONSOLE_HOST:$CONSOLE_PORT..."
while ! nc -z "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null; do
    sleep 2
done

# Open SSH tunnel (single multiplexed connection) - Key-based auth
echo "[agent] Opening SSH tunnel..."
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
    "$CONSOLE_USER@$CONSOLE_HOST"

# Verify connection
if ! ssh -S "$SSH_SOCKET" -O check "$CONSOLE_USER@$CONSOLE_HOST" 2>/dev/null; then
    echo "[agent] ERROR: SSH connection failed"
    exit 1
fi

echo "[agent] SSH tunnel established"

# Start collectors
echo "[agent] Starting collectors:"
for collector in collectors/*/*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)
        case "$name" in
            cpu)      echo "  - $name (PULSE: ${PULSE}s)" ;;
            memory)   echo "  - $name (BREATHE: ${BREATHE}s)" ;;
            disk)     echo "  - $name (CYCLE: ${CYCLE}s)" ;;
            lumenmon) echo "  - $name (REPORT: ${REPORT}s)" ;;
            *)        echo "  - $name" ;;
        esac
        "$collector" 2>/dev/null &
    fi
done

echo "[agent] All collectors running. Press Ctrl+C to stop."

# Run forever with heartbeat
exec sh -c 'while true; do sleep 30; echo "[agent] ✓ Active - metrics flowing to '"$CONSOLE_HOST"'"; done'