#!/bin/bash
# Collects GPU VRAM usage percentage when DRM VRAM counters are available.
# Exits cleanly on hosts without VRAM sysfs telemetry.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    vram_total=$(grep -hs . /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -n1 || true)
    vram_used=$(grep -hs . /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -n1 || true)
    if [ -n "$vram_total" ] && [ -n "$vram_used" ] && [ "$vram_total" -gt 0 ] 2>/dev/null; then
        vram_pct=$((vram_used * 100 / vram_total))
        publish_metric "hardware_gpu_vram_used_pct" "$vram_pct" "INTEGER" "$CYCLE" 0 95
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
