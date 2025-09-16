#!/bin/bash
# Process metrics collector - SSH transport
set -euo pipefail

# Configuration from coordinator
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${AGENT_ID:-$(hostname -s)}
SSH_OPTS=${SSH_OPTS:-"-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"}
SAMPLE_HZ=${PROCESS_SAMPLE_HZ:-0.2}  # Every 5 seconds default

# Get process statistics
get_process_stats() {
    # Count processes by state
    local total=$(ps aux | wc -l)
    local running=$(ps aux | awk '$8 ~ /R/' | wc -l)
    local sleeping=$(ps aux | awk '$8 ~ /S/' | wc -l)
    local zombie=$(ps aux | awk '$8 ~ /Z/' | wc -l)

    echo "$total $running $sleeping $zombie"
}

# Get top processes by CPU
get_top_cpu_processes() {
    ps aux --sort=-%cpu | head -4 | tail -3 | while read user pid cpu mem vsz rss tty stat start time cmd; do
        # Truncate command to first word (process name)
        local proc_name=$(echo "$cmd" | awk '{print $1}' | xargs basename)
        echo "${proc_name}:${cpu}"
    done | tr '\n' ' '
}

# Get top processes by memory
get_top_mem_processes() {
    ps aux --sort=-%mem | head -4 | tail -3 | while read user pid cpu mem vsz rss tty stat start time cmd; do
        # Truncate command to first word (process name)
        local proc_name=$(echo "$cmd" | awk '{print $1}' | xargs basename)
        echo "${proc_name}:${mem}"
    done | tr '\n' ' '
}

# Main collection loop
main() {
    echo "[process-collector] Starting for $AGENT_ID at ${SAMPLE_HZ}Hz"

    # Open persistent SSH connection
    exec 3> >(ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} "/usr/local/bin/lumenmon-append --host '$AGENT_ID'")

    local period_ns=$(echo "scale=0; 1000000000 / $SAMPLE_HZ" | bc)
    local next_ns=$(date +%s%N)

    while true; do
        local timestamp=$(date +%s)

        # Get process stats
        read total running sleeping zombie <<< $(get_process_stats)

        # Send metrics via SSH (TSV format)
        echo -e "$timestamp\t$AGENT_ID\tproc_total\tint\t$total\t5" >&3
        echo -e "$timestamp\t$AGENT_ID\tproc_running\tint\t$running\t5" >&3
        echo -e "$timestamp\t$AGENT_ID\tproc_sleeping\tint\t$sleeping\t5" >&3
        echo -e "$timestamp\t$AGENT_ID\tproc_zombie\tint\t$zombie\t5" >&3

        # Get thread count
        local threads=$(ps -eo nlwp | tail -n +2 | awk '{s+=$1} END {print s}')
        echo -e "$timestamp\t$AGENT_ID\tproc_threads\tint\t${threads:-0}\t5" >&3

        # Top processes (as string for now)
        local top_cpu=$(get_top_cpu_processes)
        local top_mem=$(get_top_mem_processes)
        echo -e "$timestamp\t$AGENT_ID\tproc_top_cpu\tstring\t${top_cpu// /_}\t5" >&3
        echo -e "$timestamp\t$AGENT_ID\tproc_top_mem\tstring\t${top_mem// /_}\t5" >&3

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
trap "echo '[process-collector] Shutting down...'; exit 0" SIGTERM SIGINT

# Start collection
main