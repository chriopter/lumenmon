#!/bin/bash
# Agent detail view with graphs

view_detail() {
    local agent=$1

    [ -z "$agent" ] && return 1

    clear_screen

    # Header
    draw_header
    echo -e "${CYAN}│${NC} ${BOLD}Agent:${NC} ${agent}                                                          ${CYAN}│${NC}"
    draw_divider

    # CPU Section
    echo -e "${CYAN}│${NC} ${BOLD}CPU Usage${NC}                                                                    ${CYAN}│${NC}"

    local cpu=$(get_metric "$agent" "generic_cpu.tsv")
    local cpu_history=$(get_history_line "$agent" "generic_cpu.tsv" 60)

    if [ -n "$cpu_history" ]; then
        local cpu_spark=$(sparkline "$cpu_history")
        echo -e "${CYAN}│${NC}   ${cpu_spark}   ${NC}"

        # Calculate stats
        local values=($cpu_history)
        local sum=0
        local min=${values[0]}
        local max=${values[0]}

        for val in "${values[@]}"; do
            sum=$(echo "$sum + $val" | bc -l)
            (($(echo "$val < $min" | bc -l))) && min=$val
            (($(echo "$val > $max" | bc -l))) && max=$val
        done

        local avg=$(echo "scale=1; $sum / ${#values[@]}" | bc -l)
        local current=${cpu:-0}

        echo -e "${CYAN}│${NC}   Current: ${GREEN}${current}%${NC}  Min: ${min}%  Avg: ${avg}%  Max: ${max}%              ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│${NC}   ${DIM}No data available${NC}                                                         ${CYAN}│${NC}"
    fi

    draw_divider

    # Memory Section
    echo -e "${CYAN}│${NC} ${BOLD}Memory Usage${NC}                                                                 ${CYAN}│${NC}"

    local mem=$(get_metric "$agent" "generic_mem.tsv")
    local mem_history=$(get_history_line "$agent" "generic_mem.tsv" 60)

    if [ -n "$mem_history" ]; then
        local mem_spark=$(sparkline "$mem_history")
        echo -e "${CYAN}│${NC}   ${mem_spark}   ${NC}"

        local values=($mem_history)
        local sum=0
        local min=${values[0]}
        local max=${values[0]}

        for val in "${values[@]}"; do
            sum=$(echo "$sum + $val" | bc -l)
            (($(echo "$val < $min" | bc -l))) && min=$val
            (($(echo "$val > $max" | bc -l))) && max=$val
        done

        local avg=$(echo "scale=1; $sum / ${#values[@]}" | bc -l)
        local current=${mem:-0}

        echo -e "${CYAN}│${NC}   Current: ${GREEN}${current}%${NC}  Min: ${min}%  Avg: ${avg}%  Max: ${max}%              ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│${NC}   ${DIM}No data available${NC}                                                         ${CYAN}│${NC}"
    fi

    # Footer
    draw_footer "detail"
}
