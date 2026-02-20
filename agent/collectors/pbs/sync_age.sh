#!/bin/bash
# Collects hours since last PBS sync log update.
# Uses sync.log mtime as freshness signal.

RHYTHM="CYCLE"
METRIC="pbs_sync_age_hours"
TYPE="INTEGER"
MAX=168
LOG_FILE="/var/log/proxmox-backup/sync.log"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"
source "$LUMENMON_HOME/core/connection/pbs_task_age.sh"

while true; do
    age_hours="$(get_pbs_task_age_hours "sync" "$LOG_FILE" "$MAX")"
    publish_metric "$METRIC" "$age_hours" "$TYPE" "$CYCLE" 0 "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
