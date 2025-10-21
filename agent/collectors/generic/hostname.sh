#!/bin/bash
# Collects system hostname and sends via SSH every REPORT interval (1hr).
# Outputs to generic_hostname.tsv on console with timestamp, interval, and hostname value.

# Config
RHYTHM="REPORT"   # Uses REPORT timing from agent.sh
PREFIX="generic_hostname"      # Metric prefix: generic_hostname
TYPE="TEXT"       # SQLite column type for string values

set -eo pipefail

# Main loop - gather hostname and send
while true; do
    # Get system hostname
    hostname=$(hostname)

    # Send hostname metric to console with type declaration
    timestamp=$(date +%s)

    echo -e "${PREFIX}.tsv $TYPE\n$timestamp $REPORT $hostname" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    sleep $REPORT
done
