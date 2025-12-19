#!/bin/bash
# ZFS pool monitoring for Proxmox.
# Reports drive counts, online status, and capacity per pool.
# Online drives use dynamic min/max = total drives for degraded detection.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get drive counts per pool (with dynamic min/max for health detection)
    LC_ALL=C zpool status | awk '/pool:/{pool=$2} /^\t    /{drives[pool]++; if($2=="ONLINE")online[pool]++} END{for(p in drives) print p, drives[p], online[p]}' | while read -r pool drives online; do
        pool_name=$(echo "$pool" | tr '-' '_')
        publish_metric "proxmox_zfs_${pool_name}_drives" "$drives" "INTEGER" "$CYCLE" "" ""
        # online: min=max=drives, so if online < drives → failed (degraded pool)
        publish_metric "proxmox_zfs_${pool_name}_online" "$online" "INTEGER" "$CYCLE" "$drives" "$drives"
    done

    # Get capacity per pool (0-100%)
    LC_ALL=C zpool list -H -o name,capacity | while read -r pool capacity; do
        pool_name=$(echo "$pool" | tr '-' '_')
        capacity_num=$(echo "$capacity" | tr -d '%')
        publish_metric "proxmox_zfs_${pool_name}_capacity" "$capacity_num" "REAL" "$CYCLE" 0 100
    done
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $CYCLE
done
