#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
set -euo pipefail

echo "[console] Starting Lumenmon Console"

source lib/setup.sh        # Setup directories and restore agents
source lib/ssh_daemon.sh   # Start SSH daemon
source lib/info.sh         # Show usage info

# Keep running
tail -f /dev/null