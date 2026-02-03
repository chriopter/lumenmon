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

# Start SMTP receiver
echo "[console] Starting SMTP receiver..."
python3 /app/core/smtp/smtp_receiver.py 2>&1 | sed 's/^/[smtp] /' &
sleep 1

# Display console info
echo "[console] ======================================"
echo "[console] Lumenmon Console Ready"
echo "[console] ======================================"
echo "[console] Console Host: ${CONSOLE_HOST:-localhost}"
echo "[console] MQTT Broker: lumenmon-console:8884 (TLS)"
echo "[console] MQTT Internal: localhost:1883"
echo "[console] SMTP Receiver: Port 25"
echo "[console] Web Interface: Port 8080 (HTTP), 8443 (HTTPS)"
echo "[console] Database: /data/metrics.db"
echo "[console] Mail: Via SMTP (port 25) or MQTT (agent spool reader)"
echo "[console]"
echo "[console] Access WebTUI: https://localhost:8443 (or http://localhost:8080)"
echo "[console]"
echo "[console] Container running. Press Ctrl+C to stop."

# Keep running
tail -f /dev/null
