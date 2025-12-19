#!/bin/bash
# Collects Proxmox storage pool usage via pvesh API.
# Publishes _used and _total (in GB) for each storage pool.

# Config
RHYTHM="CYCLE"             # Uses CYCLE timing (5m)
TYPE="REAL"

source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Check if pvesh exists
if ! command -v pvesh &>/dev/null; then
    exit 0
fi

NODE=$(hostname)

# Main loop
while true; do
    # Get storage info as JSON and parse with awk
    LC_ALL=C pvesh get /nodes/$NODE/storage --output-format json 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for s in data:
        name = s.get('storage', '').replace('-', '_')
        total = s.get('total', 0) / (1024**3)  # bytes to GB
        used = s.get('used', 0) / (1024**3)
        print(f'{name} {used:.1f} {total:.1f}')
except: pass
" | while read -r storage used total; do
        [ -z "$storage" ] && continue
        publish_metric "proxmox_storage_${storage}_used" "$used" "$TYPE" "$CYCLE"
        publish_metric "proxmox_storage_${storage}_total" "$total" "$TYPE" "$CYCLE"
    done
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $CYCLE
done
