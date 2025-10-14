#!/bin/bash
# Builds detail view as string buffer with agent header and three ASCII line charts for metrics.
# Returns accumulated buffer showing CPU, memory, and disk usage over time. Sourced by tui.sh.

view_detail() {
    local agent=$1
    local buf=""

    [ -z "$agent" ] && return 1

    # Header
    buf+="${CYAN}${BOLD}┌─ LUMENMON ─────────────────────────────────────────────────────────────────┐${NC}"$'\n'
    buf+="${CYAN}│${NC} ${BOLD}Agent Detail:${NC} ${agent}                                                 ${CYAN}│${NC}"$'\n'
    buf+="${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"$'\n'

    # Get metric histories from cache (60 points for good detail)
    local cpu_history=${HISTORY_CPU[$agent]:-}
    local mem_history=${HISTORY_MEM[$agent]:-}
    local disk_history=${HISTORY_DISK[$agent]:-}

    # CPU Chart
    if [ -n "$cpu_history" ]; then
        buf+="$(plot_line "CPU Usage (last 60 samples)" "$cpu_history" 8)"$'\n'
    else
        buf+="┌─ CPU Usage ─ No Data ─────────────────┐"$'\n'
        buf+="│ No CPU data available                 │"$'\n'
        buf+="└────────────────────────────────────────┘"$'\n'
    fi

    buf+=$'\n'

    # Memory Chart
    if [ -n "$mem_history" ]; then
        buf+="$(plot_line "Memory Usage (last 60 samples)" "$mem_history" 8)"$'\n'
    else
        buf+="┌─ Memory Usage ─ No Data ───────────────┐"$'\n'
        buf+="│ No memory data available               │"$'\n'
        buf+="└────────────────────────────────────────┘"$'\n'
    fi

    buf+=$'\n'

    # Disk Chart
    if [ -n "$disk_history" ]; then
        buf+="$(plot_line "Disk Usage (last 60 samples)" "$disk_history" 8)"$'\n'
    else
        buf+="┌─ Disk Usage ─ No Data ─────────────────┐"$'\n'
        buf+="│ No disk data available                 │"$'\n'
        buf+="└────────────────────────────────────────┘"$'\n'
    fi

    buf+=$'\n'

    # Footer
    buf+="${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"$'\n'
    buf+="${DIM}[ESC] Back to Dashboard  [r] Refresh  [q] Quit${NC}"$'\n'

    # Return buffer
    echo -n "$buf"
}
