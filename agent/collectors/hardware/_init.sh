#!/bin/bash
# Hardware collectors - runs on real hardware hosts.
# Skips virtualized systems unless forced via config or Proxmox override.

CONFIG_FILE="$LUMENMON_DATA/config"

get_config() {
    local key="$1"
    awk -F= -v key="$key" '$1==key {sub(/^[ \t]+/,"",$2); sub(/[ \t]+$/,"",$2); print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true
}

force_hardware="$(get_config hardware_force)"
virt_mode="none"

if command -v systemd-detect-virt &>/dev/null; then
    virt_mode="$(systemd-detect-virt 2>/dev/null || true)"
    [ -z "$virt_mode" ] && virt_mode="unknown"
fi

if [ "${force_hardware:-0}" != "1" ] && [ "$virt_mode" != "none" ]; then
    # Proxmox hosts can report virtualization in some setups; still allow hardware collectors there.
    if ! command -v pvesh &>/dev/null; then
        return 0 2>/dev/null || true
    fi
fi

if [ "${force_hardware:-0}" = "1" ]; then
    echo "[agent] Hardware collectors enabled (forced)"
elif [ "$virt_mode" != "none" ]; then
    echo "[agent] Hardware collectors enabled (Proxmox override: virt=$virt_mode)"
else
    echo "[agent] Hardware collectors enabled"
fi

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in temp pcie_errors intel_gpu vram smart_values ssd_samsung; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "hardware_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
