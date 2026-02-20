#!/bin/bash
# Collects Intel GPU busy percentage when available.
# Exits cleanly on hosts without Intel GPU tooling.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

has_intel_gpu() {
    local vendor_file=""

    for vendor_file in /sys/class/drm/card*/device/vendor; do
        [ -r "$vendor_file" ] || continue
        if [ "$(cat "$vendor_file" 2>/dev/null || true)" = "0x8086" ]; then
            return 0
        fi
    done

    return 1
}

intel_gpu_busy_from_top() {
    local raw=""

    command -v intel_gpu_top >/dev/null 2>&1 || return 1

    # intel_gpu_top runs continuously; timeout stops it and returns 124.
    # Keep captured output and parse best-effort from partial JSON stream.
    raw="$(timeout 3 intel_gpu_top -J -s 1000 2>/dev/null || true)"
    [ -n "$raw" ] || return 1

    printf '%s\n' "$raw" | python3 -c '
import re
import sys

text = sys.stdin.read()
matches = re.findall(r"\"busy\"\s*:\s*(?:\{[^{}]*\"value\"\s*:\s*)?([0-9]+(?:\.[0-9]+)?)", text, flags=re.S)
if not matches:
    raise SystemExit(1)

value = max(float(item) for item in matches)
if value < 0:
    value = 0
if value > 100:
    value = 100

print(int(round(value)))
' 2>/dev/null
}

intel_gpu_busy_from_top_text() {
    local raw=""

    command -v intel_gpu_top >/dev/null 2>&1 || return 1
    raw="$(timeout 3 intel_gpu_top 2>/dev/null || true)"
    [ -n "$raw" ] || return 1

    printf '%s\n' "$raw" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+(\.[0-9]+)?%$/) {
                    gsub(/%/, "", $i)
                    if ($i + 0 > max) {
                        max = $i + 0
                    }
                    found = 1
                }
            }
        }
        END {
            if (!found) {
                exit 1
            }
            if (max < 0) {
                max = 0
            }
            if (max > 100) {
                max = 100
            }
            printf "%.0f\n", max
        }
    '
}

intel_gpu_busy_from_sysfs() {
    local card=""
    local vendor=""
    local file=""
    local value=""

    for card in /sys/class/drm/card*; do
        [ -d "$card" ] || continue
        vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
        [ "$vendor" = "0x8086" ] || continue

        for file in "$card/gt_busy_percent" "$card/device/gpu_busy_percent"; do
            [ -r "$file" ] || continue
            value="$(cat "$file" 2>/dev/null || true)"
            if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                awk -v v="$value" 'BEGIN {if (v < 0) v=0; if (v > 100) v=100; printf "%.0f\n", v}'
                return 0
            fi
        done
    done

    return 1
}

while true; do
    gpu_busy=""
    if gpu_busy="$(intel_gpu_busy_from_top)"; then
        :
    elif gpu_busy="$(intel_gpu_busy_from_top_text)"; then
        :
    elif gpu_busy="$(intel_gpu_busy_from_sysfs)"; then
        :
    elif has_intel_gpu; then
        # Keep metric alive even when tooling output is temporarily unavailable.
        gpu_busy="0"
    fi

    if [ -n "$gpu_busy" ]; then
        publish_metric "hardware_intel_gpu_busy_pct" "$gpu_busy" "INTEGER" "$CYCLE" 0 100
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
