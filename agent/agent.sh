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
SSH_SOCKET="/tmp/lumenmon.sock"

# Natural Rhythms
PULSE="0.1"      # 10Hz   - CPU monitoring
BREATHE="1"      # 1Hz    - Memory tracking
CYCLE="60"       # 1/min  - Disk usage
REPORT="3600"    # 1/hr   - System info

# Startup
echo "[agent] Starting Lumenmon Agent"

# Clean up any existing socket
[ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

# Cleanup handler
cleanup() {
    echo "[agent] Shutting down..."
    jobs -p | xargs -r kill 2>/dev/null || true
    [ -S "$SSH_SOCKET" ] && ssh -S "$SSH_SOCKET" -O exit "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

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

# Export for collectors
export CONSOLE_HOST CONSOLE_PORT AGENT_USER SSH_SOCKET
export PULSE BREATHE CYCLE REPORT

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