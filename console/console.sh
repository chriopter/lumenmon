#!/bin/bash
# Main Rails console entry point with MQTT broker and reverse proxy.
# Starts MQTT broker, MQTT ingest, Rails, and Caddy as one container service.
set -euo pipefail

echo "[console] Starting Lumenmon Rails Console"

core/setup/init_db.sh
core/setup/init_mqtt_cert.sh

mkdir -p /data/mqtt
if [ ! -f /data/mqtt/passwd ]; then
    touch /data/mqtt/passwd
fi

if [ -f /data/mqtt/server.crt ]; then
    chown mosquitto:mosquitto /data/mqtt/server.crt /data/mqtt/server.key
fi

echo "[console] Preparing Rails database..."
bundle exec rails db:prepare

echo "[console] Starting Mosquitto MQTT broker..."
mosquitto -c /app/config/mosquitto.conf 2>&1 | sed 's/^/[mosquitto] /' &
MOSQUITTO_PID=$!
sleep 2

echo "[console] Starting Ruby MQTT ingest..."
bundle exec ruby /app/script/mqtt_ingest.rb 2>&1 | sed 's/^/[mqtt-ingest] /' &
MQTT_INGEST_PID=$!

echo "[console] Starting Rails..."
bundle exec rails server -b 127.0.0.1 -p 5000 2>&1 | sed 's/^/[rails] /' &
RAILS_PID=$!
sleep 2

echo "[console] Starting Caddy..."
caddy run --config /etc/caddy/Caddyfile 2>&1 | sed 's/^/[caddy] /' &
CADDY_PID=$!

echo "[console] ======================================"
echo "[console] Lumenmon Rails Console Ready"
echo "[console] ======================================"
echo "[console] Console Host: ${CONSOLE_HOST:-localhost}"
echo "[console] MQTT Broker: lumenmon-console:8884 (TLS)"
echo "[console] Web Interface: Port 8080 (HTTP), 8443 (HTTPS)"
echo "[console] Database: ${LUMENMON_DB_PATH:-/data/lumenmon.sqlite3}"
echo "[console] Access WebTUI: https://localhost:8443 or http://localhost:8080"

terminate() {
    echo "[console] Stopping services..."
    kill "$CADDY_PID" "$RAILS_PID" "$MQTT_INGEST_PID" "$MOSQUITTO_PID" 2>/dev/null || true
    wait "$CADDY_PID" "$RAILS_PID" "$MQTT_INGEST_PID" "$MOSQUITTO_PID" 2>/dev/null || true
}

trap terminate TERM INT

wait -n "$CADDY_PID" "$RAILS_PID" "$MQTT_INGEST_PID" "$MOSQUITTO_PID"
STATUS=$?
terminate
exit "$STATUS"
