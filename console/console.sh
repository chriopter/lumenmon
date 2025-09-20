#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
set -euo pipefail

echo "[console] Starting Lumenmon Console"
source app/setup.sh        # Setup directories
source app/ssh_daemon.sh   # Start SSH daemon
source app/info.sh         # Show usage info

# Keep running
tail -f /dev/null