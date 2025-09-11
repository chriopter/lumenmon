#!/bin/sh
# Proxmox VE metrics collector

# === TEMPO ===
TEMPO="adagio"

# === IDENTITY ===
GROUP="proxmox"
COLLECTOR="vms"
PREFIX="${GROUP}_${COLLECTOR}"

# === VALIDATE ===
# Check if this is a Proxmox system
if [ ! -f /usr/bin/pvesh ]; then
    exit 0
fi

# === COLLECT ===
# Count VMs
VM_COUNT=$(qm list 2>/dev/null | grep -c "^" || echo "0")

# Count containers
CT_COUNT=$(pct list 2>/dev/null | grep -c "^" || echo "0")

# Check cluster status
if [ -f /etc/pve/corosync.conf ]; then
    CLUSTER="yes"
else
    CLUSTER="no"
fi

# === OUTPUT ===
echo "${PREFIX}_count:${VM_COUNT}"
echo "${PREFIX}_containers:${CT_COUNT}"
echo "${PREFIX}_cluster:${CLUSTER}"