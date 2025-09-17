#!/bin/bash
# System info collector - Sends OS/kernel/uptime at REPORT rhythm (1/hr)

# Config
RHYTHM="REPORT"   # Uses REPORT timing from agent.sh
PREFIX="sys"      # Metric prefix: sys_os, sys_kernel, sys_uptime

set -euo pipefail

# Main loop - gather system info and send
while true; do
    # Get OS name from /etc/os-release
    os=$(grep -oP '^ID=\K.*' /etc/os-release 2>/dev/null || echo "unknown")

    # Get kernel version
    kernel=$(uname -r)

    # Get uptime in seconds
    uptime=$(cut -d. -f1 /proc/uptime)

    # Send all system metrics
    # Using a loop to keep it DRY for multiple metrics
    for metric in "${PREFIX}_os:string:$os" "${PREFIX}_kernel:string:$kernel" "${PREFIX}_uptime:int:$uptime"; do
        IFS=: read -r name type value <<< "$metric"
        echo -e "$(date +%s)\t$AGENT_ID\t$name\t$type\t$value\t$REPORT" | \
            eval "${LUMENMON_TRANSPORT:-cat}"
    done

    sleep $REPORT
done