#!/bin/bash
# Collects system hostname from /host/etc/hostname and publishes via MQTT.
# Reports hostname at REPORT interval (1hr).

# Config
RHYTHM="REPORT"            # Uses REPORT timing from agent.sh (1hr)
METRIC="generic_hostname"  # Metric name: generic_hostname
TYPE="TEXT"                # SQLite column type for string values

set -euo pipefail
source /app/core/mqtt/publish.sh

while true; do
    # Get host system hostname (not container hostname)
    if [ -f /host/etc/hostname ]; then
        hostname=$(cat /host/etc/hostname)
    else
        hostname="unknown"
    fi

    # Publish (value is quoted for TEXT type)
    publish_metric "$METRIC" "\"$hostname\"" "$TYPE"

    sleep $REPORT
done
