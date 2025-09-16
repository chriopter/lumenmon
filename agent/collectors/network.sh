#!/bin/bash
# Network metrics collector - SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${NETWORK_SAMPLE_HZ:-0.5}  # Every 2 seconds default

# Track previous values for rate calculation
prev_rx_bytes=0
prev_tx_bytes=0
prev_time=0

# Get network interface statistics
get_network_stats() {
    local primary_iface=$(ip route | grep default | awk '{print $5}' | head -1)

    if [ -z "$primary_iface" ]; then
        echo "0 0 0 0"
        return
    fi

    # Read interface statistics
    local rx_bytes=$(cat /sys/class/net/$primary_iface/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes=$(cat /sys/class/net/$primary_iface/statistics/tx_bytes 2>/dev/null || echo 0)
    local rx_packets=$(cat /sys/class/net/$primary_iface/statistics/rx_packets 2>/dev/null || echo 0)
    local tx_packets=$(cat /sys/class/net/$primary_iface/statistics/tx_packets 2>/dev/null || echo 0)

    echo "$rx_bytes $tx_bytes $rx_packets $tx_packets"
}

# Check connectivity
check_connectivity() {
    # Quick connectivity check
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        echo "1"
    else
        echo "0"
    fi
}

# Get latency
get_latency() {
    local latency=$(ping -c 1 -W 1 8.8.8.8 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1/' || echo "0")
    echo "${latency:-0}"
}

# Main collection loop
main() {
    echo "[network-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Initialize
    read prev_rx_bytes prev_tx_bytes rx_packets tx_packets <<< $(get_network_stats)
    prev_time=$(date +%s%N)

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$(echo "scale=0; 1000000000 / $SAMPLE_HZ" | bc)
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)
        local current_time=$(date +%s%N)

        # Get network stats
        read rx_bytes tx_bytes rx_packets tx_packets <<< $(get_network_stats)

        # Calculate rates
        local time_diff=$((current_time - prev_time))
        if [ $time_diff -gt 0 ]; then
            # Convert to Mbps
            local rx_rate=$(echo "scale=2; ($rx_bytes - $prev_rx_bytes) * 8 / $time_diff * 1000" | bc)
            local tx_rate=$(echo "scale=2; ($tx_bytes - $prev_tx_bytes) * 8 / $time_diff * 1000" | bc)

            echo -e "$timestamp\t$AGENT_ID\tnet_rx_mbps\tfloat\t$rx_rate\t2" >&3
            echo -e "$timestamp\t$AGENT_ID\tnet_tx_mbps\tfloat\t$tx_rate\t2" >&3
        fi

        # Total bytes (in MB)
        echo -e "$timestamp\t$AGENT_ID\tnet_rx_total_mb\tint\t$((rx_bytes / 1048576))\t2" >&3
        echo -e "$timestamp\t$AGENT_ID\tnet_tx_total_mb\tint\t$((tx_bytes / 1048576))\t2" >&3

        # Packet counts
        echo -e "$timestamp\t$AGENT_ID\tnet_rx_packets\tint\t$rx_packets\t2" >&3
        echo -e "$timestamp\t$AGENT_ID\tnet_tx_packets\tint\t$tx_packets\t2" >&3

        # Connectivity check (every 10 samples)
        if [ $((timestamp % 20)) -eq 0 ]; then
            local connected=$(check_connectivity)
            echo -e "$timestamp\t$AGENT_ID\tnet_connected\tint\t$connected\t20" >&3

            if [ "$connected" -eq 1 ]; then
                local latency=$(get_latency)
                echo -e "$timestamp\t$AGENT_ID\tnet_latency_ms\tfloat\t$latency\t20" >&3
            fi
        fi

        # Update previous values
        prev_rx_bytes=$rx_bytes
        prev_tx_bytes=$tx_bytes
        prev_time=$current_time

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
trap "echo '[network-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main