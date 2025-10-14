#!/bin/bash
# Pure bash TUI dashboard that displays agent status, metrics, and sparklines in real-time.
# Sources modular components (readers, render, views, input) and runs main event loop with 2s refresh.
set -u

# Source all modules
TUI_DIR="/app/tui"

for module in readers render views input; do
    for script in "$TUI_DIR/$module"/*.sh; do
        [ -f "$script" ] && source "$script"
    done
done

# Global state
STATE="dashboard"
SELECTED_ROW=0
SELECTED_AGENT=""

# Cleanup on exit
cleanup() {
    show_cursor
    clear_screen
    exit 0
}
trap cleanup INT TERM

# Initialize
hide_cursor
full_clear  # Clear once at startup

# Main loop
while true; do
    case "$STATE" in
        dashboard)
            view_dashboard
            ;;
        detail)
            view_detail "$SELECTED_AGENT"
            ;;
    esac

    # Handle input
    handle_input

    # Refresh rate (reduce from 1s to 2s for less flicker)
    sleep 2
done
