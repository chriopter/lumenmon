#!/bin/bash
# Lumenmon Agent - Ultra KISS Edition
set -euo pipefail

# Handle show-key
[ "${1:-}" = "--show-key" ] && exec app/showkey.sh

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
source app/keygen.sh  # Sets AGENT_USER and SSH_KEY
source app/tunnel.sh  # Establishes connection
source app/startup.sh # Starts collectors
exec app/heartbeat.sh # Run forever

