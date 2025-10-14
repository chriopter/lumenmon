#!/bin/bash
# Event loop with separated input polling (10ms) and rendering (2s) for responsive navigation.
# Uses EPOCHREALTIME for precise timing and interleaves input handling with periodic updates. Sourced by tui.sh.

# Main event loop
# Polls input at high frequency (10ms) while triggering renders at configurable interval
run_event_loop() {
    local render_interval=${1:-2}  # Seconds between renders (integer)
    local next_render=$((SECONDS + render_interval))

    while true; do
        # Fast input polling (makes UI feel responsive)
        handle_input || return 0  # Exit on quit action

        # Check if it's time to render (use bash $SECONDS builtin, no external process)
        if [ "$SECONDS" -ge "$next_render" ]; then
            # Only refresh if user idle for 1+ second (avoid lag during navigation)
            local idle_time=$((SECONDS - LAST_INPUT_TIME))
            if [ $idle_time -ge 1 ]; then
                NEEDS_REFRESH=1
            fi
            NEEDS_RENDER=1
            next_render=$((SECONDS + render_interval))
        fi

        # Perform render if needed
        if [ "$NEEDS_RENDER" -eq 1 ]; then
            perform_render
            NEEDS_RENDER=0
        fi

        # Small sleep to prevent 100% CPU usage
        # Use sleep with fractional seconds for 10ms delay
        sleep 0.01 2>/dev/null || sleep 1
    done
}

# Perform full render cycle
perform_render() {
    local buffer=""

    # Refresh data if needed
    if [ "$NEEDS_REFRESH" -eq 1 ]; then
        refresh_data
        NEEDS_REFRESH=0
    fi

    # Build buffer based on current view
    case "$STATE" in
        dashboard)
            buffer=$(view_dashboard)
            ;;
        detail)
            buffer=$(view_detail "$SELECTED_AGENT")
            ;;
    esac

    # Flush to screen
    flush_buffer "$buffer"
}

# Refresh data from disk (pure bash, no external processes)
refresh_data() {
    # Get agents (avoid subshell by using get_agents directly)
    local agents=($(get_agents))

    for agent in "${agents[@]}"; do
        local cpu_file="/data/agents/$agent/generic_cpu.tsv"
        local mem_file="/data/agents/$agent/generic_mem.tsv"
        local disk_file="/data/agents/$agent/generic_disk.tsv"

        # Read CPU metric and age (pure bash, no tail/awk/date)
        if [ -f "$cpu_file" ]; then
            local last_line
            read_last_line "$cpu_file" last_line

            local -a fields
            parse_tsv_line "$last_line" fields

            AGENT_CPU[$agent]="${fields[2]:--}"

            # Calculate age using EPOCHSECONDS (no date process)
            local ts="${fields[0]:-0}"
            AGENT_AGE[$agent]=$((EPOCHSECONDS - ts))
        else
            AGENT_CPU[$agent]="-"
            AGENT_AGE[$agent]=999
        fi

        # Read memory metric (pure bash)
        if [ -f "$mem_file" ]; then
            local last_line
            read_last_line "$mem_file" last_line

            local -a fields
            parse_tsv_line "$last_line" fields

            AGENT_MEM[$agent]="${fields[2]:--}"
        else
            AGENT_MEM[$agent]="-"
        fi

        # Read disk metric (pure bash)
        if [ -f "$disk_file" ]; then
            local last_line
            read_last_line "$disk_file" last_line

            local -a fields
            parse_tsv_line "$last_line" fields

            AGENT_DISK[$agent]="${fields[2]:--}"
        else
            AGENT_DISK[$agent]="-"
        fi

        # Read metric histories (60 points, pure bash - no tail/awk/tr)
        local -a cpu_history_lines mem_history_lines disk_history_lines

        read_last_n_lines "$cpu_file" 60 cpu_history_lines
        read_last_n_lines "$mem_file" 60 mem_history_lines
        read_last_n_lines "$disk_file" 60 disk_history_lines

        # Extract values (field 3) into space-separated strings
        extract_values cpu_history_lines HISTORY_CPU[$agent]
        extract_values mem_history_lines HISTORY_MEM[$agent]
        extract_values disk_history_lines HISTORY_DISK[$agent]

        # Pre-compute sparkline (last 8 points, no subshell)
        local cpu_hist="${HISTORY_CPU[$agent]}"
        if [ -n "$cpu_hist" ]; then
            local -a cpu_vals
            read -ra cpu_vals <<< "$cpu_hist"
            local total=${#cpu_vals[@]}
            local start=$((total > 8 ? total - 8 : 0))
            local last8="${cpu_vals[@]:$start:8}"

            # No subshell - write directly to variable
            sparkline_to_var "$last8" SPARKLINE_CPU[$agent]
        else
            SPARKLINE_CPU[$agent]=""
        fi
    done
}
