#!/bin/bash
# Collects memory usage percentage from /proc/meminfo and publishes via MQTT.
# Calculates (total - available) / total at BREATHE interval (10s).

# Config
RHYTHM="BREATHE"          # Uses BREATHE timing from agent.sh (10s)
METRIC="generic_memory"   # Metric name: generic_memory
TYPE="REAL"               # SQLite column type for decimal values
MIN=0                     # Minimum value (percentage)
MAX=100                   # Maximum value (percentage)

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Parse /proc/meminfo for total and available memory (in KB)
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "total="t";avail="a}' /proc/meminfo)

    # Calculate usage percentage: (total - available) / total * 100
    usage=$(((total - avail) * 100 / total))

    # Publish with interval and bounds
    publish_metric "$METRIC" "$usage" "$TYPE" "$BREATHE" "$MIN" "$MAX"

    sleep $BREATHE
done
