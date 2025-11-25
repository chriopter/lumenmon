#!/bin/bash
# ZFS pool monitoring for Proxmox.
# Reports drive counts, online status, and capacity per pool.

RHYTHM="CYCLE"
TYPE="INTEGER"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Get drive counts per pool
zpool status | awk '/pool:/{pool=$2} /^\t    /{drives[pool]++; if($2=="ONLINE")online[pool]++} END{for(p in drives) print p, drives[p], online[p]}' | while read -r pool drives online; do
    pool_name=$(echo "$pool" | tr '-' '_')
    publish_metric "proxmox_zfs_${pool_name}_drives" "$drives" "$TYPE" "$CYCLE"
    publish_metric "proxmox_zfs_${pool_name}_online" "$online" "$TYPE" "$CYCLE"
done

# Get capacity per pool
zpool list -H -o name,capacity | while read -r pool capacity; do
    pool_name=$(echo "$pool" | tr '-' '_')
    capacity_num=$(echo "$capacity" | tr -d '%')
    publish_metric "proxmox_zfs_${pool_name}_capacity" "$capacity_num" "REAL" "$CYCLE"
done
