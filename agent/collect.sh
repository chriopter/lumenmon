#!/bin/bash
# CPU collector - 10Hz sampling, sends TSV to server via SSH
set -euo pipefail

# Configuration
SERVER_HOST=${SERVER_HOST:-server}
SERVER_PORT=${SERVER_PORT:-22}
SERVER_USER=${SERVER_USER:-collector}
SAMPLE_HZ=${SAMPLE_HZ:-10}
BUFFER_SIZE=${BUFFER_SIZE:-100}  # Buffer before sending
CLIENT_ID=${HOSTNAME:-$(hostname -s)}

# SSH options for persistent connection
SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"

# Initialize CPU tracking
prev_idle=0
prev_total=0

# Read initial CPU state
read_cpu_initial() {
    local cpu line
    while IFS= read -r line; do
        if [[ $line == cpu\ * ]]; then
            cpu=($line)
            local idle=$((${cpu[4]} + ${cpu[5]}))
            local total=0
            for val in "${cpu[@]:1}"; do
                total=$((total + val))
            done
            prev_idle=$idle
            prev_total=$total
            break
        fi
    done < /proc/stat
}

# Calculate CPU percentage
get_cpu_percent() {
    local cpu line
    while IFS= read -r line; do
        if [[ $line == cpu\ * ]]; then
            cpu=($line)
            local idle=$((${cpu[4]} + ${cpu[5]}))
            local total=0
            for val in "${cpu[@]:1}"; do
                total=$((total + val))
            done

            local didle=$((idle - prev_idle))
            local dtotal=$((total - prev_total))

            if [ $dtotal -gt 0 ]; then
                local used=$((dtotal - didle))
                local percent=$((used * 100 / dtotal))
                echo "$percent"
            else
                echo "0"
            fi

            prev_idle=$idle
            prev_total=$total
            break
        fi
    done < /proc/stat
}

# Main collection loop
main() {
    echo "[collector] Starting CPU collector for $CLIENT_ID at ${SAMPLE_HZ}Hz"

    # Initialize CPU tracking
    read_cpu_initial

    # Create SSH connection
    echo "[collector] Connecting to $SERVER_HOST:$SERVER_PORT as $SERVER_USER"

    # Buffer for batching
    local buffer=""
    local count=0
    local period_ns=$((1000000000 / SAMPLE_HZ))
    local next_ns=$(date +%s%N)

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $SERVER_PORT ${SERVER_USER}@${SERVER_HOST} "/usr/local/bin/lumenmon-append --host '$CLIENT_ID'")

    while true; do
        # Get CPU percentage
        local cpu_pct=$(get_cpu_percent)
        local timestamp=$(date +%s)

        # Format as TSV: timestamp, host, metric, type, value, interval
        local tsv_line="$timestamp	$CLIENT_ID	cpu_usage	float	$cpu_pct	0.1"

        # Send immediately for real-time updates
        echo "$tsv_line" >&3

        # Calculate sleep time for precise timing
        next_ns=$((next_ns + period_ns))
        local now_ns=$(date +%s%N)
        local sleep_ns=$((next_ns - now_ns))

        if [ $sleep_ns -gt 0 ]; then
            # Convert to seconds.nanoseconds format
            local sleep_s=$((sleep_ns / 1000000000))
            local sleep_ns_remainder=$((sleep_ns % 1000000000))
            sleep "${sleep_s}.$(printf "%09d" $sleep_ns_remainder)"
        else
            # We're behind schedule, reset
            next_ns=$now_ns
        fi
    done
}

# Trap to ensure clean shutdown
trap "echo '[collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main