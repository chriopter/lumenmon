#!/bin/bash
# Main agent entry point that starts metric collectors publishing to MQTT.
# Checks for credentials, starts collectors. Requires registration via invite URL first.
set -euo pipefail
export LC_ALL=C  # Consistent decimal/text output across locales

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LUMENMON_HOME="${LUMENMON_HOME:-$SCRIPT_DIR}"
export LUMENMON_DATA="${LUMENMON_DATA:-$LUMENMON_HOME/data}"

echo "[agent] Starting Lumenmon Agent"

# Check if agent is registered (has MQTT credentials)
MQTT_DATA_DIR="$LUMENMON_DATA/mqtt"
if [ ! -f "$MQTT_DATA_DIR/username" ] || [ ! -f "$MQTT_DATA_DIR/password" ] || [ ! -f "$MQTT_DATA_DIR/host" ]; then
    echo "[agent] Not registered. Run: lumenmon-agent register '<invite_url>'"
    exit 1
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
BREATHE="60"
CYCLE="300"
REPORT="3600"

echo "[agent] ✓ Agent registered: $AGENT_ID"
echo "[agent] MQTT Broker: ${MQTT_HOST}:${MQTT_PORT} (TLS)"

# Cleanup on exit
cleanup() {
  echo "[agent] Shutting down..."
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Export variables needed by collectors
export AGENT_ID MQTT_HOST MQTT_PORT MQTT_USERNAME MQTT_PASSWORD
export PULSE BREATHE CYCLE REPORT

# Verify all required variables are set
: ${PULSE:?PULSE not set} ${BREATHE:?BREATHE not set} ${CYCLE:?CYCLE not set} ${REPORT:?REPORT not set}
: ${AGENT_ID:?AGENT_ID not set} ${MQTT_HOST:?MQTT_HOST not set} ${MQTT_PORT:?MQTT_PORT not set}
: ${MQTT_USERNAME:?MQTT_USERNAME not set} ${MQTT_PASSWORD:?MQTT_PASSWORD not set}

# Test MQTT connection before starting collectors
echo "[agent] Testing MQTT connection..."
MQTT_CERT="$MQTT_DATA_DIR/server.crt"
for i in 1 2 3; do
    if mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
        --cafile "$MQTT_CERT" -t "metrics/$AGENT_ID/startup" -m '{"value":1,"type":"INTEGER","interval":0}' 2>/dev/null; then
        echo "[agent] ✓ MQTT connection verified"
        break
    fi
    if [ "$i" -lt 3 ]; then
        echo "[agent] Connection attempt $i failed, retrying..."
        sleep 2
    else
        echo "[agent] WARNING: Could not verify MQTT connection, starting anyway"
    fi
done

# Start collectors (background jobs)
cd "$LUMENMON_HOME"
source "$LUMENMON_HOME/core/connection/collectors.sh"

echo "[agent] All collectors started."

# Keep running
tail -f /dev/null
