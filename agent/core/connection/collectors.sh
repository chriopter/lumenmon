#!/bin/bash
# Starts all metric collector scripts in collectors/generic/ directory as background processes.
# Each collector runs independently and publishes via mosquitto_pub.
set -euo pipefail

# LUMENMON_HOME must be set by agent.sh before sourcing
: ${LUMENMON_HOME:?LUMENMON_HOME not set}

# Start all generic collectors
echo "[agent] Starting collectors:"
for collector in "$LUMENMON_HOME/collectors/generic/"*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)

        # Extract RHYTHM from collector script
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