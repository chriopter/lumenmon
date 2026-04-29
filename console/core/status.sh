#!/bin/bash
# Prints a compact status summary for the Rails console container.
# Used by the lumenmon CLI and deployment smoke checks.
set -euo pipefail

rails_status="down"
mqtt_status="down"
caddy_status="down"

check_with_retries() {
    local attempt

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if "$@" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    return 1
}

if check_with_retries curl -fsS http://127.0.0.1:5000/health; then
    rails_status="online"
fi

if check_with_retries nc -z 127.0.0.1 1883; then
    mqtt_status="online"
fi

if check_with_retries curl -fsS http://127.0.0.1:8080/health; then
    caddy_status="online"
fi

echo "Runtime: Rails"
echo "Rails:   $rails_status"
echo "MQTT:    $mqtt_status"
echo "Caddy:   $caddy_status"
echo "DB:      /app/storage/production.sqlite3"
