#!/bin/bash
# Collects hours since last PBS garbage-collection log update.
# Uses gc.log mtime as freshness signal.

RHYTHM="CYCLE"
METRIC="pbs_gc_age_hours"
TYPE="INTEGER"
MAX=168
LOG_FILE="/var/log/proxmox-backup/gc.log"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    if [ -f "$LOG_FILE" ]; then
        now=$(date +%s)
        mtime=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo "$now")
        age_hours=$(((now - mtime) / 3600))
        publish_metric "$METRIC" "$age_hours" "$TYPE" "$CYCLE" 0 "$MAX"
    fi
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
