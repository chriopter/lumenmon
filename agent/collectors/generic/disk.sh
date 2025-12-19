#!/bin/bash
# Collects root filesystem usage percentage from df and publishes via MQTT.
# Reports disk usage for / at BREATHE interval (60s).

# Config
RHYTHM="BREATHE"       # Uses BREATHE timing from agent.sh (60s)
METRIC="generic_disk"  # Metric name: generic_disk
TYPE="REAL"            # SQLite column type for decimal values
MIN=0                  # Minimum value (percentage)
MAX=100                # Maximum value (percentage)

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get disk usage for root filesystem (remove % sign)
    # Force English locale for consistent output
    usage=$(LC_ALL=C df -P / | tail -1 | awk '{print $5}' | tr -d '%') || usage=0

    # Publish with interval and bounds
    publish_metric "$METRIC" "$usage" "$TYPE" "$BREATHE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $BREATHE
done
