#!/bin/bash
# Memory collector - Sends usage percentage at BREATHE rhythm (1Hz)

# Config
RHYTHM="BREATHE"  # Uses BREATHE timing from agent.sh
PREFIX="mem"      # Metric prefix: mem_usage

set -euo pipefail

# Main loop - read memory and send
while true; do
    # Parse /proc/meminfo for total and available memory (in KB)
    # Using eval to set both variables in one awk pass
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "total="t";available="a}' /proc/meminfo)

    # Calculate usage percentage: (total - available) / total * 100
    usage=$(((total - available) * 100 / total))

    # Send metric through SSH tunnel
    echo -e "$(date +%s)\t$AGENT_ID\t${PREFIX}_usage\tfloat\t$usage\t$BREATHE" | \
        ssh -S $SSH_SOCKET $CONSOLE_USER@$CONSOLE_HOST "/app/ssh/receiver.sh --host $AGENT_ID"

    sleep $BREATHE
done