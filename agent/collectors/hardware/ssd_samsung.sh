#!/bin/bash
# Collects Samsung SSD inventory and firmware values.
# Publishes per-disk firmware text for Samsung drives only.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

sanitize_name() {
    printf '%s' "$1" | tr '/.-' '___'
}

while true; do
    if ! command -v smartctl >/dev/null 2>&1; then
        [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
        exit 0
    fi

    samsung_count=0
    while read -r disk; do
        [ -z "$disk" ] && continue
        dev="/dev/$disk"
        model=$(smartctl -i "$dev" 2>/dev/null | awk -F: '/Device Model|Model Number/ {gsub(/^ +/,"",$2); print $2; exit}')
        if printf '%s' "$model" | grep -qi 'samsung'; then
            samsung_count=$((samsung_count + 1))
            disk_key=$(sanitize_name "$disk")
            firmware=$(smartctl -i "$dev" 2>/dev/null | awk -F: '/Firmware Version/ {gsub(/^ +/,"",$2); print $2; exit}')
            if [ -n "$firmware" ]; then
                publish_metric "hardware_samsung_${disk_key}_firmware" "$firmware" "TEXT" "$CYCLE"
            fi
        fi
    done < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}')

    publish_metric "hardware_samsung_disk_count" "$samsung_count" "INTEGER" "$CYCLE" 0

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
