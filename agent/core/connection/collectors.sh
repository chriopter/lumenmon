#!/bin/bash
# Starts all metric collector scripts in collectors/ directory as background processes.
# Each collector runs independently and sends data through the established SSH tunnel.
set -euo pipefail

# Ensure variables are exported for background jobs
export PULSE BREATHE CYCLE REPORT
export SSH_SOCKET AGENT_USER CONSOLE_HOST CONSOLE_PORT

# Start collectors
echo "[agent] Starting collectors:"
for collector in collectors/*/*.sh; do
    if [ -f "$collector" ]; then
        name=$(basename "$collector" .sh)
        case "$name" in
            cpu)      echo "  - $name (PULSE: ${PULSE}s)" ;;
            memory)   echo "  - $name (BREATHE: ${BREATHE}s)" ;;
            disk)     echo "  - $name (CYCLE: ${CYCLE}s)" ;;
            lumenmon) echo "  - $name (REPORT: ${REPORT}s)" ;;
            *)        echo "  - $name" ;;
        esac
        "$collector" 2>/dev/null &
    fi
done

echo "[agent] All collectors running. Press Ctrl+C to stop."