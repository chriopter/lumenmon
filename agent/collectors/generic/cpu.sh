#!/bin/bash
# CPU - PULSE rhythm
set -euo pipefail

# Init tracking
read line < /proc/stat; cpu=($line)
prev_idle=$((${cpu[4]}+${cpu[5]})); prev_total=0
for v in "${cpu[@]:1}"; do prev_total=$((prev_total+v)); done

while true; do
    read line < /proc/stat; cpu=($line)
    idle=$((${cpu[4]}+${cpu[5]})); total=0
    for v in "${cpu[@]:1}"; do total=$((total+v)); done
    [ $((total-prev_total)) -gt 0 ] && usage=$(((total-prev_total-idle+prev_idle)*100/(total-prev_total))) || usage=0
    echo -e "$(date +%s)\t$AGENT_ID\tcpu_usage\tfloat\t$usage\t$PULSE" | \
        ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST "/usr/local/bin/lumenmon-append --host '$AGENT_ID'" 2>/dev/null
    prev_idle=$idle; prev_total=$total
    sleep ${PULSE:-0.1}
done