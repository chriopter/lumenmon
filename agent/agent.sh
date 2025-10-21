#!/bin/bash
# Main agent entry point that establishes SSH tunnel and starts metric collectors.
# Runs identity setup, tunnel connection, collectors, and watchdog. Sourced by Docker CMD.
set -euo pipefail

# Handle show-key
[ "${1:-}" = "--show-key" ] && exec core/setup/identity.sh --show-only

# Set up environment
# Connection details come from Docker environment variables set via .env file
CONSOLE_HOST="${CONSOLE_HOST:-console}"
CONSOLE_PORT="${CONSOLE_PORT:-22}"
SSH_SOCKET="/tmp/lumenmon.sock"
PULSE="1"
BREATHE="10"
CYCLE="60"
REPORT="3600"

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

# Export variables needed by collectors (background jobs need explicit export)
export AGENT_USER SSH_KEY CONSOLE_HOST CONSOLE_PORT SSH_SOCKET
export PULSE BREATHE CYCLE REPORT

# Verify all required variables are set before starting collectors
# This catches configuration errors early rather than letting collectors crash
: ${PULSE:?PULSE not set} ${BREATHE:?BREATHE not set} ${CYCLE:?CYCLE not set} ${REPORT:?REPORT not set}
: ${AGENT_USER:?AGENT_USER not set} ${SSH_SOCKET:?SSH_SOCKET not set}
: ${CONSOLE_HOST:?CONSOLE_HOST not set} ${CONSOLE_PORT:?CONSOLE_PORT not set}

source core/connection/tunnel.sh     # Establishes connection
source core/connection/collectors.sh # Starts collectors (background jobs)
core/connection/watchdog.sh          # Monitor and reconnect (blocks forever)

