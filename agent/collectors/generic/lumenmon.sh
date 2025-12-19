#!/bin/bash
# Collects system information (OS, kernel, uptime) and publishes via MQTT.
# This collector publishes 3 separate metrics at REPORT interval (1hr).

# Config
RHYTHM="REPORT"  # Uses REPORT timing from agent.sh (1hr)

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get OS name from /etc/os-release
    os=$(grep -oP '^ID=\K.*' /etc/os-release 2>/dev/null || echo "unknown")

    # Get kernel version
    kernel=$(uname -r)

    # Get uptime in seconds
    uptime=$(cut -d. -f1 /proc/uptime)

    # Publish all three metrics with interval (TEXT auto-quoted by publish.sh)
    publish_metric "generic_sys_os" "$os" "TEXT" "$REPORT"
    publish_metric "generic_sys_kernel" "$kernel" "TEXT" "$REPORT"
    publish_metric "generic_sys_uptime" "$uptime" "INTEGER" "$REPORT" 0
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $REPORT
done
