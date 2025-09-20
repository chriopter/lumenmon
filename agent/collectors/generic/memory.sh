#!/bin/bash
# Memory collector - Sends usage percentage at BREATHE rhythm (1Hz)

# Config
RHYTHM="BREATHE"  # Uses BREATHE timing from agent.sh
PREFIX="generic_mem"      # Metric prefix: generic_mem_usage

set -euo pipefail

# Main loop - read memory and send
while true; do
    # Parse /proc/meminfo for total and available memory (in KB)
    # Using eval to set both variables in one awk pass
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "total="t";available="a}' /proc/meminfo)

    # Calculate usage percentage: (total - available) / total * 100
    usage=$(((total - available) * 100 / total))

    # Send to console - no mkdir needed!
    echo -e "${PREFIX}.tsv\n$(date +%s) $BREATHE $usage" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $BREATHE
done