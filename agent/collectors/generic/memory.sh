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

    # Direct append to console tmpfs
    echo "$(date +%s) $usage" | $LUMENMON_BASE \
        "mkdir -p /hot/$AGENT_ID && cat >> /hot/$AGENT_ID/${PREFIX}.tsv" 2>/dev/null

    sleep $BREATHE
done