#!/bin/bash
# CPU collector - Sends usage percentage at PULSE rhythm (10Hz)

# Config
RHYTHM="PULSE"   # Uses PULSE timing from agent.sh
PREFIX="cpu"      # Metric prefix: cpu_usage

set -euo pipefail

# Initialize CPU tracking from /proc/stat
# Format: cpu user nice system idle iowait irq softirq steal guest guest_nice
read line < /proc/stat
cpu=($line)
prev_idle=$((${cpu[4]} + ${cpu[5]}))  # idle + iowait
prev_total=0
for value in "${cpu[@]:1}"; do
    prev_total=$((prev_total + value))
done

# Main loop - calculate CPU usage and send
while true; do
    # Sleep first to ensure we have a time difference
    sleep $PULSE

    # Read current CPU state
    read line < /proc/stat
    cpu=($line)

    # Calculate idle and total
    idle=$((${cpu[4]} + ${cpu[5]}))
    total=0
    for value in "${cpu[@]:1}"; do
        total=$((total + value))
    done

    # Calculate usage percentage (non-idle time / total time * 100)
    diff_idle=$((idle - prev_idle))
    diff_total=$((total - prev_total))

    # Only calculate if we have a meaningful difference
    if [ $diff_total -gt 0 ]; then
        # Use awk for floating-point calculation with 1 decimal place
        usage=$(awk "BEGIN {printf \"%.1f\", ($diff_total - $diff_idle) * 100.0 / $diff_total}")
        # Clamp to 0-100 range using awk for float comparison
        usage=$(awk "BEGIN {if ($usage < 0) print \"0.0\"; else if ($usage > 100) print \"100.0\"; else print \"$usage\"}")
    else
        usage="0.0"
    fi

    # Send metric through transport
    echo -e "$(date +%s)\t$AGENT_ID\t${PREFIX}_usage\tfloat\t$usage\t$PULSE" | \
        eval "${LUMENMON_TRANSPORT:-cat}"

    # Update previous values for next iteration
    prev_idle=$idle
    prev_total=$total
done