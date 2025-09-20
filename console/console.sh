#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
set -euo pipefail

echo "[console] Starting Lumenmon Console"

source lib/setup.sh        # Setup directories and restore agents
source lib/ssh_daemon.sh   # Start SSH daemon
source lib/info.sh         # Show usage info

# Process registration queue every 5 seconds
echo "[console] Starting registration processor..."
while true; do
    /app/lib/process_registrations.sh
    sleep 5
done &

# Keep running
tail -f /dev/null