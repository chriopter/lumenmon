#!/bin/bash
# Collects system information (OS, kernel, uptime) and sends via SSH every REPORT interval (1hr).
# Outputs to generic_sys_*.tsv files on console with OS name, kernel version, and uptime seconds.

# Config
RHYTHM="REPORT"   # Uses REPORT timing from agent.sh
PREFIX="generic_sys"      # Metric prefix: generic_sys_os, generic_sys_kernel, generic_sys_uptime
TYPE_OS="TEXT"    # SQLite column type for OS name
TYPE_KERNEL="TEXT"        # SQLite column type for kernel version
TYPE_UPTIME="INTEGER"     # SQLite column type for uptime seconds

set -eo pipefail

# Main loop - gather system info and send
while true; do
    # Get OS name from /etc/os-release
    os=$(grep -oP '^ID=\K.*' /etc/os-release 2>/dev/null || echo "unknown")

    # Get kernel version
    kernel=$(uname -r)

    # Get uptime in seconds
    uptime=$(cut -d. -f1 /proc/uptime)

    # Send system metrics to console with type declarations
    timestamp=$(date +%s)

    # OS info
    echo -e "${PREFIX}_os.tsv $TYPE_OS\n$timestamp $REPORT $os" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    # Kernel info
    echo -e "${PREFIX}_kernel.tsv $TYPE_KERNEL\n$timestamp $REPORT $kernel" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    # Uptime info
    echo -e "${PREFIX}_uptime.tsv $TYPE_UPTIME\n$timestamp $REPORT $uptime" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $REPORT
done