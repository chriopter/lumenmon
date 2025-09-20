#!/bin/bash
# Lumenmon Agent - Ultra KISS Edition
set -euo pipefail

# Handle show-key
[ "${1:-}" = "--show-key" ] && exec core/setup/identity.sh --show-only

# Set up environment
export CONSOLE_HOST="${CONSOLE_HOST:-console}"
export CONSOLE_PORT="${CONSOLE_PORT:-22}"
export SSH_SOCKET="/tmp/lumenmon.sock"
export PULSE="1" BREATHE="60" CYCLE="300" REPORT="3600"

echo "[agent] Starting Lumenmon Agent"

# Cleanup on exit
cleanup() {
  echo "[agent] Shutting down..."
  jobs -p | xargs -r kill 2>/dev/null || true
  [ -S "$SSH_SOCKET" ] && ssh -S "$SSH_SOCKET" -O exit "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Run components
source core/setup/identity.sh        # Sets AGENT_USER and SSH_KEY
source core/connection/tunnel.sh     # Establishes connection
source core/connection/collectors.sh # Starts collectors
exec core/connection/watchdog.sh     # Monitor and reconnect

