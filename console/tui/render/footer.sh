#!/bin/bash
# Draw footer with keybindings

draw_footer() {
    local view=${1:-dashboard}

    draw_bottom

    if [ "$view" = "dashboard" ]; then
        echo -e "${DIM}[↑↓] Navigate  [Enter] Detail  [i] Invite  [c] Copy  [r] Refresh  [q] Quit${NC}"
    else
        echo -e "${DIM}[Esc] Back  [r] Refresh  [q] Quit${NC}"
    fi
}
