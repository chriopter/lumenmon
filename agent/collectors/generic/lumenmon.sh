#!/bin/bash
# System info collector - Sends OS/kernel/uptime at REPORT rhythm (1/hr)

# Config
RHYTHM="REPORT"   # Uses REPORT timing from agent.sh
PREFIX="generic_sys"      # Metric prefix: generic_sys_os, generic_sys_kernel, generic_sys_uptime

set -euo pipefail

# Main loop - gather system info and send
while true; do
    # Get OS name from /etc/os-release
    os=$(grep -oP '^ID=\K.*' /etc/os-release 2>/dev/null || echo "unknown")

    # Get kernel version
    kernel=$(uname -r)

    # Get uptime in seconds
    uptime=$(cut -d. -f1 /proc/uptime)

    # Direct append system metrics to console tmpfs
    # Each metric gets its own file for simplicity
    timestamp=$(date +%s)

    # OS info
    echo "$timestamp $os" | $LUMENMON_BASE \
        "mkdir -p /hot/$AGENT_ID && cat >> /hot/$AGENT_ID/${PREFIX}_os.tsv" 2>/dev/null

    # Kernel info
    echo "$timestamp $kernel" | $LUMENMON_BASE \
        "cat >> /hot/$AGENT_ID/${PREFIX}_kernel.tsv" 2>/dev/null

    # Uptime info
    echo "$timestamp $uptime" | $LUMENMON_BASE \
        "cat >> /hot/$AGENT_ID/${PREFIX}_uptime.tsv" 2>/dev/null

    sleep $REPORT
done