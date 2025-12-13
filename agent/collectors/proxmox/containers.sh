#!/bin/bash
# Collects Proxmox LXC container counts (running/stopped) via pct list.
# Only runs on Proxmox hosts where pct command exists.

# Config
RHYTHM="CYCLE"             # Uses CYCLE timing (60s)
METRIC_RUNNING="proxmox_cts_running"
METRIC_STOPPED="proxmox_cts_stopped"
TYPE="INTEGER"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Check if pct exists
if ! command -v pct &>/dev/null; then
    exit 0
fi

# Main loop
while true; do
    # Parse pct list output (skip header line)
    running=0
    stopped=0

    while read -r line; do
        if echo "$line" | grep -q "running"; then
            ((running++)) || true
        elif echo "$line" | grep -q "stopped"; then
            ((stopped++)) || true
        fi
    done < <(LC_ALL=C pct list 2>/dev/null | tail -n +2)

    publish_metric "$METRIC_RUNNING" "$running" "$TYPE" "$CYCLE"
    publish_metric "$METRIC_STOPPED" "$stopped" "$TYPE" "$CYCLE"

    sleep $CYCLE
done
