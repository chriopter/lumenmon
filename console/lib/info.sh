#!/bin/bash
# Display usage information

set -euo pipefail

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