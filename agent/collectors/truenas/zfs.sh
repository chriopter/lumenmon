#!/bin/bash
# ZFS pool monitoring for TrueNAS.
# Reports drive counts, online status, and capacity per pool.

RHYTHM="CYCLE"
TYPE="INTEGER"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get drive counts per pool (works on both FreeBSD and Linux)
    zpool status | awk '/pool:/{pool=$2} /^\t    /{drives[pool]++; if($2=="ONLINE")online[pool]++} END{for(p in drives) print p, drives[p], online[p]}' | while read -r pool drives online; do
        pool_name=$(echo "$pool" | tr '-' '_')
        publish_metric "truenas_zfs_${pool_name}_drives" "$drives" "$TYPE" "$CYCLE"
        publish_metric "truenas_zfs_${pool_name}_online" "${online:-0}" "$TYPE" "$CYCLE"
    done

    # Get capacity per pool
    zpool list -H -o name,capacity 2>/dev/null | while read -r pool capacity; do
        pool_name=$(echo "$pool" | tr '-' '_')
        capacity_num=$(echo "$capacity" | tr -d '%')
        publish_metric "truenas_zfs_${pool_name}_capacity" "$capacity_num" "REAL" "$CYCLE"
    done

    sleep $CYCLE
done
