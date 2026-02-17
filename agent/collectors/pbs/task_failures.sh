#!/bin/bash
# Collects PBS task failure count over the last 24 hours.
# Parses proxmox-backup service logs for error/failed lines.

RHYTHM="CYCLE"
METRIC="pbs_task_failures_24h"
TYPE="INTEGER"
MIN=0
MAX=0

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    failures=$(LC_ALL=C journalctl -u proxmox-backup --since '24 hours ago' --no-pager 2>/dev/null | grep -ci 'error\|failed' || echo 0)
    publish_metric "$METRIC" "$failures" "$TYPE" "$CYCLE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
