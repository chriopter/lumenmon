#!/bin/bash
# Hardware collectors - runs on real hardware hosts.
# Skips virtualized systems unless forced via config.

CONFIG_FILE="$LUMENMON_DATA/config"

get_config() {
    local key="$1"
    awk -F= -v key="$key" '$1==key {sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true
}

force_hardware="$(get_config hardware_force)"

if command -v systemd-detect-virt &>/dev/null && [ "${force_hardware:-0}" != "1" ]; then
    if [ "$(systemd-detect-virt 2>/dev/null || echo unknown)" != "none" ]; then
        return 0 2>/dev/null || true
    fi
fi

echo "[agent] Hardware collectors enabled"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in temp pcie_errors intel_gpu vram smart_values ssd_samsung; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "hardware_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
