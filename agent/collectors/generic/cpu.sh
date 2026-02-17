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

count_cpu_set() {
    local cpu_set="$1"
    local total=0
    local part=""
    local start=""
    local end=""

    [ -z "$cpu_set" ] && { echo 1; return; }

    IFS=',' read -ra parts <<< "$cpu_set"
    for part in "${parts[@]}"; do
        if [[ "$part" == *-* ]]; then
            start="${part%-*}"
            end="${part#*-}"
            if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]] && [ "$end" -ge "$start" ]; then
                total=$((total + end - start + 1))
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            total=$((total + 1))
        fi
    done

    [ "$total" -gt 0 ] || total=1
    echo "$total"
}

read_cgroup_usage_usec() {
    if [ -r /sys/fs/cgroup/cpu.stat ]; then
        awk '/^usage_usec / {print $2; exit}' /sys/fs/cgroup/cpu.stat
        return
    fi
    if [ -r /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
        awk '{print int($1/1000)}' /sys/fs/cgroup/cpuacct/cpuacct.usage
        return
    fi
    echo ""
}

detect_effective_cpus() {
    local cpus_file=""
    local cpus=""

    for cpus_file in /sys/fs/cgroup/cpuset.cpus.effective /sys/fs/cgroup/cpuset/cpuset.cpus /sys/fs/cgroup/cpuset.cpus; do
        if [ -r "$cpus_file" ]; then
            cpus="$(tr -d '[:space:]' < "$cpus_file" 2>/dev/null || true)"
            if [ -n "$cpus" ]; then
                count_cpu_set "$cpus"
                return
            fi
        fi
    done

    nproc 2>/dev/null || echo 1
}

CGROUP_MODE=0
prev_cgroup_usage=""
prev_wall_usec=""
effective_cpus="$(detect_effective_cpus)"

if [ -r /sys/fs/cgroup/cpu.stat ] || [ -r /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
    prev_cgroup_usage="$(read_cgroup_usage_usec)"
    if [ -n "$prev_cgroup_usage" ]; then
        prev_wall_usec="$(date +%s%6N)"
        CGROUP_MODE=1
    fi
fi

# Read initial CPU state
read prev_line < /proc/stat
prev_cpu=($prev_line)

# Main loop
while true; do
    sleep $PULSE

    if [ "$CGROUP_MODE" -eq 1 ]; then
        curr_cgroup_usage="$(read_cgroup_usage_usec)"
        curr_wall_usec="$(date +%s%6N)"

        if [ -n "$curr_cgroup_usage" ] && [ -n "$prev_cgroup_usage" ] && [ -n "$prev_wall_usec" ]; then
            usage_d=$((curr_cgroup_usage - prev_cgroup_usage))
            wall_d=$((curr_wall_usec - prev_wall_usec))
            if [ "$usage_d" -ge 0 ] && [ "$wall_d" -gt 0 ] && [ "$effective_cpus" -gt 0 ]; then
                usage=$(LC_ALL=C awk -v u="$usage_d" -v w="$wall_d" -v c="$effective_cpus" 'BEGIN {v=(u*100.0)/(w*c); if (v<0) v=0; if (v>100) v=100; printf "%.1f", v}')
            else
                usage="0.0"
            fi
            prev_cgroup_usage="$curr_cgroup_usage"
            prev_wall_usec="$curr_wall_usec"
        else
            usage="0.0"
        fi
    else
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
            usage=$(LC_ALL=C awk "BEGIN {printf \"%.1f\", ($total_d - $idle_d) * 100.0 / $total_d}")
        else
            usage="0.0"
        fi

        # Save for next iteration
        prev_cpu=("${curr_cpu[@]}")
    fi

    # Publish with interval and bounds
    publish_metric "$METRIC" "$usage" "$TYPE" "$PULSE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

done
