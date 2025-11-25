#!/bin/bash
# Proxmox collectors - only runs on Proxmox VE hosts.
# Detects Proxmox by checking for pvesh command.

# Check if this is a Proxmox host
if ! command -v pvesh &>/dev/null; then
    exit 0
fi

echo "[agent] Proxmox detected"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in vms containers storage; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        "$COLLECTOR_DIR/${collector}.sh" 2>/tmp/collector_proxmox_${collector}.log &
    fi
done
