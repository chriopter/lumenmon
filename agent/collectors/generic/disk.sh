#!/bin/bash
# Collects root filesystem usage percentage from df and publishes via MQTT.
# Reports disk usage for / at CYCLE interval (60s).

# Config
RHYTHM="CYCLE"         # Uses CYCLE timing from agent.sh (60s)
METRIC="generic_disk"  # Metric name: generic_disk
TYPE="REAL"            # SQLite column type for decimal values

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get disk usage for root filesystem (remove % sign)
    usage=$(df -P / | tail -1 | awk '{print $5}' | tr -d '%')

    # Publish with interval
    publish_metric "$METRIC" "$usage" "$TYPE" "$CYCLE"

    sleep $CYCLE
done
