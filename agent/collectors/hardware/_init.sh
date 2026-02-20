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
is_proxmox_host=0

has_passthrough_gpu() {
    local vendor_file=""
    local vendor=""

    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        return 0
    fi

    for vendor_file in /sys/class/drm/card*/device/vendor; do
        [ -f "$vendor_file" ] || continue
        vendor="$(cat "$vendor_file" 2>/dev/null || true)"
        case "$vendor" in
            0x8086|0x10de|0x1002)
                return 0
                ;;
        esac
    done

    return 1
}

if command -v pvesh &>/dev/null || [ -x /usr/sbin/pvesh ] || [ -x /sbin/pvesh ] || [ -f /etc/pve/.version ]; then
    is_proxmox_host=1
fi

if command -v systemd-detect-virt &>/dev/null; then
    virt_mode="$(systemd-detect-virt 2>/dev/null || true)"
    [ -z "$virt_mode" ] && virt_mode="unknown"
fi

collectors=(temp pcie_errors intel_gpu vram smart_values ssd_samsung)

if [ "${force_hardware:-0}" = "1" ]; then
    echo "[agent] Hardware collectors enabled (forced)"
elif [ "$virt_mode" != "none" ]; then
    # Proxmox hosts can report virtualization in some setups; still allow all hardware collectors there.
    if [ "$is_proxmox_host" -eq 1 ]; then
        echo "[agent] Hardware collectors enabled (Proxmox override: virt=$virt_mode)"
    elif has_passthrough_gpu; then
        collectors=(intel_gpu vram)
        echo "[agent] Hardware collectors enabled (GPU passthrough VM: virt=$virt_mode)"
    else
        return 0 2>/dev/null || true
    fi
else
    echo "[agent] Hardware collectors enabled"
fi

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in "${collectors[@]}"; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "hardware_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
