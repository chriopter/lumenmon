#!/bin/bash
# Collects Proxmox VM counts (running/stopped) via qm list.
# Only runs on Proxmox hosts where qm command exists.

# Config
RHYTHM="CYCLE"             # Uses CYCLE timing (60s)
METRIC_RUNNING="proxmox_vms_running"
METRIC_STOPPED="proxmox_vms_stopped"
TYPE="INTEGER"

set -euo pipefail
: ${LUMENMON_HOME:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Check if qm exists
if ! command -v qm &>/dev/null; then
    exit 0
fi

# Main loop
while true; do
    # Parse qm list output (skip header line)
    running=0
    stopped=0

    while read -r line; do
        if echo "$line" | grep -q "running"; then
            ((running++)) || true
        elif echo "$line" | grep -q "stopped"; then
            ((stopped++)) || true
        fi
    done < <(qm list 2>/dev/null | tail -n +2)

    publish_metric "$METRIC_RUNNING" "$running" "$TYPE" "$CYCLE"
    publish_metric "$METRIC_STOPPED" "$stopped" "$TYPE" "$CYCLE"

    sleep $CYCLE
done
