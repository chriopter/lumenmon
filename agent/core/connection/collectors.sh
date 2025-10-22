#!/bin/bash
# Starts all metric collector scripts in collectors/generic/ directory as background processes.
# Each collector runs independently and sends data through the established MQTT connection.
set -euo pipefail

# Variables already exported by agent.sh before sourcing this script
# Start all generic collectors
echo "[agent] Starting collectors:"
for collector in collectors/generic/*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)

        # Extract RHYTHM from collector script (BusyBox-compatible grep)
        # Docker container uses Alpine Linux with BusyBox grep which doesn't support -P (Perl regex)
        # This applies to ALL installations regardless of host OS, since the container is always Alpine
        # Solution: Use POSIX-compatible grep -o with cut instead of grep -oP with \K lookbehind
        rhythm=$(grep -o '^RHYTHM="[^"]*"' "$collector" 2>/dev/null | cut -d'"' -f2 || echo "")

        # Display with timing info
        if [ -n "$rhythm" ]; then
            timing="${!rhythm:-unknown}"
            echo "  - $name ($rhythm: ${timing}s)"
        else
            echo "  - $name"
        fi

        # Start collector in background (log errors to debug file)
        "$collector" 2>/tmp/collector_${name}.log &
    fi
done

echo "[agent] All collectors running. Press Ctrl+C to stop."