#!/bin/bash
# Collects CPU usage percentage from /proc/stat and publishes via MQTT.
# Calculates usage by comparing idle time between samples at PULSE interval (1s).

# Config
RHYTHM="PULSE"         # Uses PULSE timing from agent.sh (1s)
METRIC="generic_cpu"   # Metric name: generic_cpu
TYPE="REAL"            # SQLite column type for decimal values
MIN=0                  # Minimum value (percentage)
MAX=100                # Maximum value (percentage)

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Read initial CPU state
read prev_line < /proc/stat
prev_cpu=($prev_line)

# Main loop
while true; do
    sleep $PULSE

    # Read current state
    read curr_line < /proc/stat
    curr_cpu=($curr_line)

    # Calculate totals (user + nice + system + idle + iowait + irq + softirq + steal)
    prev_total=$((${prev_cpu[1]} + ${prev_cpu[2]} + ${prev_cpu[3]} + ${prev_cpu[4]} + ${prev_cpu[5]:-0} + ${prev_cpu[6]:-0} + ${prev_cpu[7]:-0} + ${prev_cpu[8]:-0}))
    curr_total=$((${curr_cpu[1]} + ${curr_cpu[2]} + ${curr_cpu[3]} + ${curr_cpu[4]} + ${curr_cpu[5]:-0} + ${curr_cpu[6]:-0} + ${curr_cpu[7]:-0} + ${curr_cpu[8]:-0}))
    # Idle = idle + iowait (CPU not doing work during I/O wait)
    prev_idle=$((${prev_cpu[4]} + ${prev_cpu[5]:-0}))
    curr_idle=$((${curr_cpu[4]} + ${curr_cpu[5]:-0}))

    # Calculate usage percentage
    total_d=$((curr_total - prev_total))
    idle_d=$((curr_idle - prev_idle))

    if [ $total_d -gt 0 ]; then
        usage=$(awk "BEGIN {printf \"%.1f\", ($total_d - $idle_d) * 100.0 / $total_d}")
    else
        usage="0.0"
    fi

    # Publish with interval and bounds
    publish_metric "$METRIC" "$usage" "$TYPE" "$PULSE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    # Save for next iteration
    prev_cpu=("${curr_cpu[@]}")
done
