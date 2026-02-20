#!/bin/bash
# Collects GPU VRAM usage percentage when DRM VRAM counters are available.
# Exits cleanly on hosts without VRAM sysfs telemetry.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

has_gpu_device() {
    local vendor_file=""
    local vendor=""

    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        return 0
    fi

    for vendor_file in /sys/class/drm/card*/device/vendor; do
        [ -r "$vendor_file" ] || continue
        vendor="$(cat "$vendor_file" 2>/dev/null || true)"
        case "$vendor" in
            0x8086|0x10de|0x1002)
                return 0
                ;;
        esac
    done

    return 1
}

vram_from_sysfs() {
    local base=""
    local total_file=""
    local used_file=""
    local total=""
    local used=""
    local total_sum=0
    local used_sum=0
    local found=0
    local pct=0

    for base in /sys/class/drm/card*/device/mem_info_vram /sys/class/drm/card*/device/mem_info_lmem /sys/class/drm/card*/device/mem_info_local_memory; do
        total_file="${base}_total"
        used_file="${base}_used"
        [ -r "$total_file" ] || continue
        [ -r "$used_file" ] || continue

        total="$(cat "$total_file" 2>/dev/null || true)"
        used="$(cat "$used_file" 2>/dev/null || true)"

        if [[ "$total" =~ ^[0-9]+$ ]] && [[ "$used" =~ ^[0-9]+$ ]] && [ "$total" -gt 0 ]; then
            total_sum=$((total_sum + total))
            used_sum=$((used_sum + used))
            found=1
        fi
    done

    [ "$found" -eq 1 ] || return 1

    pct=$((used_sum * 100 / total_sum))
    [ "$pct" -gt 100 ] && pct=100
    echo "$pct"
}

vram_from_nvidia_smi() {
    local line_total=""
    local line_used=""
    local total_sum=0
    local used_sum=0
    local pct=0

    command -v nvidia-smi >/dev/null 2>&1 || return 1

    while IFS=',' read -r line_total line_used; do
        line_total="$(printf '%s' "$line_total" | tr -d ' ')"
        line_used="$(printf '%s' "$line_used" | tr -d ' ')"

        if [[ "$line_total" =~ ^[0-9]+$ ]] && [[ "$line_used" =~ ^[0-9]+$ ]] && [ "$line_total" -gt 0 ]; then
            total_sum=$((total_sum + line_total))
            used_sum=$((used_sum + line_used))
        fi
    done < <(nvidia-smi --query-gpu=memory.total,memory.used --format=csv,noheader,nounits 2>/dev/null || true)

    [ "$total_sum" -gt 0 ] || return 1

    pct=$((used_sum * 100 / total_sum))
    [ "$pct" -gt 100 ] && pct=100
    echo "$pct"
}

while true; do
    vram_pct=""
    if vram_pct="$(vram_from_sysfs)"; then
        :
    elif vram_pct="$(vram_from_nvidia_smi)"; then
        :
    elif has_gpu_device; then
        # Keep metric alive when VRAM counters are missing on passthrough guests.
        vram_pct="0"
    fi

    if [ -n "$vram_pct" ]; then
        publish_metric "hardware_gpu_vram_used_pct" "$vram_pct" "INTEGER" "$CYCLE" 0 95
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
