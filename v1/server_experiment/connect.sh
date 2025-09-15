#!/bin/bash
# Connect to the Lumenmon TUI

echo "Connecting to Lumenmon TUI..."
echo "Use arrow keys to navigate, Enter to select, Ctrl+C to exit"
echo ""

# Connect to the running container's TTY
docker exec -it lumenmon-tui /app/scripts/tui.sh