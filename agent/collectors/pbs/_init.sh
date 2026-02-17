#!/bin/bash
# PBS collectors - only runs on Proxmox Backup Server hosts.
# Starts focused PBS checks when proxmox-backup-manager is available.

if ! command -v proxmox-backup-manager &>/dev/null; then
    return 0 2>/dev/null || true
fi

echo "[agent] PBS detected"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in datastore_count task_failures backup_age verify_age sync_age gc_age; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "pbs_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
