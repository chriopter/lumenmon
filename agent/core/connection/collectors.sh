#!/bin/bash
# Starts all metric collector scripts in collectors/generic/ directory as background processes.
# Each collector runs independently and sends data through the established SSH tunnel.
set -euo pipefail

# Ensure variables are exported for background jobs
export PULSE BREATHE CYCLE REPORT
export SSH_SOCKET AGENT_USER CONSOLE_HOST CONSOLE_PORT

# Start all generic collectors
echo "[agent] Starting collectors:"
for collector in collectors/generic/*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)

        # Extract RHYTHM from collector script
        rhythm=$(grep -oP '^RHYTHM="\K[^"]+' "$collector" 2>/dev/null || echo "")

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