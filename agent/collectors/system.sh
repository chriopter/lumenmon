#!/bin/bash
# System information collector - SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${SYSTEM_SAMPLE_HZ:-0.017}  # Once per minute default

# Get system information
get_system_info() {
    # OS Detection
    local os_type="unknown"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type="${ID:-unknown}"
    elif [ -f /proc/version ]; then
        local kernel_info=$(cat /proc/version)
        if echo "$kernel_info" | grep -q "pve"; then
            os_type="proxmox"
        elif echo "$kernel_info" | grep -qi "debian"; then
            os_type="debian"
        elif echo "$kernel_info" | grep -qi "ubuntu"; then
            os_type="ubuntu"
        elif echo "$kernel_info" | grep -qi "alpine"; then
            os_type="alpine"
        fi
    fi

    # Kernel version
    local kernel=$(uname -r 2>/dev/null || echo "unknown")

    # Architecture
    local arch=$(uname -m 2>/dev/null || echo "unknown")

    # Container detection
    local container="none"
    if [ -f /.dockerenv ]; then
        container="docker"
    elif [ -f /run/.containerenv ]; then
        container="podman"
    elif [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
        container="kubernetes"
    elif grep -q lxc /proc/1/cgroup 2>/dev/null; then
        container="lxc"
    fi

    echo "$os_type $kernel $arch $container"
}

# Get uptime in seconds
get_uptime() {
    if [ -f /proc/uptime ]; then
        cat /proc/uptime | awk '{print int($1)}'
    else
        echo "0"
    fi
}

# Main collection loop
main() {
    echo "[system-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Get static system info
    read os_type kernel arch container <<< $(get_system_info)

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$(echo "scale=0; 1000000000 / $SAMPLE_HZ" | bc)
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)

        # Dynamic metrics
        local uptime=$(get_uptime)
        local uptime_days=$((uptime / 86400))
        local uptime_hours=$(((uptime % 86400) / 3600))

        # Send metrics via SSH (TSV format)
        echo -e "$timestamp\t$AGENT_ID\tsys_os\tstring\t$os_type\t60" >&3
        echo -e "$timestamp\t$AGENT_ID\tsys_kernel\tstring\t$kernel\t60" >&3
        echo -e "$timestamp\t$AGENT_ID\tsys_arch\tstring\t$arch\t60" >&3
        echo -e "$timestamp\t$AGENT_ID\tsys_container\tstring\t$container\t60" >&3
        echo -e "$timestamp\t$AGENT_ID\tsys_uptime_seconds\tint\t$uptime\t60" >&3
        echo -e "$timestamp\t$AGENT_ID\tsys_uptime_days\tint\t$uptime_days\t60" >&3

        # Also send boot time
        local boot_time=$((timestamp - uptime))
        echo -e "$timestamp\t$AGENT_ID\tsys_boot_time\tint\t$boot_time\t60" >&3

        # Precise timing
        next_ns=$((next_ns + period_ns))
        local now_ns=$(date +%s%N)
        local sleep_ns=$((next_ns - now_ns))

        if [ $sleep_ns -gt 0 ]; then
            local sleep_s=$((sleep_ns / 1000000000))
            local sleep_ns_remainder=$((sleep_ns % 1000000000))
            sleep "${sleep_s}.$(printf "%09d" $sleep_ns_remainder)"
        else
            next_ns=$now_ns
        fi
    done
}

# Trap for clean shutdown
trap "echo '[system-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main