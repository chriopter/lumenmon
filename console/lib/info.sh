#!/bin/bash
# Display usage information

set -euo pipefail

# Count registered agents
AGENT_COUNT=$(find /data/agents -maxdepth 1 -type d -name "id_*" 2>/dev/null | wc -l)

echo "[console] ======================================"
echo "[console] Lumenmon Console Ready"
echo "[console] ======================================"
echo "[console] SSH Server: Port 22 (mapped to host 2345)"
echo "[console] Data Directory: /data/agents/"
echo "[console] Registered agents: $AGENT_COUNT"
echo "[console]"
echo "[console] View TUI:"
echo "[console]   python3 tui/tui.py"
echo "[console]"
echo "[console] Skip animation:"
echo "[console]   SKIP_ANIMATION=1 python3 tui/tui.py"
echo "[console]"
echo "[console] Container running. Press Ctrl+C to stop."