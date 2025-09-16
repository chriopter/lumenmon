#!/bin/bash
# Disk - CYCLE rhythm
set -euo pipefail

while true; do
    read -r fs size used avail pct mount <<< $(df -P / | tail -1)
    usage=${pct%\%}
    echo -e "$(date +%s)\t$AGENT_ID\tdisk_root_usage\tfloat\t$usage\t$CYCLE" | \
        ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST "/usr/local/bin/lumenmon-append --host '$AGENT_ID'" 2>/dev/null
    sleep ${CYCLE:-60}
done