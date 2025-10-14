#!/bin/bash
# Double-buffering system to eliminate flicker by writing entire screen in single operation.
# Provides flush_buffer() which writes accumulated string buffer to terminal at once. Sourced by tui.sh.

# Flush accumulated buffer to screen in single write
# Usage: flush_buffer "$buffer_string"
flush_buffer() {
    local buffer="$1"

    # Move to home position (top-left) without clearing
    # Use escape sequence directly for speed
    printf '\e[H%s' "$buffer"
}

# Alternative: Line-diff flush (only redraws changed lines)
# Tracks previous frame and only updates modified lines
declare -a PREV_LINES

flush_buffer_diff() {
    local buffer="$1"
    local -a curr_lines

    # Split buffer into lines
    mapfile -t curr_lines <<<"$buffer"

    local max=${#curr_lines[@]}
    [ ${#PREV_LINES[@]} -gt $max ] && max=${#PREV_LINES[@]}

    # Update only changed lines
    for ((i=0; i<max; i++)); do
        if [ "${curr_lines[i]}" != "${PREV_LINES[i]}" ]; then
            # Move to line i+1, column 1
            printf '\e[%d;1H' $((i+1))
            # Write line and clear to end of line
            printf '%s\e[K' "${curr_lines[i]}"
        fi
    done

    # Store current frame for next comparison
    PREV_LINES=("${curr_lines[@]}")
}
