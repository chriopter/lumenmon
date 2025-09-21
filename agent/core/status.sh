#!/bin/sh
# Agent status

# Check if sending data
if pgrep -f "ssh.*collector" >/dev/null 2>&1; then
    # Get last metric timestamp
    LAST=$(tail -1 /tmp/last_metric 2>/dev/null | cut -d' ' -f1)
    [ -n "$LAST" ] && echo "Agent: Connected (last: $LAST)" || echo "Agent: Connected"
else
    echo "Agent: Not connected"
fi