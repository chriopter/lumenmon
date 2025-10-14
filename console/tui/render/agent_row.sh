#!/bin/bash
# Draw a single agent row in the dashboard

draw_agent_row() {
    local agent=$1
    local selected=${2:-0}
    local row_num=$3

    # Get metrics
    local cpu=$(get_metric "$agent" "generic_cpu.tsv")
    local mem=$(get_metric "$agent" "generic_mem.tsv")
    local disk=$(get_metric "$agent" "generic_disk.tsv")
    local age=$(get_metric_age "$agent" "generic_cpu.tsv")

    # Default values if metrics not available
    cpu=${cpu:--}
    mem=${mem:--}
    disk=${disk:--}

    # Get sparklines (8 points for compact display)
    local cpu_history=$(get_history_line "$agent" "generic_cpu.tsv" 8)
    local cpu_spark=$(sparkline "$cpu_history")

    # Status indicator based on age
    local status="${DIM}○${NC}"  # Offline/unknown
    if [ "$age" != "999" ]; then
        if [ "$age" -lt 5 ]; then
            status="${GREEN}●${NC}"  # Fresh
        elif [ "$age" -lt 30 ]; then
            status="${YELLOW}●${NC}"  # Stale
        else
            status="${RED}●${NC}"  # Very stale
        fi
    fi

    # Selection indicator
    local arrow=" "
    [ "$selected" = "1" ] && arrow="▶"

    # Format values
    local cpu_display="${cpu:--}"
    local mem_display="${mem:--}"
    local disk_display="${disk:--}"

    [ "$cpu" != "-" ] && cpu_display=$(printf "%.1f%%" "$cpu")
    [ "$mem" != "-" ] && mem_display=$(printf "%.1f%%" "$mem")
    [ "$disk" != "-" ] && disk_display=$(printf "%.1f%%" "$disk")

    # Print row
    printf "${CYAN}│${NC} %s %b %-20s %s %8s %8s %8s %4ds ${CYAN}│${NC}\n" \
        "$arrow" "$status" "$agent" "$cpu_spark" "$cpu_display" "$mem_display" "$disk_display" "$age"
}
