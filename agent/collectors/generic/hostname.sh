#!/bin/bash
# Collects system hostname and publishes via MQTT.
# Reports hostname at REPORT interval (1hr). Interval=0 means one-time value.

# Config
RHYTHM="REPORT"            # Uses REPORT timing from agent.sh (1hr)
METRIC="generic_hostname"  # Metric name: generic_hostname
TYPE="TEXT"                # SQLite column type for string values

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get system hostname (use variable name that doesn't shadow command)
    if command -v hostname >/dev/null 2>&1; then
        host_value=$(hostname 2>/dev/null | tr -d '[:space:]') || host_value=""
    fi

    if [ -z "$host_value" ] && [ -f /etc/hostname ]; then
        host_value=$(cat /etc/hostname 2>/dev/null | tr -d '[:space:]') || host_value=""
    fi

    [ -z "$host_value" ] && host_value="unknown"

    # Publish as one-time value (interval=0, never stale)
    publish_metric "$METRIC" "$host_value" "$TYPE" 0
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $REPORT
done
