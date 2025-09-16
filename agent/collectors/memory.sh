#!/bin/bash
# Memory metrics collector - SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${MEMORY_SAMPLE_HZ:-1}  # 1Hz default for memory

# Get memory metrics
get_memory_stats() {
    local mem_total=0 mem_free=0 mem_available=0 swap_total=0 swap_free=0

    while IFS=: read -r key value; do
        case "$key" in
            MemTotal)
                mem_total=$(echo "$value" | awk '{print $1}')
                ;;
            MemFree)
                mem_free=$(echo "$value" | awk '{print $1}')
                ;;
            MemAvailable)
                mem_available=$(echo "$value" | awk '{print $1}')
                ;;
            SwapTotal)
                swap_total=$(echo "$value" | awk '{print $1}')
                ;;
            SwapFree)
                swap_free=$(echo "$value" | awk '{print $1}')
                ;;
        esac
    done < /proc/meminfo

    # Calculate percentages
    local mem_percent=0 swap_percent=0
    if [ "$mem_total" -gt 0 ]; then
        local mem_used=$((mem_total - mem_available))
        mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)
    fi
    if [ "$swap_total" -gt 0 ]; then
        local swap_used=$((swap_total - swap_free))
        swap_percent=$(echo "scale=2; $swap_used * 100 / $swap_total" | bc)
    fi

    echo "$mem_total $mem_available $mem_free $mem_percent $swap_total $swap_free $swap_percent"
}

# Main collection loop
main() {
    echo "[memory-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$((1000000000 / SAMPLE_HZ))
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)

        # Get memory stats
        read mem_total mem_available mem_free mem_percent swap_total swap_free swap_percent <<< $(get_memory_stats)

        # Send metrics via SSH (TSV format)
        echo -e "$timestamp\t$AGENT_ID\tmem_usage_percent\tfloat\t$mem_percent\t1" >&3
        echo -e "$timestamp\t$AGENT_ID\tmem_total_mb\tint\t$((mem_total / 1024))\t1" >&3
        echo -e "$timestamp\t$AGENT_ID\tmem_available_mb\tint\t$((mem_available / 1024))\t1" >&3
        echo -e "$timestamp\t$AGENT_ID\tmem_free_mb\tint\t$((mem_free / 1024))\t1" >&3

        if [ "$swap_total" -gt 0 ]; then
            echo -e "$timestamp\t$AGENT_ID\tswap_usage_percent\tfloat\t$swap_percent\t1" >&3
            echo -e "$timestamp\t$AGENT_ID\tswap_total_mb\tint\t$((swap_total / 1024))\t1" >&3
            echo -e "$timestamp\t$AGENT_ID\tswap_free_mb\tint\t$((swap_free / 1024))\t1" >&3
        fi

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
trap "echo '[memory-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main