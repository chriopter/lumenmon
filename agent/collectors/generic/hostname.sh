#!/bin/bash
# Collects system hostname and publishes via MQTT.
# Reports hostname at REPORT interval (1hr).

# Config
RHYTHM="REPORT"            # Uses REPORT timing from agent.sh (1hr)
METRIC="generic_hostname"  # Metric name: generic_hostname
TYPE="TEXT"                # SQLite column type for string values

set -euo pipefail
: ${LUMENMON_HOME:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get system hostname
    if command -v hostname >/dev/null 2>&1; then
        hostname=$(hostname | tr -d '[:space:]')
    elif [ -f /etc/hostname ]; then
        hostname=$(cat /etc/hostname | tr -d '[:space:]')
    else
        hostname="unknown"
    fi

    # Publish with interval (value is quoted for TEXT type)
    publish_metric "$METRIC" "\"$hostname\"" "$TYPE" "$REPORT"

    sleep $REPORT
done
