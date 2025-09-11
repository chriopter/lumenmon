#!/bin/sh
# Disk usage collector

# === CONFIG ===
TEMPO="andante"
INTERVAL=${ANDANTE_INTERVAL:-60}
PREFIX="lumenmon_disk"

# === COLLECT ===
# Root filesystem metrics
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')

# Count block devices
DISK_COUNT=$(lsblk -d -n -o NAME,TYPE | grep -c disk 2>/dev/null || echo "0")

# === OUTPUT with type and interval ===
echo "${PREFIX}_root_usage_percent:${ROOT_USAGE}:float:${INTERVAL}"
echo "${PREFIX}_root_total:${ROOT_TOTAL}:string:${INTERVAL}"
echo "${PREFIX}_root_used:${ROOT_USED}:string:${INTERVAL}"
echo "${PREFIX}_count:${DISK_COUNT}:int:${INTERVAL}"