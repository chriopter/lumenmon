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

    # Send system metrics to console
    timestamp=$(date +%s)

    # OS info
    echo -e "${PREFIX}_os.tsv\n$timestamp $os" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    # Kernel info
    echo -e "${PREFIX}_kernel.tsv\n$timestamp $kernel" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    # Uptime info
    echo -e "${PREFIX}_uptime.tsv\n$timestamp $uptime" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $REPORT
done