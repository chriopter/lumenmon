#!/bin/sh
# Disk usage collector

# === CONFIG ===
INTERVAL="andante"
PREFIX="generic_disk"

# === COLLECT ===
# Root filesystem metrics
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')

# Count block devices
DISK_COUNT=$(lsblk -d -n -o NAME,TYPE | grep -c disk 2>/dev/null || echo "0")

# === OUTPUT ===
echo "${PREFIX}_root_usage_percent:${ROOT_USAGE}:float"
echo "${PREFIX}_root_total:${ROOT_TOTAL}:string"
echo "${PREFIX}_root_used:${ROOT_USED}:string"
echo "${PREFIX}_count:${DISK_COUNT}:int"