#!/bin/bash
# Main console entry point that initializes directories, restores agents, and starts SSH server.
# Runs enrollment processor in background and displays console info. Sourced by Docker CMD.
set -euo pipefail

echo "[console] Starting Lumenmon Console"

# Setup
source core/setup/create_dirs.sh    # Create required directories
source core/setup/restore_users.sh  # Restore agent users

# Start services
source core/ingress/ssh_daemon.sh   # Start SSH daemon

# Start Flask API server
echo "[console] Starting Flask API server..."
cd /app/web/readers && python3 app.py 2>&1 | sed 's/^/[flask] /' &
sleep 1

# Start Caddy web server
echo "[console] Starting Caddy web server..."
caddy start --config /etc/caddy/Caddyfile 2>&1 | sed 's/^/[caddy] /' &

# Display console info
AGENT_COUNT=$(find /data/agents -maxdepth 1 -type d -name "id_*" 2>/dev/null | wc -l)

echo "[console] ======================================"
echo "[console] Lumenmon Console Ready"
echo "[console] ======================================"
echo "[console] Console Host: ${CONSOLE_HOST:-localhost}"
echo "[console] SSH Server: Port 22 (mapped to host 2345)"
echo "[console] Web Interface: Port 80 (mapped to host 8080)"
echo "[console] Data Directory: /data/agents/"
echo "[console] Registered agents: $AGENT_COUNT"
echo "[console]"
echo "[console] View TUI:"
echo "[console]   /app/tui.sh"
echo "[console]"
echo "[console] Skip animation (if implemented):"
echo "[console]   SKIP_ANIMATION=1 /app/tui.sh"
echo "[console]"
echo "[console] Container running. Press Ctrl+C to stop."

# Process registration queue every 5 seconds
echo "[console] Starting registration processor..."
while true; do
    /app/core/enrollment/agent_enroll.sh
    sleep 5
done &

# Keep running
tail -f /dev/null
