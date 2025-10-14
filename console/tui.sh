#!/bin/bash
# Pure bash TUI with double-buffering, event loop, and file caching for responsive monitoring dashboard.
# Sources modular components and runs event loop with 10ms input polling and 2s refresh rate.

set -u

# Source all modules
TUI_DIR="/app/tui"

# Core modules (state, caching)
for script in "$TUI_DIR/core"/*.sh; do
    [ -f "$script" ] && source "$script"
done

# Other modules (readers, render, views, input)
for module in readers render views input; do
    for script in "$TUI_DIR/$module"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
done

# Initialize state
init_state

# Cleanup on exit - restore terminal properly
cleanup() {
    show_cursor
    restore_terminal
    exit_alt_screen
    exit 0
}
trap cleanup INT TERM EXIT

# Initialize terminal
enter_alt_screen
hide_cursor
setup_terminal
clear_screen

# Initial render
NEEDS_REFRESH=1
NEEDS_RENDER=1

# Run event loop with 2-second refresh interval
run_event_loop 2
