#!/bin/bash
# Main console entry point that initializes directories and starts MQTT services.
# Starts MQTT-to-SQLite bridge, Flask API, and Caddy web server. Sourced by Docker CMD.
set -euo pipefail

echo "[console] Starting Lumenmon Console"

# Setup
source core/setup/init_db.sh        # Initialize SQLite database
core/setup/init_mqtt_cert.sh        # Generate MQTT TLS certificate

# Start Mosquitto MQTT broker
echo "[console] Starting Mosquitto MQTT broker..."
mkdir -p /data/mqtt
# Create empty password file if it doesn't exist
if [ ! -f "/data/mqtt/passwd" ]; then
    touch /data/mqtt/passwd
fi
# Fix cert permissions for mosquitto user
if [ -f "/data/mqtt/server.crt" ]; then
    chown mosquitto:mosquitto /data/mqtt/server.crt /data/mqtt/server.key
fi
mosquitto -c /app/config/mosquitto.conf 2>&1 | sed 's/^/[mosquitto] /' &
sleep 2

# Start MQTT-to-SQLite bridge
echo "[console] Starting MQTT-to-SQLite bridge..."
python3 /app/core/mqtt/mqtt_to_sqlite.py 2>&1 | sed 's/^/[mqtt-sqlite] /' &
sleep 1

# Start Flask API server
echo "[console] Starting Flask API server..."
cd /app/web/app && python3 app.py 2>&1 | sed 's/^/[flask] /' &
sleep 1

# Start Caddy web server
echo "[console] Starting Caddy web server..."
caddy start --config /etc/caddy/Caddyfile 2>&1 | sed 's/^/[caddy] /' &

# Start daily cleanup task (runs at 3 AM)
echo "[console] Starting daily cleanup task..."
(
  while true; do
    # Wait until 3 AM
    CURRENT_HOUR=$(date +%H)
    CURRENT_MIN=$(date +%M)

    # If it's 3 AM (03:00-03:59), run cleanup
    if [ "$CURRENT_HOUR" -eq 3 ] && [ "$CURRENT_MIN" -lt 5 ]; then
      /app/core/mqtt/cleanup_old_data.sh 2>&1 | sed 's/^/[cleanup] /'
      # Sleep 1 hour to avoid running multiple times
      sleep 3600
    else
      # Check every 5 minutes
      sleep 300
    fi
  done
) &

# Display console info
echo "[console] ======================================"
echo "[console] Lumenmon Console Ready"
echo "[console] ======================================"
echo "[console] Console Host: ${CONSOLE_HOST:-localhost}"
echo "[console] MQTT Broker: lumenmon-console:8884 (TLS)"
echo "[console] MQTT Internal: localhost:1883"
echo "[console] MQTT WebSocket: Port 9001 (for web UI)"
echo "[console] Web Interface: Port 80 (mapped to host 8080)"
echo "[console] Database: /data/metrics.db"
echo "[console] Data Retention: 7 days (cleanup runs daily at 3 AM)"
echo "[console]"
echo "[console] Access WebTUI: http://localhost:8080"
echo "[console]"
echo "[console] Container running. Press Ctrl+C to stop."

# Keep running
tail -f /dev/null
