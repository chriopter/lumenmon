#!/bin/bash
# Collects root filesystem usage percentage from df and sends via SSH every CYCLE interval (60s).
# Outputs to generic_disk.tsv on console with timestamp, interval, and usage value.

# Config
RHYTHM="CYCLE"    # Uses CYCLE timing from agent.sh
PREFIX="generic_disk"     # Metric prefix: generic_disk_root_usage
TYPE="REAL"      # SQLite column type for numeric values

set -eo pipefail

# Main loop - check disk and send
while true; do
    # Get disk usage for root filesystem
    # df output: filesystem size used available percentage mountpoint
    read -r filesystem size used available percentage mountpoint <<< $(df -P / | tail -1)

    # Remove the % sign from percentage
    usage=${percentage%\%}

    # Send to console with type declaration
    echo -e "${PREFIX}.tsv $TYPE\n$(date +%s) $CYCLE $usage" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $CYCLE
done