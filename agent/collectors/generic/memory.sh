#!/bin/bash
# Collects memory usage percentage from /proc/meminfo and sends via SSH every BREATHE interval (10s).
# Outputs to generic_mem.tsv on console with timestamp, interval, and usage value.

# Config
RHYTHM="BREATHE"  # Uses BREATHE timing from agent.sh
PREFIX="generic_mem"      # Metric prefix: generic_mem_usage
TYPE="REAL"      # SQLite column type for numeric values

set -eo pipefail

# Main loop - read memory and send
while true; do
    # Parse /proc/meminfo for total and available memory (in KB)
    # Using eval to set both variables in one awk pass
    eval $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "total="t";available="a}' /proc/meminfo)

    # Calculate usage percentage: (total - available) / total * 100
    usage=$(((total - available) * 100 / total))

    # Send to console with type declaration
    echo -e "${PREFIX}.tsv $TYPE\n$(date +%s) $BREATHE $usage" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $BREATHE
done