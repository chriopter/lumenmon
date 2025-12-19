#!/bin/bash
# Sends heartbeat signal to verify agent connectivity.
# Always publishes value 1 at PULSE interval (1s).

# Config
RHYTHM="PULSE"              # Uses PULSE timing from agent.sh (1s)
METRIC="generic_heartbeat"  # Metric name: generic_heartbeat
TYPE="INTEGER"              # SQLite column type for whole numbers

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    sleep $PULSE

    # Send heartbeat signal (always 1) with interval
    publish_metric "$METRIC" "1" "$TYPE" "$PULSE"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
done
