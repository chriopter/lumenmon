#!/bin/sh
# Agent status - technical details

# Check container basics
echo -n "Agent: "

# Container running (implicit since this script is running)
echo -n "Container ✓ | "

# Environment config
if [ -n "$CONSOLE_HOST" ]; then
    echo -n "Config: $CONSOLE_HOST:${CONSOLE_PORT:-22} | "
else
    echo "Config: ✗ Missing"
    exit
fi

# Network reachability
if nc -zw1 "$CONSOLE_HOST" "${CONSOLE_PORT:-22}" 2>/dev/null; then
    echo -n "Network ✓ | "
else
    echo -n "Network ✗ | "
fi

# SSH processes (check for actual SSH connection)
if pgrep -f "ssh.*$CONSOLE_HOST" >/dev/null || pgrep -f "ssh.*id_" >/dev/null; then
    echo -n "SSH ✓ | "

    # Count collector processes
    COLLECTORS=$(pgrep -f "collector" | wc -l)
    [ $COLLECTORS -gt 0 ] && echo -n "Collectors: $COLLECTORS | "
else
    echo -n "SSH ✗ | "
fi

# Metrics activity
if [ -f /tmp/last_metric ]; then
    TIME=$(tail -1 /tmp/last_metric 2>/dev/null | cut -d' ' -f1 | cut -dT -f2 | cut -d. -f1)
    [ -n "$TIME" ] && echo "Last metric: $TIME" || echo "Metrics: idle"
else
    # Check for any metric files
    if ls /tmp/*.tsv 2>/dev/null | head -1 >/dev/null; then
        echo "Metrics: buffered"
    else
        echo "Metrics: none"
    fi
fi