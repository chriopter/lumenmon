#!/bin/sh
# System information collector

# === IDENTITY ===
GROUP="generic"
COLLECTOR="system"
PREFIX="${GROUP}_${COLLECTOR}"

# === COLLECT ===
# Hostname
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

# OS Detection from kernel
OS_TYPE="unknown"
if [ -f /proc/version ]; then
    KERNEL_INFO=$(cat /proc/version)
    
    # Detect specific distributions
    if echo "$KERNEL_INFO" | grep -q "pve"; then
        OS_TYPE="proxmox"
    elif echo "$KERNEL_INFO" | grep -qi "debian"; then
        OS_TYPE="debian"
    elif echo "$KERNEL_INFO" | grep -qi "ubuntu"; then
        OS_TYPE="ubuntu"
    elif echo "$KERNEL_INFO" | grep -qi "red hat\|centos\|rhel"; then
        OS_TYPE="redhat"
    elif echo "$KERNEL_INFO" | grep -qi "alpine"; then
        OS_TYPE="alpine"
    elif echo "$KERNEL_INFO" | grep -qi "arch"; then
        OS_TYPE="arch"
    fi
fi

# Kernel version
KERNEL_VERSION=$(uname -r 2>/dev/null || echo "unknown")

# Architecture
ARCH=$(uname -m 2>/dev/null || echo "unknown")

# Uptime in seconds
if [ -f /proc/uptime ]; then
    UPTIME=$(cat /proc/uptime | awk '{print int($1)}')
else
    UPTIME=0
fi

# Container detection
CONTAINER="no"
if [ -f /.dockerenv ]; then
    CONTAINER="docker"
elif [ -f /run/.containerenv ]; then
    CONTAINER="podman"
elif [ -n "$KUBERNETES_SERVICE_HOST" ]; then
    CONTAINER="kubernetes"
elif grep -q lxc /proc/1/cgroup 2>/dev/null; then
    CONTAINER="lxc"
fi

# === OUTPUT ===
echo "${PREFIX}_hostname:${HOSTNAME}"
echo "${PREFIX}_os:${OS_TYPE}"
echo "${PREFIX}_kernel:${KERNEL_VERSION}"
echo "${PREFIX}_arch:${ARCH}"
echo "${PREFIX}_uptime:${UPTIME}"
echo "${PREFIX}_container:${CONTAINER}"