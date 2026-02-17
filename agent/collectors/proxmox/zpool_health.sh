#!/bin/bash
# Checks ZFS pool health states from zpool status output.
# Publishes per-pool degraded/upgrade-needed flags and global degraded flag.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    any_degraded=0

    while IFS='|' read -r pool state upgrade_needed; do
        [ -z "$pool" ] && continue

        pool_name=$(printf '%s' "$pool" | tr '-' '_')

        degraded=0
        case "$state" in
            ONLINE) degraded=0 ;;
            *) degraded=1 ;;
        esac

        if [ "$degraded" -eq 1 ]; then
            any_degraded=1
        fi

        publish_metric "proxmox_zpool_${pool_name}_degraded" "$degraded" "INTEGER" "$CYCLE" 0 0
        publish_metric "proxmox_zpool_${pool_name}_upgrade_needed" "$upgrade_needed" "INTEGER" "$CYCLE" 0 0
    done < <(
        LC_ALL=C zpool status 2>/dev/null | awk '
            /^  pool:/ {pool=$2; state="UNKNOWN"; upgrade=0}
            /^ state:/ {state=$2}
            /Some supported features are not enabled on the pool/ {upgrade=1}
            /^errors:/ {if (pool != "") {print pool "|" state "|" upgrade; pool=""}}
        '
    )

    publish_metric "proxmox_zpool_any_degraded" "$any_degraded" "INTEGER" "$CYCLE" 0 0

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
