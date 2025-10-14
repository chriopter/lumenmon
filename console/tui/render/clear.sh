#!/bin/bash
# Terminal control functions using tput and stty for screen management and raw input mode.
# Provides alt screen, cursor control, colors, and raw terminal setup for responsive input. Sourced by tui.sh.

# Enter alternate screen buffer (saves terminal state)
enter_alt_screen() {
    tput smcup
}

# Exit alternate screen buffer (restores terminal)
exit_alt_screen() {
    tput rmcup
}

# Clear entire screen and move to top-left
clear_screen() {
    tput clear
}

# Move to home position (top-left)
move_home() {
    tput cup 0 0
}

# Hide cursor
hide_cursor() {
    tput civis
}

# Show cursor
show_cursor() {
    tput cnorm
}

# Move cursor to position (row, col)
move_to() {
    tput cup "$1" "$2"
}

# Clear from cursor to end of line
clear_line() {
    tput el
}

# Setup raw terminal mode for responsive non-blocking input
setup_terminal() {
    stty -echo -icanon time 0 min 0 2>/dev/null || true
}

# Restore normal terminal mode
restore_terminal() {
    stty sane 2>/dev/null || true
}

# Color functions using tput
color_red() { tput setaf 1; }
color_green() { tput setaf 2; }
color_yellow() { tput setaf 3; }
color_cyan() { tput setaf 6; }
color_dim() { tput dim; }
color_bold() { tput bold; }
color_reverse() { tput rev; }
color_reset() { tput sgr0; }

# Export color codes (for use in echo -e)
export RED=$(tput setaf 1)
export GREEN=$(tput setaf 2)
export YELLOW=$(tput setaf 3)
export CYAN=$(tput setaf 6)
export DIM=$(tput dim)
export BOLD=$(tput bold)
export REVERSE=$(tput rev)
export NC=$(tput sgr0)
