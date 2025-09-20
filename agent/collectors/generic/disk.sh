#!/bin/bash
# Disk collector - Sends root filesystem usage at CYCLE rhythm (1/min)

# Config
RHYTHM="CYCLE"    # Uses CYCLE timing from agent.sh
PREFIX="generic_disk"     # Metric prefix: generic_disk_root_usage

set -euo pipefail

# Main loop - check disk and send
while true; do
    # Get disk usage for root filesystem
    # df output: filesystem size used available percentage mountpoint
    read -r filesystem size used available percentage mountpoint <<< $(df -P / | tail -1)

    # Remove the % sign from percentage
    usage=${percentage%\%}

    # Direct append to console tmpfs
    echo "$(date +%s) $usage" | $LUMENMON_BASE \
        "mkdir -p /hot/$AGENT_ID && cat >> /hot/$AGENT_ID/${PREFIX}.tsv" 2>/dev/null

    sleep $CYCLE
done