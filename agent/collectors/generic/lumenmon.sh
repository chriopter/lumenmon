#!/bin/bash
# System - REPORT rhythm
set -euo pipefail

while true; do
    os=$(grep -oP '^ID=\K.*' /etc/os-release 2>/dev/null || echo "unknown")
    kernel=$(uname -r)
    uptime=$(cut -d. -f1 /proc/uptime)
    for m in "sys_os:string:$os" "sys_kernel:string:$kernel" "sys_uptime:int:$uptime"; do
        IFS=: read -r name type value <<< "$m"
        echo -e "$(date +%s)\t$AGENT_ID\t$name\t$type\t$value\t$REPORT" | \
            ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST "/usr/local/bin/lumenmon-append --host '$AGENT_ID'" 2>/dev/null
    done
    sleep ${REPORT:-3600}
done