#!/bin/bash
# Collects memory usage percentage from /proc/meminfo and publishes via MQTT.
# Calculates (total - available) / total at BREATHE interval (10s).

# Config
RHYTHM="BREATHE"          # Uses BREATHE timing from agent.sh (10s)
METRIC="generic_memory"   # Metric name: generic_memory
TYPE="REAL"               # SQLite column type for decimal values

set -euo pipefail
source /app/core/mqtt/publish.sh

while true; do
    # Parse /proc/meminfo for total and available memory (in KB)
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "total="t";avail="a}' /proc/meminfo)

    # Calculate usage percentage: (total - available) / total * 100
    usage=$(((total - avail) * 100 / total))

    # Publish with interval
    publish_metric "$METRIC" "$usage" "$TYPE" "$BREATHE"

    sleep $BREATHE
done
