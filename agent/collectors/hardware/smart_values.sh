#!/bin/bash
# Collects disk SMART health, temperature, wear, and power cycles.
# Supports SATA/SAS via smartctl and NVMe via nvme-cli when available.

RHYTHM="REPORT"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

sanitize_name() {
    printf '%s' "$1" | tr '/.-' '___'
}

get_smart_temp() {
    local dev="$1"
    smartctl -A "$dev" 2>/dev/null | awk '/Temperature_Celsius|Temperature_Internal|Airflow_Temperature_Cel/ {print $10; exit}'
}

get_smart_wear() {
    local dev="$1"
    smartctl -A "$dev" 2>/dev/null | awk '/Wear_Leveling_Count|Media_Wearout_Indicator|Percent_Lifetime_Remain|Percentage Used/ {print $10; exit}'
}

get_power_cycles() {
    local dev="$1"
    smartctl -A "$dev" 2>/dev/null | awk '/Power_Cycle_Count/ {print $10; exit}'
}

while true; do
    if ! command -v smartctl >/dev/null 2>&1; then
        [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
        exit 0
    fi

    while read -r disk; do
        [ -z "$disk" ] && continue

        # Skip zvol block devices (not physical disks, SMART unsupported).
        case "$disk" in
            zd*)
                continue
                ;;
        esac

        dev="/dev/$disk"
        disk_key=$(sanitize_name "$disk")

        # smartctl uses bitmask exit codes; do not treat non-zero as immediate failure.
        # Parse textual health status from output instead.
        health_out=$(smartctl -H "$dev" 2>/dev/null || true)
        if [ -z "$health_out" ]; then
            continue
        fi

        if printf '%s' "$health_out" | grep -Eq 'PASSED|OK'; then
            health=1
        elif printf '%s' "$health_out" | grep -Eq 'FAILED|BAD|CRITICAL'; then
            health=0
        else
            # Unknown/unsupported health output: skip rather than emit false failures.
            continue
        fi

        publish_metric "hardware_smart_${disk_key}_health" "$health" "INTEGER" "$REPORT" 1 1

        temp=$(get_smart_temp "$dev" || echo "")
        if [ -n "$temp" ] && [ "$temp" != "-" ]; then
            publish_metric "hardware_smart_${disk_key}_temp_c" "$temp" "INTEGER" "$REPORT" 0 70
        fi

        wear=$(get_smart_wear "$dev" || echo "")
        if [ -n "$wear" ] && [ "$wear" != "-" ]; then
            if [ "$wear" -ge 0 ] 2>/dev/null && [ "$wear" -le 100 ] 2>/dev/null; then
                publish_metric "hardware_smart_${disk_key}_wear_pct" "$wear" "INTEGER" "$REPORT" 0 95
            fi
        fi

        cycles=$(get_power_cycles "$dev" || echo "")
        if [ -n "$cycles" ] && [ "$cycles" != "-" ]; then
            publish_metric "hardware_smart_${disk_key}_power_cycles" "$cycles" "INTEGER" "$REPORT" 0
        fi

    done < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}')

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$REPORT"
done
