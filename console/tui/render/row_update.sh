#!/bin/bash
# Differential row rendering for instant navigation - only redraws changed rows instead of full screen.
# Provides targeted cursor positioning and single-row updates like htop/vim. Sourced by tui.sh.

# Redraw a single agent row at specific screen position
# Usage: redraw_single_row <screen_row> <agent_id> <selected>
redraw_single_row() {
    local screen_row=$1
    local agent=$2
    local selected=$3

    # Move cursor to row
    printf '\e[%d;1H' "$screen_row"

    # Build and output row (writes to ROW_BUFFER)
    build_agent_row "$agent" "$selected" 0

    # Output row and clear to end of line
    printf '%s\e[K\n' "$ROW_BUFFER"
}

# Update selection highlight (unhighlight old, highlight new)
# Usage: update_selection <old_row_idx> <new_row_idx>
update_selection() {
    local old_idx=$1
    local new_idx=$2

    # Skip if same row
    [ "$old_idx" -eq "$new_idx" ] && return 0

    # Get agent list
    local agents=($(get_agents))
    local agent_count=${#agents[@]}

    # Calculate pagination
    local max_visible=20
    local start_idx=0

    if [ $agent_count -gt $max_visible ]; then
        start_idx=$((new_idx - max_visible / 2))
        [ $start_idx -lt 0 ] && start_idx=0
        [ $start_idx -gt $((agent_count - max_visible)) ] && start_idx=$((agent_count - max_visible))
    fi

    local end_idx=$((start_idx + max_visible))
    [ $end_idx -gt $agent_count ] && end_idx=$agent_count

    # If selection moved outside visible range, need full redraw
    if [ "$old_idx" -lt "$start_idx" ] || [ "$old_idx" -ge "$end_idx" ] || \
       [ "$new_idx" -lt "$start_idx" ] || [ "$new_idx" -ge "$end_idx" ]; then
        NEEDS_RENDER=1
        return 0
    fi

    # Calculate screen rows (header=1, section=1, table header=1, divider=1 = 4 lines offset)
    local old_screen_row=$((5 + old_idx - start_idx))
    local new_screen_row=$((5 + new_idx - start_idx))

    # Redraw both rows
    redraw_single_row "$old_screen_row" "${agents[$old_idx]}" 0
    redraw_single_row "$new_screen_row" "${agents[$new_idx]}" 1
}
