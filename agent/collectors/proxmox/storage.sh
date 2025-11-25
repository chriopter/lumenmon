#!/bin/bash
# Collects Proxmox storage pool usage via pvesh API.
# Only runs on Proxmox hosts where pvesh command exists.

# Config
RHYTHM="CYCLE"             # Uses CYCLE timing (60s)
TYPE="REAL"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Check if pvesh exists
if ! command -v pvesh &>/dev/null; then
    exit 0
fi

NODE=$(hostname)

# Main loop
while true; do
    # Parse JSON: extract storage name and used_fraction pairs
    pvesh get /nodes/$NODE/storage --output-format json 2>/dev/null | \
        grep -oP '"storage"\s*:\s*"\K[^"]+|"used_fraction"\s*:\s*\K[0-9.eE+-]+' | \
        paste - - | while read -r storage fraction; do
            # Convert fraction to percentage
            used_pct=$(awk "BEGIN {printf \"%.1f\", $fraction * 100}")

            # Sanitize storage name (replace - with _)
            metric_name="proxmox_storage_$(echo "$storage" | tr '-' '_')"

            publish_metric "$metric_name" "$used_pct" "$TYPE" "$CYCLE"
        done

    sleep $CYCLE
done
