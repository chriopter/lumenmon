#!/bin/bash
# CPU metrics collector - High frequency sampling with SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${CPU_SAMPLE_HZ:-10}  # 10Hz default for CPU

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

# Get additional CPU metrics
get_cpu_cores() {
    grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
}

get_load_avg() {
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

# Main collection loop
main() {
    echo "[cpu-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Initialize CPU tracking
    read_cpu_initial

    # Get static values
    local cpu_cores=$(get_cpu_cores)

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$((1000000000 / SAMPLE_HZ))
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)

        # High frequency CPU percentage
        local cpu_pct=$(get_cpu_percent)
        echo -e "$timestamp\t$AGENT_ID\tcpu_usage\tfloat\t$cpu_pct\t$(echo "scale=1; 1/$SAMPLE_HZ" | bc)" >&3

        # Lower frequency metrics (every 10 samples)
        if [ $((timestamp % 10)) -eq 0 ]; then
            # Load averages
            local loads=$(get_load_avg)
            local load1=$(echo $loads | cut -d' ' -f1)
            local load5=$(echo $loads | cut -d' ' -f2)
            local load15=$(echo $loads | cut -d' ' -f3)

            echo -e "$timestamp\t$AGENT_ID\tcpu_cores\tint\t$cpu_cores\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tload_1min\tfloat\t$load1\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tload_5min\tfloat\t$load5\t10" >&3
            echo -e "$timestamp\t$AGENT_ID\tload_15min\tfloat\t$load15\t10" >&3
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
trap "echo '[cpu-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main