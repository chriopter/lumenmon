#!/bin/bash
# Renders single agent row with status indicator, sparkline, metrics, and highlight for selected row.
# Formats CPU/memory/disk values, generates sparkline, applies reverse video for selection. Sourced by tui.sh.
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

    # Format values
    local cpu_display="${cpu:--}"
    local mem_display="${mem:--}"
    local disk_display="${disk:--}"

    [ "$cpu" != "-" ] && cpu_display=$(printf "%.1f%%" "$cpu")
    [ "$mem" != "-" ] && mem_display=$(printf "%.1f%%" "$mem")
    [ "$disk" != "-" ] && disk_display=$(printf "%.1f%%" "$disk")

    # Print row with highlighting if selected
    if [ "$selected" = "1" ]; then
        # Reverse video for selected row
        printf "${CYAN}│${REVERSE} %b %-20s %s %8s %8s %8s %4ds ${NC}${CYAN}│${NC}" \
            "$status" "$agent" "$cpu_spark" "$cpu_display" "$mem_display" "$disk_display" "$age"
    else
        printf "${CYAN}│${NC}   %b %-20s %s %8s %8s %8s %4ds ${CYAN}│${NC}" \
            "$status" "$agent" "$cpu_spark" "$cpu_display" "$mem_display" "$disk_display" "$age"
    fi
    clear_line  # Clear rest of line to avoid artifacts
    echo  # Newline
}
