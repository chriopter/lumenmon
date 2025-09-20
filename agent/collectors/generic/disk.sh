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

    # Send to console - no mkdir needed!
    echo -e "${PREFIX}.tsv\n$(date +%s) $usage" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $CYCLE
done