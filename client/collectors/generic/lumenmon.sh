#!/bin/sh
# Lumenmon self-reporting collector
# Reports Lumenmon's own configuration and status

# === TEMPO ===
TEMPO="adagio"

# === IDENTITY ===
GROUP="generic"
COLLECTOR="lumenmon"
PREFIX="${GROUP}_${COLLECTOR}"

# === COLLECT ===
# Get configuration from environment
CHECK_INTERVAL="${INTERVAL:-unknown}"
DEBUG_MODE="${DEBUG:-0}"
SERVER_URL="${SERVER_URL:-unknown}"

# Version info (could be from git or hardcoded)
VERSION="0.1.0"

# Count active collectors
COLLECTOR_COUNT=0
for dir in /collectors/*/; do
    if [ -d "$dir" ] && [ "$dir" != "/collectors/collectors/" ]; then
        for script in "$dir"*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                COLLECTOR_COUNT=$((COLLECTOR_COUNT + 1))
            fi
        done
    fi
done

# Runtime info
if [ -f /proc/1/stat ]; then
    # Get container start time (jiffies since boot)
    START_TIME=$(awk '{print $22}' /proc/1/stat)
    # Get system uptime
    SYSTEM_UPTIME=$(awk '{print $1}' /proc/uptime)
    # Calculate container uptime (very rough estimate)
    CONTAINER_UPTIME=$(echo "$SYSTEM_UPTIME" | awk '{print int($1)}')
else
    CONTAINER_UPTIME=0
fi

# === OUTPUT ===
echo "${PREFIX}_version:${VERSION}"
echo "${PREFIX}_interval:${CHECK_INTERVAL}"
echo "${PREFIX}_debug:${DEBUG_MODE}"
echo "${PREFIX}_server:${SERVER_URL}"
echo "${PREFIX}_collectors:${COLLECTOR_COUNT}"
echo "${PREFIX}_uptime:${CONTAINER_UPTIME}"