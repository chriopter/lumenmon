#!/bin/bash
# Memory - BREATHE rhythm
set -euo pipefail

while true; do
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "t="t";a="a}' /proc/meminfo)
    usage=$(((t-a)*100/t))
    echo -e "$(date +%s)\t$AGENT_ID\tmem_usage\tfloat\t$usage\t$BREATHE" | \
        ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST "/usr/local/bin/lumenmon-append --host '$AGENT_ID'" 2>/dev/null
    sleep ${BREATHE:-1}
done