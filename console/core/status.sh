#!/bin/bash
# Prints a compact status summary for the Rails console container.
# Used by the lumenmon CLI and deployment smoke checks.
set -euo pipefail

rails_status="down"
mqtt_status="down"
caddy_status="down"

if curl -fsS http://127.0.0.1:5000/health >/dev/null 2>&1; then
    rails_status="online"
fi

if nc -z 127.0.0.1 1883 >/dev/null 2>&1; then
    mqtt_status="online"
fi

if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
    caddy_status="online"
fi

echo "Runtime: Rails"
echo "Rails:   $rails_status"
echo "MQTT:    $mqtt_status"
echo "Caddy:   $caddy_status"
echo "DB:      ${LUMENMON_DB_PATH:-/data/lumenmon.sqlite3}"
