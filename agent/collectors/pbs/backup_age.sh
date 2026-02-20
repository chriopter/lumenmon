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
source "$LUMENMON_HOME/core/connection/pbs_task_age.sh"

while true; do
    age_hours="$(get_pbs_task_age_hours "backup" "$LOG_FILE" "$MAX")"
    publish_metric "$METRIC" "$age_hours" "$TYPE" "$CYCLE" 0 "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
