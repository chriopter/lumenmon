#!/bin/bash
# Disk metrics collector - SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${DISK_SAMPLE_HZ:-0.1}  # Every 10 seconds default

# Get disk usage for all filesystems
get_disk_stats() {
    df -P | tail -n +2 | while read filesystem size used avail percent mount; do
        # Skip special filesystems
        if [[ "$filesystem" == tmpfs* ]] || [[ "$filesystem" == devtmpfs* ]] || [[ "$filesystem" == none* ]]; then
            continue
        fi

        # Remove % from percent
        percent=${percent%\%}

        # Sanitize mount point for metric name
        metric_name=$(echo "$mount" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/^_//' | sed 's/_$//')
        [ -z "$metric_name" ] && metric_name="root"

        echo "$metric_name $size $used $avail $percent $mount"
    done
}

# Main collection loop
main() {
    echo "[disk-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$(echo "scale=0; 1000000000 / $SAMPLE_HZ" | bc)
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)

        # Get disk stats for all filesystems
        get_disk_stats | while read name size used avail percent mount; do
            # Send metrics via SSH (TSV format) - convert KB to MB
            echo -e "$timestamp\t$AGENT_ID\tdisk_${name}_usage_percent\tfloat\t$percent\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tdisk_${name}_total_mb\tint\t$((size / 1024))\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tdisk_${name}_used_mb\tint\t$((used / 1024))\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tdisk_${name}_free_mb\tint\t$((avail / 1024))\t10" >&3
        done

        # Also get inode usage for root filesystem
        local inode_info=$(df -i / | tail -1)
        local inodes_percent=$(echo "$inode_info" | awk '{print $5}' | sed 's/%//')
        echo -e "$timestamp\t$AGENT_ID\tdisk_root_inodes_percent\tfloat\t$inodes_percent\t10" >&3

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
trap "echo '[disk-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main