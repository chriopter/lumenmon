#!/bin/bash
# CPU collector - Sends usage percentage at PULSE rhythm (10Hz)

# Config
RHYTHM="PULSE"   # Uses PULSE timing from agent.sh
PREFIX="cpu"      # Metric prefix: cpu_usage

set -euo pipefail

# Read initial CPU state
read prev_line < /proc/stat
prev_cpu=($prev_line)

# Main loop - calculate CPU usage and send
while true; do
    sleep $PULSE

    # Read current CPU state
    read curr_line < /proc/stat
    curr_cpu=($curr_line)

    # Calculate deltas for each field (skip "cpu" label at index 0)
    # Fields: user nice system idle iowait irq softirq steal guest guest_nice
    user_d=$((${curr_cpu[1]} - ${prev_cpu[1]}))
    nice_d=$((${curr_cpu[2]} - ${prev_cpu[2]}))
    system_d=$((${curr_cpu[3]} - ${prev_cpu[3]}))
    idle_d=$((${curr_cpu[4]} - ${prev_cpu[4]}))
    iowait_d=$((${curr_cpu[5]:-0} - ${prev_cpu[5]:-0}))
    irq_d=$((${curr_cpu[6]:-0} - ${prev_cpu[6]:-0}))
    softirq_d=$((${curr_cpu[7]:-0} - ${prev_cpu[7]:-0}))
    steal_d=$((${curr_cpu[8]:-0} - ${prev_cpu[8]:-0}))

    # Total CPU time passed
    total_d=$((user_d + nice_d + system_d + idle_d + iowait_d + irq_d + softirq_d + steal_d))

    # Calculate usage (non-idle time / total time * 100)
    if [ $total_d -gt 0 ]; then
        # Active time = total - idle - iowait (iowait is considered idle)
        active_d=$((total_d - idle_d - iowait_d))
        usage=$(awk "BEGIN {printf \"%.1f\", $active_d * 100.0 / $total_d}")
    else
        usage="0.0"
    fi

    # Send metric through transport
    echo -e "$(date +%s)\t$AGENT_ID\t${PREFIX}_usage\tfloat\t$usage\t$PULSE" | \
        eval "${LUMENMON_TRANSPORT:-cat}"

    # Save current as previous for next iteration
    prev_cpu=("${curr_cpu[@]}")
done