#!/bin/bash
# Collects generic ZFS zpool summary metrics on Linux hosts.
# Publishes total pools and degraded pools for quick health rollups.

RHYTHM="CYCLE"
METRIC_TOTAL="generic_zpool_total"
METRIC_DEGRADED="generic_zpool_degraded"
TYPE="INTEGER"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Avoid duplicate zpool signal on Proxmox (dedicated proxmox_zpool_* exists).
if command -v pvesh >/dev/null 2>&1; then
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    exit 0
fi

while true; do
    if ! command -v zpool >/dev/null 2>&1; then
        [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
        exit 0
    fi

    total_pools=0
    degraded_pools=0

    while IFS='|' read -r _pool state; do
        [ -z "$state" ] && continue
        total_pools=$((total_pools + 1))
        if [ "$state" != "ONLINE" ]; then
            degraded_pools=$((degraded_pools + 1))
        fi
    done < <(LC_ALL=C zpool status 2>/dev/null | awk '/^  pool:/ {pool=$2} /^ state:/ {print pool "|" $2}')

    publish_metric "$METRIC_TOTAL" "$total_pools" "$TYPE" "$CYCLE" 0
    publish_metric "$METRIC_DEGRADED" "$degraded_pools" "$TYPE" "$CYCLE" 0 0

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
