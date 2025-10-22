#!/bin/bash
# Main agent entry point that starts metric collectors publishing to MQTT.
# Checks for credentials, starts collectors. Requires registration via invite URL first.
set -euo pipefail

echo "[agent] Starting Lumenmon Agent (MQTT mode)"

# Check if agent is registered (has MQTT credentials)
MQTT_DATA_DIR="/data/mqtt"
if [ ! -f "$MQTT_DATA_DIR/username" ] || [ ! -f "$MQTT_DATA_DIR/password" ] || [ ! -f "$MQTT_DATA_DIR/host" ]; then
    echo "[agent] ERROR: Agent not registered!"
    echo "[agent]"
    echo "[agent] To register this agent:"
    echo "[agent]   1. Get an invite URL from your console (run: lumenmon invite)"
    echo "[agent]   2. Register: docker exec lumenmon-agent /app/core/setup/register.sh '<invite_url>'"
    echo "[agent]"
    echo "[agent] Container will keep running. Register when ready."

    # Keep container running so user can exec register command
    tail -f /dev/null
fi

# Load credentials
MQTT_USERNAME=$(cat "$MQTT_DATA_DIR/username")
MQTT_PASSWORD=$(cat "$MQTT_DATA_DIR/password")
MQTT_HOST=$(cat "$MQTT_DATA_DIR/host")
MQTT_PORT="8884"  # TLS port

# Generate or load agent ID (from credentials)
AGENT_ID="$MQTT_USERNAME"

# Collector timing
PULSE="1"
BREATHE="10"
CYCLE="60"
REPORT="3600"

echo "[agent] ✓ Agent registered: $AGENT_ID"
echo "[agent] MQTT Broker: ${MQTT_HOST}:${MQTT_PORT} (TLS)"

# Cleanup on exit
cleanup() {
  echo "[agent] Shutting down..."

  # Kill all collector processes
  jobs -p | xargs -r kill 2>/dev/null || true

  # Clean up Unix socket
  rm -f /tmp/mqtt.sock 2>/dev/null || true

  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Export variables needed by collectors (background jobs need explicit export)
export AGENT_ID MQTT_HOST MQTT_PORT MQTT_USERNAME MQTT_PASSWORD
export PULSE BREATHE CYCLE REPORT

# Verify all required variables are set
: ${PULSE:?PULSE not set} ${BREATHE:?BREATHE not set} ${CYCLE:?CYCLE not set} ${REPORT:?REPORT not set}
: ${AGENT_ID:?AGENT_ID not set} ${MQTT_HOST:?MQTT_HOST not set} ${MQTT_PORT:?MQTT_PORT not set}
: ${MQTT_USERNAME:?MQTT_USERNAME not set} ${MQTT_PASSWORD:?MQTT_PASSWORD not set}

# Start Python MQTT publisher daemon (single persistent connection)
echo "[agent] Starting MQTT publisher daemon..."
python3 /app/core/mqtt/mqtt_publisher.py 2>&1 | sed 's/^/[mqtt-pub] /' &
sleep 2  # Wait for Unix socket to be ready

# Start collectors (background jobs)
source core/connection/collectors.sh

echo "[agent] All collectors started. MQTT handles reconnection automatically."

# Keep running (no watchdog needed - MQTT client handles reconnection)
tail -f /dev/null
