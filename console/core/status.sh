#!/bin/sh
# Console status - clean formatted output

# Paths
A="/data/agents"
K="/data/ssh/ssh_host_ed25519_key"

# SSH status
if pgrep -f sshd >/dev/null; then
    PORT="${CONSOLE_PORT:-2345}"
    SSH="SSH on :$PORT"
else
    SSH="SSH down"
fi

# Agent count
if [ -d "$A" ]; then
    TOTAL=$(ls "$A" 2>/dev/null | wc -l)
    if [ $TOTAL -gt 0 ]; then
        # Count active (data within last 60s)
        ACTIVE=0
        for D in "$A"/*; do
            [ -d "$D" ] || continue
            H="/var/lib/lumenmon/hot/$(basename "$D")"
            [ -d "$H" ] && find "$H" -name "*.tsv" -mmin -1 2>/dev/null | grep -q . && ACTIVE=$((ACTIVE+1))
        done
        AGENTS="$TOTAL agents, $ACTIVE active"
    else
        AGENTS="No agents"
    fi
else
    AGENTS="No agents"
fi

echo "Console: $SSH | $AGENTS"