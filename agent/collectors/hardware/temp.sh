#!/bin/bash
# Collects CPU and NVMe temperatures on real hardware hosts.
# Publishes thermal telemetry with conservative alert thresholds.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    if command -v sensors >/dev/null 2>&1; then
        cpu_temp=$(LC_ALL=C sensors 2>/dev/null | awk '/Package id 0:|Tctl:|CPU Temperature:/ {gsub(/\+|°C/,"",$4); print $4; exit}')
        if [ -n "$cpu_temp" ]; then
            publish_metric "hardware_temp_cpu_c" "$cpu_temp" "REAL" "$CYCLE" 0 90
        fi
    fi

    if command -v nvme >/dev/null 2>&1; then
        while read -r dev; do
            [ -z "$dev" ] && continue
            key=$(basename "$dev" | tr '.-' '__')
            temp=$(nvme smart-log "$dev" 2>/dev/null | awk '/^temperature/ {print $3; exit}')
            if [ -n "$temp" ]; then
                publish_metric "hardware_temp_nvme_${key}_c" "$temp" "INTEGER" "$CYCLE" 0 70
            fi
        done < <(nvme list 2>/dev/null | awk '/^\/dev\/nvme/ {print $1}')
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
