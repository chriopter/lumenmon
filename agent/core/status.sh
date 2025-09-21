#!/bin/sh
# Agent status - clean formatted output

# Check if we have console config from environment
if [ -z "$CONSOLE_HOST" ]; then
    echo "Agent: Not configured"
    exit
fi

# Connection status
if pgrep -f "ssh.*collector" >/dev/null; then
    if [ -f /tmp/last_metric ]; then
        TIME=$(tail -1 /tmp/last_metric | cut -d' ' -f1 | cut -dT -f2 | cut -d. -f1)
        STATUS="Connected to $CONSOLE_HOST:${CONSOLE_PORT:-22} (last: $TIME)"
    else
        STATUS="Connected to $CONSOLE_HOST:${CONSOLE_PORT:-22} (no data yet)"
    fi
else
    # Check if reachable
    if nc -zw1 "$CONSOLE_HOST" "${CONSOLE_PORT:-22}" 2>/dev/null; then
        STATUS="Disconnected (console reachable at $CONSOLE_HOST:${CONSOLE_PORT:-22})"
    else
        STATUS="Disconnected (cannot reach $CONSOLE_HOST:${CONSOLE_PORT:-22})"
    fi
fi

echo "Agent: $STATUS"