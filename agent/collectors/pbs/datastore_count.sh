#!/bin/bash
# Collects number of configured PBS datastores.
# Uses proxmox-backup-manager datastore list.

RHYTHM="CYCLE"
METRIC="pbs_datastore_count"
TYPE="INTEGER"
MIN=1

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    count=$(LC_ALL=C proxmox-backup-manager datastore list 2>/dev/null | awk 'NR>1 && NF>0 {c++} END {print c+0}')
    publish_metric "$METRIC" "$count" "$TYPE" "$CYCLE" "$MIN"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
