#!/bin/bash
# Collects CPU usage percentage from /proc/stat and sends via SSH every PULSE interval (1s).
# Outputs to generic_cpu.tsv on console with timestamp, interval, and usage value.

# Config
RHYTHM="PULSE"   # Uses PULSE timing from agent.sh
PREFIX="generic_cpu"      # Metric prefix: generic_cpu_usage

set -euo pipefail

# Read initial CPU state
read prev_line < /proc/stat
prev_cpu=($prev_line)

# Main loop - KISS CPU usage calculation
while true; do
    sleep $PULSE

    # Read current CPU state
    read curr_line < /proc/stat
    curr_cpu=($curr_line)

    # Simple calculation: just need total and idle
    # Fields after "cpu": user nice system idle (rest are optional)
    prev_total=$((${prev_cpu[1]} + ${prev_cpu[2]} + ${prev_cpu[3]} + ${prev_cpu[4]} + ${prev_cpu[5]:-0} + ${prev_cpu[6]:-0} + ${prev_cpu[7]:-0}))
    curr_total=$((${curr_cpu[1]} + ${curr_cpu[2]} + ${curr_cpu[3]} + ${curr_cpu[4]} + ${curr_cpu[5]:-0} + ${curr_cpu[6]:-0} + ${curr_cpu[7]:-0}))

    prev_idle=${prev_cpu[4]}
    curr_idle=${curr_cpu[4]}

    # Calculate CPU usage
    total_d=$((curr_total - prev_total))
    idle_d=$((curr_idle - prev_idle))

    if [ $total_d -gt 0 ]; then
        usage=$(awk "BEGIN {printf \"%.1f\", ($total_d - $idle_d) * 100.0 / $total_d}")
    else
        usage="0.0"
    fi

    # Send to console - no mkdir needed!
    echo -e "${PREFIX}.tsv\n$(date +%s) $PULSE $usage" | \
        ssh -S $SSH_SOCKET $AGENT_USER@$CONSOLE_HOST 2>/dev/null

    # Save current as previous for next iteration
    prev_cpu=("${curr_cpu[@]}")
done