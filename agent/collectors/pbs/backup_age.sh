#!/bin/bash
# Collects hours since PBS backup activity log update.
# Uses active task log mtime as freshness signal.

RHYTHM="CYCLE"
METRIC="pbs_backup_age_hours"
TYPE="INTEGER"
MAX=24
LOG_FILE="/var/log/proxmox-backup/tasks/active.log"

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
