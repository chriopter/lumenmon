#!/bin/bash
# Provides ANSI escape code functions for cursor control, screen clearing, and color codes.
# Exports color codes and functions: clear_screen(), hide_cursor(), show_cursor(), move_to(), clear_line(). Sourced by tui.sh.
# Clear entire screen and move to top-left
clear_screen() {
    printf '\033[H'  # Just move to top-left, don't clear (smoother)
}

# Full clear (for initial setup)
full_clear() {
    printf '\033[2J\033[H'
}

# Hide cursor
hide_cursor() {
    printf '\033[?25l'
}

# Show cursor
show_cursor() {
    printf '\033[?25h'
}

# Move cursor to position (row, col)
move_to() {
    printf '\033[%d;%dH' "$1" "$2"
}

# Clear from cursor to end of line
clear_line() {
    printf '\033[K'
}

# Color codes
export RED='\033[31m'
export GREEN='\033[32m'
export YELLOW='\033[33m'
export CYAN='\033[36m'
export DIM='\033[2m'
export BOLD='\033[1m'
export REVERSE='\033[7m'  # Reverse video (highlight)
export NC='\033[0m'  # No Color / Reset
