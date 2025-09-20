#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
# Receives metrics via SSH, stores persistently, displays in TUI

set -euo pipefail

# Configuration
DATA_DIR="/data/agents"

# Startup
echo "[console] Starting Lumenmon Console"

# Setup data directories
echo "[console] Setting up data storage..."
mkdir -p "$DATA_DIR"

# Start SSH server with authentication
echo "[console] Starting SSH authentication server..."
auth/sshd.sh

# Wait for SSH to be ready
sleep 2

# Show info
echo "[console] ======================================"
echo "[console] Console ready to receive agent data"
echo "[console] ======================================"
echo "[console]"
echo "[console] View TUI:"
echo "[console]   python3 tui/tui.py"
echo "[console]"
echo "[console] Skip animation:"
echo "[console]   SKIP_ANIMATION=1 python3 tui/tui.py"
echo "[console]"
echo "[console] Container running. Press Ctrl+C to stop."

# Keep running
tail -f /dev/null