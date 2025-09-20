#!/bin/bash
# Monitor SSH tunnel and reconnect if needed

set -euo pipefail

echo "[agent] Starting connection monitor"

# Monitor loop
while true; do
    sleep 30

    # Check if SSH socket exists and is responsive
    if [ -S "$SSH_SOCKET" ]; then
        if ssh -S "$SSH_SOCKET" -O check "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null; then
            echo "[agent] ✓ Active - metrics flowing to $CONSOLE_HOST"
        else
            echo "[agent] ⚠ SSH tunnel check failed - reconnecting..."

            # Kill collectors
            jobs -p | xargs -r kill 2>/dev/null || true

            # Clean up socket
            [ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

            # Re-establish tunnel
            source /app/lib/tunnel.sh

            # Restart collectors
            source /app/lib/startup.sh

            echo "[agent] ✓ Reconnected and collectors restarted"
        fi
    else
        echo "[agent] ⚠ SSH socket missing - reconnecting..."

        # Kill collectors
        jobs -p | xargs -r kill 2>/dev/null || true

        # Re-establish tunnel
        source /app/lib/tunnel.sh

        # Restart collectors
        source /app/lib/startup.sh

        echo "[agent] ✓ Reconnected and collectors restarted"
    fi
done