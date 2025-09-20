#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
set -euo pipefail

echo "[console] Starting Lumenmon Console"

# Make scripts accessible from expected locations
chmod +x app/add_agent.sh app/gateway.sh 2>/dev/null || true
ln -sf /app/app/add_agent.sh /app/add_agent.sh 2>/dev/null || true
ln -sf /app/app/gateway.sh /app/gateway.sh 2>/dev/null || true

source app/setup.sh        # Setup directories
source app/ssh_daemon.sh   # Start SSH daemon
source app/info.sh         # Show usage info

# Keep running
tail -f /dev/null