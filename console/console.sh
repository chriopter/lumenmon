#!/bin/bash
# Lumenmon Console - Ultra KISS Edition
# Receives metrics via SSH, stores in tmpfs, displays in TUI

set -euo pipefail

# Configuration
DATA_DIR="/var/lib/lumenmon/hot"

# Startup
echo "[console] Starting Lumenmon Console"

# Setup tmpfs storage
echo "[console] Setting up tmpfs storage..."
mkdir -p "$DATA_DIR/latest"
mkdir -p "$DATA_DIR/ring"
chmod -R 777 "$DATA_DIR"

# Start SSH server
echo "[console] Starting SSH server..."
ssh/sshd.sh

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