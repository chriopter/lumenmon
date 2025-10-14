#!/bin/bash
# Renders TUI footer showing available keyboard shortcuts for dashboard and detail views.
# Displays context-sensitive keybindings (navigation, invite, copy, refresh, quit). Sourced by tui.sh.
draw_footer() {
    local view=${1:-dashboard}

    draw_bottom

    if [ "$view" = "dashboard" ]; then
        echo -e "${DIM}[↑↓] Navigate  [Enter] Detail  [i] Invite  [c] Copy  [r] Refresh  [q] Quit${NC}"
    else
        echo -e "${DIM}[Esc] Back  [r] Refresh  [q] Quit${NC}"
    fi
}
