#!/bin/bash
# Proxmox collectors - only runs on Proxmox VE hosts.
# Detects Proxmox by checking for pvesh command.

# Check if this is a Proxmox host (return early if not, don't exit - we're sourced)
if ! command -v pvesh &>/dev/null; then
    return 0 2>/dev/null || true
fi

echo "[agent] Proxmox detected"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in vms containers storage; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        "$COLLECTOR_DIR/${collector}.sh" 2>/tmp/collector_proxmox_${collector}.log &
    fi
done
