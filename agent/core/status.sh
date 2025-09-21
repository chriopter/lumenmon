#!/bin/sh
# Agent status - clean formatted output

# Paths
CFG="/data/config/console"
KEY="/home/metrics/.ssh/id_ed25519"
RSA="/home/metrics/.ssh/id_rsa"

# Check if configured
if [ ! -f "$CFG" ]; then
    echo "Agent: Not configured"
    exit
fi

# Load config
. "$CFG"

# Connection status
if pgrep -f "ssh.*collector" >/dev/null; then
    if [ -f /tmp/last_metric ]; then
        TIME=$(tail -1 /tmp/last_metric | cut -d' ' -f1 | cut -dT -f2 | cut -d. -f1)
        STATUS="Connected to $CONSOLE_HOST:$CONSOLE_PORT (last: $TIME)"
    else
        STATUS="Connected to $CONSOLE_HOST:$CONSOLE_PORT (no data yet)"
    fi
else
    # Check if reachable
    if nc -zw1 "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null; then
        STATUS="Disconnected (console reachable at $CONSOLE_HOST:$CONSOLE_PORT)"
    else
        STATUS="Disconnected (cannot reach $CONSOLE_HOST:$CONSOLE_PORT)"
    fi
fi

echo "Agent: $STATUS"