#!/bin/bash
# ANSI escape codes for screen control

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

# Color codes
export RED='\033[31m'
export GREEN='\033[32m'
export YELLOW='\033[33m'
export CYAN='\033[36m'
export DIM='\033[2m'
export BOLD='\033[1m'
export NC='\033[0m'  # No Color / Reset
